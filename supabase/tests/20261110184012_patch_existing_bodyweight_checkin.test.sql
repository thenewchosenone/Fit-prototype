begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();
insert into auth.users(id,email) values
 ('c2300000-0000-4000-8000-000000000001','weight-patch-owner@example.test'),
 ('c2300000-0000-4000-8000-000000000002','weight-patch-other@example.test');
insert into public.bodyweight_records(id,user_id,weight,recorded_at,notes) values
 ('c2400000-0000-4000-8000-000000000001','c2300000-0000-4000-8000-000000000001',185,'2026-11-01T03:21:00Z','original'),
 ('c2400000-0000-4000-8000-000000000002','c2300000-0000-4000-8000-000000000001',190,'2026-11-02T03:21:00Z','latest'),
 ('c2400000-0000-4000-8000-000000000003','c2300000-0000-4000-8000-000000000002',160,'2026-11-01T03:21:00Z','other');
update public.profile_private_details set bodyweight_lb=190 where user_id='c2300000-0000-4000-8000-000000000001';
select is_definer('public','patch_own_bodyweight_checkin',array['uuid','jsonb','jsonb'],'owner check-in patch has controlled definer boundary');
select is((select proconfig::text from pg_proc where oid='public.patch_own_bodyweight_checkin(uuid,jsonb,jsonb)'::regprocedure),'{search_path=pg_catalog}','check-in patch pins search path');
select ok(not has_function_privilege('anon','public.patch_own_bodyweight_checkin(uuid,jsonb,jsonb)','execute'),'anonymous patches denied');
select ok(has_function_privilege('authenticated','public.patch_own_bodyweight_checkin(uuid,jsonb,jsonb)','execute'),'authenticated owner API available');
select is((select proconfig::text from pg_proc where oid='public.save_bodyweight_checkin(uuid,numeric,timestamptz,text)'::regprocedure),'{search_path=pg_catalog}','canonical create/update pins its path');
select is((select proconfig::text from pg_proc where oid='public.delete_bodyweight_checkin(uuid)'::regprocedure),'{search_path=pg_catalog}','canonical delete pins its path');
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{}','{}')$$,'42501','Authentication required','no identity denied');
select set_config('request.jwt.claim.sub','c2300000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000003','{}','{}')$$,'P0002','Check-in is unavailable or was deleted','another owner record is unavailable');
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000004','{}','{}')$$,'P0002','Check-in is unavailable or was deleted','deleted/missing record is not recreated');
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','[]','{}')$$,'22023','Check-in changes must be objects','malformed changes denied');
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"user_id":"other"}','{"user_id":"owner"}')$$,'22023','Invalid check-in fields','ownership changes denied');
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"notes":"new"}','{}')$$,'22023','Invalid check-in fields','original baseline required');
select lives_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"notes":"new"}','{"notes":"original"}')$$,'notes-only edit succeeds after independent weight changed');
select is((select weight from public.bodyweight_records where id='c2400000-0000-4000-8000-000000000001'),185::numeric,'notes edit preserves newer weight');
select is((select recorded_at from public.bodyweight_records where id='c2400000-0000-4000-8000-000000000001'),'2026-11-01T03:21:00Z'::timestamptz,'notes edit preserves exact timestamp');
select is((select bodyweight_lb from public.profile_private_details where user_id=auth.uid()),190::numeric,'historical patch preserves authoritative latest weight');
select lives_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"notes":"new"}','{"notes":"original"}')$$,'same desired notes retry is idempotent');
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"weight":180,"notes":"wrong"}','{"weight":175,"notes":"new"}')$$,'40001','Check-in changed on another device','stale weight conflicts before any field writes');
select is((select notes from public.bodyweight_records where id='c2400000-0000-4000-8000-000000000001'),'new','conflict leaves otherwise valid note untouched');
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"weight":"180"}','{"weight":185}')$$,'22023','Invalid check-in value','numeric type enforced');
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"weight":20}','{"weight":185}')$$,'22023','Bodyweight must be between 40 and 1500 pounds','canonical weight bounds retained');
select lives_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"recorded_at":"2026-11-03T03:21:00Z"}','{"recorded_at":"2026-10-31T23:21:00-04:00"}')$$,'equivalent original timestamp offsets compare as the same instant');
select is((select bodyweight_lb from public.profile_private_details where user_id=auth.uid()),185::numeric,'moving record latest updates current authoritative weight');
select throws_ok($$select public.patch_own_bodyweight_checkin('c2400000-0000-4000-8000-000000000001','{"recorded_at":"2026-11-04T00:00:00Z"}','{"recorded_at":"2026-11-01T03:21:00Z"}')$$,'40001','Check-in changed on another device','stale date conflicts');
reset role;
select is((select weight from public.bodyweight_records where id='c2400000-0000-4000-8000-000000000003'),160::numeric,'other owner remains unchanged');
select is((select count(*)::integer from public.bodyweight_records where id='c2400000-0000-4000-8000-000000000004'),0,'unavailable edit created no record');
select * from finish();
rollback;

