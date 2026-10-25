begin;
select plan(7);

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('99000000-0000-4000-8000-000000000301', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'avatar-private@example.test', '', '{}', '{}', now(), now()),
  ('99000000-0000-4000-8000-000000000302', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'avatar-friend@example.test', '', '{}', '{}', now(), now()),
  ('99000000-0000-4000-8000-000000000303', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'avatar-outsider@example.test', '', '{}', '{}', now(), now());

insert into storage.objects(bucket_id, name, owner_id)
values
  ('profile-avatars', '99000000-0000-4000-8000-000000000301/avatar/avatar-full.jpg', '99000000-0000-4000-8000-000000000301');

update public.profile_privacy
set profile_audience = 'private'
where user_id = '99000000-0000-4000-8000-000000000301';

set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000301', true);
select is(
  (select count(*)::integer from storage.objects where bucket_id = 'profile-avatars'),
  1,
  'an owner can read their own avatar when their profile is private'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000303', true);
select is(
  (select count(*)::integer from storage.objects where bucket_id = 'profile-avatars'),
  0,
  'an unrelated authenticated user cannot read a private profile avatar'
);
reset role;

update public.profile_privacy
set profile_audience = 'public'
where user_id = '99000000-0000-4000-8000-000000000301';
set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000303', true);
select is(
  (select count(*)::integer from storage.objects where bucket_id = 'profile-avatars'),
  1,
  'an authenticated user can read a public profile avatar'
);
reset role;

update public.profile_privacy
set profile_audience = 'friends'
where user_id = '99000000-0000-4000-8000-000000000301';
insert into public.friend_relationships(user_low_id, user_high_id, requested_by, status, responded_at)
values (
  '99000000-0000-4000-8000-000000000301',
  '99000000-0000-4000-8000-000000000302',
  '99000000-0000-4000-8000-000000000301',
  'accepted',
  now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000302', true);
select is(
  (select count(*)::integer from storage.objects where bucket_id = 'profile-avatars'),
  1,
  'an accepted friend can read a friends-only profile avatar'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000303', true);
select is(
  (select count(*)::integer from storage.objects where bucket_id = 'profile-avatars'),
  0,
  'an unrelated user cannot read a friends-only profile avatar'
);
reset role;

select ok(
  (select qual like '%can_view_profile%' from pg_catalog.pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname = 'profile avatars authenticated read'),
  'avatar reads delegate to the canonical profile visibility rule'
);
select ok(
  (select roles = array['authenticated']::name[] from pg_catalog.pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname = 'profile avatars authenticated read'),
  'avatar visibility remains limited to authenticated readers'
);

select * from finish();
rollback;
