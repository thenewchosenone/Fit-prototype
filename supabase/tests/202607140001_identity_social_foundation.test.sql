begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(64);

select has_table('public', 'profiles', 'profiles exists');
select has_table('public', 'profile_private_details', 'private profile details exist');
select has_table('public', 'profile_privacy', 'profile privacy exists');
select has_table('public', 'gyms', 'gyms exist');
select has_table('public', 'gym_memberships', 'canonical gym memberships exist');
select has_table('public', 'friend_relationships', 'canonical friend relationships exist');
select has_function('public', 'join_gym', array['uuid', 'boolean'], 'secure gym join function exists');
select has_function('public', 'request_friendship', array['uuid'], 'secure friendship request function exists');
select has_table('public', 'gym_memberships_legacy_20260712', 'legacy gym memberships remain intact');
select has_table('public', 'friendships_legacy_20260712', 'legacy friendships remain intact');
select has_table('public', 'lift_submissions', 'existing lift submissions still exist');
select is(
  (
    select c.data_type
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = 'lift_submissions' and c.column_name = 'gym_id'
  ),
  'text',
  'Migration 1 preserves the legacy lift gym identifier for later reconciliation'
);

create or replace function pg_temp.sqlstate_of(command text)
returns text
language plpgsql
as $$
begin
  execute command;
  return null;
exception when others then
  return sqlstate;
end;
$$;

create or replace function pg_temp.affected_rows_of(command text)
returns integer
language plpgsql
as $$
declare
  affected_rows integer;
begin
  execute command;
  get diagnostics affected_rows = row_count;
  return affected_rows;
end;
$$;

-- Stable fixture IDs make failures easy to reproduce.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'recipient@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'stranger@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

select is(
  (select count(*)::integer from public.profiles where id = '10000000-0000-0000-0000-000000000001'),
  1,
  'auth signup creates exactly one profile'
);
select is(
  (select count(*)::integer from public.profile_private_details where user_id = '10000000-0000-0000-0000-000000000001'),
  1,
  'auth signup creates exactly one private-details row'
);
select is(
  (select count(*)::integer from public.profile_privacy where user_id = '10000000-0000-0000-0000-000000000001'),
  1,
  'auth signup creates exactly one privacy row'
);
select isnt(
  (select position('owner' in username) from public.profiles where id = '10000000-0000-0000-0000-000000000001'),
  1,
  'placeholder username does not expose the email local-part'
);
select matches(
  (select username from public.profiles where id = '10000000-0000-0000-0000-000000000001'),
  '^member_[a-f0-9]{12}$',
  'placeholder username is an opaque account-ID derivative'
);
select has_index('public', 'profiles', 'profiles_username_lower_unique', 'usernames have case-insensitive uniqueness');

update public.profile_private_details
set birth_date = (current_date - interval '36 years')::date,
    sex_category = 'female',
    city = 'Private City',
    region = 'Private Region'
where user_id = '10000000-0000-0000-0000-000000000002';

