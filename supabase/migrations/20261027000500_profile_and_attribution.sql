-- Attribution, real author identity, and a flat library projection.
--
-- A deck installed from the library keeps a pointer to the first deck in the
-- remix chain plus that deck's author name, so a copy can always credit the
-- person who wrote the original even after the original is unpublished.

alter table public.decks
  add column if not exists original_deck_id uuid
    references public.decks(id) on delete set null;

alter table public.decks
  add column if not exists original_author_name text;

comment on column public.decks.original_deck_id is
  'First deck in the remix chain. Null when this deck is not a remix.';

comment on column public.decks.original_author_name is
  'Display name of the original author, captured at install time so credit survives the original being deleted.';

-- Distinguishes a name the user typed from the one Google supplied at sign
-- up, so a device never replaces a chosen name with "طالب" on first sync.
alter table public.profiles
  add column if not exists display_name_custom boolean not null default false;

-- A signed-in user must be able to create their own profile row when the
-- sign-up trigger has not run for them yet.
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));

-- The library projection is flat now: one row per published deck, no subtree
-- walk. Rebuilt from scratch because columns were removed as well as added.
drop view if exists public.public_decks;

create view public.public_decks as
select
  d.id,
  d.owner_id,
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
  d.original_deck_id,
  d.original_author_name,
  p.display_name as author_name,
  p.avatar_url as author_avatar,
  coalesce(round(avg(r.rating), 2), 0::numeric) as rating,
  count(distinct r.user_id) as rating_count,
  (select count(*) from public.cards c
    where c.deck_id = d.id and c.deleted_at is null) as card_count,
  d.install_count
from public.decks d
join public.profiles p on p.id = d.owner_id
left join public.deck_ratings r on r.deck_id = d.id
where d.privacy = 'public'::public.deck_privacy
  and d.deleted_at is null
group by d.id, p.display_name, p.avatar_url;

grant select on public.public_decks to anon, authenticated, service_role;
