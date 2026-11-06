begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select no_plan();

select has_table('storage', 'buckets', 'storage buckets are present');
select is((select public from storage.buckets where id = 'forum-media'), false, 'forum media stays in a private bucket');
select is((select file_size_limit from storage.buckets where id = 'forum-media'), 52428800::bigint, 'bucket upload ceiling is 50 MiB');
select ok(
  (select allowed_mime_types @> array['image/jpeg', 'video/mp4']::text[]
     and allowed_mime_types <@ array['image/jpeg', 'video/mp4']::text[]
   from storage.buckets where id = 'forum-media'),
  'bucket accepts only JPEG photos and MP4 videos'
);
select ok(has_table_privilege('anon', 'storage.objects', 'select'), 'anonymous read grant allows the public-post media policy to run');
select has_function('public', 'forum_media_is_attached', array['text'], 'attachment lookup helper exists');
select is_definer('public', 'forum_media_is_attached', array['text'], 'attachment lookup is evaluated with owner privileges');
select ok(
  (select proconfig @> array['search_path=pg_catalog']::text[]
   from pg_proc where oid = 'public.forum_media_is_attached(text)'::regprocedure),
  'attachment lookup uses a fixed search path'
);
select ok(has_function_privilege('authenticated', 'public.forum_media_is_attached(text)', 'EXECUTE'), 'authenticated upload retries can check attachment state');
select ok(not has_function_privilege('anon', 'public.forum_media_is_attached(text)', 'EXECUTE'), 'anonymous callers cannot inspect attachment state directly');
select has_function('public', 'validate_forum_attachments', array[]::text[], 'attachment validation trigger function exists');
select is_definer('public', 'validate_forum_attachments', array[]::text[], 'attachment validation runs as the database owner');
select ok(
  (select proconfig @> array['search_path=pg_catalog']::text[]
   from pg_proc where oid = 'public.validate_forum_attachments()'::regprocedure),
  'attachment validation uses a fixed search path'
);
select ok(not has_function_privilege('authenticated', 'public.validate_forum_attachments()', 'EXECUTE'), 'clients cannot invoke the trigger function directly');
select has_trigger('public', 'forum_posts', 'forum_attachments_guard', 'forum attachment validation is triggered on writes');
select policy_cmd_is('storage', 'objects', 'forum media owner upload', 'INSERT', 'uploads use an owner-scoped insert policy');
select policy_cmd_is('storage', 'objects', 'forum media owner retry', 'UPDATE', 'retry updates use a pending-owner policy');
select policy_cmd_is('storage', 'objects', 'forum media owner cleanup', 'DELETE', 'pending cleanup uses an owner policy');
select policy_cmd_is('storage', 'objects', 'forum media visible with post', 'SELECT', 'media reads use a post-linked policy');
select policy_cmd_is('storage', 'objects', 'forum media owner pending read', 'SELECT', 'owners can read pending uploads for retry');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('d5100000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-media-owner@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('d5100000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-media-reader@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('d5100000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-media-blocked@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('d5100000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-media-invite@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('d5100000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-media-gym@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.forum_memberships(community_id, user_id, status)
values
  ('f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Joined'),
  ('f1000000-0000-0000-0000-000000000008', 'd5100000-0000-4000-8000-000000000001', 'Joined'),
  ('f1000000-0000-0000-0000-000000000008', 'd5100000-0000-4000-8000-000000000004', 'Joined');

insert into public.gyms(id, name, status)
values ('d5200000-0000-4000-8000-000000000001', 'Forum media test gym', 'active');
insert into public.gym_memberships(user_id, gym_id, is_primary)
values
  ('d5100000-0000-4000-8000-000000000001', 'd5200000-0000-4000-8000-000000000001', true),
  ('d5100000-0000-4000-8000-000000000005', 'd5200000-0000-4000-8000-000000000001', true);

insert into public.user_blocks(blocker_id, blocked_id)
values ('d5100000-0000-4000-8000-000000000001', 'd5100000-0000-4000-8000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000001', true);

select lives_ok($$insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"image/jpeg","size":1234}')$$,
'the owner can upload a pending JPEG to a UUID-scoped path');
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name like 'd5100000-0000-4000-8000-000000000001/%'), 1, 'the uploader can read its unlinked object for retry');
select lives_ok($$update storage.objects set metadata = '{"mimetype":"image/jpeg","size":2345}' where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg'$$, 'the owner can retry a pending upload');
select is((select metadata->>'size' from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg'), '2345', 'retry updates the pending object metadata');
select lives_ok($$delete from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg'$$, 'the owner can clean up an unlinked upload');
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg'), 0, 'pending cleanup removes only the unlinked object');
select lives_ok($$insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"image/jpeg","size":1234}')$$,
'the owner can upload again after cleanup');

select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000002', true);
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name like 'd5100000-0000-4000-8000-000000000001/%'), 0, 'other users cannot read an unlinked upload');
select throws_ok($$insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000009/d5400000-0000-4000-8000-000000000009.jpg', 'd5100000-0000-4000-8000-000000000002', '{"mimetype":"image/jpeg","size":100}')$$,
'42501', 'new row violates row-level security policy for table "objects"', 'a different user cannot upload into the owner folder');
select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000001', true);
select throws_ok($$insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/not-a-uuid/not-a-uuid.jpg', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"image/jpeg","size":100}')$$,
'42501', 'new row violates row-level security policy for table "objects"', 'upload paths must contain owner, post, and media UUIDs');

