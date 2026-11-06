begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(15);

select has_function(
  'public',
  'get_self_reported_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','text'],
  'self-reported leaderboard query exists'
);

select is_definer(
  'public',
  'get_self_reported_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','text'],
  'self-reported ranking runs as its fixed owner'
);

select is(
  (
    select p.proconfig::text
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_self_reported_ranked_lift_ids'
  ),
  '{search_path=pg_catalog}',
  'self-reported ranking has a fixed catalog-only search path'
);

select function_privs_are(
  'public', 'get_self_reported_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','text'],
  'authenticated', array['EXECUTE'], 'authenticated members can execute the query'
);

select function_privs_are(
  'public', 'get_self_reported_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','text'],
  'anon', array[]::text[], 'anonymous members have no query privileges'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    cross join lateral pg_catalog.aclexplode(p.proacl) acl
    where n.nspname = 'public'
      and p.proname = 'get_self_reported_ranked_lift_ids'
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC has no execute grant'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select * from public.get_self_reported_ranked_lift_ids(
    null::text, 'absolute', null::uuid, null::text, null::text, null::text,
    null::text, null::text, null::numeric, null::numeric, 'All time'
  )$$,
  '42501',
  'permission denied for function get_self_reported_ranked_lift_ids',
  'anonymous callers cannot execute the self-reported ranking query'
);
reset role;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  ('a3100000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'self-ranked-' || n || '@example.test', '', '{}'::jsonb,
  jsonb_build_object('display_name', 'Ranked User ' || n, 'handle', '@rank_user_' || n), now(), now()
from generate_series(1, 221) n;

update public.profile_privacy
set profile_audience = 'public', bodyweight_audience = 'public', show_lift_videos = true
where user_id between 'a3100000-0000-4000-8000-000000000001'::uuid
                  and 'a3100000-0000-4000-8000-000000000221'::uuid;
update public.profile_privacy
set profile_audience = 'private'
where user_id = 'a3100000-0000-4000-8000-000000000003';
insert into public.user_blocks(blocker_id, blocked_id)
values (
  'a3100000-0000-4000-8000-000000000001',
  'a3100000-0000-4000-8000-000000000005'
);

alter table public.lift_submissions disable trigger competitive_lift_authority;
insert into public.lift_submissions (
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max,
  competitive_movement, evidence_status, moderation_status, leaderboard_eligible_at,
  review_status, evidence_public, approved_evidence_storage_path, disputed_at
)
values
  ('b3100000-0000-4000-8000-000000000001', 'a3100000-0000-4000-8000-000000000002', 'bench', null, 225, 'lb', 1, 200, 'Public', 'Self Reported', 'valid self-reported lift', now() - interval '1 day', true, 'barbell_bench_press', 'self_reported', 'clear', statement_timestamp(), 'pending', false, null, null),
  ('b3100000-0000-4000-8000-000000000002', 'a3100000-0000-4000-8000-000000000003', 'bench', null, 500, 'lb', 1, 200, 'Public', 'Self Reported', 'private profile', now() - interval '1 day', true, 'barbell_bench_press', 'self_reported', 'clear', statement_timestamp(), 'pending', false, null, null),
  ('b3100000-0000-4000-8000-000000000003', 'a3100000-0000-4000-8000-000000000004', 'bench', null, 500, 'lb', 1, 200, 'Public', 'Self Reported', 'under moderation', now() - interval '1 day', true, 'barbell_bench_press', 'self_reported', 'under_review', statement_timestamp(), 'pending', false, null, null),
  ('b3100000-0000-4000-8000-000000000004', 'a3100000-0000-4000-8000-000000000005', 'bench', null, 500, 'lb', 1, 200, 'Public', 'Self Reported', 'blocked account', now() - interval '1 day', true, 'barbell_bench_press', 'self_reported', 'clear', statement_timestamp(), 'pending', false, null, null),
  ('b3100000-0000-4000-8000-000000000005', 'a3100000-0000-4000-8000-000000000006', 'bench', null, 500, 'lb', 1, 200, 'Private', 'Self Reported', 'non-public lift', now() - interval '1 day', true, 'barbell_bench_press', 'self_reported', 'clear', statement_timestamp(), 'pending', false, null, null),
  ('b3100000-0000-4000-8000-000000000006', 'a3100000-0000-4000-8000-000000000007', 'bench', null, 500, 'lb', 1, 200, 'Public', 'Self Reported', 'disputed lift', now() - interval '1 day', true, 'barbell_bench_press', 'self_reported', 'clear', statement_timestamp(), 'pending', false, null, statement_timestamp()),
  ('b3100000-0000-4000-8000-000000000007', 'a3100000-0000-4000-8000-000000000008', 'bench', null, 500, 'lb', 1, 200, 'Public', 'Self Reported', 'not yet eligible', now() - interval '1 day', true, 'barbell_bench_press', 'self_reported', 'clear', null, 'pending', false, null, null),
  ('b3100000-0000-4000-8000-000000000008', 'a3100000-0000-4000-8000-000000000009', 'bench', null, 500, 'lb', 2, 200, 'Public', 'Self Reported', 'not a one-rep max', now() - interval '1 day', false, 'barbell_bench_press', 'self_reported', 'clear', statement_timestamp(), 'pending', false, null, null);

insert into public.lift_submissions (
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max,
  competitive_movement, evidence_status, moderation_status, leaderboard_eligible_at,
  review_status, evidence_public, approved_evidence_storage_path
)
select
  ('b3200000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  ('a3100000-0000-4000-8000-' || lpad((20 + n)::text, 12, '0'))::uuid,
  'bench', null, 300 + n, 'lb', 1, 200, 'Public', 'Video Verified',
  'verified video ranking fixture', now() - interval '1 day', true,
  'barbell_bench_press', 'video_backed', 'clear', statement_timestamp(),
  'approved', true, 'ranking-fixture/' || n || '.mp4'
from generate_series(1, 201) n;
alter table public.lift_submissions enable trigger competitive_lift_authority;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a3100000-0000-4000-8000-000000000001', true);

select is(
  (select count(*) from public.get_self_reported_ranked_lift_ids(
    null::text, 'absolute', null::uuid, null::text, null::text, null::text,
    null::text, null::text, null::numeric, null::numeric, 'All time'
  )),
  1::bigint,
  'only the eligible public, clear, unblocked self-reported lift is ranked'
);

select is(
  (select rank from public.get_self_reported_ranked_lift_ids(
    null::text, 'absolute', null::uuid, null::text, null::text, null::text,
    null::text, null::text, null::numeric, null::numeric, 'All time'
  ) where lift_id = 'b3100000-0000-4000-8000-000000000001'),
  1::bigint,
  'self-reported lifts use rank order within the self-reported evidence universe'
);

select ok(
  not exists (
    select 1
    from public.get_self_reported_ranked_lift_ids(
      null::text, 'absolute', null::uuid, null::text, null::text, null::text,
      null::text, null::text, null::numeric, null::numeric, 'All time'
    ) ranked
    where ranked.lift_id between 'b3100000-0000-4000-8000-000000000002'::uuid
                             and 'b3100000-0000-4000-8000-000000000008'::uuid
  ),
  'private profiles, non-public lifts, non-clear or disputed rows, blocked users, ineligible timestamps, and non-1RMs are filtered'
);

select is(
  (select count(*) from public.get_ranked_lift_ids(
    null::text, 'absolute', null::uuid, null::text, null::text, null::text,
    null::text, null::text, null::numeric, null::numeric, false, 'All time'
  )),
  202::bigint,
  'the mixed evidence leaderboard contains 201 videos followed by the self-reported lift'
);

select is(
  (select rank from public.get_ranked_lift_ids(
    null::text, 'absolute', null::uuid, null::text, null::text, null::text,
    null::text, null::text, null::numeric, null::numeric, false, 'All time'
  ) where lift_id = 'b3100000-0000-4000-8000-000000000001'),
  202::bigint,
  'the self-reported lift ranks behind all 201 higher-scoring video lifts in the mixed universe'
);

select ok(
  (select rank > 200 from public.get_ranked_lift_ids(
    null::text, 'absolute', null::uuid, null::text, null::text, null::text,
    null::text, null::text, null::numeric, null::numeric, false, 'All time'
  ) where lift_id = 'b3100000-0000-4000-8000-000000000001')
  and not exists (
    select 1 from (
      select lift_id from public.get_ranked_lift_ids(
        null::text, 'absolute', null::uuid, null::text, null::text, null::text,
        null::text, null::text, null::numeric, null::numeric, false, 'All time'
      ) order by rank limit 200
    ) mixed_page
    where mixed_page.lift_id = 'b3100000-0000-4000-8000-000000000001'
  ),
  'a self-reported lift below the mixed top-200 page is still present in its dedicated ranking'
);

select is(
  (select count(*) from public.get_ranked_lift_ids(
    null::text, 'absolute', null::uuid, null::text, null::text, null::text,
    null::text, null::text, null::numeric, null::numeric, true, 'All time'
  )),
  201::bigint,
  'verified-only ranking returns the 201 video-backed fixtures'
);

select ok(
  not exists (
    select 1 from public.get_ranked_lift_ids(
      null::text, 'absolute', null::uuid, null::text, null::text, null::text,
      null::text, null::text, null::numeric, null::numeric, true, 'All time'
    ) where lift_id = 'b3100000-0000-4000-8000-000000000001'
  ),
  'self-reported lifts do not enter the verified-video ranking'
);

select * from finish();
rollback;
