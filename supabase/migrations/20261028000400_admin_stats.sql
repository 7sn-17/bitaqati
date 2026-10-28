-- The dashboard's numbers in one row.
--
-- Counting from the browser meant either downloading up to five hundred rows
-- to take their length, or asking for a HEAD count on tables whose row-level
-- security hides other people's rows from an admin — which returns a confident
-- zero. One security-definer call answers all six counts, checks is_admin()
-- itself, and transfers a single object.
create or replace function public.admin_stats()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.is_admin() then json_build_object(
      'users', (select count(*) from public.profiles),
      'pro', (select count(*) from public.profiles where is_pro),
      'decks', (select count(*) from public.decks where deleted_at is null),
      'cards', (select count(*) from public.cards where deleted_at is null),
      'codes', (select count(*) from public.activation_codes),
      'unused', (select count(*) from public.activation_codes where not is_used)
    )
    else null
  end;
$$;

comment on function public.admin_stats() is
  'Admin-only counters for the dashboard, in one row.';

revoke all on function public.admin_stats() from public;
grant execute on function public.admin_stats() to authenticated;
