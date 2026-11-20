begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);
select has_column('public', 'public_athletes', 'primary_gym_id', 'public athlete projection exposes the consent-gated gym ID');
select has_column('public', 'public_athletes', 'primary_gym_name', 'public athlete projection exposes the consent-gated gym name');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '98000000-0000-4000-8000-000000000101',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'public-gym-projection@example.test', '',
  '{}'::jsonb, '{}'::jsonb, now(), now()
);

insert into public.gyms (id, name, status)
values ('98000000-0000-4000-8000-000000000102', 'Public Projection Test Gym', 'active');

insert into public.gym_memberships (user_id, gym_id, is_primary)
values (
  '98000000-0000-4000-8000-000000000101',
  '98000000-0000-4000-8000-000000000102',
  true
);

update public.profile_privacy
set profile_audience = 'public', gym_audience = 'private'
where user_id = '98000000-0000-4000-8000-000000000101';

set local role anon;
select is(
  (select show_gym from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  false,
  'private gym audience is hidden from anonymous profiles'
);
select is(
  (select primary_gym_id from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  null::uuid,
  'private gym ID is not projected anonymously'
);
select is(
  (select primary_gym_name from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  null::text,
  'private gym name is not projected anonymously'
);
reset role;

update public.profile_privacy
set gym_audience = 'public'
where user_id = '98000000-0000-4000-8000-000000000101';

set local role anon;
select is(
  (select show_gym from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  true,
  'public gym audience is visible on an anonymous public profile'
);
select is(
  (select primary_gym_id from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  '98000000-0000-4000-8000-000000000102'::uuid,
  'public primary gym ID is projected'
);
select is(
  (select primary_gym_name from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  'Public Projection Test Gym',
  'public primary gym name is projected'
);
reset role;

update public.profile_privacy
set gym_audience = 'friends'
where user_id = '98000000-0000-4000-8000-000000000101';

set local role anon;
select is(
  (select show_gym from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  false,
  'friends-only gym audience is hidden from anonymous profiles'
);
select is(
  (select primary_gym_id from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  null::uuid,
  'friends-only gym ID is not projected anonymously'
);
select is(
  (select primary_gym_name from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  null::text,
  'friends-only gym name is not projected anonymously'
);
reset role;

update public.profile_privacy
set profile_audience = 'private', gym_audience = 'public'
where user_id = '98000000-0000-4000-8000-000000000101';

set local role anon;
select is(
  (select count(*)::integer from public.public_athletes where id = '98000000-0000-4000-8000-000000000101'),
  0,
  'private profile is absent from the anonymous public-athlete projection'
);
reset role;

select * from finish();
rollback;
