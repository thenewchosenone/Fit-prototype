begin;

drop policy if exists "profile avatars authenticated read" on storage.objects;
create policy "profile avatars authenticated read" on storage.objects
for select to authenticated
using (
  bucket_id = 'profile-avatars'
  and exists (
    select 1
    from public.profiles p
    where p.id::text = (storage.foldername(name))[1]
      and public.can_view_profile(p.id)
  )
);

commit;
