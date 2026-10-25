begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(14);

select has_table('public', 'profile_username_changes', 'username change audit table exists');
select has_function('public', 'change_username', array['text', 'text'], 'explicit username change function exists');
select has_trigger('public', 'profiles', 'protect_profile_identity', 'profile identity protection trigger exists');
select ok(
  not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'claim_username'
  ),
  'implicit claim_username function is removed'
);
select ok(
  not has_column_privilege('authenticated', 'public.profiles', 'username', 'UPDATE'),
  'authenticated clients cannot directly update usernames'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values (
  'a1000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'username-owner@example.test', '', '{}'::jsonb, '{}'::jsonb,
  now(), now()
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
set local role authenticated;

select is(
  (select username from public.profiles where id = 'a1000000-0000-0000-0000-000000000001'),
  'member_a10000000000',
  'new profiles start with their generated username'
);

select lives_ok(
  $$select public.save_own_profile(
    'Updated Owner', '', 'lb', null, 'open', null,
    '', '', 'US', 0::smallint, 'beginner',
    'public', 'public', 'public', 'friends', 'public', 'friends', true, null
  )$$,
  'normal profile saves still succeed'
);
select is(
  (select username from public.profiles where id = 'a1000000-0000-0000-0000-000000000001'),
  'member_a10000000000',
  'normal profile saves preserve the username'
);

select throws_ok(
  $$update public.profiles set username = 'unauthorized_name' where id = 'a1000000-0000-0000-0000-000000000001'$$,
  '42501',
  'permission denied for table profiles',
  'direct username updates are rejected'
);

select is(
  public.change_username('member_a10000000000', 'Rob'),
  'rob',
  'explicit username changes normalize the requested value'
);
select is(
  (select username from public.profiles where id = 'a1000000-0000-0000-0000-000000000001'),
  'rob',
  'explicit username changes update the username'
);
select is(
  (select handle from public.profiles where id = 'a1000000-0000-0000-0000-000000000001'),
  '@rob',
  'explicit username changes keep the handle synchronized'
);
reset role;
select is(
  (select count(*)::integer from public.profile_username_changes where user_id = 'a1000000-0000-0000-0000-000000000001'),
  1,
  'explicit username changes are audited'
);
set local role authenticated;
select throws_ok(
  $$select public.change_username('stale_name', 'another_name')$$,
  '40001',
  'Profile changed; reload before changing the username',
  'stale username changes are rejected'
);

select * from finish();
rollback;