select lives_ok($$insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000002/d5400000-0000-4000-8000-000000000002.mp4', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"video/mp4","size":3000}')$$,
'the owner can upload a pending MP4');

select lives_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000001', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Photo post', 'JPEG attachment', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg"}]')$$,
'a correctly uploaded JPEG can be attached to its owner’s community post');
select is((select attachments from public.forum_posts where id = 'd5300000-0000-4000-8000-000000000001'), '[{"kind":"photo", "storage_path": "d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg"}]'::jsonb, 'photo metadata is stored on the post');
select lives_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000002', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Video post', 'MP4 attachment', '[{"kind":"video","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000002/d5400000-0000-4000-8000-000000000002.mp4"}]')$$,
'a correctly uploaded MP4 can be attached to its owner’s community post');

select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000009', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Bad kind', 'Invalid kind', '[{"kind":"gif","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000009/d5400000-0000-4000-8000-000000000009.jpg"}]')$$,
'P0001', 'Invalid discussion attachment', 'unknown attachment kinds are rejected');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000010', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Extra key', 'Invalid metadata', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000010/d5400000-0000-4000-8000-000000000010.jpg","url":"https://example.test/file.jpg"}]')$$,
'P0001', 'Invalid discussion attachment', 'attachment metadata cannot carry extra keys or external URLs');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000011', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'External URL', 'Invalid path', '[{"kind":"photo","storage_path":"https://example.test/file.jpg"}]')$$,
'P0001', 'Invalid discussion attachment', 'external media URLs are rejected');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000012', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Wrong owner path', 'Invalid owner', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000002/d5300000-0000-4000-8000-000000000012/d5400000-0000-4000-8000-000000000012.jpg"}]')$$,
'P0001', 'Invalid discussion attachment', 'the attachment path must belong to the post author');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000013', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Wrong post path', 'Invalid post', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg"}]')$$,
'P0001', 'Invalid discussion attachment', 'the attachment path must match the post id');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000014', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Missing object', 'Invalid upload', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000014/d5400000-0000-4000-8000-000000000014.jpg"}]')$$,
'P0001', 'Attachment upload is missing, invalid, or too large', 'posts cannot reference an object that was not uploaded');

select lives_ok($$insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000015/d5400000-0000-4000-8000-000000000015.jpg', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"video/mp4","size":3000}')$$,
'an owner can stage a mismatched content type for validation');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000015', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Wrong MIME', 'Invalid MIME', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000015/d5400000-0000-4000-8000-000000000015.jpg"}]')$$,
'P0001', 'Attachment upload is missing, invalid, or too large', 'photo posts reject non-JPEG object metadata');
select lives_ok($$insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000016/d5400000-0000-4000-8000-000000000016.jpg', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"image/jpeg","size":10485761}')$$,
'an owner can stage an oversized photo for validation');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000016', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Oversized photo', 'Invalid size', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000016/d5400000-0000-4000-8000-000000000016.jpg"}]')$$,
'P0001', 'Attachment upload is missing, invalid, or too large', 'photo attachments are limited to 10 MiB');
select lives_ok($$insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000017/d5400000-0000-4000-8000-000000000017.mp4', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"video/mp4","size":52428801}')$$,
'an owner can stage an oversized video for validation');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000017', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Oversized video', 'Invalid size', '[{"kind":"video","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000017/d5400000-0000-4000-8000-000000000017.mp4"}]')$$,
'P0001', 'Attachment upload is missing, invalid, or too large', 'video attachments are limited to 50 MiB');
select throws_ok($$insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000018', 'f1000000-0000-0000-0000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Two files', 'Only one is allowed', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg"},{"kind":"video","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000002/d5400000-0000-4000-8000-000000000002.mp4"}]')$$,
'P0001', 'Attach one photo or video per discussion', 'a post cannot attach multiple media files');

