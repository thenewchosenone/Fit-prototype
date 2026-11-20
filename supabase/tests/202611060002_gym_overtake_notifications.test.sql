begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select has_function('public', 'notify_gym_overtake', array[]::text[], 'gym overtakes have a server trigger');
select function_privs_are('public', 'notify_gym_overtake', array[]::text[], 'authenticated', array[]::text[], 'clients cannot invoke the trigger');
select ok((select proconfig = array['search_path=pg_catalog'] and prosecdef from pg_proc where oid = 'public.notify_gym_overtake()'::regprocedure), 'trigger has fixed search path');

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select ('f6100000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
 'gym-alert-' || n || '@example.test','','{}','{}',now(),now()
from generate_series(1,8) n;
insert into public.gyms(id,name,status) values ('f6200000-0000-4000-8000-000000000001','Gym alert test','active');
insert into public.gym_memberships(user_id,gym_id,is_primary)
select id,'f6200000-0000-4000-8000-000000000001',true from public.profiles where id::text like 'f6100000%';
update public.profile_private_details set birth_date='1990-01-01',sex_category='male' where user_id::text like 'f6100000%';
update public.profile_privacy set profile_audience='public',age_band_audience='public',division_audience='public',show_lift_videos=true
where user_id::text like 'f6100000%';
select is((select count(*) from public.profile_privacy where user_id::text like 'f6100000%' and gym_overtake_alerts),0::bigint,'alerts default off');

create function pg_temp.test_lift(n integer, kg numeric, make_verified boolean default true) returns uuid language plpgsql as $$
declare owner_id uuid := ('f6100000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid;
  lift_id uuid := gen_random_uuid();
begin
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  insert into public.lift_submissions(id,user_id,exercise_id,gym_id,weight,unit,reps,bodyweight,visibility,verification,caption,performed_at,is_actual_one_rep_max)
  values(lift_id,owner_id,'bench','f6200000-0000-4000-8000-000000000001',kg,'kg',1,180,'Public','Self Reported','test',now(),true);
  if make_verified then
  insert into public.lift_media_assets(id,owner_id,lift_id,storage_path,content_type,byte_count)
  values(lift_id,owner_id,lift_id,owner_id::text || '/' || lift_id::text || '.mp4','video/mp4',1);
  perform set_config('liftrank.trusted_media_finalize','true',true);
  update public.lift_submissions set evidence_status='video_backed',verification='Video Verified',review_status='approved',evidence_public=true,
    video_asset_id=lift_id,approved_evidence_storage_path=owner_id::text || '/test.mp4' where id=lift_id;
  perform set_config('liftrank.trusted_media_finalize','false',true);
  end if;
  return lift_id;
end;
$$;
select pg_temp.test_lift(n,100) from generate_series(2,8) n;
select pg_temp.test_lift(1,90);
select ok((select public.is_gym_alert_lift_eligible(jsonb_populate_record(l,
  '{"review_status":"pending","evidence_public":false}'::jsonb))
  from public.lift_submissions l where l.user_id='f6100000-0000-4000-8000-000000000001'),
  'eligibility matches production ranking without legacy review fields');
select ok((select not public.is_gym_alert_lift_eligible(jsonb_populate_record(l,
  '{"video_asset_id":null}'::jsonb))
  from public.lift_submissions l where l.user_id='f6100000-0000-4000-8000-000000000001'),
  'a storage path alone does not satisfy production verified rankings');
select is((select count(*) from public.notifications where kind='gym_overtake'),0::bigint,'no opt-in means no alerts');

set local role authenticated;
select set_config('request.jwt.claim.sub','f6100000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.save_own_settings('{"gym_overtake_alerts":"true"}','{"gym_overtake_alerts":"false"}')$$,'owner can opt in');
select throws_ok($$select public.save_own_settings('{"gym_overtake_alerts":"false"}','{"gym_overtake_alerts":"false"}')$$,'40001','Settings changed on another device','stale preference updates are rejected');
reset role;
update public.profile_privacy set gym_overtake_alerts=true where user_id::text like 'f6100000%' and user_id <> 'f6100000-0000-4000-8000-000000000003';
insert into public.user_blocks(blocker_id,blocked_id) values('f6100000-0000-4000-8000-000000000004','f6100000-0000-4000-8000-000000000001');
update public.profile_private_details set birth_date='1960-01-01' where user_id='f6100000-0000-4000-8000-000000000005';
update public.profile_privacy set age_band_audience='private' where user_id='f6100000-0000-4000-8000-000000000006';
update public.gym_memberships set is_primary=false where user_id='f6100000-0000-4000-8000-000000000007';
update public.profile_privacy set show_lift_videos=false where user_id='f6100000-0000-4000-8000-000000000008';

select pg_temp.test_lift(1,115,false);
select is((select count(*) from public.notifications where kind='gym_overtake'),0::bigint,'a self-reported lift does not trigger verified alerts');
select pg_temp.test_lift(1,100);
select is((select count(*) from public.notifications where kind='gym_overtake'),0::bigint,'tying a lift does not count as passing');
select pg_temp.test_lift(1,110);
select is((select count(*) from public.notifications where kind='gym_overtake'),1::bigint,'only the opted-in eligible unblocked peer receives an alert');
select is((select user_id from public.notifications where kind='gym_overtake'),'f6100000-0000-4000-8000-000000000002'::uuid,'correct recipient');
select is((select destination->>'gymID' from public.notifications where kind='gym_overtake'),'f6200000-0000-4000-8000-000000000001','destination retains gym');
select is((select destination->>'exerciseID' from public.notifications where kind='gym_overtake'),'barbell_bench_press','destination retains movement');
select is((select destination->>'sexCategory' from public.notifications where kind='gym_overtake'),'Male','destination uses client division encoding');
select is((select destination->>'videoBackedOnly' from public.notifications where kind='gym_overtake'),'true','destination selects verified rankings');
select pg_temp.test_lift(1,120);
select is((select count(*) from public.notifications where kind='gym_overtake'),1::bigint,'improving while already ahead does not re-alert');

select set_config('request.jwt.claim.sub','f6100000-0000-4000-8000-000000000001',true);
update public.lift_submissions set caption='Edited caption' where user_id=auth.uid();
select is((select count(*) from public.notifications where kind='gym_overtake'),1::bigint,'unrelated edits do not re-alert');
select pg_temp.test_lift(2,125);
select pg_temp.test_lift(1,130);
select is((select count(*) from public.notifications where kind='gym_overtake' and user_id='f6100000-0000-4000-8000-000000000002'),1::bigint,'repeated overtakes coalesce within the same UTC day');

set local role authenticated;
select set_config('request.jwt.claim.sub','f6100000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.notifications where kind='gym_overtake'),0::bigint,'notification RLS hides other recipients');
select throws_ok($$update public.notifications set title='Forged'$$,'42501',null,'clients cannot forge notification content');
select set_config('request.jwt.claim.sub','f6100000-0000-4000-8000-000000000002',true);
select lives_ok($$update public.notifications set read_at=now() where kind='gym_overtake'$$,'owner can mark notifications read');
select is((select count(*) from public.notifications where kind='gym_overtake' and read_at is not null),1::bigint,'read state persists for the owner');
reset role;
insert into public.friend_relationships(user_low_id,user_high_id,requested_by,status)
values('f6100000-0000-4000-8000-000000000002','f6100000-0000-4000-8000-000000000003','f6100000-0000-4000-8000-000000000002','pending');
select is((select count(*) from public.notifications where kind='friendship'),1::bigint,'new request notifies its recipient');
update public.friend_relationships set status='declined' where user_low_id='f6100000-0000-4000-8000-000000000002';
update public.friend_relationships set status='pending' where user_low_id='f6100000-0000-4000-8000-000000000002';
select is((select count(*) from public.notifications where kind='friendship'),2::bigint,'a renewed request also notifies');
update public.friend_relationships set status='accepted' where user_low_id='f6100000-0000-4000-8000-000000000002';
select is((select count(*) from public.notifications where kind='friendship' and user_id='f6100000-0000-4000-8000-000000000002'),1::bigint,'acceptance notifies the original requester');
select ok((select bool_and(destination->>'kind'='friendRequests') from public.notifications where kind='friendship'),'friend events route to the requests screen');
select ok((select proconfig = array['search_path=pg_catalog'] from pg_proc where oid='public.notify_friendship_change()'::regprocedure),'friend notification trigger uses a fixed search path');
select function_privs_are('public','get_friend_relationship_cards',array[]::text[],'anon',array[]::text[],'anonymous users cannot read friend cards');
select ok((select proconfig=array['search_path=pg_catalog'] and prosecdef from pg_proc where oid='public.get_friend_relationship_cards()'::regprocedure),'friend cards use a fixed search path');
set local role authenticated;
select set_config('request.jwt.claim.sub','f6100000-0000-4000-8000-000000000005',true);
select is((select count(*) from public.get_friend_relationship_cards()),0::bigint,'strangers cannot list other friendships');
select set_config('request.jwt.claim.sub','f6100000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.get_friend_relationship_cards()),1::bigint,'participants can see their friendship');
reset role;
update public.profile_privacy set profile_audience='private' where user_id='f6100000-0000-4000-8000-000000000003';
set local role authenticated;
select is((select count(*) from public.get_friend_relationship_cards()),1::bigint,'private profiles do not prevent reviewing an existing relationship');
reset role;
insert into public.user_blocks(blocker_id,blocked_id) values('f6100000-0000-4000-8000-000000000003','f6100000-0000-4000-8000-000000000002');
set local role authenticated;
select is((select count(*) from public.get_friend_relationship_cards()),0::bigint,'blocks hide relationship cards');
reset role;
select * from finish();
rollback;
