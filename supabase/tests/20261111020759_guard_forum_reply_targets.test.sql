create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
set search_path = public, extensions;

-- These fixtures are committed so the dblink sessions can race on the same rows.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('61100000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-target-owner@example.test', '', '{}', '{}', now(), now()),
  ('61100000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-target-replier@example.test', '', '{}', '{}', now(), now());

insert into public.forum_memberships (community_id, user_id, role, status)
values
  ('f1000000-0000-0000-0000-000000000001', '61100000-0000-0000-0000-000000000001', 'Moderator', 'Joined'),
  ('f1000000-0000-0000-0000-000000000001', '61100000-0000-0000-0000-000000000002', 'Member', 'Joined');

insert into public.forum_posts (id, community_id, author_id, kind, title, body)
select ('61100000-0000-0000-0000-0000000000' || suffix)::uuid,
       'f1000000-0000-0000-0000-000000000001', '61100000-0000-0000-0000-000000000001',
       'Discussion', 'Reply target', 'Fixture discussion'
from unnest(array['10','11','12','13','14','15','16','17','18']) as suffix;

insert into public.gyms (id,name,status)
values ('61100000-0000-0000-0000-000000000098','Fixture private gym','active');
insert into public.forum_posts (id, gym_id, author_id, kind, title, body)
values ('61100000-0000-0000-0000-000000000099','61100000-0000-0000-0000-000000000098',
        '61100000-0000-0000-0000-000000000001','Discussion','Hidden target','Fixture discussion');

insert into public.forum_comments (id, post_id, author_id, body)
values
  ('61100000-0000-0000-0000-000000000020','61100000-0000-0000-0000-000000000014','61100000-0000-0000-0000-000000000001','Parent'),
  ('61100000-0000-0000-0000-000000000021','61100000-0000-0000-0000-000000000015','61100000-0000-0000-0000-000000000001','Parent'),
  ('61100000-0000-0000-0000-000000000022','61100000-0000-0000-0000-000000000016','61100000-0000-0000-0000-000000000001','Parent'),
  ('61100000-0000-0000-0000-000000000023','61100000-0000-0000-0000-000000000018','61100000-0000-0000-0000-000000000001','Parent');

-- Production and the newer app schema have the media-screening migration.
do $$
begin
  if exists (select from pg_attribute where attrelid='public.forum_posts'::regclass and attname='media_reviewed_at' and not attisdropped) then
    insert into public.forum_posts (id, community_id, author_id, kind, title, body, link_url)
    values
      ('61100000-0000-0000-0000-000000000030','f1000000-0000-0000-0000-000000000001','61100000-0000-0000-0000-000000000001',
       'Discussion','Reviewed thread','Fixture with an approved link','https://example.test/reviewed'),
      ('61100000-0000-0000-0000-000000000031','f1000000-0000-0000-0000-000000000001','61100000-0000-0000-0000-000000000001',
       'Discussion','Reviewed thread','Fixture with an approved link','https://example.test/reviewed');
    update public.forum_posts set media_reviewed_at=now()
    where id in ('61100000-0000-0000-0000-000000000030','61100000-0000-0000-0000-000000000031');
  end if;
end;
$$;

update public.forum_comments set removed_at=now() where id='61100000-0000-0000-0000-000000000022';
update public.forum_posts set removed_at=now() where id='61100000-0000-0000-0000-000000000017';

select no_plan();
select ok(
  exists (select from pg_proc
    where oid='private.guard_forum_reply_targets()'::regprocedure and prosecdef and proconfig @> array['search_path=pg_catalog']),
  'guard is privileged only inside a fixed search path'
);
select ok(
  not exists (
    select from unnest(array['anon','authenticated','service_role']) as role_name
    where has_function_privilege(role_name,'private.guard_forum_reply_targets()','EXECUTE')
      or has_schema_privilege(role_name,'private','USAGE')
  ),
  'API roles cannot invoke the private guard'
);

create function pg_temp.forum_reply_sql(post_id uuid, author_id uuid, parent_id uuid, reply_id uuid)
returns text language sql as $$
  select format(
    'insert into public.forum_comments(id,post_id,author_id,parent_comment_id,body) values (%L,%L,%L,%L,%L) returning id',
    reply_id,post_id,author_id,parent_id,'Fixture reply'
  );
