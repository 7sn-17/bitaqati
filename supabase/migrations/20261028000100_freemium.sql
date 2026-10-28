-- Freemium: device-bound limits, entitlements and activation codes.
--
-- The client enforces the same numbers, but the client is a suggestion: an APK
-- can be patched, so the authoritative allowance lives here. Every rule below
-- is expressed as a trigger on the tables the app writes, which means a
-- decompiled build that skips its own guards still cannot create deck 21.

-- ---------------------------------------------------------------------------
-- 1. Entitlement columns
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists device_id text,
  add column if not exists is_pro boolean not null default false,
  add column if not exists pro_expiry_date timestamptz;

comment on column public.profiles.device_id is
  'Stable, hashed fingerprint of the phone. Free-tier limits are counted per device, so a second account on the same phone inherits them.';
comment on column public.profiles.is_pro is
  'Paid tier flag. Only the service role may change it; see profiles_guard_entitlement.';
comment on column public.profiles.pro_expiry_date is
  'End of the paid period. Never null for someone who has ever subscribed, which is what grants the 25-deck freeze bonus.';

-- Counting decks per device means a lookup by device on every insert.
create index if not exists profiles_device_idx
  on public.profiles (device_id)
  where device_id is not null;

-- ---------------------------------------------------------------------------
-- 2. Activation codes
-- ---------------------------------------------------------------------------

create table if not exists public.activation_codes (
  code text primary key,
  plan_type text not null check (plan_type in ('monthly', 'quarterly', 'yearly')),
  is_used boolean not null default false,
  -- Deadline for redeeming the code. Null means it never expires.
  expiry_date timestamptz,
  used_by uuid references public.profiles (id) on delete set null,
  used_at timestamptz,
  note text,
  created_at timestamptz not null default now()
);

comment on table public.activation_codes is
  'Manual-payment activation codes. Written and read only by the activate-code Edge Function, which holds the service key.';

alter table public.activation_codes enable row level security;

-- No policies at all, and the table grants are revoked: RLS with zero policies
-- denies everything to anon and authenticated, and the revoke means even a
-- future permissive policy cannot leak the list of unused codes.
revoke all on table public.activation_codes from anon, authenticated;

create index if not exists activation_codes_unused_idx
  on public.activation_codes (is_used)
  where is_used = false;

-- ---------------------------------------------------------------------------
-- 3. Nobody upgrades themselves
-- ---------------------------------------------------------------------------

create or replace function public.profiles_guard_entitlement()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
begin
  -- auth.uid() is null for every context that is not a signed-in client: the
  -- service key, the SQL editor, migrations, and the handle_new_user trigger
  -- that runs before a session exists. Those are the only callers allowed to
  -- write the paid columns.
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- profiles_insert_own lets a client create its own row, so without this a
    -- hand-written POST could arrive already Pro.
    if new.is_pro or new.pro_expiry_date is not null then
      raise exception 'The subscription can only be changed by the server'
        using errcode = 'insufficient_privilege';
    end if;
    return new;
  end if;

  if new.is_pro is distinct from old.is_pro
     or new.pro_expiry_date is distinct from old.pro_expiry_date then
    raise exception 'The subscription can only be changed by the server'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$function$;

drop trigger if exists profiles_guard_entitlement on public.profiles;
create trigger profiles_guard_entitlement
  before insert or update on public.profiles
  for each row execute function public.profiles_guard_entitlement();

comment on function public.profiles_guard_entitlement() is
  'Stops a client from writing is_pro or pro_expiry_date on its own profile row.';

-- ---------------------------------------------------------------------------
-- 4. Shared allowance helpers
-- ---------------------------------------------------------------------------

