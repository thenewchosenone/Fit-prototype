begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege('anon','public.reserve_lift_removal(uuid,uuid)','execute'),'anonymous cannot reserve cleanup');
select ok(not has_function_privilege('authenticated','public.reserve_lift_removal(uuid,uuid)','execute'),'clients cannot reserve arbitrary cleanup');
select ok(has_function_privilege('service_role','public.reserve_lift_removal(uuid,uuid)','execute'),'only trusted workflow reserves cleanup');
select ok(not has_function_privilege('authenticated','public.finalize_lift_removal(uuid)','execute'),'clients cannot bypass storage cleanup');
select is((select count(*)::integer from pg_proc where oid in('public.reserve_lift_removal(uuid,uuid)'::regprocedure,'public.finalize_lift_removal(uuid)'::regprocedure,'public.guard_lift_evidence_storage_write()'::regprocedure,'public.prevent_removed_lift_recreation()'::regprocedure) and prosecdef and proconfig='{search_path=pg_catalog}'),4,'all cleanup definers have fixed search path');
insert into auth.users(id,email) values('d6100000-0000-4000-8000-000000000001','removal-owner@example.test'),('d6100000-0000-4000-8000-000000000002','removal-other@example.test');
set local role authenticated;
select set_config('request.jwt.claim.sub','d6100000-0000-4000-8000-000000000001',true);
insert into public.lift_submissions(id,user_id,exercise_id,weight,unit,reps,bodyweight,visibility,caption,performed_at,is_actual_one_rep_max)
select ('d6200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,auth.uid(),'bench',100,'kg',1,180,'Private','',now(),true from generate_series(1,3)n;
select lives_ok($$insert into storage.objects(bucket_id,name,owner_id)values('lift-videos','d6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000001/video.mp4',auth.uid()::text)$$,'normal native upload succeeds before reservation');
select throws_ok($$insert into storage.objects(bucket_id,name,owner_id)values('lift-videos','d6100000-0000-4000-8000-000000000001/flat.mp4',auth.uid()::text)$$,'42501',null,'malformed client paths denied');
select throws_ok($$insert into storage.objects(bucket_id,name,owner_id)values('lift-videos','d6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000099/video.mp4',auth.uid()::text)$$,'55000','Lift evidence is unavailable or removal has started','upload requires a saved owned lift');
reset role;
-- Two unattached files must both be collected, without touching another lift.
insert into storage.objects(bucket_id,name,owner_id)values
('lift-videos','d6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000001/unattached.mp4','d6100000-0000-4000-8000-000000000001'),
('lift-videos','d6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000002/keep.mp4','d6100000-0000-4000-8000-000000000001');
set local role service_role;
select throws_ok($$select public.reserve_lift_removal('d6200000-0000-4000-8000-000000000001','d6100000-0000-4000-8000-000000000002')$$,'P0002','Owned lift not found','foreign reservation denied');
select is(jsonb_array_length(public.reserve_lift_removal('d6200000-0000-4000-8000-000000000001','d6100000-0000-4000-8000-000000000001')->'storage_objects'),2,'reservation includes all attached and unattached prefix objects');
reset role;
select is((select count(*)::integer from public.lift_removal_requests where owner_id='d6100000-0000-4000-8000-000000000002'),0,'foreign attempt creates no request');
select ok((select protected_record from public.lift_removal_requests where lift_id='d6200000-0000-4000-8000-000000000001'),'unattached stored evidence requires coordinated cleanup');
select throws_ok($$select public.finalize_lift_removal((select id from public.lift_removal_requests where lift_id='d6200000-0000-4000-8000-000000000001'))$$,'55000','Evidence cleanup is incomplete','finalizer refuses pending storage');
set local role authenticated;
select throws_ok($$select * from public.complete_lift_media_upload('d6300000-0000-4000-8000-000000000001','d6200000-0000-4000-8000-000000000001','d6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000001/video.mp4','video/mp4',100)$$,'55000','Lift removal has started','native finalizer honors reservation');
select throws_ok($$select * from public.complete_lift_media_upload_if_current('d6300000-0000-4000-8000-000000000001','d6200000-0000-4000-8000-000000000001',null,'d6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000001/video.mp4','video/mp4',100)$$,'55000','Lift removal has started','web finalizer honors reservation');
reset role;
-- Privileged actual Storage insert must reject even after a rolled-back caller probe.
select throws_ok($$insert into storage.objects(bucket_id,name,owner_id)values('lift-videos','d6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000001/late.mp4','d6100000-0000-4000-8000-000000000001')$$,'55000','Lift evidence is unavailable or removal has started','actual privileged insert cannot bypass reservation');
delete from storage.objects where name like 'd6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000001/%';
select lives_ok($$select public.finalize_lift_removal((select id from public.lift_removal_requests where lift_id='d6200000-0000-4000-8000-000000000001'))$$,'cleaned request finalizes');
select is((select count(*)::integer from public.lift_submissions where id='d6200000-0000-4000-8000-000000000001'),0,'lift removed');
select is((select count(*)::integer from storage.objects where name like '%/d6200000-0000-4000-8000-000000000002/%'),1,'other lift object preserved');
select is(public.reserve_lift_removal('d6200000-0000-4000-8000-000000000001','d6100000-0000-4000-8000-000000000001')->>'status','completed','completed reserve replay remains idempotent');
set local role authenticated;
select throws_ok($$insert into public.lift_submissions(id,user_id,exercise_id,weight,unit,reps,bodyweight,visibility,caption,performed_at,is_actual_one_rep_max)values('d6200000-0000-4000-8000-000000000001',auth.uid(),'bench',100,'kg',1,180,'Private','',now(),true)$$,'55000','A removed lift identifier cannot be reused','old client cannot recreate removed ID');
reset role;
-- Unsafe legacy pointers must never be sent to privileged Storage.remove.
update public.lift_submissions set approved_evidence_storage_path='d6100000-0000-4000-8000-000000000002/d6200000-0000-4000-8000-000000000002/foreign.mp4' where id='d6200000-0000-4000-8000-000000000002';
select throws_ok($$select public.reserve_lift_removal('d6200000-0000-4000-8000-000000000002','d6100000-0000-4000-8000-000000000001')$$,'22023','Evidence path requires administrative repair','foreign legacy evidence rejected');
update public.lift_submissions set approved_evidence_storage_path='d6100000-0000-4000-8000-000000000001/d6200000-0000-4000-8000-000000000003/other-lift.mp4' where id='d6200000-0000-4000-8000-000000000002';
select throws_ok($$select public.reserve_lift_removal('d6200000-0000-4000-8000-000000000002','d6100000-0000-4000-8000-000000000001')$$,'22023','Evidence path requires administrative repair','same-owner different-lift pointer rejected');
select is((select count(*)::integer from public.lift_removal_requests where lift_id='d6200000-0000-4000-8000-000000000002'),0,'unsafe paths start no destructive request');
select * from finish();
rollback;

-- Committed multi-connection fixtures cover both lock orders and permission-probe
-- savepoint rollback followed by the actual privileged Storage metadata write.
create extension if not exists dblink with schema extensions;
begin;
insert into auth.users(id,email)values('d6400000-0000-4000-8000-000000000001','removal-race@example.test');
select set_config('request.jwt.claim.sub','d6400000-0000-4000-8000-000000000001',true);
insert into public.lift_submissions(id,user_id,exercise_id,weight,unit,reps,bodyweight,visibility,caption,performed_at,is_actual_one_rep_max)
select ('d6500000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,auth.uid(),'bench',100,'kg',1,180,'Private','',now(),true from generate_series(1,4)n;
commit;
begin;
set local search_path=public,extensions;
select no_plan();
select extensions.dblink_connect('remove_a',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select extensions.dblink_connect('remove_b',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select set_config('test.remove_b_pid',(select pid::text from extensions.dblink('remove_b','select pg_backend_pid()') as t(pid integer)),true);
select extensions.dblink_exec('remove_a','set statement_timeout=''5s'';begin');
select extensions.dblink_exec('remove_b','set statement_timeout=''5s'';begin');
select extensions.dblink_exec('remove_a',$$insert into storage.objects(bucket_id,name,owner_id)values('lift-videos','d6400000-0000-4000-8000-000000000001/d6500000-0000-4000-8000-000000000001/early.mp4','d6400000-0000-4000-8000-000000000001')$$);
select extensions.dblink_send_query('remove_b',$$select jsonb_array_length(public.reserve_lift_removal('d6500000-0000-4000-8000-000000000001','d6400000-0000-4000-8000-000000000001')->'storage_objects')$$);
create function pg_temp.wait_removal_lock() returns boolean language plpgsql as $$
declare waited boolean;
begin
  for n in 1..100 loop
    perform pg_stat_clear_snapshot();select wait_event_type='Lock' into waited from pg_stat_activity where pid=current_setting('test.remove_b_pid')::integer;
    if waited then return true;end if;perform pg_sleep(0.005);
  end loop;
  return false;
end$$;
select ok(pg_temp.wait_removal_lock(),'reservation waits for actual earlier upload insert');
select extensions.dblink_exec('remove_a','commit');
select is((select result from extensions.dblink_get_result('remove_b') as t(result integer)),1,'reservation snapshot includes newly committed upload');
select * from extensions.dblink_get_result('remove_b') as t(result integer);
select extensions.dblink_exec('remove_b','commit');
-- Reserve first; a separate privileged actual insert must wait and then fail.
select extensions.dblink_exec('remove_a','begin');
select result from extensions.dblink('remove_a',$$select public.reserve_lift_removal('d6500000-0000-4000-8000-000000000002','d6400000-0000-4000-8000-000000000001')::text$$)as t(result text);
select extensions.dblink_send_query('remove_b',$$insert into storage.objects(bucket_id,name,owner_id)values('lift-videos','d6400000-0000-4000-8000-000000000001/d6500000-0000-4000-8000-000000000002/late.mp4','d6400000-0000-4000-8000-000000000001') returning 1$$);
select ok(pg_temp.wait_removal_lock(),'privileged late insert waits for removal reservation');
select extensions.dblink_exec('remove_a','commit');
create temporary table removal_race_errors(code text);
do $$begin
  begin perform result from extensions.dblink_get_result('remove_b') as t(result integer);insert into removal_race_errors values('ok');
  exception when others then insert into removal_race_errors values(sqlstate);end;
  perform result from extensions.dblink_get_result('remove_b') as t(result integer);
end$$;
select is((select code from removal_race_errors),'55000','privileged late insert rejects after waiting');
select is((select count(*)::integer from storage.objects where name like '%/d6500000-0000-4000-8000-000000000002/%'),0,'late upload creates no metadata orphan');
-- Mirror Storage's rolled-back caller probe; no lock from that probe is relied on.
select extensions.dblink_exec('remove_a',$$begin;set local role authenticated;set local request.jwt.claim.sub='d6400000-0000-4000-8000-000000000001';savepoint permission_probe;insert into storage.objects(bucket_id,name,owner_id)values('lift-videos','d6400000-0000-4000-8000-000000000001/d6500000-0000-4000-8000-000000000003/probe.mp4','d6400000-0000-4000-8000-000000000001');rollback to permission_probe;reset role;$$);
select result from extensions.dblink('remove_b',$$select public.reserve_lift_removal('d6500000-0000-4000-8000-000000000003','d6400000-0000-4000-8000-000000000001')::text$$)as t(result text);
select throws_ok($$select extensions.dblink_exec('remove_a',$q$insert into storage.objects(bucket_id,name,owner_id)values('lift-videos','d6400000-0000-4000-8000-000000000001/d6500000-0000-4000-8000-000000000003/probe.mp4','d6400000-0000-4000-8000-000000000001')$q$)$$,'55000','Lift evidence is unavailable or removal has started','actual privileged insert after rolled-back probe still checks reservation');
select extensions.dblink_exec('remove_a','rollback');
select is((select count(*)::integer from storage.objects where name like '%/d6500000-0000-4000-8000-000000000003/%'),0,'probe and rejected actual write leave no storage metadata');
-- An old INSERT already waiting on deletion must not resurrect the same ID.
select extensions.dblink_exec('remove_a','begin');
select result from extensions.dblink('remove_a',$$select public.reserve_lift_removal('d6500000-0000-4000-8000-000000000004','d6400000-0000-4000-8000-000000000001')::text$$)as t(result text);
select result from extensions.dblink('remove_a',$$select public.finalize_lift_removal((select id from public.lift_removal_requests where lift_id='d6500000-0000-4000-8000-000000000004'))$$)as t(result boolean);
select extensions.dblink_exec('remove_b',$$set request.jwt.claim.sub='d6400000-0000-4000-8000-000000000001'$$);
select extensions.dblink_send_query('remove_b',$$insert into public.lift_submissions(id,user_id,exercise_id,weight,unit,reps,bodyweight,visibility,caption,performed_at,is_actual_one_rep_max)values('d6500000-0000-4000-8000-000000000004','d6400000-0000-4000-8000-000000000001','bench',100,'kg',1,180,'Private','',now(),true)returning 1$$);
select ok(pg_temp.wait_removal_lock(),'stale INSERT waits for in-flight coordinated deletion');
select extensions.dblink_exec('remove_a','commit');
truncate removal_race_errors;
do $$begin
  begin perform result from extensions.dblink_get_result('remove_b') as t(result integer);insert into removal_race_errors values('ok');
  exception when others then insert into removal_race_errors values(sqlstate);end;
  perform result from extensions.dblink_get_result('remove_b') as t(result integer);
end$$;
select is((select code from removal_race_errors),'55000','waiting stale INSERT sees committed removal tombstone');
select is((select count(*)::integer from public.lift_submissions where id='d6500000-0000-4000-8000-000000000004'),0,'stale waiting INSERT does not resurrect deleted lift');
select extensions.dblink_disconnect('remove_a');select extensions.dblink_disconnect('remove_b');
select * from finish();
rollback;
delete from storage.objects where name like 'd6400000-0000-4000-8000-000000000001/%';
delete from auth.users where id='d6400000-0000-4000-8000-000000000001';
