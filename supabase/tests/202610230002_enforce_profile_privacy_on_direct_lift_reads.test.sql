begin;
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select ('ffa02302-0000-4000-8000-00000000000' || n)::uuid,
  '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
  'direct-lift-audit-' || n || '@example.test','','{}','{}',now(),now()
from generate_series(1,2) n;
update public.profile_privacy set profile_audience='private'
where user_id='ffa02302-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','ffa02302-0000-4000-8000-000000000001',true);
insert into public.lift_submissions(id,user_id,exercise_id,gym_id,weight,unit,reps,bodyweight,visibility,performed_at)
values ('ffa02302-0000-4000-8000-000000000011',auth.uid(),'bench',null,225,'lb',1,190,'Public',now());
do $$ begin
  if not exists(select id from public.lift_submissions where id='ffa02302-0000-4000-8000-000000000011') then raise exception 'Owner lost access to own lift'; end if;
end $$;
select set_config('request.jwt.claim.sub','ffa02302-0000-4000-8000-000000000002',true);
do $$ begin
  if exists(select id from public.lift_submissions where id='ffa02302-0000-4000-8000-000000000011') then raise exception 'Direct read bypassed private profile'; end if;
end $$;
reset role;
update public.profile_privacy set profile_audience='public' where user_id='ffa02302-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
  if not exists(select id from public.lift_submissions where id='ffa02302-0000-4000-8000-000000000011') then raise exception 'Public lift became unavailable'; end if;
end $$;
reset role;
update public.profile_privacy set profile_audience='friends' where user_id='ffa02302-0000-4000-8000-000000000001';
insert into public.friend_relationships(user_low_id,user_high_id,requested_by,status,responded_at)
values ('ffa02302-0000-4000-8000-000000000001','ffa02302-0000-4000-8000-000000000002','ffa02302-0000-4000-8000-000000000001','accepted',now());
set local role authenticated;
do $$ begin
  if not exists(select id from public.lift_submissions where id='ffa02302-0000-4000-8000-000000000011') then raise exception 'Accepted friend lost access'; end if;
end $$;
reset role;
insert into public.user_blocks(blocker_id,blocked_id)
values ('ffa02302-0000-4000-8000-000000000002','ffa02302-0000-4000-8000-000000000001');
set local role authenticated;
do $$ begin
  if exists(select id from public.lift_submissions where id='ffa02302-0000-4000-8000-000000000011') then raise exception 'Direct read bypassed user block'; end if;
end $$;
reset role;
select 'PASS: direct lift reads enforce owner, private, public, friends, and blocked profile visibility' as security_assertions;
rollback;
