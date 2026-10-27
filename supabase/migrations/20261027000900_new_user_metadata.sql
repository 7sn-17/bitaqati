-- Give new accounts a real name and avatar.
--
-- Google puts the person's name in `full_name` / `name` and the photo in
-- `picture`. The sign-up trigger only looked at `display_name` and
-- `avatar_url`, so every Google account landed in the library as "طالب" with
-- no picture -- which made the author line on a public deck useless.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  resolved_name text;
  resolved_avatar text;
begin
  resolved_name := coalesce(
    nullif(trim(meta->>'display_name'), ''),
    nullif(trim(meta->>'full_name'), ''),
    nullif(trim(meta->>'name'), ''),
    nullif(trim(split_part(coalesce(new.email, ''), '@', 1)), ''),
    'طالب'
  );

  resolved_avatar := coalesce(
    nullif(trim(meta->>'avatar_url'), ''),
    nullif(trim(meta->>'picture'), '')
  );

  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, resolved_name, resolved_avatar)
  on conflict (id) do update
    set display_name = case
          when public.profiles.display_name in ('', 'طالب') then excluded.display_name
          else public.profiles.display_name
        end,
        avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
        updated_at = now();

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Repair the accounts created before the fix. Names the user typed in the app
-- are marked with display_name_custom, and those are never touched.
-- ---------------------------------------------------------------------------

update public.profiles p
set display_name = src.resolved_name,
    updated_at = now()
from (
  select u.id,
         coalesce(
           nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
           nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
           nullif(trim(u.raw_user_meta_data->>'name'), '')
         ) as resolved_name
  from auth.users u
) src
where p.id = src.id
  and src.resolved_name is not null
  and coalesce(p.display_name_custom, false) = false
  and coalesce(p.display_name, '') in ('', 'طالب');

update public.profiles p
set avatar_url = src.resolved_avatar,
    updated_at = now()
from (
  select u.id,
         coalesce(
           nullif(trim(u.raw_user_meta_data->>'avatar_url'), ''),
           nullif(trim(u.raw_user_meta_data->>'picture'), '')
         ) as resolved_avatar
  from auth.users u
) src
where p.id = src.id
  and p.avatar_url is null
  and src.resolved_avatar is not null;