select lives_ok($$update public.forum_posts set title = 'Updated photo title', body = 'Updated text; same media' where id = 'd5300000-0000-4000-8000-000000000001'$$, 'text edits remain allowed on an attached post');
select is((select attachments from public.forum_posts where id = 'd5300000-0000-4000-8000-000000000001'), '[{"kind":"photo", "storage_path": "d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg"}]'::jsonb, 'text edits retain the attachment');
reset role;
select throws_ok($$update public.forum_posts set attachments = '[]'::jsonb where id = 'd5300000-0000-4000-8000-000000000001'$$,
'42501', 'Published attachments cannot be replaced', 'published attachment metadata is immutable at the database trigger');
set local role authenticated;
select lives_ok($sql$
do $$begin
  update storage.objects set metadata = '{"mimetype":"image/jpeg","size":9999}'
  where bucket_id = 'forum-media'
    and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg';
  if found then raise exception 'attached media was mutable'; end if;
end$$;
$sql$, 'a published storage object cannot be replaced');
select lives_ok($sql$
do $$begin
  delete from storage.objects where bucket_id = 'forum-media'
    and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg';
  if found then raise exception 'attached media was deletable'; end if;
end$$;
$sql$, 'a published storage object cannot be deleted');

select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000002', true);
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg'), 1, 'a reader can access media attached to a visible public post');
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000002/d5400000-0000-4000-8000-000000000002.mp4'), 1, 'a reader can resolve media attached to a visible video post');
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000016/d5400000-0000-4000-8000-000000000016.jpg'), 0, 'a reader cannot see an unlinked upload');

reset role;
update public.forum_posts set removed_at = now() where id = 'd5300000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000002', true);
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg'), 0, 'removed posts no longer expose their attachment');

reset role;
update public.forum_posts set removed_at = null where id = 'd5300000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000003', true);
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000001.jpg'), 0, 'blocked users cannot read a post attachment');

reset role;
insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000003/d5400000-0000-4000-8000-000000000003.jpg', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"image/jpeg","size":1000}');
insert into public.forum_posts(id, community_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000003', 'f1000000-0000-0000-0000-000000000008', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Invite-only media', 'Private post', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000003/d5400000-0000-4000-8000-000000000003.jpg"}]');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000004', true);
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000003/d5400000-0000-4000-8000-000000000003.jpg'), 1, 'an invited community member can read its post media');
select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000002', true);
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000003/d5400000-0000-4000-8000-000000000003.jpg'), 0, 'a nonmember cannot read invite-only post media');

reset role;
insert into storage.objects(bucket_id, name, owner_id, metadata)
values ('forum-media', 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000004/d5400000-0000-4000-8000-000000000004.jpg', 'd5100000-0000-4000-8000-000000000001', '{"mimetype":"image/jpeg","size":1000}');
insert into public.forum_posts(id, gym_id, author_id, kind, title, body, attachments)
values ('d5300000-0000-4000-8000-000000000004', 'd5200000-0000-4000-8000-000000000001', 'd5100000-0000-4000-8000-000000000001', 'Discussion', 'Gym media', 'Members only', '[{"kind":"photo","storage_path":"d5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000004/d5400000-0000-4000-8000-000000000004.jpg"}]');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000005', true);
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000004/d5400000-0000-4000-8000-000000000004.jpg'), 1, 'a gym member can read media attached to its gym post');
select set_config('request.jwt.claim.sub', 'd5100000-0000-4000-8000-000000000002', true);
select is((select count(*)::int from storage.objects where bucket_id = 'forum-media' and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000004/d5400000-0000-4000-8000-000000000004.jpg'), 0, 'a nonmember cannot read gym post media');

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select lives_ok($sql$
do $$begin
  if (select count(*) from storage.objects where bucket_id = 'forum-media'
      and name = 'd5100000-0000-4000-8000-000000000001/d5300000-0000-4000-8000-000000000002/d5400000-0000-4000-8000-000000000002.mp4') <> 1 then
    raise exception 'public video attachment is not visible';
  end if;
end$$;
$sql$, 'anonymous readers can access media on a public forum post');

reset role;
select * from finish();
rollback;
