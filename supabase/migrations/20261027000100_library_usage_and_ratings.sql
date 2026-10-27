-- Library usage tracking and rating support.
--
-- `install_count` is incremented through a security-definer RPC so a reader
-- can record an install without update access to another user's deck row.
-- Ratings already live in `public.deck_ratings`; the public view aggregates
-- them for the catalog.

alter table public.decks
  add column if not exists install_count bigint not null default 0;

alter table public.cards
  add column if not exists favorite boolean not null default false;

create or replace function public.record_deck_install(p_deck_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.decks
     set install_count = install_count + 1
   where id = p_deck_id
     and privacy in ('public', 'unlisted')
     and deleted_at is null;
$$;

revoke all on function public.record_deck_install(uuid) from public;
grant execute on function public.record_deck_install(uuid)
  to anon, authenticated;

create or replace view public.public_decks
with (security_invoker = true)
as
with recursive public_subtrees as (
  select d.id as published_id, d.id as node_id
  from public.decks d
  where d.privacy = 'public' and d.deleted_at is null
  union all
  select tree.published_id, child.id
  from public_subtrees tree
  join public.decks child on child.parent_id = tree.node_id
  where child.privacy = 'public' and child.deleted_at is null
),
card_counts as (
  select tree.published_id, count(card.id) as card_count
  from public_subtrees tree
  left join public.cards card
    on card.deck_id = tree.node_id and card.deleted_at is null
  group by tree.published_id
),
subdeck_counts as (
  select tree.published_id, count(child.id) as subdeck_count
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
  coalesce(round(avg(r.rating), 2), 0::numeric) as rating,
  count(distinct r.user_id) as rating_count,
  coalesce(max(card_counts.card_count), 0::bigint) as card_count,
  coalesce(max(subdeck_counts.subdeck_count), 0::bigint) as subdeck_count,
  not exists (
    select 1 from public.decks ancestor
    where ancestor.id = any (d.path)
      and ancestor.privacy = 'public'
      and ancestor.deleted_at is null
  ) as is_standalone,
  d.install_count
from public.decks d
join public.profiles p on p.id = d.owner_id
left join public.deck_ratings r on r.deck_id = d.id
left join card_counts on card_counts.published_id = d.id
left join subdeck_counts on subdeck_counts.published_id = d.id
where d.privacy = 'public' and d.deleted_at is null
group by d.id, p.display_name, p.avatar_url,
         card_counts.card_count, subdeck_counts.subdeck_count;

grant select on public.public_decks to anon, authenticated;
