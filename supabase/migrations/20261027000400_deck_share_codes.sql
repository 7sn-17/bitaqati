-- Decks are flat: every deck owns its cards directly, so a share code can
-- point at exactly one deck and nothing else.
--
-- The nesting columns (parent_id, root_id, path, depth) are left in place
-- with their existing defaults. The app only ever writes a top-level row, so
-- the legacy trigger keeps producing depth 0 / empty path, and published
-- decks from before this change keep working without a rewrite.

alter table public.decks add column if not exists share_code text;

comment on column public.decks.share_code is
  'Six-character code the owner can read out loud. Resolves to this deck while its privacy is public or unlisted.';

-- Codes avoid vowels and the easily confused glyphs 0/O and 1/I/L, so a code
-- cannot spell a word and survives being read over the phone.
create or replace function public.new_share_code()
returns text
language plpgsql
volatile
as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  code text := '';
begin
  for i in 1..6 loop
    code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return code;
end;
$$;

-- Backfill before the unique index exists, so a duplicate cannot abort it.
do $$
declare
  target record;
begin
  for target in
    select id from public.decks where share_code is null and deleted_at is null
  loop
    update public.decks set share_code = public.new_share_code() where id = target.id;
  end loop;
end;
$$;

alter table public.decks
  add constraint decks_share_code_format
  check (share_code is null or share_code ~ '^[2-9A-HJKMNP-Z]{6}$');

create unique index if not exists decks_share_code_key
  on public.decks (upper(share_code))
  where share_code is not null and deleted_at is null;

-- Runs after decks_before_write (trigger names fire alphabetically), so the
-- row already has its id and defaults by the time we look for collisions.
create or replace function public.decks_share_code()
returns trigger
language plpgsql
as $$
begin
  if new.share_code is not null then
    new.share_code := upper(trim(new.share_code));
    if exists (
      select 1 from public.decks
      where upper(share_code) = new.share_code
        and deleted_at is null
        and id is distinct from new.id
    ) then
      new.share_code := null;
    end if;
  end if;

  if new.share_code is null then
    loop
      new.share_code := public.new_share_code();
      exit when not exists (
        select 1 from public.decks
        where upper(share_code) = new.share_code
          and deleted_at is null
          and id is distinct from new.id
      );
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists decks_share_code on public.decks;
create trigger decks_share_code
  before insert or update on public.decks
  for each row execute function public.decks_share_code();

-- Resolving a code must work for signed-out users too, so this runs as the
-- definer. It only ever returns decks that are already readable by anyone,
-- and it never leaks content: just the id, title and size.
create or replace function public.resolve_share_code(p_code text)
returns table (id uuid, title text, card_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select d.id,
         d.title,
         (select count(*) from public.cards c
           where c.deck_id = d.id and c.deleted_at is null) as card_count
  from public.decks d
  where d.deleted_at is null
    and d.privacy in ('public', 'unlisted')
    and upper(d.share_code) = upper(trim(p_code))
  limit 1;
$$;

revoke all on function public.resolve_share_code(text) from public;
grant execute on function public.resolve_share_code(text) to anon, authenticated;
