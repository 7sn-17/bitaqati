-- Hardening pass from the Supabase database advisors.
-- Fixes mutable function search paths, function execute grants, RLS initplans,
-- duplicate permissive policies, and unindexed foreign keys.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Cover foreign keys reported by the performance advisor.
create index if not exists deck_ratings_user_idx
  on public.deck_ratings (user_id);
create index if not exists deck_reports_deck_idx
  on public.deck_reports (deck_id);
create index if not exists deck_reports_reporter_idx
  on public.deck_reports (reporter_id);
create index if not exists deck_subscriptions_deck_idx
  on public.deck_subscriptions (deck_id);
create index if not exists deck_subscriptions_source_deck_idx
  on public.deck_subscriptions (source_deck_id);
create index if not exists decks_source_deck_idx
  on public.decks (source_deck_id);

-- ---------------------------------------------------------------------------
-- Replace policies with initplan-safe, non-overlapping versions
-- ---------------------------------------------------------------------------

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "decks_read_visible" on public.decks;
create policy "decks_read_visible"
  on public.decks for select
  to anon, authenticated
  using (
    deleted_at is null
    and (
      owner_id = (select auth.uid())
      or privacy in ('public', 'unlisted')
    )
  );

drop policy if exists "decks_insert_own" on public.decks;
create policy "decks_insert_own"
  on public.decks for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

drop policy if exists "decks_update_own" on public.decks;
create policy "decks_update_own"
  on public.decks for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

drop policy if exists "decks_delete_own" on public.decks;
create policy "decks_delete_own"
  on public.decks for delete
  to authenticated
  using (owner_id = (select auth.uid()));

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
        and (
          d.owner_id = (select auth.uid())
          or d.privacy in ('public', 'unlisted')
        )
    )
  );

drop policy if exists "cards_write_own" on public.cards;
drop policy if exists "cards_insert_own" on public.cards;
create policy "cards_insert_own"
  on public.cards for insert
  to authenticated
  with check (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and d.owner_id = (select auth.uid())
    )
  );

drop policy if exists "cards_update_own" on public.cards;
create policy "cards_update_own"
  on public.cards for update
  to authenticated
  using (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and d.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and d.owner_id = (select auth.uid())
    )
  );

drop policy if exists "cards_delete_own" on public.cards;
create policy "cards_delete_own"
  on public.cards for delete
  to authenticated
  using (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and d.owner_id = (select auth.uid())
    )
  );

drop policy if exists "card_states_own" on public.card_states;
create policy "card_states_own"
  on public.card_states for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "review_logs_own" on public.review_logs;
create policy "review_logs_own"
  on public.review_logs for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "user_settings_own" on public.user_settings;
create policy "user_settings_own"
  on public.user_settings for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "ai_jobs_own" on public.ai_jobs;
create policy "ai_jobs_own"
  on public.ai_jobs for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "deck_ratings_public_read" on public.deck_ratings;
create policy "deck_ratings_public_read"
  on public.deck_ratings for select
  to anon, authenticated
  using (true);

drop policy if exists "deck_ratings_write_own" on public.deck_ratings;
drop policy if exists "deck_ratings_insert_own" on public.deck_ratings;
create policy "deck_ratings_insert_own"
  on public.deck_ratings for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.decks d
      where d.id = deck_id and d.privacy = 'public'
    )
  );

drop policy if exists "deck_ratings_update_own" on public.deck_ratings;
create policy "deck_ratings_update_own"
  on public.deck_ratings for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "deck_ratings_delete_own" on public.deck_ratings;
create policy "deck_ratings_delete_own"
  on public.deck_ratings for delete
  to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "deck_reports_insert_own" on public.deck_reports;
create policy "deck_reports_insert_own"
  on public.deck_reports for insert
  to authenticated
  with check (reporter_id = (select auth.uid()));

drop policy if exists "deck_reports_read_own" on public.deck_reports;
create policy "deck_reports_read_own"
  on public.deck_reports for select
  to authenticated
  using (reporter_id = (select auth.uid()));

drop policy if exists "deck_subscriptions_own" on public.deck_subscriptions;
create policy "deck_subscriptions_own"
  on public.deck_subscriptions for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
