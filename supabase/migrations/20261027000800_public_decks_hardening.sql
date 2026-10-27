-- public_decks: read-only, and evaluated with the caller's rights.
--
-- The view was last recreated in 20261027000500 without `security_invoker`, so
-- it has been running as its owner and skipping RLS on decks/profiles. The
-- filter inside the view still hides everything private, but a projection that
-- bypasses RLS is one careless edit away from leaking rows. Turning the option
-- back on keeps the same result set -- the anon/authenticated policies already
-- allow public decks, public cards, public ratings and every profile.
--
-- The blanket grants Supabase puts on new objects also handed anon
-- INSERT/UPDATE/DELETE/TRUNCATE on a grouped view. Nothing can be written
-- through it, but the grants should not exist at all.

alter view public.public_decks set (security_invoker = true);

revoke all on public.public_decks from anon, authenticated;
grant select on public.public_decks to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Pin search_path on the helpers that still relied on the caller's path
-- ---------------------------------------------------------------------------

alter function public.handle_new_user() set search_path = public, pg_temp;

do $do$
declare
  entry record;
begin
  for entry in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proconfig is null
  loop
    execute format(
      'alter function %s set search_path = public, pg_temp',
      entry.signature
    );
  end loop;
end
$do$;

-- PostgREST caches view columns and grants; make it pick the new shape up.
notify pgrst, 'reload schema';