$$;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000010','61100000-0000-0000-0000-000000000002',null,gen_random_uuid()),
  '42501','Reply target is unavailable','authenticated role without a JWT is denied'
);
select set_config('request.jwt.claim.sub','61100000-0000-0000-0000-000000000002',true);
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000010','61100000-0000-0000-0000-000000000001',null,gen_random_uuid()),
  '42501','Reply target is unavailable','forged author is denied'
);
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000099','61100000-0000-0000-0000-000000000002',null,gen_random_uuid()),
  '42501','Reply target is unavailable','hidden discussion uses the same denial as a missing discussion'
);
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000097','61100000-0000-0000-0000-000000000002',null,gen_random_uuid()),
  '42501','Reply target is unavailable','missing discussion is denied'
);
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000010','61100000-0000-0000-0000-000000000002','61100000-0000-0000-0000-000000000020',gen_random_uuid()),
  'P0001','Reply parent must belong to the same discussion','original cross-discussion guard still applies'
);
select set_config('request.jwt.claim.sub','61100000-0000-0000-0000-000000000001',true);
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000016','61100000-0000-0000-0000-000000000001','61100000-0000-0000-0000-000000000022',gen_random_uuid()),
  '42501','Reply target is unavailable','authors cannot reply to their own removed parents'
);
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000017','61100000-0000-0000-0000-000000000001',null,gen_random_uuid()),
  '42501','Reply target is unavailable','authors cannot reply to their own removed discussions'
);
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role service_role;
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000010','61100000-0000-0000-0000-000000000002',null,gen_random_uuid()),
  '42501','permission denied for table forum_comments','service role gains no direct comment insert privilege'
);
reset role;
select lives_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000010','61100000-0000-0000-0000-000000000002',null,gen_random_uuid()),
  'trusted postgres inserts with no JWT still work on an active discussion'
);
select throws_ok(
  pg_temp.forum_reply_sql('61100000-0000-0000-0000-000000000017','61100000-0000-0000-0000-000000000002',null,gen_random_uuid()),
  '42501','Reply target is unavailable','trusted inserts still require active targets'
);
rollback;

-- Use independent READ COMMITTED transactions and observe the actual blocker
-- before releasing the first writer. Each case uses a separate discussion.
create function pg_temp.forum_race(operation text, writer_first boolean, post_id uuid, parent_id uuid)
returns boolean language plpgsql as $$
declare
  connection text := format('host=%L port=%s dbname=%L',trim(split_part(current_setting('unix_socket_directories'),',',1)),current_setting('port'),current_database());
  owner_id constant uuid := '61100000-0000-0000-0000-000000000001';
  replier_id constant uuid := '61100000-0000-0000-0000-000000000002';
  reply_id uuid := gen_random_uuid();
  reply_sql text := pg_temp.forum_reply_sql(post_id,replier_id,parent_id,reply_id);
  writer_sql text;
  second_reply_id uuid := gen_random_uuid();
  waiter text;
  holder text;
  waiter_pid integer;
  holder_pid integer;
  deadline timestamptz;
  result_state text := '00000';
  reply_saved boolean;
  notification_count integer;
