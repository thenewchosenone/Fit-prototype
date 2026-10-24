-- Transactional security assertions; no pgTAP installation or persistent fixtures.
begin;
do $$
begin
  if has_function_privilege('anon', 'public.get_profile_cards(uuid[])', 'EXECUTE')
    or has_function_privilege('anon', 'public.delete_own_workout_plan(uuid)', 'EXECUTE')
    or has_function_privilege('anon', 'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text,integer,uuid,text,text)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.refresh_lift_review_state(uuid)', 'EXECUTE')
    or has_function_privilege('anon', 'public.refresh_lift_review_state(uuid)', 'EXECUTE')
  then raise exception 'RPC execute privileges are too broad'; end if;
  if has_table_privilege('authenticated', 'public.workout_plan_deletions', 'INSERT,UPDATE,DELETE') then
    raise exception 'Clients can forge or remove deletion tombstones';
  end if;
  if exists (select 1 from auth.users where id between 'ffa02300-0000-4000-8000-000000000001'::uuid and 'ffa02300-0000-4000-8000-000000000003'::uuid) then
    raise exception 'Audit fixture identifiers are already in use';
  end if;
end $$;

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select ('ffa02300-0000-4000-8000-00000000000' || n)::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'rpc-audit-' || n || '@example.test', '', '{}', '{}', now(), now()
from generate_series(1, 3) n;
update public.profile_privacy set profile_audience='private', bodyweight_audience='private', location_audience='private'
where user_id='ffa02300-0000-4000-8000-000000000001';
update public.profile_private_details set experience_level='advanced', city_id=(select id from public.location_cities order by id limit 1)
where user_id='ffa02300-0000-4000-8000-000000000001';
select set_config('test.audit_city', (select city_id::text from public.profile_private_details where user_id='ffa02300-0000-4000-8000-000000000001'), true);
insert into public.workout_plan_documents(id,owner_id,revision,name,payload)
values ('ffa02300-0000-4000-8000-000000000011','ffa02300-0000-4000-8000-000000000001',1,'RPC audit fixture','{}');
insert into storage.objects(bucket_id,name,owner_id)
values ('profile-avatars','ffa02300-0000-4000-8000-000000000001/audit/avatar.jpg','ffa02300-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','ffa02300-0000-4000-8000-000000000001',true);
select public.save_bodyweight_checkin('ffa02300-0000-4000-8000-000000000012',190,now(),'RPC audit fixture');
insert into public.lift_submissions(id,user_id,exercise_id,gym_id,weight,unit,reps,bodyweight,visibility,performed_at,is_actual_one_rep_max)
values ('ffa02300-0000-4000-8000-000000000013',auth.uid(),'bench',null,225,'lb',1,190,'Public',now(),true);
do $$ begin
  if (select count(*) from public.get_visible_lift_submissions(auth.uid(),null,10,0)) <> 1 then raise exception 'Owner cannot read private-profile lifts'; end if;
  if not exists(select 1 from storage.objects where bucket_id='profile-avatars' and name='ffa02300-0000-4000-8000-000000000001/audit/avatar.jpg') then raise exception 'Owner cannot read private avatar'; end if;
end $$;
select set_config('request.jwt.claim.sub','ffa02300-0000-4000-8000-000000000003',true);
do $$ begin
  if public.delete_own_workout_plan('ffa02300-0000-4000-8000-000000000011') then raise exception 'Outsider deleted owner plan'; end if;
  if exists(select 1 from public.get_profile_cards(array['ffa02300-0000-4000-8000-000000000001'::uuid])) then raise exception 'Private profile leaked through batch'; end if;
  if exists(select 1 from public.get_visible_lift_submissions('ffa02300-0000-4000-8000-000000000001',null,10,0)) then raise exception 'Private-profile lifts leaked'; end if;
  if exists(select 1 from storage.objects where bucket_id='profile-avatars' and name='ffa02300-0000-4000-8000-000000000001/audit/avatar.jpg') then raise exception 'Private avatar leaked'; end if;
