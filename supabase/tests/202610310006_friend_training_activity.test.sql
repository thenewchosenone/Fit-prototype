begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(38);

select has_function('public', 'record_friend_workout_start', array['uuid','uuid'], 'workout-start RPC exists');
select has_function('public', 'record_friend_top_lift', array['uuid'], 'top-lift RPC exists');
select has_function('public', 'get_friend_training_activity', array[]::text[], 'friend activity feed RPC exists');
select function_privs_are('public', 'record_friend_workout_start', array['uuid','uuid'], 'authenticated', array['EXECUTE'], 'authenticated members can record workout starts');
select function_privs_are('public', 'record_friend_workout_start', array['uuid','uuid'], 'anon', array[]::text[], 'anonymous members cannot record workout starts');
select function_privs_are('public', 'record_friend_top_lift', array['uuid'], 'authenticated', array['EXECUTE'], 'authenticated members can record top lifts');
select function_privs_are('public', 'record_friend_top_lift', array['uuid'], 'anon', array[]::text[], 'anonymous members cannot record top lifts');
select function_privs_are('public', 'get_friend_training_activity', array[]::text[], 'authenticated', array['EXECUTE'], 'authenticated members can query friend activity');
select function_privs_are('public', 'get_friend_training_activity', array[]::text[], 'anon', array[]::text[], 'anonymous members cannot query friend activity');
select ok(
  (select count(*) = 3 from pg_catalog.pg_proc p
   join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('record_friend_workout_start','record_friend_top_lift','get_friend_training_activity')
     and p.prosecdef
     and p.proconfig = array['search_path=pg_catalog']),
  'all friend activity RPCs use SECURITY DEFINER with a fixed search path'
);
select ok(
  not has_table_privilege('authenticated', 'public.friend_training_activity', 'SELECT')
  and not has_table_privilege('authenticated', 'public.friend_training_activity', 'INSERT')
  and not has_table_privilege('authenticated', 'public.friend_training_activity', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.friend_training_activity', 'DELETE'),
  'authenticated members have no direct activity-table privileges'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  ('d4100000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'friend-activity-' || n || '@example.test', '', '{}'::jsonb,
  jsonb_build_object('display_name', 'Activity User ' || n), now(), now()
from generate_series(1, 4) n;

update public.profile_privacy
set profile_audience = 'friends'
where user_id = 'd4100000-0000-4000-8000-000000000001';
insert into public.friend_relationships(user_low_id, user_high_id, requested_by, status, responded_at)
values
  ('d4100000-0000-4000-8000-000000000001', 'd4100000-0000-4000-8000-000000000002', 'd4100000-0000-4000-8000-000000000001', 'accepted', now()),
  ('d4100000-0000-4000-8000-000000000001', 'd4100000-0000-4000-8000-000000000004', 'd4100000-0000-4000-8000-000000000001', 'accepted', now());
insert into public.user_blocks(blocker_id, blocked_id)
values ('d4100000-0000-4000-8000-000000000001', 'd4100000-0000-4000-8000-000000000004');
insert into public.gyms(id, name, status)
values ('d4200000-0000-4000-8000-000000000001', 'Activity test gym', 'active');
insert into public.gym_memberships(user_id, gym_id, is_primary)
values
  ('d4100000-0000-4000-8000-000000000001', 'd4200000-0000-4000-8000-000000000001', true),
  ('d4100000-0000-4000-8000-000000000002', 'd4200000-0000-4000-8000-000000000001', true);

select is(
  (select share_workout_starts_with_friends::text || ':' || share_prs_with_friends::text
   from public.profile_privacy where user_id = 'd4100000-0000-4000-8000-000000000001'),
  'false:false', 'both friend activity preferences default off'
);

create function pg_temp.profile_payload(overrides jsonb default '{}') returns jsonb language sql as $$
select '{"new_display_name":"Activity Owner","new_bio":"Training","new_preferred_unit":"kg",
"new_birth_date":"1990-01-02","new_sex_category":"male","new_height_cm":180,
"new_city_id":null,"new_city":null,"new_region":null,"new_country_code":null,
"new_years_experience":5,"new_experience_level":"intermediate","new_profile_audience":"friends",
"new_age_band_audience":"public","new_division_audience":"friends","new_location_audience":"private",
"new_gym_audience":"private","new_friend_list_audience":"friends","new_bodyweight_audience":"private",
"new_show_lift_videos":false,"complete_onboarding":true,"new_bodyweight_pounds":180,
"new_training_focus":"bodybuilding","new_avatar_path":null,"updates_primary_gym":false}'::jsonb || overrides
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000001', true);
select public.record_friend_workout_start('d4300000-0000-4000-8000-000000000001', auth.uid());
insert into public.lift_submissions(
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max
)
values
  ('d4400000-0000-4000-8000-000000000001', auth.uid(), 'bench', 'd4200000-0000-4000-8000-000000000001', 225, 'lb', 1, 180, 'Public', 'Self Reported', 'top bench', now(), true),
  ('d4400000-0000-4000-8000-000000000002', auth.uid(), 'bench', 'd4200000-0000-4000-8000-000000000001', 200, 'lb', 1, 180, 'Public', 'Self Reported', 'lower bench', now(), true),
  ('d4400000-0000-4000-8000-000000000003', auth.uid(), 'bench', 'd4200000-0000-4000-8000-000000000001', 300, 'lb', 2, 180, 'Public', 'Self Reported', 'not a one rep max', now(), false);
select public.record_friend_top_lift('d4400000-0000-4000-8000-000000000001');
reset role;

select is(
  (select count(*) from public.friend_training_activity),
  0::bigint, 'default-off preferences do not write workout or PR events'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000002', true);
insert into public.lift_submissions(
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max
)
values (
  'd4400000-0000-4000-8000-000000000004', auth.uid(), 'squat', 'd4200000-0000-4000-8000-000000000001',
  185, 'lb', 1, 160, 'Public', 'Self Reported', 'friend squat', now(), true
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select public.record_friend_workout_start(
    'd4300000-0000-4000-8000-000000000001', 'd4100000-0000-4000-8000-000000000002'
  )$$,
  '42501', 'Workout belongs to another account', 'stale account context cannot record a workout start'
);
select public.save_own_profile_mobile(pg_temp.profile_payload(
  '{"new_share_workout_starts_with_friends":true,"new_share_prs_with_friends":true}'
));
select is(
  (select share_workout_starts_with_friends::text || ':' || share_prs_with_friends::text
   from public.profile_privacy where user_id = auth.uid()),
  'true:true', 'atomic mobile profile save persists both friend activity preferences'
);
select lives_ok(
  $$select public.record_friend_workout_start('d4300000-0000-4000-8000-000000000001', 'd4100000-0000-4000-8000-000000000001')$$,
  'owner can record an opted-in workout start'
);
select lives_ok(
  $$select public.record_friend_workout_start('d4300000-0000-4000-8000-000000000001', 'd4100000-0000-4000-8000-000000000001')$$,
  'repeated workout start recording is idempotent'
);
select lives_ok(
  $$select public.record_friend_top_lift('d4400000-0000-4000-8000-000000000001')$$,
  'owner can record an eligible top lift'
);
select lives_ok(
  $$select public.record_friend_top_lift('d4400000-0000-4000-8000-000000000002')$$,
  'a lower non-PR lift is safely ignored'
);
select lives_ok(
  $$select public.record_friend_top_lift('d4400000-0000-4000-8000-000000000003')$$,
  'a multi-rep non-1RM is safely ignored'
);
select throws_ok(
  $$select public.record_friend_top_lift('d4400000-0000-4000-8000-000000000004')$$,
  '42501', 'Lift is not owned by this account', 'another account cannot emit a lift into the caller activity'
);
reset role;
select is(
  (select count(*) from public.friend_training_activity
   where owner_id = 'd4100000-0000-4000-8000-000000000001' and kind = 'workout_started'
     and source_id = 'd4300000-0000-4000-8000-000000000001'),
  1::bigint, 'duplicate start calls create one owner-scoped activity row'
);
select is(
  (select count(*) from public.friend_training_activity
   where owner_id = 'd4100000-0000-4000-8000-000000000001' and kind = 'top_lift'
     and source_id = 'd4400000-0000-4000-8000-000000000001'),
  1::bigint, 'only the eligible top lift creates a PR activity row'
);
select ok(
  (select occurred_at between statement_timestamp() - interval '1 minute' and statement_timestamp() + interval '1 second'
   from public.friend_training_activity
   where owner_id = 'd4100000-0000-4000-8000-000000000001'
     and kind = 'workout_started' and source_id = 'd4300000-0000-4000-8000-000000000001'),
  'activity timestamp is assigned by the server at insert time'
);
select is(
  (select count(*) from public.friend_training_activity),
  2::bigint, 'ignored lifts do not add activity rows'
);

select is(
  (select count(*) from public.friend_training_activity),
  2::bigint, 'direct database inspection sees exactly the two owner events'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.get_friend_training_activity()), 2::bigint, 'accepted friend sees opted-in workout and PR activity');
select ok(
  (select bool_and(owner_id = 'd4100000-0000-4000-8000-000000000001' and display_name = 'Activity Owner')
   from public.get_friend_training_activity()),
  'friend feed identifies the event owner without exposing raw snapshots'
);
select throws_ok(
  $$select * from public.friend_training_activity$$,
  '42501', null, 'authenticated members cannot query raw activity rows directly'
);
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000003', true);
select is((select count(*) from public.get_friend_training_activity()), 0::bigint, 'stranger cannot see friend activity');
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000004', true);
select is((select count(*) from public.get_friend_training_activity()), 0::bigint, 'blocked accepted friend cannot see activity');
reset role;

update public.profile_privacy set profile_audience = 'private'
where user_id = 'd4100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.get_friend_training_activity()), 0::bigint, 'profile privacy revocation immediately hides the feed');
reset role;
update public.profile_privacy set profile_audience = 'friends'
where user_id = 'd4100000-0000-4000-8000-000000000001';
update public.profile_privacy set share_workout_starts_with_friends = false
where user_id = 'd4100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.get_friend_training_activity()), 1::bigint, 'turning off workout-start sharing revokes only start activity');
reset role;
update public.profile_privacy set share_workout_starts_with_friends = true, share_prs_with_friends = false
where user_id = 'd4100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.get_friend_training_activity()), 1::bigint, 'turning off PR sharing revokes only top-lift activity');
reset role;
update public.profile_privacy set share_prs_with_friends = true
where user_id = 'd4100000-0000-4000-8000-000000000001';

alter table public.lift_submissions disable trigger competitive_lift_authority;
update public.lift_submissions set moderation_status = 'under_review'
where id = 'd4400000-0000-4000-8000-000000000001';
alter table public.lift_submissions enable trigger competitive_lift_authority;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.get_friend_training_activity()), 1::bigint, 'moderation changes immediately hide a prior PR event');
reset role;
alter table public.lift_submissions disable trigger competitive_lift_authority;
update public.lift_submissions set moderation_status = 'clear', visibility = 'Friends'
where id = 'd4400000-0000-4000-8000-000000000001';
alter table public.lift_submissions enable trigger competitive_lift_authority;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.get_friend_training_activity()), 2::bigint, 'accepted friend can see a clear Friends-visible top lift');
reset role;
alter table public.lift_submissions disable trigger competitive_lift_authority;
update public.lift_submissions set visibility = 'Private'
where id = 'd4400000-0000-4000-8000-000000000001';
alter table public.lift_submissions enable trigger competitive_lift_authority;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4100000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.get_friend_training_activity()), 1::bigint, 'changing a prior PR source to Private hides it from the friend feed');
reset role;

set local role anon;
select throws_ok(
  $$select public.get_friend_training_activity()$$,
  '42501', null, 'anonymous caller cannot read friend activity'
);
reset role;

select * from finish();
rollback;
