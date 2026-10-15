begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(4);

select col_is_null(
  'public', 'lift_submissions', 'gym_id',
  'lift submissions permit no gym affiliation'
);
select is_definer(
  'public', 'enforce_competitive_lift_authority', array[]::text[],
  'competitive lift authority remains security definer'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '81000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'gymless@example.test', '',
  '{}'::jsonb, '{}'::jsonb, now(), now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);

select lives_ok($$
  insert into public.lift_submissions (
    id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
    visibility, verification, caption, performed_at, is_actual_one_rep_max
  ) values (
    '82000000-0000-0000-0000-000000000001',
    '81000000-0000-0000-0000-000000000001',
    'bench', null, 225, 'lb', 1, 180,
    'Public', 'Video Submitted', '', now(), true
  )
$$, 'an authenticated athlete can submit a lift without a gym');

select throws_ok($$
  insert into public.lift_submissions (
    id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
    visibility, verification, caption, performed_at, is_actual_one_rep_max
  ) values (
    '82000000-0000-0000-0000-000000000002',
    '81000000-0000-0000-0000-000000000001',
    'bench', '83000000-0000-0000-0000-000000000001', 225, 'lb', 1, 180,
    'Public', 'Video Submitted', '', now(), true
  )
$$, 'P0001', 'An active gym membership is required when a gym is supplied',
  'a supplied gym still requires an active membership');

select * from finish();
rollback;
