-- Flatten the deck hierarchy.
--
-- Phase 1 gave `decks` a self-referencing tree (parent_id / root_id / path /
-- depth) plus the triggers and indexes that maintained it. The app has since
-- moved to a flat model -- a deck owns cards, nothing else -- and
-- lib/data/local/app_database.dart already dropped the same columns locally in
-- schema v5. The remote table is the last place where the dead tree survives.
--
-- Order matters: the trigger function reads the tree columns, so it is
-- rewritten before the columns go away.

-- ---------------------------------------------------------------------------
-- 1. Keep the published_at guarantee, drop the tree bookkeeping
-- ---------------------------------------------------------------------------

create or replace function public.decks_before_write()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
begin
  if tg_op = 'INSERT' then
    if new.id is null then
      new.id := gen_random_uuid();
    end if;
    if new.privacy = 'public' then
      new.published_at := coalesce(new.published_at, now());
    else
      new.published_at := null;
    end if;
    return new;
  end if;

  if new.privacy = 'public' then
    if old.privacy <> 'public' then
      new.published_at := now();
    end if;
  else
    new.published_at := null;
  end if;
  return new;
end;
$function$;

comment on function public.decks_before_write() is
  'Stamps published_at when a deck becomes public. Decks are flat: no tree maintenance.';

-- The publish helper used to walk a subtree through parent_id. Same signature,
-- same grants, one row: older clients that still call the RPC keep working.
create or replace function public.set_deck_privacy(
  p_deck_id uuid,
  p_privacy public.deck_privacy
)
returns integer
language plpgsql
set search_path = public, pg_temp
as $function$
declare affected integer;
begin
  update public.decks
  set privacy = p_privacy
  where id = p_deck_id
    and owner_id = auth.uid()
    and deleted_at is null;

  get diagnostics affected = row_count;
  if affected = 0 then
    raise exception 'Deck not found or not owned by the current user'
      using errcode = 'insufficient_privilege';
  end if;
  return affected;
end;
$function$;

revoke execute on function public.set_deck_privacy(uuid, public.deck_privacy)
  from public, anon;
grant execute on function public.set_deck_privacy(uuid, public.deck_privacy)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Drop the tree constraints and indexes
-- ---------------------------------------------------------------------------

alter table public.decks drop constraint if exists decks_depth_check;
alter table public.decks drop constraint if exists decks_path_length_check;

drop index if exists public.decks_parent_idx;
drop index if exists public.decks_path_idx;
drop index if exists public.decks_root_idx;
drop index if exists public.decks_public_tree_idx;

-- ---------------------------------------------------------------------------
-- 3. Drop the tree columns
-- ---------------------------------------------------------------------------

alter table public.decks
  drop column if exists parent_id,
  drop column if exists root_id,
  drop column if exists path,
  drop column if exists depth;

comment on column public.decks.position is
  'Manual ordering inside the library. Decks are flat, so this is the only ordering key.';
