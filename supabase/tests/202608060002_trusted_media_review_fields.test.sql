begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(6);

select is_definer(
  'public', 'enforce_competitive_lift_authority', array[]::text[],
  'competitive lift authority remains security definer'
);
select is_definer(
  'public', 'complete_lift_media_upload',
  array['uuid', 'uuid', 'text', 'text', 'bigint'],
  'media completion remains security definer'
);
select is(
  (
    select p.proconfig::text
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'complete_lift_media_upload'
  ),
  '{search_path=pg_catalog}',
  'media completion has a fixed search path'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '93000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'media-finalizer@example.test', '',
  '{}'::jsonb, '{}'::jsonb, now(), now()
);

insert into storage.objects(id, bucket_id, name, owner_id)
values (
  '93000000-0000-4000-8000-000000000002',
  'lift-videos',
  '93000000-0000-4000-8000-000000000001/93000000-0000-4000-8000-000000000003/93000000-0000-4000-8000-000000000004.mp4',
  '93000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000001', true);

insert into public.lift_submissions (
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max
) values (
  '93000000-0000-4000-8000-000000000003',
  '93000000-0000-4000-8000-000000000001',
  'conventional_deadlift', null, 315, 'lb', 1, 205,
  'Private', 'Self Reported', '', now(), true
);

select lives_ok($$
  select *
  from public.complete_lift_media_upload(
    '93000000-0000-4000-8000-000000000004',
    '93000000-0000-4000-8000-000000000003',
    '93000000-0000-4000-8000-000000000001/93000000-0000-4000-8000-000000000003/93000000-0000-4000-8000-000000000004.mp4',
    'video/mp4',
    1
  )
$$, 'the trusted finalizer completes an owned upload');

select is(
  (
    select jsonb_build_array(evidence_status, verification, video_asset_id)::text
    from public.lift_submissions
    where id = '93000000-0000-4000-8000-000000000003'
  ),
  '["video_backed", "Video Verified", "93000000-0000-4000-8000-000000000004"]',
  'trusted media fields survive both protection triggers'
);

select set_config('request.jwt.claim.sub', '93000000-0000-4000-8000-000000000099', true);
select throws_ok($$
  select *
  from public.complete_lift_media_upload(
    '93000000-0000-4000-8000-000000000005',
    '93000000-0000-4000-8000-000000000003',
    '93000000-0000-4000-8000-000000000001/93000000-0000-4000-8000-000000000003/93000000-0000-4000-8000-000000000004.mp4',
    'video/mp4',
    1
  )
$$, 'P0001', 'Lift not found',
  'another user cannot finalize the lift');

select * from finish();
rollback;
