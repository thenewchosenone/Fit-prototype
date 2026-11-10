begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege('anon','public.complete_lift_media_upload_if_current(uuid,uuid,uuid,text,text,bigint)','execute'),'anonymous cannot finalize');
select ok(has_function_privilege('authenticated','public.complete_lift_media_upload_if_current(uuid,uuid,uuid,text,text,bigint)','execute'),'authenticated uses guarded finalizer');
select is((select proconfig::text from pg_proc where oid='public.complete_lift_media_upload_if_current(uuid,uuid,uuid,text,text,bigint)'::regprocedure),'{search_path=pg_catalog}','definer pins search path');
insert into auth.users(id,email) values ('d5100000-0000-4000-8000-000000000001','media-cas-owner@example.test'),('d5100000-0000-4000-8000-000000000002','media-cas-other@example.test');
set local role authenticated;
select set_config('request.jwt.claim.sub','d5100000-0000-4000-8000-000000000001',true);
insert into public.lift_submissions(id,user_id,exercise_id,weight,unit,reps,bodyweight,visibility,caption,performed_at,is_actual_one_rep_max)
values('d5200000-0000-4000-8000-000000000001',auth.uid(),'bench',100,'kg',1,180,'Public','',now(),true);
reset role;
insert into storage.objects(bucket_id,name,owner_id)
select 'lift-videos','d5100000-0000-4000-8000-000000000001/d5200000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-'||lpad(n::text,12,'0')||'.mp4','d5100000-0000-4000-8000-000000000001' from generate_series(1,4)n;
create function pg_temp.attach(asset_id uuid, expected_id uuid) returns uuid language sql as $$
select id from public.complete_lift_media_upload_if_current(asset_id,'d5200000-0000-4000-8000-000000000001',expected_id,'d5100000-0000-4000-8000-000000000001/d5200000-0000-4000-8000-000000000001/'||asset_id::text||'.mp4','video/mp4',1024)
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select pg_temp.attach('d5400000-0000-4000-8000-000000000001',null)$$,'42501','Authentication required','missing identity rejected');
select set_config('request.jwt.claim.sub','d5100000-0000-4000-8000-000000000002',true);
select throws_ok($$select pg_temp.attach('d5400000-0000-4000-8000-000000000001',null)$$,'P0002','Owned lift not found','foreign owner cannot finalize');
select set_config('request.jwt.claim.sub','d5100000-0000-4000-8000-000000000001',true);
select throws_ok($$select pg_temp.attach('d5400000-0000-4000-8000-000000000005',null)$$,'P0001','Completed upload not found','missing storage object remains rejected');
select is((select video_asset_id from public.lift_submissions where id='d5200000-0000-4000-8000-000000000001'),null::uuid,'failed attachment leaves pointer unchanged');
select is(pg_temp.attach('d5400000-0000-4000-8000-000000000001',null),'d5400000-0000-4000-8000-000000000001'::uuid,'first attachment succeeds');
select is(pg_temp.attach('d5400000-0000-4000-8000-000000000001',null),'d5400000-0000-4000-8000-000000000001'::uuid,'same acknowledged attempt is idempotent');
select throws_ok($$select * from public.complete_lift_media_upload_if_current('d5400000-0000-4000-8000-000000000001','d5200000-0000-4000-8000-000000000001',null,'different/path.mp4','video/mp4',1024)$$,'22023','Attached upload does not match this attempt','replay cannot change upload identity');
select throws_ok($$select pg_temp.attach('d5400000-0000-4000-8000-000000000002',null)$$,'40001','Lift video changed. Reload before replacing evidence','stale expected pointer cannot replace');
select is((select count(*)::integer from public.lift_media_assets where id='d5400000-0000-4000-8000-000000000002'),0,'conflict creates no media row');
select is(pg_temp.attach('d5400000-0000-4000-8000-000000000002','d5400000-0000-4000-8000-000000000001'),'d5400000-0000-4000-8000-000000000002'::uuid,'explicit current pointer supports replacement');
select is((select evidence_status::text from public.lift_submissions where id='d5200000-0000-4000-8000-000000000001'),'video_backed','existing authority controls evidence status');
select is((select count(*)::integer from public.lift_media_assets where lift_id='d5200000-0000-4000-8000-000000000001'),2,'prior assets remain for coordinated owner cleanup');
select lives_ok($$select * from public.complete_lift_media_upload('d5400000-0000-4000-8000-000000000003','d5200000-0000-4000-8000-000000000001','d5100000-0000-4000-8000-000000000001/d5200000-0000-4000-8000-000000000001/d5400000-0000-4000-8000-000000000003.mp4','video/mp4',1024)$$,'existing native finalizer remains compatible');
select throws_ok($$select pg_temp.attach('d5400000-0000-4000-8000-000000000004','d5400000-0000-4000-8000-000000000002')$$,'40001','Lift video changed. Reload before replacing evidence','native replacement invalidates a prior web baseline');
select * from finish();
rollback;

