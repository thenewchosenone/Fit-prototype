begin;
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select ('ffa02401-0000-4000-8000-00000000000' || n)::uuid,
  '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
  'workout-summary-audit-' || n || '@example.test','','{}','{}',now(),now()
from generate_series(1,2) n;
update public.profile_privacy set profile_audience='public'
where user_id='ffa02401-0000-4000-8000-000000000001';

insert into public.completed_workout_snapshots(id,owner_id,payload,completed_at)
select ('ffa02401-0000-4000-8000-00000000001' || n)::uuid,
  'ffa02401-0000-4000-8000-000000000001',
  to_jsonb(encode(convert_to((jsonb_build_object(
    'name','Workout A','duration',600,'notes','PRIVATE NOTE','bodyweight',200,'gymID','PRIVATE GYM',
    'exercises',jsonb_build_array(jsonb_build_object('id','exercise-1','exerciseName','Bench press')),
    'sets',jsonb_build_array(
      jsonb_build_object('prescriptionID','exercise-1','isComplete',true,'isWarmup',false),
      jsonb_build_object('prescriptionID','exercise-1','isComplete',true,'isWarmup',true),
      jsonb_build_object('prescriptionID','exercise-1','isComplete',false,'isWarmup',false))
  ) || case n when 1 then '{"isPublic":true}'::jsonb when 2 then '{"isPublic":false}'::jsonb else '{}'::jsonb end)::text,'UTF8'),'base64')),
  '2026-10-24T12:00:00Z'
from generate_series(1,3) n;

do $$ begin
  if has_function_privilege('anon','public.get_profile_workout_summaries(uuid)','EXECUTE') then
    raise exception 'Anonymous execution permitted';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','ffa02401-0000-4000-8000-000000000002',true);
do $$
declare summary jsonb; n integer;
begin
  select count(*) into n from public.get_profile_workout_summaries('ffa02401-0000-4000-8000-000000000001');
  if n <> 1 then raise exception 'Private or legacy history leaked, or public summary missing'; end if;
  select to_jsonb(s) into summary from public.get_profile_workout_summaries('ffa02401-0000-4000-8000-000000000001') s;
  if (summary->>'set_count')::integer <> 1 or summary->'exercise_names' <> '["Bench press"]'::jsonb then
    raise exception 'Completed working-set projection incorrect';
  end if;
  if summary - array['id','name','completed_at','duration','set_count','exercise_names'] <> '{}'::jsonb
     or summary::text like '%PRIVATE%' then raise exception 'Private workout fields leaked'; end if;
  if exists(select 1 from public.completed_workout_snapshots where owner_id='ffa02401-0000-4000-8000-000000000001') then
    raise exception 'Full private snapshot readable by visitor';
  end if;
end $$;

reset role;
update public.profile_privacy set profile_audience='private' where user_id='ffa02401-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
  if exists(select 1 from public.get_profile_workout_summaries('ffa02401-0000-4000-8000-000000000001')) then
    raise exception 'Private profile bypassed';
  end if;
end $$;
select set_config('request.jwt.claim.sub','ffa02401-0000-4000-8000-000000000001',true);
do $$ begin
  if (select count(*) from public.get_profile_workout_summaries(auth.uid())) <> 1 then raise exception 'Owner lost summary access'; end if;
end $$;
reset role;
update public.profile_privacy set profile_audience='public' where user_id='ffa02401-0000-4000-8000-000000000001';
insert into public.user_blocks(blocker_id,blocked_id)
values('ffa02401-0000-4000-8000-000000000001','ffa02401-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','ffa02401-0000-4000-8000-000000000002',true);
do $$ begin
  if exists(select 1 from public.get_profile_workout_summaries('ffa02401-0000-4000-8000-000000000001')) then
    raise exception 'Blocked viewer read workout summary';
  end if;
end $$;
select 'PASS: workout summaries enforce explicit sharing, profile visibility, blocks, private snapshot isolation, and restricted output' as security_assertions;
rollback;