end $$;
reset role;
update public.profile_privacy set profile_audience='public' where user_id='ffa02300-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
  if (select array_agg(id) from public.get_profile_cards(array['ffa02300-0000-4000-8000-000000000001'::uuid,'ffa02300-0000-4000-8000-000000000003'::uuid]))
    is distinct from array['ffa02300-0000-4000-8000-000000000001'::uuid,'ffa02300-0000-4000-8000-000000000003'::uuid] then raise exception 'Batch order or viewer visibility failed'; end if;
  if exists(select 1 from public.get_profile_cards(array['ffa02300-0000-4000-8000-000000000001'::uuid]) where bodyweight_pounds is not null) then raise exception 'Private bodyweight leaked'; end if;
  if (select count(*) from public.get_profile_cards(array_fill('ffa02300-0000-4000-8000-000000000001'::uuid,array[201]))) <> 0 then raise exception 'Oversized batch accepted'; end if;
  if not exists(select 1 from storage.objects where bucket_id='profile-avatars' and name='ffa02300-0000-4000-8000-000000000001/audit/avatar.jpg') then raise exception 'Public avatar unavailable'; end if;
  if not exists(select 1 from public.get_ranked_lift_ids('bench','Absolute',null,null,null,null,null,null,null,null,false,'All time',1,null,'advanced','self_reported') where user_id='ffa02300-0000-4000-8000-000000000001') then raise exception 'Mobile leaderboard contract failed'; end if;
  if exists(select 1 from public.get_ranked_lift_ids('bench','Absolute',null,null,null,null,null,null,null,null,false,'All time',1,null,'beginner',null) where user_id='ffa02300-0000-4000-8000-000000000001') then raise exception 'Experience filter failed'; end if;
  if exists(select 1 from public.get_ranked_lift_ids('bench','Absolute',null,null,null,null,null,null,null,null,false,'All time',1,null,null,'video_backed') where user_id='ffa02300-0000-4000-8000-000000000001') then raise exception 'Evidence filter failed'; end if;
  if exists(select 1 from public.get_ranked_lift_ids('bench','Absolute',null,null,null,null,null,null,null,null,false,'All time',1,current_setting('test.audit_city')::uuid,null,null) where user_id='ffa02300-0000-4000-8000-000000000001') then raise exception 'City filter revealed hidden location'; end if;
end $$;
reset role;
update public.profile_privacy set bodyweight_audience='public', location_audience='public' where user_id='ffa02300-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
  if (select bodyweight_pounds from public.get_profile_cards(array['ffa02300-0000-4000-8000-000000000001'::uuid])) is distinct from 190::numeric then raise exception 'Visible logged bodyweight missing'; end if;
  if not exists(select 1 from public.get_ranked_lift_ids('bench','Absolute',null,null,null,null,null,null,null,null,false,'All time',1,current_setting('test.audit_city')::uuid,null,null) where user_id='ffa02300-0000-4000-8000-000000000001') then raise exception 'Visible city filter failed'; end if;
end $$;
reset role;
insert into public.user_blocks(blocker_id,blocked_id) values('ffa02300-0000-4000-8000-000000000003','ffa02300-0000-4000-8000-000000000001');
set local role authenticated;
do $$ begin
  if exists(select 1 from public.get_profile_cards(array['ffa02300-0000-4000-8000-000000000001'::uuid])) then raise exception 'Blocked profile leaked through batch'; end if;
  if exists(select 1 from public.get_visible_lift_submissions('ffa02300-0000-4000-8000-000000000001',null,10,0)) then raise exception 'Blocked lifts leaked'; end if;
  if exists(select 1 from public.public_athletes where id='ffa02300-0000-4000-8000-000000000001') then raise exception 'Blocked athlete leaked through view'; end if;
  if exists(select 1 from storage.objects where bucket_id='profile-avatars' and name='ffa02300-0000-4000-8000-000000000001/audit/avatar.jpg') then raise exception 'Blocked avatar leaked'; end if;
end $$;
select set_config('request.jwt.claim.sub','ffa02300-0000-4000-8000-000000000001',true);
do $$ begin
  if not public.delete_own_workout_plan('ffa02300-0000-4000-8000-000000000011') then raise exception 'Owner deletion failed'; end if;
  if exists(select 1 from public.workout_plan_documents where id='ffa02300-0000-4000-8000-000000000011') then raise exception 'Deleted plan still exists'; end if;
  if not public.delete_own_workout_plan('ffa02300-0000-4000-8000-000000000011') then raise exception 'Deletion retry failed'; end if;
  begin
    insert into public.workout_plan_documents(id,owner_id,revision,name,payload) values ('ffa02300-0000-4000-8000-000000000011',auth.uid(),1,'Stale fixture','{}');
    raise exception 'Deleted plan was resurrected';
  exception when raise_exception then
    if sqlerrm <> 'Workout plan has been deleted' then raise; end if;
  end;
end $$;
select set_config('request.jwt.claim.sub','ffa02300-0000-4000-8000-000000000003',true);
do $$ begin
  if exists(select 1 from public.workout_plan_deletions where plan_id='ffa02300-0000-4000-8000-000000000011') then raise exception 'Owner tombstone leaked'; end if;
end $$;
reset role;
select 'PASS: mobile RPC contracts, plan ownership and resurrection, profile/bodyweight privacy, Storage visibility, blocks, leaderboard filters' as security_assertions;
rollback;
