-- Author names in the public library are never copied onto a deck row.
--
-- `public_decks.author_name` is read from `profiles.display_name` at query
-- time, so renaming yourself in Settings changes the credit on every deck
-- you published, immediately, with no backfill and nothing to keep in sync.
-- A stored copy would need a trigger to stay correct and would still be
-- wrong for anyone reading a stale row, so the join is the cheaper design.
--
-- What this migration adds is the other half of that guarantee: a display
-- name can never be blank or padded with whitespace, because a blank name
-- would render as an empty author on every published deck at once.

create or replace function public.normalise_display_name()
returns trigger
language plpgsql
as $$
begin
  new.display_name := nullif(
    btrim(regexp_replace(coalesce(new.display_name, ''), '\s+', ' ', 'g')),
    ''
  );
  if new.display_name is null then
    -- Keep the previous name rather than erasing the credit.
    if tg_op = 'UPDATE' then
      new.display_name := coalesce(old.display_name, 'طالب');
    else
      new.display_name := 'طالب';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_normalise_name on public.profiles;
create trigger profiles_normalise_name
  before insert or update on public.profiles
  for each row execute function public.normalise_display_name();

-- Fix any row written before the trigger existed.
update public.profiles
   set display_name = btrim(regexp_replace(display_name, '\s+', ' ', 'g'))
 where display_name <> btrim(regexp_replace(display_name, '\s+', ' ', 'g'));

update public.profiles
   set display_name = 'طالب'
 where display_name is null or btrim(display_name) = '';

-- The library lists public decks newest first; this keeps the filter and the
-- profiles join off a small index instead of a full scan.
create index if not exists decks_published_owner_idx
  on public.decks (owner_id)
  where privacy = 'public' and deleted_at is null;

comment on view public.public_decks is
  'Published decks for the library. author_name is joined live from profiles, so a rename in Settings shows up here without any backfill.';
