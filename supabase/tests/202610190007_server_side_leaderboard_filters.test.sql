begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

select has_function(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text','integer','uuid','text','text'],
  'server-filtered leaderboard overload exists without removing the earlier contracts'
);
select is_definer(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text','integer','uuid','text','text'],
  'server-filtered leaderboard overload remains security definer'
);
select is(
  (select p.proconfig::text from pg_catalog.pg_proc p
   join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'get_ranked_lift_ids' and p.pronargs = 16),
  '{search_path=pg_catalog}',
  'server-filtered leaderboard overload keeps the fixed search path'
);
select function_privs_are(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text','integer','uuid','text','text'],
  'authenticated', array['EXECUTE'],
  'server-filtered leaderboard is executable by authenticated users'
);
select function_privs_are(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text','integer','uuid','text','text'],
  'anon', array[]::text[],
  'server-filtered leaderboard is not executable by anonymous users'
);
select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text,integer,uuid,text,text)'::pg_catalog.regprocedure
    ),
    '$14 is null or (pd.city_id = $14 and public.can_view_profile_field'
  ) > 0,
  'city ID filtering is conditioned on profile location visibility'
);

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('99000000-0000-4000-8000-000000000401', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'leaderboard-advanced@example.test', '', '{}', '{}', now(), now()),
  ('99000000-0000-4000-8000-000000000402', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'leaderboard-beginner@example.test', '', '{}', '{}', now(), now()),
  ('99000000-0000-4000-8000-000000000403', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'leaderboard-viewer@example.test', '', '{}', '{}', now(), now());

update public.profile_privacy
set profile_audience = 'public', location_audience = 'public'
where user_id in (
  '99000000-0000-4000-8000-000000000401',
  '99000000-0000-4000-8000-000000000402'
);
update public.profile_private_details
set experience_level = 'advanced',
    city_id = (select id from public.location_cities order by country_code, ascii_name limit 1)
where user_id = '99000000-0000-4000-8000-000000000401';
update public.profile_private_details
set experience_level = 'beginner',
    city_id = (select id from public.location_cities order by country_code, ascii_name offset 1 limit 1)
where user_id = '99000000-0000-4000-8000-000000000402';

set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000401', true);
insert into public.lift_submissions (
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max
) values (
  '99000000-0000-4000-8000-000000000411', auth.uid(), 'bench', null, 225, 'lb', 1, 180, 'Public', 'Self Reported', '', now(), true
);
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000402', true);
insert into public.lift_submissions (
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max
) values (
  '99000000-0000-4000-8000-000000000412', auth.uid(), 'bench', null, 185, 'lb', 1, 170, 'Public', 'Self Reported', '', now(), true
);
reset role;

select is(
  (select count(distinct city_id)::integer from public.profile_private_details
   where user_id in ('99000000-0000-4000-8000-000000000401', '99000000-0000-4000-8000-000000000402')),
  2,
  'fixture profiles have distinct canonical city IDs'
);
select set_config(
  'test.city_id_filter',
  (select city_id::text from public.profile_private_details where user_id = '99000000-0000-4000-8000-000000000401'),
  true
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000403', true);
select is(
  (select array_agg(user_id order by user_id) from public.get_ranked_lift_ids(
    'bench', 'Absolute', null, null, null, null, null, null, null, null, false, 'All time', 1,
    current_setting('test.city_id_filter')::uuid, null, null
  )),
  array['99000000-0000-4000-8000-000000000401'::uuid],
  'city ID filter returns only the matching visible city'
);
reset role;
update public.profile_privacy
set location_audience = 'private'
where user_id = '99000000-0000-4000-8000-000000000401';
set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000403', true);
select is(
  (select count(*)::integer from public.get_ranked_lift_ids(
    'bench', 'Absolute', null, null, null, null, null, null, null, null, false, 'All time', 1,
    current_setting('test.city_id_filter')::uuid, null, null
  )),
  0,
  'city ID filtering does not reveal a hidden location through leaderboard membership'
);
reset role;
update public.profile_privacy
set location_audience = 'public'
where user_id = '99000000-0000-4000-8000-000000000401';
set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000403', true);
select is(
  (select user_id from public.get_ranked_lift_ids(
    'bench', 'Absolute', null, null, null, null, null, null, null, null, false, 'All time', 1,
    null, 'advanced', null
  )),
  '99000000-0000-4000-8000-000000000401'::uuid,
  'experience filter returns the matching profile rather than defaulting all remote cards to beginner'
);
select is(
  (select user_id from public.get_ranked_lift_ids(
    'bench', 'Absolute', null, null, null, null, null, null, null, null, false, 'All time', 1,
    current_setting('test.city_id_filter')::uuid, 'advanced', 'self_reported'
  )),
  '99000000-0000-4000-8000-000000000401'::uuid,
  'city, experience, and evidence filters compose before ranking'
);
select is(
  (select count(*)::integer from public.get_ranked_lift_ids(
    'bench', 'Absolute', null, null, null, null, null, null, null, null, false, 'All time', 1,
    null, null, 'self_reported'
  )),
  2,
  'self-reported evidence filter preserves all matching self-reported lifters'
);
select is(
  (select count(*)::integer from public.get_ranked_lift_ids(
    'bench', 'Absolute', null, null, null, null, null, null, null, null, false, 'All time', 1,
    null, null, 'video_backed'
  )),
  0,
  'video-backed evidence filter excludes self-reported lifts'
);
select is(
  (select count(*)::integer from public.get_ranked_lift_ids(
    'bench', 'Absolute', null, null, null, null, null, null, null, null, false, 'All time', 1,
    null, null, null
  )),
  2,
  'null server-side filters preserve the unfiltered result set'
);
reset role;

select * from finish();
rollback;
