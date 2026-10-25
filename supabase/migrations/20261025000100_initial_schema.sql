-- Bitaqati initial schema
-- Local-first app; this schema is the cloud sync and public library layer.

create extension if not exists pgcrypto;

do $$
begin
  create type public.deck_privacy as enum ('private', 'unlisted', 'public');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.card_type as enum ('basic', 'cloze', 'mcq', 'occlusion');
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.card_state as enum (
    'new', 'learning', 'review', 'relearning', 'suspended', 'buried'
  );
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique,
  display_name text not null default 'طالب',
  avatar_url text,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  locale text not null default 'ar',
  theme text not null default 'system'
    check (theme in ('system', 'light', 'dark')),
  notifications_enabled boolean not null default true,
  reminder_time time not null default '20:00',
  timezone text not null default 'UTC',
  daily_new_limit integer not null default 10
    check (daily_new_limit between 0 and 500),
  daily_review_limit integer not null default 200
    check (daily_review_limit between 0 and 5000),
  desired_retention real not null default 0.90
    check (desired_retention between 0.70 and 0.99),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), 'طالب'),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Taxonomy and content
-- ---------------------------------------------------------------------------

create table if not exists public.subjects (
  id text primary key
    check (id ~ '^[a-z0-9_]+$'),
  name_ar text not null unique,
  name_en text not null,
  color_hex text not null,
  icon text not null,
  sort_order integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.decks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  subject_id text not null references public.subjects (id),
  title text not null check (char_length(title) between 1 and 160),
  description text not null default '',
  color_hex text,
  privacy public.deck_privacy not null default 'private',
  cover_url text,
  tags text[] not null default '{}',
  settings jsonb not null default jsonb_build_object(
    'new_per_day', 10,
    'review_per_day', 200,
    'desired_retention', 0.90,
    'leech_threshold', 8
  ),
  source_deck_id uuid references public.decks (id) on delete set null,
  source_version integer not null default 1,
  forked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references public.decks (id) on delete cascade,
  type public.card_type not null default 'basic',
  front text not null default '',
  back text not null default '',
  notes text not null default '',
  tags text[] not null default '{}',
  media jsonb not null default '[]'::jsonb,
  occlusion jsonb,
  source text,
  ai_generated boolean not null default false,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.card_states (
  card_id uuid not null references public.cards (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  state public.card_state not null default 'new',
  due timestamptz not null default now(),
  stability double precision not null default 0 check (stability >= 0),
  difficulty double precision not null default 0
    check (difficulty between 0 and 10),
  elapsed_days integer not null default 0,
  scheduled_days integer not null default 0,
  learning_steps integer not null default 0,
  reps integer not null default 0,
  lapses integer not null default 0,
  last_review timestamptz,
  updated_at timestamptz not null default now(),
  primary key (card_id, user_id)
);

create table if not exists public.review_logs (
  id bigint generated always as identity primary key,
  card_id uuid not null references public.cards (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  rating smallint not null check (rating between 1 and 4),
  reviewed_at timestamptz not null default now(),
  elapsed_ms integer,
  scheduled_days integer,
  stability double precision,
  difficulty double precision,
  prev_state jsonb,
  next_state jsonb
);

create table if not exists public.ai_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'queued'
    check (status in ('queued', 'running', 'completed', 'failed', 'cancelled')),
  source_type text not null
    check (source_type in ('text', 'pdf', 'image', 'docx', 'url')),
  source_name text,
  source_meta jsonb not null default '{}'::jsonb,
  config jsonb not null default '{}'::jsonb,
  result jsonb,
  error text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz
);

create table if not exists public.deck_ratings (
  deck_id uuid not null references public.decks (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  review text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (deck_id, user_id)
);

create table if not exists public.deck_reports (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references public.decks (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null,
  details text,
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);

create table if not exists public.deck_subscriptions (
  user_id uuid not null references public.profiles (id) on delete cascade,
  deck_id uuid not null references public.decks (id) on delete cascade,
  source_deck_id uuid not null references public.decks (id) on delete cascade,
  source_version integer not null default 1,
  notify_updates boolean not null default true,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (user_id, deck_id)
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index if not exists decks_owner_idx on public.decks (owner_id);
create index if not exists decks_subject_idx on public.decks (subject_id);
create index if not exists decks_public_idx
  on public.decks (subject_id, created_at desc)
  where privacy = 'public' and deleted_at is null;
create index if not exists cards_deck_idx
  on public.cards (deck_id, position)
  where deleted_at is null;
create index if not exists cards_tags_idx on public.cards using gin (tags);
create index if not exists decks_tags_idx on public.decks using gin (tags);
create index if not exists card_states_due_idx
  on public.card_states (user_id, due);
create index if not exists review_logs_user_idx
  on public.review_logs (user_id, reviewed_at desc);
create index if not exists review_logs_card_idx
  on public.review_logs (card_id, reviewed_at desc);
create index if not exists ai_jobs_user_idx
  on public.ai_jobs (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Public library projection
-- ---------------------------------------------------------------------------

create or replace view public.public_decks
with (security_invoker = true)
as
select
  d.id,
  d.owner_id,
  d.subject_id,
  d.title,
  d.description,
  d.color_hex,
  d.cover_url,
  d.tags,
  d.settings,
  d.source_deck_id,
  d.source_version,
  d.created_at,
  d.updated_at,
  p.display_name as author_name,
  p.avatar_url as author_avatar,
  coalesce(round(avg(r.rating)::numeric, 2), 0) as rating,
  count(distinct r.user_id) as rating_count,
  count(distinct c.id) as card_count
from public.decks d
join public.profiles p on p.id = d.owner_id
left join public.deck_ratings r on r.deck_id = d.id
left join public.cards c on c.deck_id = d.id and c.deleted_at is null
where d.privacy = 'public' and d.deleted_at is null
group by d.id, p.display_name, p.avatar_url;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists decks_set_updated_at on public.decks;
create trigger decks_set_updated_at
  before update on public.decks
  for each row execute function public.set_updated_at();

drop trigger if exists cards_set_updated_at on public.cards;
create trigger cards_set_updated_at
  before update on public.cards
  for each row execute function public.set_updated_at();

drop trigger if exists user_settings_set_updated_at on public.user_settings;
create trigger user_settings_set_updated_at
  before update on public.user_settings
  for each row execute function public.set_updated_at();

drop trigger if exists deck_ratings_set_updated_at on public.deck_ratings;
create trigger deck_ratings_set_updated_at
  before update on public.deck_ratings
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.subjects enable row level security;
alter table public.decks enable row level security;
alter table public.cards enable row level security;
alter table public.card_states enable row level security;
alter table public.review_logs enable row level security;
alter table public.ai_jobs enable row level security;
alter table public.deck_ratings enable row level security;
alter table public.deck_reports enable row level security;
alter table public.deck_subscriptions enable row level security;

drop policy if exists "profiles_public_read" on public.profiles;
create policy "profiles_public_read"
  on public.profiles for select
  to anon, authenticated
  using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "subjects_public_read" on public.subjects;
create policy "subjects_public_read"
  on public.subjects for select
  to anon, authenticated
  using (true);

drop policy if exists "decks_read_visible" on public.decks;
create policy "decks_read_visible"
  on public.decks for select
  to anon, authenticated
  using (
    deleted_at is null
    and (
      owner_id = auth.uid()
      or privacy in ('public', 'unlisted')
    )
  );

drop policy if exists "decks_insert_own" on public.decks;
create policy "decks_insert_own"
  on public.decks for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "decks_update_own" on public.decks;
create policy "decks_update_own"
  on public.decks for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "decks_delete_own" on public.decks;
create policy "decks_delete_own"
  on public.decks for delete
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists "cards_read_visible" on public.cards;
create policy "cards_read_visible"
  on public.cards for select
  to anon, authenticated
  using (
    deleted_at is null
    and exists (
      select 1
      from public.decks d
      where d.id = cards.deck_id
        and d.deleted_at is null
        and (d.owner_id = auth.uid() or d.privacy in ('public', 'unlisted'))
    )
  );

drop policy if exists "cards_write_own" on public.cards;
create policy "cards_write_own"
  on public.cards for all
  to authenticated
  using (
    exists (
      select 1
      from public.decks d
      where d.id = cards.deck_id and d.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.decks d
      where d.id = cards.deck_id and d.owner_id = auth.uid()
    )
  );

drop policy if exists "card_states_own" on public.card_states;
create policy "card_states_own"
  on public.card_states for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "review_logs_own" on public.review_logs;
create policy "review_logs_own"
  on public.review_logs for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "user_settings_own" on public.user_settings;
create policy "user_settings_own"
  on public.user_settings for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "ai_jobs_own" on public.ai_jobs;
create policy "ai_jobs_own"
  on public.ai_jobs for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "deck_ratings_public_read" on public.deck_ratings;
create policy "deck_ratings_public_read"
  on public.deck_ratings for select
  to anon, authenticated
  using (true);

drop policy if exists "deck_ratings_write_own" on public.deck_ratings;
create policy "deck_ratings_write_own"
  on public.deck_ratings for all
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.decks d
      where d.id = deck_id and d.privacy = 'public'
    )
  );

drop policy if exists "deck_reports_insert_own" on public.deck_reports;
create policy "deck_reports_insert_own"
  on public.deck_reports for insert
  to authenticated
  with check (reporter_id = auth.uid());

drop policy if exists "deck_reports_read_own" on public.deck_reports;
create policy "deck_reports_read_own"
  on public.deck_reports for select
  to authenticated
  using (reporter_id = auth.uid());

drop policy if exists "deck_subscriptions_own" on public.deck_subscriptions;
create policy "deck_subscriptions_own"
  on public.deck_subscriptions for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

grant usage on schema public to anon, authenticated;

grant select on public.profiles, public.subjects, public.decks, public.cards,
  public.deck_ratings, public.public_decks
  to anon, authenticated;

grant select, insert, update, delete on public.profiles, public.decks,
  public.cards, public.card_states, public.review_logs, public.user_settings,
  public.ai_jobs, public.deck_ratings, public.deck_reports,
  public.deck_subscriptions
  to authenticated;

grant usage, select on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- Starter taxonomy (must match the app exactly)
-- ---------------------------------------------------------------------------

insert into public.subjects (id, name_ar, name_en, color_hex, icon, sort_order)
values
  ('physics', 'الفيزياء', 'Physics', '#0B4C72', 'bolt', 1),
  ('chemistry', 'الكيمياء', 'Chemistry', '#054D28', 'science', 2),
  ('biology', 'البيولوجيا', 'Biology', '#163300', 'biotech', 3),
  ('history_of_medicine', 'تاريخ الطب', 'History of Medicine', '#7A3E2F', 'history_edu', 4),
  ('english_1', 'الانكليزية 1', 'English 1', '#4A3F7A', 'translate', 5)
on conflict (id) do update set
  name_ar = excluded.name_ar,
  name_en = excluded.name_en,
  color_hex = excluded.color_hex,
  icon = excluded.icon,
  sort_order = excluded.sort_order,
  is_active = true;