begin
  writer_sql := case operation
    when 'post removal' then format('select public.delete_own_forum_post(%L)',post_id)
    when 'parent removal' then format('select public.delete_own_forum_comment(%L)',parent_id)
    when 'parallel replies' then pg_temp.forum_reply_sql(post_id,owner_id,parent_id,second_reply_id)
    when 'edit pending review' then format('update public.forum_posts set body=%L where id=%L returning id','Edited while approved',post_id)
    when 'lock' then format('select public.moderate_forum_post(%L,%L,%L)',post_id,'Locked','Concurrency fixture')
  end;

  perform extensions.dblink_connect('forum_writer',connection);
  perform extensions.dblink_connect('forum_replier',connection);
  perform extensions.dblink_exec('forum_writer',format('set role authenticated; set request.jwt.claim.sub=%L; set statement_timeout=%L',owner_id,'6s'));
  perform extensions.dblink_exec('forum_replier',format('set role authenticated; set request.jwt.claim.sub=%L; set statement_timeout=%L',replier_id,'6s'));

  holder := case when writer_first then 'forum_writer' else 'forum_replier' end;
  waiter := case when writer_first then 'forum_replier' else 'forum_writer' end;
  select pid into holder_pid from extensions.dblink(holder,'select pg_backend_pid()') as pid(pid integer);
  select pid into waiter_pid from extensions.dblink(waiter,'select pg_backend_pid()') as pid(pid integer);
  perform extensions.dblink_exec(holder,'begin isolation level read committed');
  perform value from extensions.dblink(holder,case when writer_first then writer_sql else reply_sql end) as response(value text);

  if operation = 'parallel replies' then
    -- The second sibling must commit while the first still holds both locks.
    perform value from extensions.dblink(waiter,writer_sql) as response(value text);
    perform extensions.dblink_exec(holder,'commit');
    perform extensions.dblink_disconnect(holder);
    perform extensions.dblink_disconnect(waiter);
    return (select count(*)=2 from public.forum_comments c where c.id in (reply_id,second_reply_id));
  end if;

  if extensions.dblink_send_query(waiter,case when writer_first then reply_sql else writer_sql end) <> 1 then
    raise exception 'Could not dispatch concurrent Forum test';
  end if;
  deadline := clock_timestamp() + interval '4 seconds';
  while not (holder_pid = any(pg_blocking_pids(waiter_pid))) loop
    if clock_timestamp() > deadline or extensions.dblink_is_busy(waiter) = 0 then
      raise exception 'Concurrent Forum operation did not wait for its target';
    end if;
    perform pg_sleep(0.02);
  end loop;

  perform extensions.dblink_exec(holder,'commit');
  begin
    perform value from extensions.dblink_get_result(waiter) as response(value text);
  exception when others then
    result_state := sqlstate;
  end;
  perform extensions.dblink_disconnect(holder);
  perform extensions.dblink_disconnect(waiter);

  select exists(select from public.forum_comments c where c.id=reply_id and c.parent_comment_id is not distinct from parent_id) into reply_saved;
  select count(*) from public.notifications n
  where n.kind='forum_reply' and n.user_id=owner_id and n.destination->>'commentID'=reply_id::text
  into notification_count;
  return case when writer_first then result_state='42501' and not reply_saved and notification_count=0
              else result_state='00000' and reply_saved and notification_count=1 end;
end;
$$;

select ok(pg_temp.forum_race('post removal',true,'61100000-0000-0000-0000-000000000010',null),
          'post removal wins before reply, with no row or notification');
select ok(pg_temp.forum_race('post removal',false,'61100000-0000-0000-0000-000000000011',null),
          'reply wins before post removal and sends one notification');
select ok(pg_temp.forum_race('lock',true,'61100000-0000-0000-0000-000000000012',null),
          'moderator lock wins before reply, with no row or notification');
select ok(pg_temp.forum_race('lock',false,'61100000-0000-0000-0000-000000000013',null),
          'reply wins before moderator lock and sends one notification');
select ok(pg_temp.forum_race('parent removal',true,'61100000-0000-0000-0000-000000000014','61100000-0000-0000-0000-000000000020'),
          'parent removal wins before reply, with no row or notification');
select ok(pg_temp.forum_race('parent removal',false,'61100000-0000-0000-0000-000000000015','61100000-0000-0000-0000-000000000021'),
          'reply wins before parent removal and sends one notification');

select ok(pg_temp.forum_race('parallel replies',false,'61100000-0000-0000-0000-000000000018','61100000-0000-0000-0000-000000000023'),
          'simultaneous siblings can share the same active post and parent locks');

select ok(pg_temp.forum_race('edit pending review',true,'61100000-0000-0000-0000-000000000030',null),
          'attachment re-screening hides the discussion before reply, with no row or notification')
where exists (select from pg_attribute where attrelid='public.forum_posts'::regclass and attname='media_reviewed_at' and not attisdropped);
select ok(pg_temp.forum_race('edit pending review',false,'61100000-0000-0000-0000-000000000031',null),
          'reply wins before attachment re-screening and sends one notification')
where exists (select from pg_attribute where attrelid='public.forum_posts'::regclass and attname='media_reviewed_at' and not attisdropped);

select * from finish();
reset search_path;
