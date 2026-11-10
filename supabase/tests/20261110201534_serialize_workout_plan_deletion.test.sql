begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();
insert into auth.users(id,email) values
 ('c3100000-0000-4000-8000-000000000001','plan-contract-owner@example.test'),
 ('c3100000-0000-4000-8000-000000000002','plan-contract-other@example.test');
insert into public.workout_plan_documents(id,owner_id,revision,name,payload) values
 ('c3200000-0000-4000-8000-000000000001','c3100000-0000-4000-8000-000000000001',1,'Owner plan','"e30="'),
 ('c3200000-0000-4000-8000-000000000002','c3100000-0000-4000-8000-000000000002',1,'Other plan','"e30="');
select ok((select relrowsecurity from pg_class where oid='public.workout_plan_deletions'::regclass),'tombstones have RLS');
select ok(not has_table_privilege('authenticated','public.workout_plan_documents','truncate'),'authenticated cannot truncate all plans');
select ok(not has_table_privilege('anon','public.workout_plan_documents','truncate'),'anonymous cannot truncate all plans');
select ok(not has_table_privilege('authenticated','public.workout_plan_documents','trigger'),'authenticated cannot install plan triggers');
select ok(not has_table_privilege('authenticated','public.workout_plan_deletions','insert,update,delete,truncate'),'owners cannot alter tombstones directly');
select ok(not has_function_privilege('anon','public.delete_own_workout_plan(uuid)','execute'),'anonymous cannot call plan deletion');
select ok(not has_function_privilege('authenticated','public.reject_deleted_workout_plan_reinsert()','execute'),'internal trigger not API callable');
select is((select proconfig::text from pg_proc where oid='public.delete_own_workout_plan(uuid)'::regprocedure),'{search_path=pg_catalog}','delete pins search path');
select is((select proconfig::text from pg_proc where oid='public.reject_deleted_workout_plan_reinsert()'::regprocedure),'{search_path=pg_catalog}','guard pins search path');
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.delete_own_workout_plan('c3200000-0000-4000-8000-000000000001')$$,'42501','Authentication required','missing identity cannot delete');
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000001',true);
select throws_ok($$truncate public.workout_plan_documents$$,'42501',null,'raw SQL cannot bulk-delete plan rows');
select is((select count(*)::integer from public.workout_plan_documents),1,'owner reads exclude other plans');
select throws_ok($$insert into public.workout_plan_documents(id,owner_id,name,payload) values('c3200000-0000-4000-8000-000000000003','c3100000-0000-4000-8000-000000000002','Foreign','"e30="')$$,'42501',null,'owner cannot insert for another owner');
select throws_ok($$update public.workout_plan_documents set owner_id='c3100000-0000-4000-8000-000000000002' where id='c3200000-0000-4000-8000-000000000001'$$,'42501','Workout plan identity cannot change','owner identity cannot be reassigned');
with changed as (update public.workout_plan_documents set revision=2,name='Owner edit' where owner_id=auth.uid() and id='c3200000-0000-4000-8000-000000000001' and revision=1 returning id)
select is((select count(*)::integer from changed),1,'native original-revision update succeeds');
with changed as (update public.workout_plan_documents set revision=2,name='Stale edit' where owner_id=auth.uid() and id='c3200000-0000-4000-8000-000000000001' and revision=1 returning id)
select is((select count(*)::integer from changed),0,'stale original revision matches no rows');
select is(public.delete_own_workout_plan('c3200000-0000-4000-8000-000000000002'),false,'foreign plan is unavailable to deletion RPC');
select is(public.delete_own_workout_plan('c3200000-0000-4000-8000-000000000001'),true,'owner deletes with tombstone');
select is(public.delete_own_workout_plan('c3200000-0000-4000-8000-000000000001'),true,'deletion retry remains idempotent');
select throws_ok($$insert into public.workout_plan_documents(id,owner_id,name,payload) values('c3200000-0000-4000-8000-000000000001','c3100000-0000-4000-8000-000000000001','Resurrected','"e30="')$$,'P0001','Workout plan has been deleted','committed tombstone blocks insert');
insert into public.workout_plan_documents(id,owner_id,name,payload) values('c3200000-0000-4000-8000-000000000003','c3100000-0000-4000-8000-000000000001','New plan','"e30="');
select throws_ok($$update public.workout_plan_documents set id='c3200000-0000-4000-8000-000000000001' where id='c3200000-0000-4000-8000-000000000003'$$,'42501','Workout plan identity cannot change','ID-changing update cannot bypass tombstone');
select is((select count(*)::integer from public.workout_plan_deletions),1,'owner sees own tombstone');
select set_config('request.jwt.claim.sub','c3100000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.workout_plan_deletions),0,'other owner cannot see tombstone');
select is((select name from public.workout_plan_documents where owner_id=auth.uid()),'Other plan','foreign plan preserved');
select * from finish();
rollback;

create extension if not exists dblink with schema extensions;
begin;
insert into auth.users(id,email) values('c3300000-0000-4000-8000-000000000001','plan-race-owner@example.test');
insert into public.workout_plan_documents(id,owner_id,name,payload) values
 ('c3400000-0000-4000-8000-000000000001','c3300000-0000-4000-8000-000000000001','Delete then insert','"e30="'),
 ('c3400000-0000-4000-8000-000000000002','c3300000-0000-4000-8000-000000000001','Update then delete','"e30="'),
 ('c3400000-0000-4000-8000-000000000004','c3300000-0000-4000-8000-000000000001','Delete then update','"e30="');
commit;
begin;
select no_plan();
select extensions.dblink_connect('plan_a',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select extensions.dblink_connect('plan_b',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select set_config('test.plan_b_pid',(select pid::text from extensions.dblink('plan_b','select pg_backend_pid()') as t(pid integer)),true);
select extensions.dblink_exec('plan_a',$$set role authenticated; set request.jwt.claim.sub='c3300000-0000-4000-8000-000000000001'; set statement_timeout='5s'$$);
select extensions.dblink_exec('plan_b',$$set role authenticated; set request.jwt.claim.sub='c3300000-0000-4000-8000-000000000001'; set statement_timeout='5s'$$);
create function pg_temp.run_plan_race(first_command text,second_command text)
returns table(second_waited boolean,second_result text,affected integer)
language plpgsql as $$
declare attempt integer;
begin
  perform extensions.dblink_exec('plan_a','begin');
  perform extensions.dblink_exec('plan_b','begin');
  perform result from extensions.dblink('plan_a',first_command) as t(result integer);
  perform extensions.dblink_send_query('plan_b',second_command);
  second_waited := false;
  for attempt in 1..100 loop
    perform pg_stat_clear_snapshot();
    select wait_event_type='Lock' into second_waited from pg_stat_activity where pid=current_setting('test.plan_b_pid')::integer;
    exit when second_waited;
    perform pg_sleep(0.005);
  end loop;
  perform extensions.dblink_exec('plan_a','commit');
  begin
    select result into affected from extensions.dblink_get_result('plan_b') as t(result integer);
    second_result := 'ok';
  exception when others then second_result := sqlstate;
  end;
  perform result from extensions.dblink_get_result('plan_b') as t(result integer);
  perform extensions.dblink_exec('plan_b',case when second_result='ok' then 'commit' else 'rollback' end);
  return next;
end;
$$;
create temporary table plan_race_result as select * from pg_temp.run_plan_race(
 $$select 1 from (select public.delete_own_workout_plan('c3400000-0000-4000-8000-000000000001')) t$$,
 $$with inserted as (insert into public.workout_plan_documents(id,owner_id,name,payload) values('c3400000-0000-4000-8000-000000000001','c3300000-0000-4000-8000-000000000001','Must not return','"e30="') returning id) select count(*)::integer from inserted$$);
select ok(second_waited,'insert waits for pending canonical deletion') from plan_race_result;
select is(second_result,'P0001','waiting insert sees committed tombstone') from plan_race_result;
select is((select count(*)::integer from public.workout_plan_documents where id='c3400000-0000-4000-8000-000000000001'),0,'race leaves no live resurrected plan');
select is((select count(*)::integer from public.workout_plan_deletions where plan_id='c3400000-0000-4000-8000-000000000001'),1,'race retains the tombstone');
truncate plan_race_result;
insert into plan_race_result select * from pg_temp.run_plan_race(
 $$with changed as (update public.workout_plan_documents set revision=2 where id='c3400000-0000-4000-8000-000000000002' and revision=1 returning id) select count(*)::integer from changed$$,
 $$select 1 from (select public.delete_own_workout_plan('c3400000-0000-4000-8000-000000000002')) t$$);
select ok(second_waited,'delete waits for a native row update without lock inversion') from plan_race_result;
select is(second_result,'ok','native update/delete complete without deadlock') from plan_race_result;
select is((select count(*)::integer from public.workout_plan_documents where id='c3400000-0000-4000-8000-000000000002'),0,'delete removes the updated plan');
truncate plan_race_result;
insert into plan_race_result select * from pg_temp.run_plan_race(
 $$with inserted as (insert into public.workout_plan_documents(id,owner_id,name,payload) values('c3400000-0000-4000-8000-000000000003','c3300000-0000-4000-8000-000000000001','Pending new plan','"e30="') returning id) select count(*)::integer from inserted$$,
 $$select case when public.delete_own_workout_plan('c3400000-0000-4000-8000-000000000003') then 1 else 0 end$$);
select ok(second_waited,'delete waits for an uncommitted new plan before checking existence') from plan_race_result;
select is(affected,1,'waiting delete finds and removes the committed insertion') from plan_race_result;
select is((select count(*)::integer from public.workout_plan_documents where id='c3400000-0000-4000-8000-000000000003'),0,'reverse race leaves no surviving plan');
select is((select count(*)::integer from public.workout_plan_deletions where plan_id='c3400000-0000-4000-8000-000000000003'),1,'reverse race records deletion');
truncate plan_race_result;
insert into plan_race_result select * from pg_temp.run_plan_race(
 $$select 1 from (select public.delete_own_workout_plan('c3400000-0000-4000-8000-000000000004')) t$$,
 $$with changed as (update public.workout_plan_documents set revision=2 where id='c3400000-0000-4000-8000-000000000004' and revision=1 returning id) select count(*)::integer from changed$$);
select ok(second_waited,'native update waits for deletion row lock') from plan_race_result;
select is(second_result,'ok','delete/update complete without deadlock') from plan_race_result;
select is(affected,0,'waiting native CAS matches zero rows after deletion') from plan_race_result;
select extensions.dblink_disconnect('plan_a');
select extensions.dblink_disconnect('plan_b');
select * from finish();
delete from auth.users where id='c3300000-0000-4000-8000-000000000001';
commit;
