-- Storage bucket for card media (images + audio).
--
-- The app uploads to `card-media/<user-id>/<uuid>.<ext>` and stores the public
-- URL in the card body, so the bucket must be publicly readable while writes
-- stay scoped to the owner's folder.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'card-media',
  'card-media',
  true,
  10485760, -- 10 MiB
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/ogg'
  ]
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Anyone can read: card media is embedded in public decks.
drop policy if exists "card media is readable by everyone" on storage.objects;
create policy "card media is readable by everyone"
  on storage.objects for select
  using (bucket_id = 'card-media');

-- Only the owner may write inside their own folder.
drop policy if exists "card media is writable by its owner" on storage.objects;
create policy "card media is writable by its owner"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'card-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "card media is updatable by its owner" on storage.objects;
create policy "card media is updatable by its owner"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'card-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "card media is deletable by its owner" on storage.objects;
create policy "card media is deletable by its owner"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'card-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
