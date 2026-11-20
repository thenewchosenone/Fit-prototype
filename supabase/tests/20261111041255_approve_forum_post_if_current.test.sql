create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
set search_path=public,extensions;

insert into auth.users(id,email) values
('62100000-0000-4000-8000-000000000001','review-owner@example.test'),
('62100000-0000-4000-8000-000000000002','review-moderator@example.test'),
('62100000-0000-4000-8000-000000000003','review-member@example.test'),
('62100000-0000-4000-8000-000000000004','review-admin@example.test');
-- Seed authority at INSERT; the profile UPDATE guard intentionally preserves old.role.
delete from public.profiles where id='62100000-0000-4000-8000-000000000004';
insert into public.profiles(id,display_name,username,handle,role) values('62100000-0000-4000-8000-000000000004','Review administrator','review_admin_fixture','@review_admin_fixture','Admin');
insert into public.forum_memberships(community_id,user_id,role,status) values
('f1000000-0000-0000-0000-000000000001','62100000-0000-4000-8000-000000000001','Member','Joined'),
('f1000000-0000-0000-0000-000000000001','62100000-0000-4000-8000-000000000002','Moderator','Joined'),
('f1000000-0000-0000-0000-000000000001','62100000-0000-4000-8000-000000000003','Member','Joined');
insert into public.forum_posts(id,community_id,author_id,kind,title,body,link_url)
select ('62100000-0000-4000-8000-0000000000'||suffix)::uuid,
       'f1000000-0000-0000-0000-000000000001','62100000-0000-4000-8000-000000000001',
       'Discussion','Review fixture','Original content','https://example.test/review'
from unnest(array['10','11','12','13','14','15','16','17','18','19']) as suffix;
insert into public.gyms(id,name,status) values('62100000-0000-4000-8000-000000000099','Review fixture gym','active');
insert into public.forum_posts(id,gym_id,author_id,kind,title,body)
values('62100000-0000-4000-8000-000000000020','62100000-0000-4000-8000-000000000099',
       '62100000-0000-4000-8000-000000000001','Discussion','Gym review','Original gym content');
update public.forum_posts set removed_at=now() where id='62100000-0000-4000-8000-000000000011';

create function pg_temp.review_snapshot(target uuid) returns jsonb language sql as $$
  select jsonb_build_object(
    'author_id',p.author_id,'community_id',p.community_id,'gym_id',p.gym_id,
    'kind',p.kind,'title',p.title,'body',p.body,'tag',p.tag,'attachments',p.attachments,
    'poll',p.poll,'link_url',p.link_url,'lift_id',p.lift_id,'workout_id',p.workout_id,
    'review_pending',(to_jsonb(p)->>'media_reviewed_at') is null
  ) from public.forum_posts p where id=target;
$$;
create function pg_temp.review_sql(target uuid,snapshot jsonb) returns text language sql as $$
  select format('select public.approve_forum_post_if_current(%L,%L::jsonb,%L)',target,snapshot,'Runtime review fixture');
$$;
create temp table review_snapshots as select id,pg_temp.review_snapshot(id) as snapshot from public.forum_posts
where id::text like '62100000-%';
grant select on review_snapshots to authenticated;

select no_plan();
select ok((select prosecdef and proconfig @> array['search_path=pg_catalog'] from pg_proc where oid='public.approve_forum_post_if_current(uuid,jsonb,text)'::regprocedure),'approval has fixed privileged search path');
select ok(has_function_privilege('authenticated','public.approve_forum_post_if_current(uuid,jsonb,text)','EXECUTE'),'authenticated can reach guarded approval');
select ok(not has_function_privilege(role_name,'public.approve_forum_post_if_current(uuid,jsonb,text)','EXECUTE'),role_name||' cannot execute approval') from unnest(array['anon','service_role']) role_name;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000010',(select snapshot from review_snapshots where id='62100000-0000-4000-8000-000000000010')),'42501',null,'missing JWT denied');
select set_config('request.jwt.claim.sub','62100000-0000-4000-8000-000000000001',true);
select throws_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000010',(select snapshot from review_snapshots where id='62100000-0000-4000-8000-000000000010')),'42501',null,'author cannot approve own discussion');
select set_config('request.jwt.claim.sub','62100000-0000-4000-8000-000000000003',true);
select throws_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000010',(select snapshot from review_snapshots where id='62100000-0000-4000-8000-000000000010')),'42501',null,'ordinary member cannot approve');
select set_config('request.jwt.claim.sub','62100000-0000-4000-8000-000000000002',true);
select throws_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000011',(select snapshot from review_snapshots where id='62100000-0000-4000-8000-000000000011')),'42501',null,'removed discussion cannot be restored through approval');
select throws_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000020',(select snapshot from review_snapshots where id='62100000-0000-4000-8000-000000000020')),'42501',null,'community reviewer cannot approve gym discussion');
select throws_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000098','{}'),'42501',null,'missing discussion denied');
select throws_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000010',null),'40001',null,'missing snapshot denied');
select throws_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000010',snapshot||jsonb_build_object(key,'changed')), '40001',null,'stale '||key||' rejected')
from review_snapshots cross join unnest(array['author_id','community_id','gym_id','kind','title','body','tag','attachments','poll','link_url','lift_id','workout_id','review_pending']) key
where id='62100000-0000-4000-8000-000000000010';
select lives_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000010',(select snapshot from review_snapshots where id='62100000-0000-4000-8000-000000000010')),'reviewer approves matching active snapshot');
select set_config('request.jwt.claim.sub','62100000-0000-4000-8000-000000000004',true);
select lives_ok(pg_temp.review_sql('62100000-0000-4000-8000-000000000020',(select snapshot from review_snapshots where id='62100000-0000-4000-8000-000000000020')),'global administrator approves gym snapshot');
rollback;

