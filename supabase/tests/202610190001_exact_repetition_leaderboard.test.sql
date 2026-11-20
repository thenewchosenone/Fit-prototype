begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select has_function(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text'],
  'the existing public-leaderboard RPC signature remains available'
);

select has_function(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text','integer'],
  'exact-repetition leaderboard RPC overload exists'
);

select is_definer(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text','integer'],
  'exact-repetition ranking retains the security-definer boundary'
);

select is(
  (
    select p.proconfig::text
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_ranked_lift_ids'
      and p.pronargs = 13
  ),
  '{search_path=pg_catalog}',
  'exact-repetition ranking keeps a fixed search path'
);

select function_privs_are(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text','integer'],
  'authenticated', array['EXECUTE'],
  'exact-repetition ranking is executable by authenticated users'
);

select function_privs_are(
  'public', 'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text','integer'],
  'anon', array[]::text[],
  'exact-repetition ranking is not executable by anonymous users'
);

select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text,integer)'::pg_catalog.regprocedure
    ),
    '$13 is not null and l.reps = $13'
  ) > 0,
  'the selected exact rep count constrains eligible lift rows'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '93000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'exact-repetition@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()
);
update public.profile_privacy
set profile_audience = 'public'
where user_id = '93000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000001', true);
select lives_ok($$
  insert into public.lift_submissions (
    id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
    visibility, verification, caption, performed_at, is_actual_one_rep_max
  ) values
    ('94000000-0000-4000-8000-000000000001', auth.uid(), 'bench', null, 200, 'lb', 1, 180, 'Public', 'Self Reported', '', now(), true),
    ('94000000-0000-4000-8000-000000000002', auth.uid(), 'bench', null, 150, 'lb', 5, 180, 'Public', 'Self Reported', '', now(), false),
    ('94000000-0000-4000-8000-000000000003', auth.uid(), 'bench', null, 130, 'lb', 8, 180, 'Public', 'Self Reported', '', now(), false),
    ('94000000-0000-4000-8000-000000000004', auth.uid(), 'bench', null, 190, 'lb', 1, 180, 'Public', 'Self Reported', '', now(), false),
    ('94000000-0000-4000-8000-000000000005', auth.uid(), 'bench', null, 145, 'lb', 5, 180, 'Private', 'Self Reported', '', now(), false),
    ('94000000-0000-4000-8000-000000000006', auth.uid(), 'cable_curl', null, 60, 'lb', 5, 180, 'Public', 'Self Reported', '', now(), false)
$$, 'public, private, competitive, and non-competitive rep-count fixtures can be recorded');

select is(
  (select leaderboard_eligible_at is not null from public.lift_submissions where id = '94000000-0000-4000-8000-000000000002'),
  true,
  'five-rep public lift receives leaderboard eligibility'
);
select is(
  (select leaderboard_eligible_at is not null from public.lift_submissions where id = '94000000-0000-4000-8000-000000000003'),
  true,
  'custom-rep public lift receives leaderboard eligibility'
);
select is(
  (select leaderboard_eligible_at is not null from public.lift_submissions where id = '94000000-0000-4000-8000-000000000004'),
  false,
  'a one-rep lift not declared an actual one-rep max is not leaderboard eligible'
);
select is(
  (select leaderboard_eligible_at is not null from public.lift_submissions where id = '94000000-0000-4000-8000-000000000005'),
  false,
  'a private multi-rep lift is not leaderboard eligible'
);
select is(
  (select leaderboard_eligible_at is not null from public.lift_submissions where id = '94000000-0000-4000-8000-000000000006'),
  false,
  'a public multi-rep lift outside competitive movements is not leaderboard eligible'
);
select is(
  (select lift_id from public.get_ranked_lift_ids('bench', 'Absolute', null, null, null, null, null, null, null, null, false, null)),
  '94000000-0000-4000-8000-000000000001'::uuid,
  'the legacy leaderboard overload still selects actual one-rep maxes'
);
select is(
  (select lift_id from public.get_ranked_lift_ids('bench', 'Absolute', null, null, null, null, null, null, null, null, false, null, 1)),
  '94000000-0000-4000-8000-000000000001'::uuid,
  'exact one-rep mode selects an actual one-rep max'
);
select is(
  (select lift_id from public.get_ranked_lift_ids('bench', 'Absolute', null, null, null, null, null, null, null, null, false, null, 5)),
  '94000000-0000-4000-8000-000000000002'::uuid,
  'exact five-rep mode returns the five-rep record'
);
select is(
  (select lift_id from public.get_ranked_lift_ids('bench', 'Absolute', null, null, null, null, null, null, null, null, false, null, 8)),
  '94000000-0000-4000-8000-000000000003'::uuid,
  'custom exact-rep mode returns the selected rep-count record'
);
select is(
  (select lift_id from public.get_ranked_lift_ids('bench', 'Absolute', null, null, null, null, null, null, null, null, false, null, null::integer)),
  '94000000-0000-4000-8000-000000000001'::uuid,
  'a null rep filter preserves the one-rep default'
);
reset role;

select * from finish();
rollback;
