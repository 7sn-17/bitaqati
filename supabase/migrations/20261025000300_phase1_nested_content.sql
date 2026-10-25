-- Phase 1: nested decks, granular publishing, and sync-ready local content.
--
-- Content hierarchy:
--   root deck (parent_id = null)
--     └── lesson / sub-deck (parent_id = root)
--           └── cards
--
-- Privacy is explicit per node. Publishing a node propagates the same privacy
-- to its subtree through public.set_deck_privacy(), which gives users
-- granular sharing without expensive ancestor checks inside RLS policies.

alter table public.decks
  alter column subject_id drop not null;

alter table public.decks
  add column if not exists parent_id uuid
    references public.decks (id) on delete cascade,
  add column if not exists root_id uuid
    references public.decks (id) on delete set null,
  add column if not exists path uuid[] not null default '{}',
  add column if not exists depth integer not null default 0,
  add column if not exists position integer not null default 0,
  add column if not exists icon text not null default 'layers',
  add column if not exists is_starter boolean not null default false,
  add column if not exists published_at timestamptz;

alter table public.cards
  add column if not exists hint text not null default '';

alter table public.review_logs
  add column if not exists client_id uuid not null default gen_random_uuid();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'decks_depth_check'
      and conrelid = 'public.decks'::regclass
  ) then
    alter table public.decks
      add constraint decks_depth_check check (depth between 0 and 20);
  end if;
  if not exists (
    select 1
    from pg_constraint
    where conname = 'decks_path_length_check'
      and conrelid = 'public.decks'::regclass
  ) then
    alter table public.decks
      add constraint decks_path_length_check check (cardinality(path) = depth);
  end if;
  if not exists (
    select 1
    from pg_constraint
    where conname = 'review_logs_client_id_key'
      and conrelid = 'public.review_logs'::regclass
  ) then
    alter table public.review_logs
      add constraint review_logs_client_id_key unique (client_id);
  end if;
end $$;

-- Existing Phase 0 decks are all roots.
update public.decks
set root_id = id,
    path = '{}',
    depth = 0
where root_id is null;

create index if not exists decks_parent_idx
  on public.decks (parent_id, position)
  where deleted_at is null;
create index if not exists decks_root_idx
  on public.decks (root_id, depth, position)
  where deleted_at is null;
create index if not exists decks_path_idx
  on public.decks using gin (path);
create index if not exists decks_public_tree_idx
  on public.decks (parent_id, position)
  where privacy = 'public' and deleted_at is null;
create unique index if not exists review_logs_client_id_idx
  on public.review_logs (client_id);

-- ---------------------------------------------------------------------------
-- Hierarchy maintenance
-- ---------------------------------------------------------------------------

create or replace function public.decks_before_write()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  parent_deck public.decks%rowtype;
begin
  if tg_op = 'INSERT' then
    if new.id is null then
      new.id := gen_random_uuid();
    end if;

    if new.parent_id is null then
      new.root_id := new.id;
      new.path := '{}';
      new.depth := 0;
    else
      select * into parent_deck
      from public.decks
      where id = new.parent_id and deleted_at is null;

      if not found then
        raise exception 'Parent deck % does not exist', new.parent_id
          using errcode = 'foreign_key_violation';
      end if;
      if parent_deck.owner_id <> new.owner_id then
        raise exception 'A deck can only be nested under the same owner'
          using errcode = 'insufficient_privilege';
      end if;
      if parent_deck.depth >= 20 then
        raise exception 'Deck nesting is limited to 20 levels'
          using errcode = 'check_violation';
      end if;

      new.root_id := parent_deck.root_id;
      new.path := parent_deck.path || parent_deck.id;
      new.depth := parent_deck.depth + 1;
    end if;

    if new.privacy = 'public' then
      new.published_at := coalesce(new.published_at, now());
    else
      new.published_at := null;
    end if;

    return new;
  end if;

  if new.parent_id is distinct from old.parent_id then
    raise exception 'Moving a deck is not supported yet; duplicate it instead'
      using errcode = 'feature_not_supported';
  end if;

  if new.privacy = 'public' and old.privacy <> 'public' then
    new.published_at := now();
  elsif new.privacy <> 'public' then
    new.published_at := null;
  end if;

  return new;
end;
$$;

drop trigger if exists decks_before_write on public.decks;
create trigger decks_before_write
  before insert or update on public.decks
  for each row execute function public.decks_before_write();

