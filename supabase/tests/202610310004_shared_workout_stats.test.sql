begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(26);

select has_function(
  'public', 'get_shared_workout_stats', array['uuid'],
  'aggregate workout stats RPC exists'
);
select is_definer(
  'public', 'get_shared_workout_stats', array['uuid'],
  'aggregate workout stats runs with its fixed owner'
);
select is(
  (select p.proconfig::text
   from pg_catalog.pg_proc p
   join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_shared_workout_stats'),
  '{search_path=pg_catalog}',
  'aggregate workout stats has a fixed catalog-only search path'
);
select function_privs_are(
  'public', 'get_shared_workout_stats', array['uuid'],
  'authenticated', array['EXECUTE'], 'authenticated members can query aggregates'
);
select function_privs_are(
  'public', 'get_shared_workout_stats', array['uuid'],
  'anon', array[]::text[], 'anonymous members cannot query aggregates'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  ('c3100000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'workout-stats-' || n || '@example.test', '', '{}'::jsonb,
  jsonb_build_object('display_name', 'Stats User ' || n), now(), now()
from generate_series(1, 5) n;

select is(
  (select workout_stats_audience from public.profile_privacy
   where user_id = 'c3100000-0000-4000-8000-000000000001'),
  'private',
  'new and existing privacy rows default workout stats to private'
);

update public.profile_privacy
set profile_audience = 'public'
where user_id = 'c3100000-0000-4000-8000-000000000001';
insert into public.friend_relationships(user_low_id, user_high_id, requested_by, status, responded_at)
values (
  'c3100000-0000-4000-8000-000000000001',
  'c3100000-0000-4000-8000-000000000002',
  'c3100000-0000-4000-8000-000000000001', 'accepted', now()
);
insert into public.gyms(id, name, status)
values ('c3200000-0000-4000-8000-000000000001', 'Workout stats gym', 'active');
insert into public.gym_memberships(user_id, gym_id, is_primary)
values
  ('c3100000-0000-4000-8000-000000000001', 'c3200000-0000-4000-8000-000000000001', true),
  ('c3100000-0000-4000-8000-000000000003', 'c3200000-0000-4000-8000-000000000001', true);
insert into public.user_blocks(blocker_id, blocked_id)
values (
  'c3100000-0000-4000-8000-000000000001',
  'c3100000-0000-4000-8000-000000000005'
);
insert into public.completed_workout_snapshots(id, owner_id, payload, completed_at)
values
  ('c3300000-0000-4000-8000-000000000001', 'c3100000-0000-4000-8000-000000000001', '{"secret":"first"}', now() - interval '1 day'),
  ('c3300000-0000-4000-8000-000000000002', 'c3100000-0000-4000-8000-000000000001', '{"secret":"second"}', now() - interval '6 days'),
  ('c3300000-0000-4000-8000-000000000003', 'c3100000-0000-4000-8000-000000000001', '{"secret":"third"}', now() - interval '8 days');

select ok(
  has_table_privilege('authenticated', 'public.completed_workout_snapshots', 'SELECT')
  and has_table_privilege('authenticated', 'public.completed_workout_snapshots', 'INSERT')
  and has_table_privilege('authenticated', 'public.completed_workout_snapshots', 'UPDATE')
  and has_table_privilege('authenticated', 'public.completed_workout_snapshots', 'DELETE'),
  'authenticated workout sync has required snapshot CRUD privileges before row-level ownership filtering'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000001', true);
select is(
  (select workout_count from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  3::bigint, 'owner can read the aggregate count while stats are private'
);
select is(
  (select recent_workout_count from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  2::bigint, 'recent aggregate counts only completed workouts from the last seven days'
);
select is(
  (select latest_workout_at from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  (select max(completed_at) from public.completed_workout_snapshots
   where owner_id = 'c3100000-0000-4000-8000-000000000001'),
  'aggregate reports the latest completion timestamp'
);
select is(
  (select count(*) from public.completed_workout_snapshots),
  3::bigint, 'owner can read their raw completed workout snapshots'
);
select lives_ok(
  $$update public.completed_workout_snapshots
    set payload = '{"secret":"owner-updated"}'
    where owner_id = 'c3100000-0000-4000-8000-000000000001'
      and id = 'c3300000-0000-4000-8000-000000000001'$$,
  'owner can update their raw workout snapshot'
);

select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000002', true);
select is(
  (select count(*) from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  0::bigint, 'friend cannot read aggregates under the default private setting'
);
select is(
  (select count(*) from public.completed_workout_snapshots),
  0::bigint, 'friend cannot read raw workout snapshots'
);
select throws_ok(
  $$insert into public.completed_workout_snapshots(id, owner_id, payload, completed_at)
    values ('c3300000-0000-4000-8000-000000000004',
      'c3100000-0000-4000-8000-000000000001', '{}', now())$$,
  '42501', null, 'friend cannot write a snapshot owned by another account'
);

reset role;
update public.profile_privacy set workout_stats_audience = 'friends'
where user_id = 'c3100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000002', true);
select is(
  (select workout_count from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  3::bigint, 'accepted friend can read aggregate stats when shared with friends'
);
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000004', true);
select is(
  (select count(*) from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  0::bigint, 'stranger cannot read friend-only aggregate stats'
);

reset role;
update public.profile_privacy set workout_stats_audience = 'gym'
where user_id = 'c3100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000003', true);
select is(
  (select workout_count from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  3::bigint, 'active shared-gym member can read gym-only aggregate stats'
);
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000002', true);
select is(
  (select count(*) from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  0::bigint, 'friend outside the shared gym cannot read gym-only aggregate stats'
);

reset role;
update public.profile_privacy set workout_stats_audience = 'public'
where user_id = 'c3100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000004', true);
select is(
  (select workout_count from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  3::bigint, 'stranger can read aggregate stats when shared publicly'
);
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000005', true);
select is(
  (select count(*) from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  0::bigint, 'blocked user cannot read aggregates even when public'
);
reset role;
update public.profile_privacy
set profile_audience = 'private'
where user_id = 'c3100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000004', true);
select is(
  (select count(*) from public.get_shared_workout_stats('c3100000-0000-4000-8000-000000000001')),
  0::bigint, 'aggregate sharing also respects the profile audience gate'
);
reset role;

insert into public.profile_private_details(user_id)
values ('c3100000-0000-4000-8000-000000000001') on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000001', true);
select public.save_own_profile_mobile(
  '{"new_display_name":"Stats Owner","new_bio":"Training","new_preferred_unit":"kg",
    "new_birth_date":"1990-01-02","new_sex_category":"male","new_height_cm":180,
    "new_city_id":null,"new_city":null,"new_region":null,"new_country_code":null,
    "new_years_experience":5,"new_experience_level":"intermediate","new_profile_audience":"public",
    "new_age_band_audience":"public","new_division_audience":"friends","new_location_audience":"gym",
    "new_gym_audience":"public","new_friend_list_audience":"private","new_bodyweight_audience":"private",
    "new_show_lift_videos":true,"complete_onboarding":true,"new_bodyweight_pounds":200,
    "new_training_focus":"bodybuilding","new_avatar_path":null,"updates_primary_gym":false,
    "new_workout_stats_audience":"friends"}'::jsonb
);
reset role;
select is(
  (select workout_stats_audience from public.profile_privacy
   where user_id = 'c3100000-0000-4000-8000-000000000001'),
  'friends', 'atomic profile save persists workout stats audience'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select public.save_own_profile_mobile(
    '{"new_display_name":"Must roll back","new_bio":"Training","new_preferred_unit":"kg",
      "new_birth_date":"1990-01-02","new_sex_category":"male","new_height_cm":180,
      "new_city_id":null,"new_city":null,"new_region":null,"new_country_code":null,
      "new_years_experience":5,"new_experience_level":"intermediate","new_profile_audience":"private",
      "new_age_band_audience":"public","new_division_audience":"friends","new_location_audience":"gym",
      "new_gym_audience":"public","new_friend_list_audience":"private","new_bodyweight_audience":"private",
      "new_show_lift_videos":false,"complete_onboarding":true,"new_bodyweight_pounds":200,
      "new_training_focus":"bodybuilding","new_avatar_path":null,"updates_primary_gym":false,
      "new_workout_stats_audience":"invalid"}'::jsonb
  )$$,
  '23514',
  null,
  'invalid workout stats audience is rejected by atomic profile save'
);
reset role;
select is(
  (select display_name from public.profiles
   where id = 'c3100000-0000-4000-8000-000000000001'),
  'Stats Owner', 'failed privacy update rolls back preceding profile fields'
);
select is(
  (select workout_stats_audience from public.profile_privacy
   where user_id = 'c3100000-0000-4000-8000-000000000001'),
  'friends', 'failed privacy update retains the saved sharing choice'
);

select * from finish();
rollback;