create extension if not exists dblink with schema extensions;
begin;
insert into auth.users(id,email) values('d5500000-0000-4000-8000-000000000001','media-cas-race@example.test');
set local role authenticated;
select set_config('request.jwt.claim.sub','d5500000-0000-4000-8000-000000000001',true);
insert into public.lift_submissions(id,user_id,exercise_id,weight,unit,reps,bodyweight,visibility,caption,performed_at,is_actual_one_rep_max)
values('d5600000-0000-4000-8000-000000000001',auth.uid(),'bench',100,'kg',1,180,'Public','',now(),true);
reset role;
insert into storage.objects(bucket_id,name,owner_id)
select 'lift-videos','d5500000-0000-4000-8000-000000000001/d5600000-0000-4000-8000-000000000001/d5700000-0000-4000-8000-'||lpad(n::text,12,'0')||'.mp4','d5500000-0000-4000-8000-000000000001' from generate_series(1,2)n;
commit;
begin;
set local search_path=public,extensions;
select no_plan();
select extensions.dblink_connect('media_a',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select extensions.dblink_connect('media_b',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select set_config('test.media_b_pid',(select pid::text from extensions.dblink('media_b','select pg_backend_pid()') as t(pid integer)),true);
select extensions.dblink_exec('media_a',$$set role authenticated;set request.jwt.claim.sub='d5500000-0000-4000-8000-000000000001';set statement_timeout='5s';begin$$);
select extensions.dblink_exec('media_b',$$set role authenticated;set request.jwt.claim.sub='d5500000-0000-4000-8000-000000000001';set statement_timeout='5s';begin$$);
select result from extensions.dblink('media_a',$$select count(*)::integer from public.complete_lift_media_upload('d5700000-0000-4000-8000-000000000001','d5600000-0000-4000-8000-000000000001','d5500000-0000-4000-8000-000000000001/d5600000-0000-4000-8000-000000000001/d5700000-0000-4000-8000-000000000001.mp4','video/mp4',1024)$$) as t(result integer);
select extensions.dblink_send_query('media_b',$$select count(*)::integer from public.complete_lift_media_upload_if_current('d5700000-0000-4000-8000-000000000002','d5600000-0000-4000-8000-000000000001',null,'d5500000-0000-4000-8000-000000000001/d5600000-0000-4000-8000-000000000001/d5700000-0000-4000-8000-000000000002.mp4','video/mp4',1024)$$);
create temporary table media_wait(waited boolean);
do $$declare waited boolean:=false;begin
  for n in 1..100 loop
    perform pg_stat_clear_snapshot();
    select wait_event_type='Lock' into waited from pg_stat_activity where pid=current_setting('test.media_b_pid')::integer;
    exit when waited;perform pg_sleep(0.005);
  end loop;
  insert into media_wait values(coalesce(waited,false));
end$$;
select ok((select waited from media_wait),'guarded web attachment waits for native finalization lock');
select extensions.dblink_exec('media_a','commit');
create temporary table media_result(code text);
do $$begin
  begin perform result from extensions.dblink_get_result('media_b') as t(result integer);insert into media_result values('ok');
  exception when others then insert into media_result values(sqlstate);end;
  perform result from extensions.dblink_get_result('media_b') as t(result integer);
end$$;
select is((select code from media_result),'40001','waiting web finalization detects newly committed native attachment');
select extensions.dblink_exec('media_b','rollback');
select is((select video_asset_id from public.lift_submissions where id='d5600000-0000-4000-8000-000000000001'),'d5700000-0000-4000-8000-000000000001'::uuid,'concurrent web request does not overwrite native video');
select is((select count(*)::integer from public.lift_media_assets where id='d5700000-0000-4000-8000-000000000002'),0,'concurrent conflict leaves no second asset row');
select extensions.dblink_disconnect('media_a');select extensions.dblink_disconnect('media_b');
select * from finish();
rollback;
delete from storage.objects where name like 'd5500000-0000-4000-8000-000000000001/%';
delete from auth.users where id='d5500000-0000-4000-8000-000000000001';
