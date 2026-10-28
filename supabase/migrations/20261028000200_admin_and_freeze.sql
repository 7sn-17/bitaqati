-- Proportional freeze allowance, and the admin surface the dashboard needs.
--
-- Two changes that belong together: the freeze became a share of the library
-- instead of a flat 25 decks, and the owner gained a way to issue and revoke
-- codes without opening the Supabase SQL editor.

-- ---------------------------------------------------------------------------
-- 1. Half the library stays open, never fewer than 20
-- ---------------------------------------------------------------------------

-- A lapsed subscriber used to keep a flat 25 decks whatever their library
-- looked like. That punished a small library and insulted a large one. The
-- allowance is now half the decks the device already holds, rounded up, with
-- the free floor underneath it. The client applies the same formula to decide
-- which decks to freeze, so the two cannot disagree about the number.
create or replace function public.deck_allowance(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select case
    when public.is_pro_user(p_user) then null
    else greatest(
      20,
      ceil(public.device_deck_count(p_user) / 2.0)::integer
    )
  end;
$function$;

comment on function public.deck_allowance(uuid) is
  'Decks a device may hold: unlimited while Pro, otherwise half of what it already has, at least 20.';

grant execute on function public.deck_allowance(uuid) to authenticated;

comment on column public.profiles.pro_expiry_date is
  'End of the paid period. Never null for someone who has ever subscribed, which is what keeps the paid palette after a lapse.';

-- ---------------------------------------------------------------------------
-- 2. Who may run the dashboard
-- ---------------------------------------------------------------------------

create table if not exists public.admins (
  email text primary key,
  note text,
  created_at timestamptz not null default now()
);

comment on table public.admins is
  'Emails allowed to issue codes and change a subscription from admin_dashboard.html.';

alter table public.admins enable row level security;

-- Read by the security-definer helper below and by nothing else. No policy and
-- no grant: the list of admins is not something a client may enumerate.
revoke all on table public.admins from anon, authenticated;

-- True for the signed-in account whose email is on the list.
--
-- Security definer because the caller cannot read public.admins, and the
-- answer is a single boolean rather than the row itself.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select exists (
    select 1
    from public.admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$function$;

grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. The entitlement guard learns about admins
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

  -- The dashboard writes is_pro and pro_expiry_date on purpose. The check is
  -- an email on the admins list, so a patched client still cannot claim it.
  if public.is_admin() then
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

-- ---------------------------------------------------------------------------
-- 4. The policies the dashboard signs in under
-- ---------------------------------------------------------------------------

-- Codes were readable by nobody but the service role, which is right for the
-- app and useless for the owner. The grant comes back only for authenticated,
-- and the policy narrows it to an admin.
grant select, insert, update, delete on public.activation_codes to authenticated;

drop policy if exists activation_codes_admin on public.activation_codes;
create policy activation_codes_admin
  on public.activation_codes for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- profiles_public_read already lets anyone list the accounts. What was missing
-- was the right to write someone else's row, which is how the dashboard turns
-- Pro on or off by hand.
drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write
  on public.profiles for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());