-- True when the account has an active paid period.
create or replace function public.is_pro_user(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select coalesce(
    (
      select p.is_pro
         and (p.pro_expiry_date is null or p.pro_expiry_date > now())
      from public.profiles p
      where p.id = p_user
    ),
    false
  );
$function$;

-- The device this account is bound to, or null when it has not reported one.
create or replace function public.device_of(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select nullif(p.device_id, '') from public.profiles p where p.id = p_user;
$function$;

-- Decks this device may hold. A lapsed subscriber keeps 25, a free account 20.
create or replace function public.deck_allowance(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select case
    when public.is_pro_user(p_user) then null
    when exists (
      select 1 from public.profiles p
      where p.id = p_user and p.pro_expiry_date is not null
    ) then 25
    else 20
  end;
$function$;

-- Decks already stored for this device, across every account on it.
create or replace function public.device_deck_count(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select count(*)::integer
  from public.decks d
  join public.profiles p on p.id = d.owner_id
  where d.deleted_at is null
    and (
      (
        public.device_of(p_user) is not null
        and p.device_id = public.device_of(p_user)
      )
      or (public.device_of(p_user) is null and d.owner_id = p_user)
    );
$function$;

-- Cards already stored for this device, across every account on it.
create or replace function public.device_card_count(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select count(*)::integer
  from public.cards c
  join public.decks d on d.id = c.deck_id
  join public.profiles p on p.id = d.owner_id
  where c.deleted_at is null
    and d.deleted_at is null
    and (
      (
        public.device_of(p_user) is not null
        and p.device_id = public.device_of(p_user)
      )
      or (public.device_of(p_user) is null and d.owner_id = p_user)
    );
$function$;

-- ---------------------------------------------------------------------------
-- 5. Deck and card ceilings
-- ---------------------------------------------------------------------------

create or replace function public.decks_enforce_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  allowance integer;
  used integer;
begin
  -- Only a signed-in client is limited. The service role, migrations and the
  -- publish helpers run with no JWT and must never be blocked.
  if auth.uid() is null then
    return new;
  end if;

  -- An upsert of a deck that already exists is not a new deck. Without this,
  -- a lapsed subscriber could never re-push the decks they already own.
  if exists (select 1 from public.decks where id = new.id) then
    return new;
  end if;

  allowance := public.deck_allowance(auth.uid());
  if allowance is null then
    return new;
  end if;

  used := public.device_deck_count(auth.uid());
  if used >= allowance then
    raise exception 'DECK_LIMIT_REACHED'
      using errcode = 'check_violation',
            hint = 'This device has reached the free deck allowance.';
  end if;

  return new;
end;
$function$;

drop trigger if exists decks_enforce_limit on public.decks;
create trigger decks_enforce_limit
  before insert on public.decks
  for each row execute function public.decks_enforce_limit();

create or replace function public.cards_enforce_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  allowance integer;
  used integer;
begin
  if auth.uid() is null then
    return new;
  end if;

  if exists (select 1 from public.cards where id = new.id) then
    return new;
  end if;

  if public.is_pro_user(auth.uid()) then
    return new;
  end if;

  allowance := 1000;
  used := public.device_card_count(auth.uid());
  if used >= allowance then
    raise exception 'CARD_LIMIT_REACHED'
      using errcode = 'check_violation',
            hint = 'This device has reached the free card allowance.';
  end if;

  return new;
end;
$function$;

drop trigger if exists cards_enforce_limit on public.cards;
create trigger cards_enforce_limit
  before insert on public.cards
  for each row execute function public.cards_enforce_limit();

comment on function public.decks_enforce_limit() is
  'Rejects a deck insert past the device allowance (20 free, 25 lapsed, unlimited pro).';

-- ---------------------------------------------------------------------------
-- 6. Grants
-- ---------------------------------------------------------------------------

revoke execute on function public.is_pro_user(uuid) from public, anon;
revoke execute on function public.device_of(uuid) from public, anon;
revoke execute on function public.deck_allowance(uuid) from public, anon;
revoke execute on function public.device_deck_count(uuid) from public, anon;
revoke execute on function public.device_card_count(uuid) from public, anon;

grant execute on function public.is_pro_user(uuid) to authenticated;
grant execute on function public.device_of(uuid) to authenticated;
grant execute on function public.deck_allowance(uuid) to authenticated;
grant execute on function public.device_deck_count(uuid) to authenticated;
grant execute on function public.device_card_count(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Redeeming a code, in one transaction
-- ---------------------------------------------------------------------------

-- The Edge Function could do this in three REST calls, but then a crash
-- between "mark used" and "grant" would burn a code the learner paid for.
-- One function, one transaction: either the code is spent and the account is
-- Pro, or nothing changed.
create or replace function public.redeem_activation_code(
  p_code text,
  p_user uuid
)
returns table (
  ok boolean,
  message text,
  plan_type text,
  expiry_date timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_code public.activation_codes%rowtype;
  v_months integer;
  v_base timestamptz;
  v_expiry timestamptz;
begin
  if p_user is null then
    return query select false, 'لا يوجد حساب لتفعيل الكود عليه.'::text,
      null::text, null::timestamptz;
    return;
  end if;

  select * into v_code
  from public.activation_codes c
  where upper(c.code) = upper(trim(p_code))
  for update;

  if not found then
    return query select false, 'هذا الكود غير صحيح. تأكد من الحروف والأرقام.'::text,
      null::text, null::timestamptz;
    return;
  end if;

  if v_code.is_used then
    return query select false, 'هذا الكود مستخدم من قبل. تواصل معنا إن كان خطأ.'::text,
      null::text, null::timestamptz;
    return;
  end if;

  if v_code.expiry_date is not null and v_code.expiry_date < now() then
    return query select false, 'انتهت صلاحية هذا الكود. اطلب كوداً جديداً.'::text,
      null::text, null::timestamptz;
    return;
  end if;

  v_months := case v_code.plan_type
    when 'monthly' then 1
    when 'quarterly' then 3
    else 12
  end;

  -- Renewing early stacks: the new months start where the paid period ends,
  -- never before today.
  select greatest(now(), coalesce(p.pro_expiry_date, now()))
    into v_base
  from public.profiles p
  where p.id = p_user;
  if v_base is null then
    v_base := now();
  end if;

  v_expiry := v_base + make_interval(months => v_months);

  update public.activation_codes
  set is_used = true, used_by = p_user, used_at = now()
  where code = v_code.code;

  -- Update first, then insert only when the row is missing. An insert with
  -- ON CONFLICT would still have to satisfy profiles.display_name NOT NULL,
  -- and a code redeemed by an account whose profile row never got created
  -- would fail at the worst possible moment.
  update public.profiles
  set is_pro = true,
      pro_expiry_date = v_expiry,
      updated_at = now()
  where id = p_user;

  if not found then
    insert into public.profiles (id, display_name, is_pro, pro_expiry_date, updated_at)
    values (p_user, '', true, v_expiry, now());
  end if;

  return query select true, 'تم تفعيل Pro على هذا الحساب.'::text,
    v_code.plan_type, v_expiry;
end;
$function$;

comment on function public.redeem_activation_code(text, uuid) is
  'Claims an unused code and grants its months atomically. Called by the activate-code function with the service key.';

revoke all on function public.redeem_activation_code(text, uuid)
  from public, anon, authenticated;

-- The Edge Function calls this with the service key. Revoking from public
-- removes the implicit grant that every role inherits, so it has to be given
-- back explicitly to the only role that should have it.
grant execute on function public.redeem_activation_code(text, uuid)
  to service_role;