create extension if not exists dblink with schema extensions;
begin;
insert into auth.users(id,email) values
 ('c2500000-0000-4000-8000-000000000001','weight-race-owner@example.test'),
 ('c2500000-0000-4000-8000-000000000002','weight-race-other@example.test');
insert into public.bodyweight_records(id,user_id,weight,recorded_at,notes) values
 ('c2600000-0000-4000-8000-000000000001','c2500000-0000-4000-8000-000000000001',185,'2026-11-01T03:21:00Z','original'),
 ('c2600000-0000-4000-8000-000000000002','c2500000-0000-4000-8000-000000000001',190,'2026-11-02T03:21:00Z','latest'),
 ('c2600000-0000-4000-8000-000000000003','c2500000-0000-4000-8000-000000000001',180,'2026-11-01T03:21:00Z','older');
update public.profile_private_details set bodyweight_lb=190 where user_id='c2500000-0000-4000-8000-000000000001';
commit;
begin;
select no_plan();
select extensions.dblink_connect('weight_a',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select extensions.dblink_connect('weight_b',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select set_config('test.weight_b_pid',(select pid::text from extensions.dblink('weight_b','select pg_backend_pid()') as t(pid integer)),true);
select extensions.dblink_exec('weight_a',$$set role authenticated; set request.jwt.claim.sub='c2500000-0000-4000-8000-000000000001'$$);
select extensions.dblink_exec('weight_b',$$set role authenticated; set request.jwt.claim.sub='c2500000-0000-4000-8000-000000000001'$$);
create function pg_temp.run_weight_race(first_command text,second_command text)
returns table(second_waited boolean,second_result text)
language plpgsql as $$
declare attempt integer;
begin
  perform extensions.dblink_exec('weight_a','begin');
  perform extensions.dblink_exec('weight_b','begin');
  perform result from extensions.dblink('weight_a',first_command) as t(result integer);
  perform extensions.dblink_send_query('weight_b',second_command);
  second_waited := false;
  for attempt in 1..100 loop
    perform pg_stat_clear_snapshot();
    select wait_event_type='Lock' into second_waited from pg_stat_activity where pid=current_setting('test.weight_b_pid')::integer;
    exit when second_waited;
    perform pg_sleep(0.005);
  end loop;
  perform extensions.dblink_exec('weight_a','commit');
  begin
    perform result from extensions.dblink_get_result('weight_b') as t(result integer);
    second_result := 'ok';
  exception when others then second_result := sqlstate;
  end;
  perform result from extensions.dblink_get_result('weight_b') as t(result integer);
  perform extensions.dblink_exec('weight_b',case when second_result='ok' then 'commit' else 'rollback' end);
  return next;
end;
$$;
create temporary table weight_race_result as select * from pg_temp.run_weight_race(
 $$select 1 from (select public.save_bodyweight_checkin('c2600000-0000-4000-8000-000000000001',185,'2026-11-01T03:21:00Z','app change')) t$$,
 $$select 1 from (select public.patch_own_bodyweight_checkin('c2600000-0000-4000-8000-000000000001','{"notes":"web change"}','{"notes":"original"}')) t$$);
select ok(second_waited,'same-row edit waits for native transaction') from weight_race_result;
select is(second_result,'40001','same-row stale edit conflicts after wait') from weight_race_result;
select is((select notes from public.bodyweight_records where id='c2600000-0000-4000-8000-000000000001'),'app change','winning native edit preserved');
truncate weight_race_result;
insert into weight_race_result select * from pg_temp.run_weight_race(
 $$select 1 from (select public.delete_bodyweight_checkin('c2600000-0000-4000-8000-000000000001')) t$$,
 $$select 1 from (select public.patch_own_bodyweight_checkin('c2600000-0000-4000-8000-000000000001','{"notes":"web change"}','{"notes":"app change"}')) t$$);
select ok(second_waited,'edit waits for competing deletion') from weight_race_result;
select is(second_result,'P0002','edit refuses a deleted record after wait') from weight_race_result;
select is((select count(*)::integer from public.bodyweight_records where id='c2600000-0000-4000-8000-000000000001'),0,'concurrent edit does not resurrect deleted record');
truncate weight_race_result;
insert into weight_race_result select * from pg_temp.run_weight_race(
 $$select 1 from (select public.save_bodyweight_checkin('c2600000-0000-4000-8000-000000000002',200,'2026-11-03T03:21:00Z','latest changed')) t$$,
 $$select 1 from (select public.save_bodyweight_checkin('c2600000-0000-4000-8000-000000000003',175,'2026-11-01T03:21:00Z','older changed')) t$$);
select ok(second_waited,'different-row native writes share owner lock') from weight_race_result;
select is(second_result,'ok','different-row native write succeeds after lock') from weight_race_result;
select is((select weight from public.bodyweight_records where id='c2600000-0000-4000-8000-000000000003'),175::numeric,'older record edit persisted');
select is((select bodyweight_lb from public.profile_private_details where user_id='c2500000-0000-4000-8000-000000000001'),200::numeric,'concurrent different-row writes leave current weight aligned with latest record');
select extensions.dblink_exec('weight_b',$$set request.jwt.claim.sub='c2500000-0000-4000-8000-000000000002'$$);
truncate weight_race_result;
insert into weight_race_result select * from pg_temp.run_weight_race(
 $$select 1 from (select public.save_bodyweight_checkin('c2600000-0000-4000-8000-000000000004',180,'2026-11-04T03:21:00Z','owner one')) t$$,
 $$select 1 from (select public.save_bodyweight_checkin('c2600000-0000-4000-8000-000000000004',220,'2026-11-05T03:21:00Z','owner two')) t$$);
select ok(second_waited,'different owner colliding on a new ID waits for insert') from weight_race_result;
select is(second_result,'42501','conflicting ID cannot update another owner after wait') from weight_race_result;
select is((select user_id from public.bodyweight_records where id='c2600000-0000-4000-8000-000000000004'),'c2500000-0000-4000-8000-000000000001'::uuid,'collision preserves original owner');
select is((select weight from public.bodyweight_records where id='c2600000-0000-4000-8000-000000000004'),180::numeric,'collision preserves original weight');
select is((select notes from public.bodyweight_records where id='c2600000-0000-4000-8000-000000000004'),'owner one','collision preserves original notes');
select ok((select bodyweight_lb is null from public.profile_private_details where user_id='c2500000-0000-4000-8000-000000000002'),'collision leaves other owner profile untouched');
select extensions.dblink_disconnect('weight_a');
select extensions.dblink_disconnect('weight_b');
select * from finish();
delete from auth.users where id in ('c2500000-0000-4000-8000-000000000001','c2500000-0000-4000-8000-000000000002');
commit;
