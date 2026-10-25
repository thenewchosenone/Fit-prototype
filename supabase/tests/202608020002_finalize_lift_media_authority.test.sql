begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(4);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '84000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'media-finalize@example.test', '',
  '{}'::jsonb, '{}'::jsonb, now(), now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '84000000-0000-0000-0000-000000000001', true);

insert into public.lift_submissions (
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max
) values (
  '85000000-0000-0000-0000-000000000001',
  '84000000-0000-0000-0000-000000000001',
  'bench', null, 225, 'lb', 1, 180,
  'Public', 'Video Submitted', '', now(), true
);

update public.lift_submissions
set evidence_status = 'video_backed', verification = 'Video Verified'
where id = '85000000-0000-0000-0000-000000000001';

select is(
  (select evidence_status::text from public.lift_submissions where id = '85000000-0000-0000-0000-000000000001'),
  'self_reported',
  'an authenticated table update cannot forge video evidence'
);

reset role;
insert into storage.objects (id, bucket_id, name, owner_id)
values (
  '86000000-0000-0000-0000-000000000001',
  'lift-videos',
  '84000000-0000-0000-0000-000000000001/85000000-0000-0000-0000-000000000001/87000000-0000-0000-0000-000000000001.mp4',
  '84000000-0000-0000-0000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '84000000-0000-0000-0000-000000000001', true);

select lives_ok($$
  select * from public.complete_lift_media_upload(
    '87000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000001',
    '84000000-0000-0000-0000-000000000001/85000000-0000-0000-0000-000000000001/87000000-0000-0000-0000-000000000001.mp4',
    'video/mp4',
    1024
  )
$$, 'the trusted finalizer can attach uploaded media');

select is(
  (select evidence_status::text from public.lift_submissions where id = '85000000-0000-0000-0000-000000000001'),
  'video_backed',
  'the trusted finalizer marks the lift video-backed'
);

select ok(
  (select video_asset_id = '87000000-0000-0000-0000-000000000001'::uuid
   from public.lift_submissions where id = '85000000-0000-0000-0000-000000000001'),
  'the trusted finalizer links the media asset'
);

select * from finish();
rollback;
