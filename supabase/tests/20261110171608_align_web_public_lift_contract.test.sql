begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into auth.users(id,email) values
 ('c1100000-0000-4000-8000-000000000001','web-public-owner@example.test'),
 ('c1100000-0000-4000-8000-000000000002','web-private-owner@example.test'),
 ('c1100000-0000-4000-8000-000000000003','web-viewer@example.test');
update public.profile_privacy set profile_audience='public',show_lift_videos=true,
 bodyweight_audience='private',location_audience='private',gym_audience='private'
where user_id='c1100000-0000-4000-8000-000000000001';
update public.profile_privacy set profile_audience='private'
where user_id='c1100000-0000-4000-8000-000000000002';

-- Controlled server-state fixtures; restore authority before any role checks.
alter table public.lift_submissions disable trigger competitive_lift_authority;
insert into public.lift_submissions(id,user_id,exercise_id,weight,unit,reps,bodyweight,
 visibility,verification,evidence_status,moderation_status,is_actual_one_rep_max,
 competitive_movement,leaderboard_eligible_at,performed_at)
select ('c1200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case when n=7 then 'c1100000-0000-4000-8000-000000000002'::uuid else 'c1100000-0000-4000-8000-000000000001'::uuid end,
 'barbell-bench-press',225,'lb',1,180,
 case n when 2 then 'Private'::public.lift_visibility when 3 then 'Friends'::public.lift_visibility else 'Public'::public.lift_visibility end,
 case when n=6 then 'Self Reported' else 'Video Verified' end,
 case when n=6 then 'self_reported'::public.lift_evidence_status else 'video_backed'::public.lift_evidence_status end,
 case when n=4 then 'under_review'::public.lift_moderation_status when n=9 then 'rejected'::public.lift_moderation_status else 'clear'::public.lift_moderation_status end,
 true,'barbell_bench_press',now()-interval '1 hour',now()
from generate_series(1,9) n;
insert into public.lift_media_assets(id,owner_id,lift_id,storage_path,content_type,byte_count)
select ('c1300000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case when n=7 then 'c1100000-0000-4000-8000-000000000002'::uuid else 'c1100000-0000-4000-8000-000000000001'::uuid end,
 ('c1200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'web-contract-fixture/'||n||'.mp4','video/mp4',1024
from generate_series(1,9) n where n not in (5,6);
update public.lift_submissions l set video_asset_id=a.id
from public.lift_media_assets a where a.lift_id=l.id and a.storage_path like 'web-contract-fixture/%';
update public.lift_submissions set disputed_at=now() where id='c1200000-0000-4000-8000-000000000008';
alter table public.lift_submissions enable trigger competitive_lift_authority;

select is_definer('public','get_public_lift_records',array['uuid','uuid'],'projection has a controlled definer boundary');
select is((select proconfig::text from pg_proc where oid='public.get_public_lift_records(uuid,uuid)'::regprocedure),'{search_path=pg_catalog}','projection has a fixed search path');
select ok(has_function_privilege('anon','public.get_public_lift_records(uuid,uuid)','execute'),'anonymous public reads permitted');
select ok(not has_function_privilege('anon','public.get_lift_media_for_playback(uuid)','execute'),'anonymous clients cannot request private media signing');

set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is((select count(*)::integer from public.get_public_lift_records()),0,'unscoped requests return no records');
select is((select count(*)::integer from public.get_public_lift_records('c1100000-0000-4000-8000-000000000001')),1,'anonymous profile includes current video asset despite pending legacy flags');
select is((select value->>'weight' from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000001') value),'225','public proof and profile refer to the same weight');
select is((select value->>'bodyweight' from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000001') value),null,'private lift bodyweight is redacted');
select is((select value->>'gym_id' from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000001') value),null,'private gym is redacted');
select ok((select not (value ? 'storage_path' or value ? 'evidence_storage_path' or value ? 'email') from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000001') value),'public projection omits storage paths and account identity');
select is((select count(*)::integer from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000002')),0,'private submission excluded');
select is((select count(*)::integer from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000003')),0,'friends submission excluded');
select is((select count(*)::integer from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000004')),0,'under-review submission excluded');
select is((select count(*)::integer from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000005')),0,'incomplete video asset excluded');
select is((select count(*)::integer from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000006')),0,'anonymous scope does not expand to self-reported submissions');
select is((select count(*)::integer from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000007')),0,'private athlete excluded');
select is((select count(*)::integer from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000008')),0,'disputed submission excluded');
select is((select count(*)::integer from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000009')),0,'rejected submission excluded');
select is((select count(*)::integer from public.get_public_lift_records('c1100000-0000-4000-8000-000000000002','c1200000-0000-4000-8000-000000000001')),0,'athlete and lift filters cannot be crossed');
select is((select value->>'latest_lift_id' from public.get_public_leaderboard_v3() value where value->>'athlete_id'='c1100000-0000-4000-8000-000000000001'),'c1200000-0000-4000-8000-000000000001','web leaderboard joins canonical record, not legacy views');
select ok((select abs((value->>'score')::numeric-225)<0.0001 from public.get_public_leaderboard_v3() value where value->>'athlete_id'='c1100000-0000-4000-8000-000000000001'),'canonical kilograms are converted once at the web presentation boundary');
select is((select value->>'verified_lift_count' from public.get_public_leaderboard_v3() value where value->>'athlete_id'='c1100000-0000-4000-8000-000000000001'),'1','leaderboard count agrees with public record projection');

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','c1100000-0000-4000-8000-000000000003',true);
select is((select count(*)::integer from public.get_public_lift_records('c1100000-0000-4000-8000-000000000001')),2,'signed-in viewers also see intentionally public self-reported records');
reset role;
insert into public.user_blocks(blocker_id,blocked_id) values('c1100000-0000-4000-8000-000000000001','c1100000-0000-4000-8000-000000000003');
set local role authenticated;
select is((select count(*)::integer from public.get_public_lift_records('c1100000-0000-4000-8000-000000000001')),0,'owner block hides profile records');
select is((select count(*)::integer from public.get_public_leaderboard_v3() value where value->>'athlete_id'='c1100000-0000-4000-8000-000000000001'),0,'owner block hides leaderboard records');
reset role;
delete from public.user_blocks where blocker_id='c1100000-0000-4000-8000-000000000001';
insert into public.user_blocks(blocker_id,blocked_id) values('c1100000-0000-4000-8000-000000000003','c1100000-0000-4000-8000-000000000001');
set local role authenticated;
select is((select count(*)::integer from public.get_public_lift_records('c1100000-0000-4000-8000-000000000001')),0,'viewer block hides profile records');
reset role;
delete from public.user_blocks where blocker_id='c1100000-0000-4000-8000-000000000003';
update public.profile_privacy set show_lift_videos=false where user_id='c1100000-0000-4000-8000-000000000001';
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select is((select count(*)::integer from public.get_public_lift_records('c1100000-0000-4000-8000-000000000001')),0,'video opt-out revokes anonymous record access');
set local role authenticated;
select set_config('request.jwt.claim.sub','c1100000-0000-4000-8000-000000000003',true);
select is((select value->>'video_asset_id' from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000001') value),null,'signed-in metadata does not expose hidden video references');
select is((select value->>'evidence_available' from public.get_public_lift_records(null,'c1200000-0000-4000-8000-000000000001') value),'false','hidden playback is unavailable');
reset role;
update public.profile_privacy set profile_audience='private' where user_id='c1100000-0000-4000-8000-000000000001';
set local role authenticated;
select is((select count(*)::integer from public.get_public_lift_records('c1100000-0000-4000-8000-000000000001')),0,'profile privacy revocation immediately hides records');
reset role;
select * from finish();
rollback;