insert into public.gyms (id, name, status) values
  ('20000000-0000-0000-0000-000000000001', 'Gym One', 'active'),
  ('20000000-0000-0000-0000-000000000002', 'Gym Two', 'active'),
  ('20000000-0000-0000-0000-000000000003', 'Gym Three', 'active'),
  ('20000000-0000-0000-0000-000000000004', 'Gym Four', 'active'),
  ('20000000-0000-0000-0000-000000000005', 'Recipient Gym', 'active');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select public.join_gym('20000000-0000-0000-0000-000000000005', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select count(*)::integer from public.profile_private_details),
  1,
  'a user can read only their own private details'
);
select is(
  (select count(*)::integer from public.profile_privacy),
  1,
  'a user can read only their own privacy settings'
);
select is(
  pg_temp.affected_rows_of($$
    update public.profile_private_details
    set city = 'Stolen'
    where user_id = '10000000-0000-0000-0000-000000000002'
  $$),
  0,
  'a user cannot modify another user private details'
);
select is(
  pg_temp.affected_rows_of($$
    update public.profile_privacy
    set profile_audience = 'private'
    where user_id = '10000000-0000-0000-0000-000000000002'
  $$),
  0,
  'a user cannot modify another user privacy settings'
);
select is(
  pg_temp.affected_rows_of($$
    update public.profiles
    set display_name = 'Unauthorized Name'
    where id = '10000000-0000-0000-0000-000000000002'
  $$),
  0,
  'a user cannot modify another user public profile'
);
select lives_ok(
  $$update public.profiles set display_name = 'Updated Owner' where id = '10000000-0000-0000-0000-000000000001'$$,
  'an owner can update a permitted profile field'
);
select is(
  (select display_name from public.profiles where id = '10000000-0000-0000-0000-000000000001'),
  'Updated Owner',
  'the permitted owner profile update is persisted'
);
select lives_ok(
  $$select public.save_own_profile(
    'Saved Owner', 'Remote profile', 'kg', date '1990-04-20', 'open', 180::numeric,
    'Miami', 'Florida', 'us', 5::smallint, 'intermediate',
    'public', 'friends', 'public', 'gym', 'friends', 'private', true
  )$$,
  'the transactional profile function saves an owner profile'
);
select is(
  (select preferred_unit from public.profile_private_details where user_id = '10000000-0000-0000-0000-000000000001'),
  'kg',
  'transactional profile save persists private details'
);
select is(
  (select location_audience from public.profile_privacy where user_id = '10000000-0000-0000-0000-000000000001'),
  'gym',
  'transactional profile save persists privacy settings'
);
select is(
  (select onboarding_completed from public.profiles where id = '10000000-0000-0000-0000-000000000001'),
  true,
  'transactional profile save completes onboarding'
);
select is(
  pg_temp.sqlstate_of($$update public.profiles set updated_at = now() where id = '10000000-0000-0000-0000-000000000001'$$),
  '42501',
  'clients cannot write server-controlled profile timestamps'
);
select is(
  pg_temp.sqlstate_of($$update public.profiles set role = 'Admin' where id = '10000000-0000-0000-0000-000000000001'$$),
  '42501',
  'clients cannot write server-controlled profile roles'
);
select is(
  (select age_band from public.get_profile_card('10000000-0000-0000-0000-000000000002')),
  '35-39',
  'profile cards expose an allowed derived age band, never the birth date'
);
select is(
  (select sex_category from public.get_profile_card('10000000-0000-0000-0000-000000000002')),
  'female',
  'profile cards expose an allowed division field'
);
select is(
  (select city from public.get_profile_card('10000000-0000-0000-0000-000000000002')),
  null,
  'profile cards redact friends-only location from unrelated users'
);
select is(
  (select primary_gym_name from public.get_profile_card('10000000-0000-0000-0000-000000000002')),
  'Recipient Gym',
  'profile cards expose an allowed public primary gym'
);

