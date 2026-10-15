insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values(
  'profile-avatars',
  'profile-avatars',
  false,
  5242880,
  array['image/jpeg']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "profile avatars authenticated read" on storage.objects;
drop policy if exists "profile avatars owner upload" on storage.objects;
drop policy if exists "profile avatars owner update" on storage.objects;
drop policy if exists "profile avatars owner delete" on storage.objects;

create policy "profile avatars authenticated read" on storage.objects
for select to authenticated
using(bucket_id = 'profile-avatars');

create policy "profile avatars owner upload" on storage.objects
for insert to authenticated
with check(
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "profile avatars owner update" on storage.objects
for update to authenticated
using(
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check(
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "profile avatars owner delete" on storage.objects
for delete to authenticated
using(
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
