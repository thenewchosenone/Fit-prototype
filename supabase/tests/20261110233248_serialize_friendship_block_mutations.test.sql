begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege('anon',fn,'execute'),'anonymous cannot execute '||fn)
from unnest(array['public.request_friendship(uuid)','public.respond_to_friendship(uuid,boolean)','public.block_user(uuid)','public.unblock_user(uuid)']) fn;
select ok(has_function_privilege('authenticated',fn,'execute'),'authenticated may execute '||fn)
from unnest(array['public.request_friendship(uuid)','public.respond_to_friendship(uuid,boolean)','public.block_user(uuid)','public.unblock_user(uuid)']) fn;
select is((select count(*)::integer from pg_proc where oid in('public.request_friendship(uuid)'::regprocedure,'public.respond_to_friendship(uuid,boolean)'::regprocedure,'public.block_user(uuid)'::regprocedure,'public.unblock_user(uuid)'::regprocedure,'public.are_friends(uuid,uuid)'::regprocedure) and prosecdef and proconfig='{search_path=pg_catalog}'),5,'all changed definers pin search path');
select ok(not has_table_privilege('authenticated','public.user_blocks',priv),'raw user_blocks '||priv||' denied')from unnest(array['TRUNCATE','REFERENCES','TRIGGER','INSERT','UPDATE','DELETE'])priv;
select ok(has_column_privilege('authenticated','public.user_blocks','blocker_id','SELECT'),'own block reads preserved');
insert into auth.users(id,email)values('e7100000-0000-4000-8000-000000000001','friend-a@example.test'),('e7100000-0000-4000-8000-000000000002','friend-b@example.test'),('e7100000-0000-4000-8000-000000000003','friend-c@example.test');
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.request_friendship('e7100000-0000-4000-8000-000000000002')$$,'28000','Authentication required','request requires identity');
select throws_ok($$select public.respond_to_friendship('e7300000-0000-4000-8000-000000000001',true)$$,'28000','Authentication required','response requires identity');
select throws_ok($$select public.block_user('e7100000-0000-4000-8000-000000000002')$$,'42501','authentication required','block requires identity');
select throws_ok($$select public.unblock_user('e7100000-0000-4000-8000-000000000002')$$,'42501','authentication required','unblock requires identity');
select throws_ok($$truncate public.user_blocks$$,'42501',null,'RLS cannot be bypassed through raw TRUNCATE');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.request_friendship(auth.uid())$$,'23514','Users cannot friend themselves','self request unchanged');
select throws_ok($$select public.block_user(auth.uid())$$,'P0001','cannot block yourself','self block unchanged');
select throws_ok($$select public.request_friendship('e7100000-0000-4000-8000-000000000099')$$,'P0002','Profile not found','missing profile unchanged');
select is((public.request_friendship('e7100000-0000-4000-8000-000000000002')).status::text,'pending','normal request still returns composite pending row');
select set_config('test.friend_id',(select id::text from public.friend_relationships where requested_by=auth.uid()),true);
select throws_ok($$select public.request_friendship('e7100000-0000-4000-8000-000000000002')$$,'23505','A friendship or pending request already exists','duplicate request unchanged');
select throws_ok($$select public.respond_to_friendship(current_setting('test.friend_id')::uuid,true)$$,'42501','Only the recipient may respond to a friend request','requester cannot accept own request');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.respond_to_friendship(current_setting('test.friend_id')::uuid,true)$$,'42501','Only the recipient may respond to a friend request','unrelated caller cannot accept');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.request_friendship('e7100000-0000-4000-8000-000000000001')$$,'23505','A friendship or pending request already exists','crossed request never autoaccepts');
select is((public.respond_to_friendship(current_setting('test.friend_id')::uuid,true)).status::text,'accepted','recipient acceptance remains compatible');
select ok(public.are_friends(auth.uid(),'e7100000-0000-4000-8000-000000000001'),'accepted participants see friendship');
reset role;
select is((select count(*)::integer from public.notifications where user_id='e7100000-0000-4000-8000-000000000002' and kind='friendship' and title='New friend request'),1,'normal request still notifies recipient once');
select is((select count(*)::integer from public.notifications where user_id='e7100000-0000-4000-8000-000000000001' and kind='friendship' and title='Friend request accepted'),1,'normal acceptance still notifies requester once');
set local role authenticated;
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000003',true);
select ok(not public.are_friends('e7100000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000002'),'unrelated caller cannot inspect accepted pair');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.unblock_user('e7100000-0000-4000-8000-000000000001')$$,'unblock without own block is idempotent');
select ok(public.are_friends(auth.uid(),'e7100000-0000-4000-8000-000000000001'),'idempotent unblock preserves ordinary friendship');
select lives_ok($$select public.remove_friendship(current_setting('test.friend_id')::uuid)$$,'existing remove RPC still works');
select is((public.request_friendship('e7100000-0000-4000-8000-000000000001')).id::text,current_setting('test.friend_id'),'terminal relationship ID reuse preserved');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000001',true);
select is((public.respond_to_friendship(current_setting('test.friend_id')::uuid,false)).status::text,'declined','normal decline remains compatible');
select lives_ok($$select public.block_user('e7100000-0000-4000-8000-000000000002')$$,'block removes terminal relationship too');
select throws_ok($$select public.request_friendship('e7100000-0000-4000-8000-000000000002')$$,'42501','Friendship is unavailable for blocked users','outgoing blocked request denied');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.request_friendship('e7100000-0000-4000-8000-000000000001')$$,'42501','Friendship is unavailable for blocked users','incoming blocked request denied');
reset role;
-- Historical latent rows are modeled administratively; mutation clients have no DML.
insert into public.friend_relationships(id,user_low_id,user_high_id,requested_by,status)
values('e7300000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000002','e7100000-0000-4000-8000-000000000001','pending');
set local role authenticated;
select throws_ok($$select public.respond_to_friendship('e7300000-0000-4000-8000-000000000001',true)$$,'42501','Friendship is unavailable for blocked users','legacy blocked pending cannot be accepted');
reset role;
update public.friend_relationships set status='accepted' where id='e7300000-0000-4000-8000-000000000001';
set local role authenticated;
select ok(not public.are_friends('e7100000-0000-4000-8000-000000000001',auth.uid()),'legacy blocked accepted is never an authoritative friendship');
select lives_ok($$select public.unblock_user('e7100000-0000-4000-8000-000000000001')$$,'cannot remove someone else block');
reset role;
select is((select count(*)::integer from public.user_blocks),1,'reverse block retained');
set local role authenticated;
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.unblock_user('e7100000-0000-4000-8000-000000000002')$$,'actual own unblock cleans historical relationship');
select is((select count(*)::integer from public.friend_relationships),0,'unblock cannot resurrect latent accepted friendship');
select is((public.request_friendship('e7100000-0000-4000-8000-000000000002')).status::text,'pending','unblocked pair requires a fresh request');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000003',true);
select ok(not public.are_friends('e7100000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000002'),'unrelated caller cannot inspect pair friendship');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000002',true);
select public.block_user('e7100000-0000-4000-8000-000000000001');
select set_config('request.jwt.claim.sub','e7100000-0000-4000-8000-000000000001',true);
select public.block_user('e7100000-0000-4000-8000-000000000002');
reset role;
insert into public.friend_relationships(user_low_id,user_high_id,requested_by,status)values
('e7100000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000002','e7100000-0000-4000-8000-000000000001','accepted'),
('e7100000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000003','e7100000-0000-4000-8000-000000000001','accepted');
set local role authenticated;
select public.unblock_user('e7100000-0000-4000-8000-000000000002');
select is((select count(*)::integer from public.user_blocks),0,'caller block read hides reverse owner block');
reset role;
select is((select count(*)::integer from public.user_blocks),1,'actual unblock retains reverse-direction block');
select is((select count(*)::integer from public.friend_relationships where user_high_id='e7100000-0000-4000-8000-000000000002'),0,'latent target relationship cleaned even with reverse block');
select is((select count(*)::integer from public.friend_relationships where user_high_id='e7100000-0000-4000-8000-000000000003'),1,'unrelated accepted friendship retained');
set local role authenticated;
select throws_ok($$select public.request_friendship('e7100000-0000-4000-8000-000000000002')$$,'42501','Friendship is unavailable for blocked users','reverse block still prevents new request after own unblock');
select set_config('request.jwt.claim.sub','',true);
select ok(not public.are_friends('e7100000-0000-4000-8000-000000000001','e7100000-0000-4000-8000-000000000003'),'missing identity cannot inspect accepted friendship');
select * from finish();
rollback;

