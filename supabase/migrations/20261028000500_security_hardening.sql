-- Security hardening: admins, activation codes, profiles.
--
-- Everything here is idempotent: it can be applied to a fresh project or
-- re-applied to this one without changing the outcome.
--
-- The posture before this migration:
--   * public.admins had row-level security on and no policies, which is the
--     right shape, but no uniqueness on the email and no explicit revoke.
--   * public.activation_codes was already admin-only.
--   * public.profiles had USING (true) on SELECT, so any visitor — signed in or
--     not — could read every column of every row: device ids, Pro state and
--     expiry dates included.
--   * public.profiles let a user update any column of their own row. The
--     entitlement trigger stopped is_pro and pro_expiry_date, but not id, and
--     not device_id.

-- ---------------------------------------------------------------- admins ----

-- Admins are identified by email, so the email is the key: two rows with the
-- same address would mean two indistinguishable admins and an audit trail that
-- cannot say which one acted. Case-insensitive, because mail addresses are.
create unique index if not exists admins_email_lower_key
  on public.admins (lower(email));

alter table public.admins enable row level security;
-- Deliberately not FORCE: is_admin() is SECURITY DEFINER and runs as the table
-- owner, and forcing row-level security would subject that owner to policies
-- that, by design, do not exist — is_admin() would answer false forever.
alter table public.admins no force row level security;

-- Nothing on the client needs this table. is_admin() reads it as the definer.
revoke all on public.admins from anon, authenticated;

-- Any policy that ever existed here is dropped: the table is closed, and the
-- only reader is the function below.
do $$
declare
  p record;
begin
  for p in select policyname from pg_policies
           where schemaname = 'public' and tablename = 'admins'
  loop
    execute format('drop policy if exists %I on public.admins', p.policyname);
  end loop;
end;
$$;

-- The admin check. SECURITY DEFINER so it can read the closed table, with a
-- fixed search_path so a caller cannot shadow the tables it reads.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select exists (
    select 1
    from public.admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and coalesce(auth.jwt() ->> 'email', '') <> ''
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- --------------------------------------------------------- activation -------

alter table public.activation_codes enable row level security;

-- A code is a bearer instrument: whoever reads the table can redeem one, and
-- whoever writes it can mint Pro. No visitor role gets near it.
revoke all on public.activation_codes from anon;
revoke all on public.activation_codes from authenticated;
grant select, insert, update, delete on public.activation_codes to authenticated;

drop policy if exists activation_codes_admin on public.activation_codes;
create policy activation_codes_admin on public.activation_codes
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- -------------------------------------------------------------- profiles ----

alter table public.profiles enable row level security;

-- Who may be seen. A row is visible to its owner, to an admin, and to anyone
-- who is already being shown that person's name in the library: the author of
-- a published deck, or someone who reviewed one. That last clause is what keeps
-- the community screens working without exposing the whole directory.
create or replace function public.profile_is_public(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select exists (
           select 1
           from public.decks d
           where d.owner_id = p_id
             and d.published_at is not null
             and d.deleted_at is null
         )
      or exists (
           select 1
           from public.deck_ratings r
           join public.decks d on d.id = r.deck_id
           where r.user_id = p_id
             and d.published_at is not null
             and d.deleted_at is null
         );
$$;

revoke all on function public.profile_is_public(uuid) from public;
grant execute on function public.profile_is_public(uuid) to anon, authenticated;

drop policy if exists profiles_public_read on public.profiles;
drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_select_admin on public.profiles;
drop policy if exists profiles_select_public on public.profiles;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_select_admin on public.profiles
  for select to authenticated
  using (public.is_admin());

create policy profiles_select_public on public.profiles
  for select to anon, authenticated
  using (public.profile_is_public(id));

-- device_id identifies the install. The client writes it once, on first
-- launch, and never reads it back from the server, so the column is not part of
-- what a visitor may select — table-level SELECT is replaced by a column list.
revoke select on public.profiles from anon, authenticated;
grant select (
  id, username, display_name, display_name_custom, avatar_url, bio,
  is_pro, pro_expiry_date, created_at, updated_at
) on public.profiles to anon, authenticated;

-- --------------------------------------------------------- row guards -------

-- A user may edit their own row, but not its identity and not the two columns
-- that decide what they paid for. The entitlement half already existed; this
-- version adds the primary key and the device binding, and treats the service
-- role as trusted (edge functions run there, and have no JWT subject).
create or replace function public.profiles_guard_entitlement()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_role text := coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
    ''
  );
begin
  -- No session at all: the service key, the SQL editor, migrations, and the
  -- handle_new_user trigger that runs before a session exists.
  if auth.uid() is null or v_role = 'service_role' then
    return new;
  end if;

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

  if new.id is distinct from old.id then
    raise exception 'A profile cannot be moved to another account'
      using errcode = 'insufficient_privilege';
  end if;

  if new.is_pro is distinct from old.is_pro
     or new.pro_expiry_date is distinct from old.pro_expiry_date then
    raise exception 'The subscription can only be changed by the server'
      using errcode = 'insufficient_privilege';
  end if;

  -- The device binding is written once, when the install first syncs. Changing
  -- it later would let one account hop between devices to reset its limits.
  if old.device_id is not null
     and new.device_id is distinct from old.device_id then
    raise exception 'The device binding cannot be changed'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_guard_entitlement on public.profiles;
create trigger profiles_guard_entitlement
  before insert or update on public.profiles
  for each row execute function public.profiles_guard_entitlement();

-- Keep the write policies explicit rather than inherited from an older run.
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));