-- Publishing a deck publishes its entire subtree. Unpublishing hides it.
create or replace function public.set_deck_privacy(
  p_deck_id uuid,
  p_privacy public.deck_privacy
)
returns integer
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  affected integer;
begin
  if not exists (
    select 1
    from public.decks
    where id = p_deck_id
      and owner_id = auth.uid()
      and deleted_at is null
  ) then
    raise exception 'Deck not found or not owned by the current user'
      using errcode = 'insufficient_privilege';
  end if;

  with recursive subtree as (
    select id
    from public.decks
    where id = p_deck_id
      and owner_id = auth.uid()
      and deleted_at is null
    union all
    select child.id
    from public.decks child
    join subtree parent on child.parent_id = parent.id
    where child.owner_id = auth.uid()
      and child.deleted_at is null
  )
  update public.decks deck
  set privacy = p_privacy,
      published_at = case
        when p_privacy = 'public' then coalesce(deck.published_at, now())
        else null
      end
  from subtree
  where deck.id = subtree.id;

  get diagnostics affected = row_count;
  return affected;
end;
$$;

revoke execute on function public.set_deck_privacy(uuid, public.deck_privacy)
  from public, anon;
grant execute on function public.set_deck_privacy(uuid, public.deck_privacy)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Public library projection, including only the public parts of a subtree
-- ---------------------------------------------------------------------------

drop view if exists public.public_decks;

create view public.public_decks
with (security_invoker = true)
as
with recursive public_subtrees as (
  select d.id as published_id, d.id as node_id
  from public.decks d
  where d.privacy = 'public'
    and d.deleted_at is null
  union all
  select tree.published_id, child.id
  from public_subtrees tree
  join public.decks child on child.parent_id = tree.node_id
  where child.privacy = 'public'
    and child.deleted_at is null
),
card_counts as (
  select tree.published_id, count(card.id)::bigint as card_count
  from public_subtrees tree
  left join public.cards card
    on card.deck_id = tree.node_id
   and card.deleted_at is null
  group by tree.published_id
),
subdeck_counts as (
  select tree.published_id, count(child.id)::bigint as subdeck_count
  from public_subtrees tree
  left join public.decks child
    on child.parent_id = tree.node_id
   and child.privacy = 'public'
   and child.deleted_at is null
  group by tree.published_id
)
select
  d.id,
  d.owner_id,
  d.parent_id,
  d.root_id,
  d.depth,
  d.path,
  d.subject_id,
  d.title,
  d.description,
  d.color_hex,
  d.icon,
  d.cover_url,
  d.tags,
  d.settings,
  d.is_starter,
  d.source_deck_id,
  d.source_version,
  d.published_at,
  d.created_at,
  d.updated_at,
  p.display_name as author_name,
  p.avatar_url as author_avatar,
  coalesce(round(avg(r.rating)::numeric, 2), 0) as rating,
  count(distinct r.user_id)::bigint as rating_count,
  coalesce(max(card_counts.card_count), 0) as card_count,
  coalesce(max(subdeck_counts.subdeck_count), 0) as subdeck_count,
  not exists (
    select 1
    from public.decks ancestor
    where ancestor.id = any(d.path)
      and ancestor.privacy = 'public'
      and ancestor.deleted_at is null
  ) as is_standalone
from public.decks d
join public.profiles p on p.id = d.owner_id
left join public.deck_ratings r on r.deck_id = d.id
left join card_counts on card_counts.published_id = d.id
left join subdeck_counts on subdeck_counts.published_id = d.id
where d.privacy = 'public'
  and d.deleted_at is null
group by
  d.id,
  p.display_name,
  p.avatar_url,
  card_counts.card_count,
  subdeck_counts.subdeck_count;

grant select on public.public_decks to anon, authenticated;

-- Keep the public catalog fast and predictable.
create index if not exists decks_public_catalog_idx
  on public.decks (privacy, published_at desc)
  where deleted_at is null;

comment on column public.decks.parent_id is
  'NULL for a root deck, otherwise the parent deck/lesson.';
comment on column public.decks.path is
  'Ancestor UUIDs, root first, excluding this deck. Maintained by trigger.';
comment on column public.decks.published_at is
  'Set when privacy becomes public. Publishing a node propagates to its subtree via set_deck_privacy().';
comment on function public.set_deck_privacy(uuid, public.deck_privacy) is
  'Publishes or unpublishes a deck and all of its descendants for granular sharing.';