-- Committed fixtures exercise the same RPCs with actual RLS, notification
-- triggers and multiple transactions; every synthetic user is removed below.
create extension if not exists dblink with schema extensions;
begin;
insert into auth.users(id,email)select ('e8100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'friend-race-'||n||'@example.test' from generate_series(1,16)n;
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000007',true);
select public.request_friendship('e8100000-0000-4000-8000-000000000008');
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000009',true);
select public.request_friendship('e8100000-0000-4000-8000-000000000010');
select set_config('request.jwt.claim.sub','e8100000-0000-4000-8000-000000000013',true);
select public.request_friendship('e8100000-0000-4000-8000-000000000014');
-- Historical relationship left behind by the previous mutation race.
insert into public.friend_relationships(user_low_id,user_high_id,requested_by,status)values('e8100000-0000-4000-8000-000000000011','e8100000-0000-4000-8000-000000000012','e8100000-0000-4000-8000-000000000011','accepted');
insert into public.user_blocks(blocker_id,blocked_id)values('e8100000-0000-4000-8000-000000000011','e8100000-0000-4000-8000-000000000012');
commit;
begin;
set local search_path=public,extensions;
select no_plan();
select extensions.dblink_connect('friend_a',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select extensions.dblink_connect('friend_b',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select extensions.dblink_connect('friend_c',format('host=%s port=%s dbname=%I',split_part(current_setting('unix_socket_directories'),',',1),current_setting('port'),current_database()));
select set_config('test.friend_b_pid',(select pid::text from extensions.dblink('friend_b','select pg_backend_pid()')as t(pid integer)),true);
select extensions.dblink_exec('friend_a','set role authenticated;set statement_timeout=''5s''');
select extensions.dblink_exec('friend_b','set role authenticated;set statement_timeout=''5s''');
select extensions.dblink_exec('friend_c',$$set role authenticated;set statement_timeout='1s';set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000015'$$);
create function pg_temp.wait_friend_lock()returns boolean language plpgsql as $$
declare waited boolean;
begin
  for n in 1..100 loop
    perform pg_stat_clear_snapshot();select wait_event_type='Lock' into waited from pg_stat_activity where pid=current_setting('test.friend_b_pid')::integer;
    if waited then return true;end if;perform pg_sleep(0.005);
  end loop;return false;
end$$;
create function pg_temp.friend_result_code()returns text language plpgsql as $$
declare code text:='ok';
begin
  begin perform result from extensions.dblink_get_result('friend_b')as t(result text);
  exception when others then code:=sqlstate;end;
  perform result from extensions.dblink_get_result('friend_b')as t(result text);
  return code;
end$$;
-- Block first: the waiting reverse request must refresh blocked state afterwards.
select extensions.dblink_exec('friend_a',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000001';begin$$);
select result from extensions.dblink('friend_a',$$select public.block_user('e8100000-0000-4000-8000-000000000002')$$)as t(result text);
select extensions.dblink_exec('friend_b',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000002'$$);
select extensions.dblink_send_query('friend_b',$$select (public.request_friendship('e8100000-0000-4000-8000-000000000001')).status::text$$);
select ok(pg_temp.wait_friend_lock(),'request waits for pair block transaction');
select is((select result from extensions.dblink('friend_c',$$select (public.request_friendship('e8100000-0000-4000-8000-000000000016')).status::text$$)as t(result text)),'pending','unrelated pair remains usable while another pair is locked');
select extensions.dblink_exec('friend_a','commit');
select is(pg_temp.friend_result_code(),'42501','waiting request sees newly committed reverse block');
select is((select count(*)::integer from public.notifications where user_id in('e8100000-0000-4000-8000-000000000001','e8100000-0000-4000-8000-000000000002') and kind='friendship'),0,'denied block-first request emits no friendship notification');
select is((select count(*)::integer from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000001'),0,'blocked pair gets no pending relationship');
-- Request first: block waits, then deletes the committed pending relationship.
select extensions.dblink_exec('friend_a',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000003';begin$$);
select result from extensions.dblink('friend_a',$$select (public.request_friendship('e8100000-0000-4000-8000-000000000004')).status::text$$)as t(result text);
select extensions.dblink_exec('friend_b',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000004'$$);
select extensions.dblink_send_query('friend_b',$$select public.block_user('e8100000-0000-4000-8000-000000000003')$$);
select ok(pg_temp.wait_friend_lock(),'block waits for earlier missing-row request');
select extensions.dblink_exec('friend_a','commit');
select is(pg_temp.friend_result_code(),'ok','waiting block completes');
select is((select count(*)::integer from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000003'),0,'block removes request committed during its wait');
-- Crossed missing-row requests serialize without autoaccepting or duplicating.
select extensions.dblink_exec('friend_a',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000005';begin$$);
select result from extensions.dblink('friend_a',$$select (public.request_friendship('e8100000-0000-4000-8000-000000000006')).status::text$$)as t(result text);
select extensions.dblink_exec('friend_b',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000006'$$);
select extensions.dblink_send_query('friend_b',$$select (public.request_friendship('e8100000-0000-4000-8000-000000000005')).status::text$$);
select ok(pg_temp.wait_friend_lock(),'crossed request waits on same canonical pair');
select extensions.dblink_exec('friend_a','commit');
select is(pg_temp.friend_result_code(),'23505','waiting crossed request preserves duplicate-request behavior');
select is((select count(*)::integer from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000005'and status='pending'),1,'crossed requests leave exactly one pending row');
-- Acceptance first, then block: no accepted relationship remains after block.
select extensions.dblink_exec('friend_a',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000008';begin$$);
select result from extensions.dblink('friend_a',$$select (public.respond_to_friendship((select id from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000007'),true)).status::text$$)as t(result text);
select extensions.dblink_exec('friend_b',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000007'$$);
select extensions.dblink_send_query('friend_b',$$select public.block_user('e8100000-0000-4000-8000-000000000008')$$);
select ok(pg_temp.wait_friend_lock(),'block waits for in-flight recipient acceptance');
select extensions.dblink_exec('friend_a','commit');
select is(pg_temp.friend_result_code(),'ok','block after acceptance completes without deadlock');
select is((select count(*)::integer from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000007'),0,'accepted-before-block relationship removed');
-- Block first, then response: pair lookup never locks the row before pair lock.
select extensions.dblink_exec('friend_a',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000009';begin$$);
select result from extensions.dblink('friend_a',$$select public.block_user('e8100000-0000-4000-8000-000000000010')$$)as t(result text);
select extensions.dblink_exec('friend_b',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000010'$$);
select extensions.dblink_send_query('friend_b',$$select (public.respond_to_friendship((select id from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000009'),true)).status::text$$);
select ok(pg_temp.wait_friend_lock(),'response waits on pair before locking pending relationship');
select extensions.dblink_exec('friend_a','commit');
select is(pg_temp.friend_result_code(),'P0002','waiting response observes deleted request');
select is((select count(*)::integer from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000009'),0,'block-first response cannot leave accepted relationship');
-- Actual unblock clears latent friendship before another request can proceed.
select extensions.dblink_exec('friend_a',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000011';begin$$);
select result from extensions.dblink('friend_a',$$select public.unblock_user('e8100000-0000-4000-8000-000000000012')$$)as t(result text);
select extensions.dblink_exec('friend_b',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000012'$$);
select extensions.dblink_send_query('friend_b',$$select (public.request_friendship('e8100000-0000-4000-8000-000000000011')).status::text$$);
select ok(pg_temp.wait_friend_lock(),'new request waits for own unblock and legacy cleanup');
select extensions.dblink_exec('friend_a','commit');
select is(pg_temp.friend_result_code(),'ok','request proceeds after completed unblock');
select is((select status::text from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000011'),'pending','unblock requires new pending request rather than resurrecting acceptance');
create function pg_temp.friend_isolation_code(isolation text,command text)returns text language plpgsql as $$
declare code text:='ok';
begin
  perform extensions.dblink_exec('friend_b',format('begin isolation level %s',isolation));
  begin perform result from extensions.dblink('friend_b',command)as t(result text);
  exception when others then code:=sqlstate;end;
  perform extensions.dblink_exec('friend_b','rollback');return code;
end$$;
select extensions.dblink_exec('friend_b',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000014'$$);
select is(pg_temp.friend_isolation_code(isolation,command),'25000',name||' rejects stale-snapshot '||isolation)
from(values('repeatable read'),('serializable'))i(isolation)
cross join(values
('request',$$select (public.request_friendship('e8100000-0000-4000-8000-000000000013')).status::text$$),
('respond',$$select (public.respond_to_friendship((select id from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000013'),true)).status::text$$),
('block',$$select public.block_user('e8100000-0000-4000-8000-000000000013')$$),
('unblock',$$select public.unblock_user('e8100000-0000-4000-8000-000000000013')$$))c(name,command);
select is((select status::text from public.friend_relationships where user_low_id='e8100000-0000-4000-8000-000000000013'),'pending','rejected isolation calls change no relationship');
select is((select count(*)::integer from public.user_blocks where blocker_id in('e8100000-0000-4000-8000-000000000013','e8100000-0000-4000-8000-000000000014')),0,'rejected isolation calls create no block');
select extensions.dblink_exec('friend_b',$$set request.jwt.claim.sub='e8100000-0000-4000-8000-000000000002'$$);
select is(pg_temp.friend_isolation_code('read uncommitted',$$select (public.request_friendship('e8100000-0000-4000-8000-000000000001')).status::text$$),'42501','PostgreSQL Read Uncommitted also sees the committed reverse block');
select extensions.dblink_disconnect('friend_a');select extensions.dblink_disconnect('friend_b');select extensions.dblink_disconnect('friend_c');
select * from finish();
rollback;
delete from auth.users where id::text like 'e8100000-0000-4000-8000-%';
