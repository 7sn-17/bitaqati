-- One row instead of one row per rating.
--
-- Opening a deck used to download every star it had ever received and average
-- them on the client: four hundred rows over the wire to produce two numbers,
-- on every open, for a deck that is merely popular. The aggregate belongs next
-- to the data, where it costs one row whatever the deck's size.
create or replace function public.deck_rating_summary(p_deck uuid)
returns table (average numeric, total bigint)
language sql
stable
security definer
set search_path = public
as $$
  select round(avg(r.rating)::numeric, 2) as average,
         count(*)::bigint as total
  from public.deck_ratings r
  where r.deck_id = p_deck;
$$;

comment on function public.deck_rating_summary(uuid) is
  'Average and count of a deck''s ratings in one row.';

revoke all on function public.deck_rating_summary(uuid) from public;
grant execute on function public.deck_rating_summary(uuid) to anon, authenticated;