select lives_ok(
  $$select public.join_gym('20000000-0000-0000-0000-000000000001', true)$$,
  'first gym can be joined'
);
select lives_ok(
  $$select public.join_gym('20000000-0000-0000-0000-000000000002', false)$$,
  'second gym can be joined'
);
select lives_ok(
  $$select public.join_gym('20000000-0000-0000-0000-000000000003', false)$$,
  'third gym can be joined'
);
select throws_ok(
  $$select public.join_gym('20000000-0000-0000-0000-000000000004', false)$$,
  '23514',
  'A user may join at most three active gyms',
  'a fourth active gym is rejected'
);
select is(
  (select count(*)::integer from public.gym_memberships where left_at is null),
  3,
  'the user has at most three visible active memberships'
);
select is(
  (select count(*)::integer from public.gym_memberships where left_at is null and is_primary),
  1,
  'the user has exactly one active primary gym'
);
select throws_ok(
  $$select public.leave_gym('20000000-0000-0000-0000-000000000001')$$,
  '23514',
  'Choose another primary gym before leaving',
  'the primary gym cannot be accidentally left'
);
select is(
  pg_temp.sqlstate_of($$insert into public.gym_memberships(user_id, gym_id) values ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000004')$$),
  '42501',
  'direct gym-membership mutation is denied'
);
select throws_ok(
  $$select public.leave_gym('20000000-0000-0000-0000-000000000005')$$,
  'P0002',
  'Active gym membership not found',
  'a caller cannot leave another user gym membership'
);

select throws_ok(
  $$select public.request_friendship('10000000-0000-0000-0000-000000000001')$$,
  '23514',
  'Users cannot friend themselves',
  'a user cannot request themselves as a friend'
);
select lives_ok(
  $$select public.request_friendship('10000000-0000-0000-0000-000000000002')$$,
  'a user can request another user as a friend'
);
select is(
  (select count(*)::integer from public.friend_relationships),
  1,
  'one normalized relationship row is created'
);
select throws_ok(
  $$select public.respond_to_friendship((select id from public.friend_relationships), true)$$,
  '42501',
  'Only the recipient may respond to a friend request',
  'the requester cannot accept their own request'
);
select is(
  pg_temp.sqlstate_of($$update public.friend_relationships set status = 'accepted'$$),
  '42501',
  'direct friendship state mutation is denied'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.request_friendship('10000000-0000-0000-0000-000000000001')$$,
  '23505',
  'A friendship or pending request already exists',
  'a reverse request cannot create a duplicate relationship'
);
select lives_ok(
  $$select public.respond_to_friendship((select id from public.friend_relationships), true)$$,
  'the recipient can accept the request'
);
select is(
  (select count(*)::integer from public.friend_relationships where status = 'accepted'),
  1,
  'acceptance updates the one normalized relationship'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  (select city from public.get_profile_card('10000000-0000-0000-0000-000000000002')),
  'Private City',
  'profile cards expose friends-only location after friendship acceptance'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select is(
  (select count(*)::integer from public.friend_relationships),
  0,
  'a non-participant cannot read a friendship'
);
select is(
  (select count(*)::integer from public.gym_memberships),
  0,
  'a user cannot read another user gym memberships directly'
);

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  pg_temp.sqlstate_of($$select count(*) from public.profiles$$),
  '42501',
  'anonymous users cannot browse beta profiles'
);
select is(
  pg_temp.sqlstate_of($$select count(*) from public.gym_memberships$$),
  '42501',
  'anonymous users cannot browse gym memberships'
);

reset role;
select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'create_profile_for_new_user', 'are_friends', 'share_active_gym',
        'can_view_profile_field', 'can_view_profile', 'get_profile_card',
        'claim_username', 'join_gym', 'leave_gym', 'set_primary_gym',
        'save_own_profile',
        'request_friendship', 'respond_to_friendship', 'cancel_friendship',
        'remove_friendship', 'is_admin', 'moderates', 'is_thread_member'
      )
      and p.prosecdef
      and not ('search_path=pg_catalog' = any(coalesce(p.proconfig, array[]::text[])))
  ),
  0,
  'all security-definer functions use a fixed pg_catalog search path'
);
select matches(
  pg_get_functiondef('public.join_gym(uuid,boolean)'::regprocedure),
  '(?i)for[[:space:]]+update',
  'gym joins take a per-user row lock before checking the membership limit'
);
select ok(
  (select i.indisunique and i.indpred is not null
   from pg_index i
   where i.indexrelid = 'public.gym_memberships_one_active_primary'::regclass),
  'a partial unique index enforces one active primary gym'
);
select is(
  (
    select count(*)::integer
    from information_schema.parameters p
    where p.specific_schema = 'public'
      and p.specific_name like 'get_profile_card_%'
      and p.parameter_name = 'birth_date'
  ),
  0,
  'the public profile-card contract never returns an exact birth date'
);
select ok(
  has_function_privilege('authenticated', 'public.join_gym(uuid,boolean)', 'EXECUTE'),
  'authenticated users can execute secured mutation functions'
);
select ok(
  not has_function_privilege('anon', 'public.join_gym(uuid,boolean)', 'EXECUTE'),
  'anonymous users cannot execute secured mutation functions'
);
select ok(
  not has_function_privilege('authenticated', 'public.create_profile_for_new_user()', 'EXECUTE'),
  'authenticated users cannot invoke the auth trigger function directly'
);

select * from finish();
rollback;