select is((select count(*)::integer from public.forum_moderation_actions where target_id::text like '62100000-%'),0,'rejected and rolled-back approval leaves no audit records');

create function pg_temp.review_race(operation text,post_id uuid,approval_first boolean default false)
returns boolean language plpgsql as $$
declare
  connection text:=format('host=%L port=%s dbname=%L',trim(split_part(current_setting('unix_socket_directories'),',',1)),current_setting('port'),current_database());
  snapshot jsonb:=pg_temp.review_snapshot(post_id);
  approval_sql text:=pg_temp.review_sql(post_id,snapshot);
  writer_sql text;
  holder text:=case when approval_first then 'approval_reviewer' else 'approval_writer' end;
  waiter text:=case when approval_first then 'approval_writer' else 'approval_reviewer' end;
  holder_pid integer;waiter_pid integer;deadline timestamptz;result_state text:='00000';
begin
  writer_sql:=case operation when 'edit' then format('update public.forum_posts set body=%L where id=%L returning id','Changed after review',post_id)
    when 'remove' then format('select public.delete_own_forum_post(%L)',post_id)
    when 'revoke' then format('select id from public.forum_posts where id=%L for update',post_id) end;
  perform extensions.dblink_connect('approval_writer',connection);
  perform extensions.dblink_connect('approval_reviewer',connection);
  perform extensions.dblink_exec('approval_writer',format('set role authenticated;set request.jwt.claim.sub=%L;set statement_timeout=%L','62100000-0000-4000-8000-000000000001','6s'));
  perform extensions.dblink_exec('approval_reviewer',format('set role authenticated;set request.jwt.claim.sub=%L;set statement_timeout=%L','62100000-0000-4000-8000-000000000002','6s'));
  select pid into holder_pid from extensions.dblink(holder,'select pg_backend_pid()') response(pid integer);
  select pid into waiter_pid from extensions.dblink(waiter,'select pg_backend_pid()') response(pid integer);
  perform extensions.dblink_exec(holder,'begin isolation level read committed');
  perform value from extensions.dblink(holder,case when approval_first then approval_sql else writer_sql end) response(value text);
  perform extensions.dblink_send_query(waiter,case when approval_first then writer_sql else approval_sql end);
  deadline:=clock_timestamp()+interval '4 seconds';
  while not holder_pid=any(pg_blocking_pids(waiter_pid)) loop
    if clock_timestamp()>deadline or extensions.dblink_is_busy(waiter)=0 then raise exception 'Approval operation did not wait for the competing writer';end if;
    perform pg_sleep(.02);
  end loop;
  if operation='revoke' then
    perform extensions.dblink_connect('approval_revoker',connection);
    perform extensions.dblink_exec('approval_revoker',
      'update public.forum_memberships set status=''Left'' where community_id=''f1000000-0000-0000-0000-000000000001'' and user_id=''62100000-0000-4000-8000-000000000002''');
    perform extensions.dblink_disconnect('approval_revoker');
  end if;
  perform extensions.dblink_exec(holder,'commit');
  begin perform value from extensions.dblink_get_result(waiter) response(value text);exception when others then result_state:=sqlstate;end;
  perform extensions.dblink_disconnect(holder);perform extensions.dblink_disconnect(waiter);
  if operation='revoke' then
    update public.forum_memberships set status='Joined' where community_id='f1000000-0000-0000-0000-000000000001' and user_id='62100000-0000-4000-8000-000000000002';
  end if;
  if approval_first then
    return result_state='00000' and (select count(*)=1 from public.forum_moderation_actions where target_id=post_id)
      and case when operation='remove' then (select removed_at is not null from public.forum_posts where id=post_id)
        else (select body='Changed after review' and (to_jsonb(p)->>'media_reviewed_at') is null from public.forum_posts p where id=post_id) end;
  end if;
  return result_state=case when operation='edit' then '40001' else '42501' end
    and not exists(select from public.forum_moderation_actions where target_id=post_id)
    and (select case when operation='remove' then removed_at is not null else removed_at is null end from public.forum_posts where id=post_id);
end;
$$;

select ok(pg_temp.review_race('edit','62100000-0000-4000-8000-000000000012'),'edit commits before waiting approval: reject changed content');
select ok(pg_temp.review_race('edit','62100000-0000-4000-8000-000000000013',true),'approval wins before edit: edit still resets review');
select ok(pg_temp.review_race('remove','62100000-0000-4000-8000-000000000014'),'removal commits before waiting approval: no resurrection');
select ok(pg_temp.review_race('remove','62100000-0000-4000-8000-000000000015',true),'approval wins before removal: removal remains effective');
select ok(pg_temp.review_race('revoke','62100000-0000-4000-8000-000000000016'),'reviewer revoked while waiting is denied');
select * from finish();
reset search_path;
