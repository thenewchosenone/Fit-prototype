begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(11);

select is(
  (select count(*)::integer from storage.buckets where id = 'profile-avatars'),
  1,
  'profile avatar bucket exists exactly once'
);
select is(
  (select public from storage.buckets where id = 'profile-avatars'),
  false,
  'profile avatar bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'profile-avatars'),
  5242880::bigint,
  'profile avatar uploads are size limited'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'profile-avatars'),
  array['image/jpeg']::text[],
  'profile avatar uploads accept JPEG only'
);

select has_policy('storage', 'objects', 'profile avatars authenticated read', 'authenticated read policy exists');
select has_policy('storage', 'objects', 'profile avatars owner upload', 'owner upload policy exists');
select has_policy('storage', 'objects', 'profile avatars owner update', 'owner update policy exists');
select has_policy('storage', 'objects', 'profile avatars owner delete', 'owner delete policy exists');
select policy_cmd_is('storage', 'objects', 'profile avatars owner upload', 'INSERT', 'upload policy is insert-only');
select policy_cmd_is('storage', 'objects', 'profile avatars owner update', 'UPDATE', 'update policy is update-only');
select policy_cmd_is('storage', 'objects', 'profile avatars owner delete', 'DELETE', 'delete policy is delete-only');

select * from finish();
rollback;
