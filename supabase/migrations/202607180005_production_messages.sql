create table public.message_reads (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key(message_id,user_id)
);
create table public.message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check(reason in ('Spam','Offensive','Harassment','Other')),
  note text not null default '' check(char_length(note)<=1000),
  created_at timestamptz not null default now(),
  unique(message_id,reporter_id)
);
create table public.hidden_message_threads (
  thread_id uuid not null references public.message_threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  hidden_at timestamptz not null default now(),
  primary key(thread_id,user_id)
);
alter table public.message_reads enable row level security;
alter table public.message_reports enable row level security;
alter table public.hidden_message_threads enable row level security;
create policy "message reads owner" on public.message_reads for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "message reports owner insert" on public.message_reports for insert to authenticated with check(reporter_id=auth.uid());
create policy "message reports owner read" on public.message_reports for select to authenticated using(reporter_id=auth.uid() or public.is_admin());
create policy "hidden threads owner" on public.hidden_message_threads for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

create or replace function public.get_message_threads()
returns table(id uuid,participant_ids uuid[],created_at timestamptz,updated_at timestamptz)
language sql stable security definer set search_path=public as $$
  select t.id,array_agg(m.user_id order by m.user_id),t.created_at,t.updated_at
  from public.message_threads t join public.message_thread_members m on m.thread_id=t.id
  where public.is_thread_member(t.id)
    and not exists(select 1 from public.hidden_message_threads h where h.thread_id=t.id and h.user_id=auth.uid())
    and not exists(
      select 1 from public.message_thread_members other
      where other.thread_id=t.id and other.user_id<>auth.uid()
        and exists(select 1 from public.user_blocks b where b.blocked_id=auth.uid() and b.blocker_id=other.user_id)
    )
  group by t.id order by t.updated_at desc;
$$;

create or replace function public.create_or_get_message_thread(target_user_id uuid)
returns table(id uuid,participant_ids uuid[],created_at timestamptz,updated_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare found_id uuid;
begin
  if target_user_id=auth.uid() or public.is_blocked_pair(target_user_id,auth.uid()) then raise exception 'Messaging unavailable';end if;
  if not public.are_friends(target_user_id,auth.uid()) then raise exception 'Messaging requires an accepted friendship';end if;
  select t.id into found_id from public.message_threads t where
    exists(select 1 from public.message_thread_members a where a.thread_id=t.id and a.user_id=auth.uid()) and
    exists(select 1 from public.message_thread_members b where b.thread_id=t.id and b.user_id=target_user_id) and
    (select count(*) from public.message_thread_members c where c.thread_id=t.id)=2 limit 1;
  if found_id is null then insert into public.message_threads default values returning message_threads.id into found_id;
    insert into public.message_thread_members(thread_id,user_id) values(found_id,auth.uid()),(found_id,target_user_id);end if;
  delete from public.hidden_message_threads h where h.thread_id=found_id and h.user_id=auth.uid();
  return query select t.id,array[auth.uid(),target_user_id],t.created_at,t.updated_at from public.message_threads t where t.id=found_id;
end;$$;

create or replace function public.get_thread_messages(target_thread_id uuid)
returns table(id uuid,thread_id uuid,sender_id uuid,body text,created_at timestamptz,is_read boolean,is_reported boolean)
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_thread_member(target_thread_id) then raise exception 'Thread membership required'; end if;
  if exists(
    select 1 from public.message_thread_members other
    join public.user_blocks b on b.blocker_id=other.user_id and b.blocked_id=auth.uid()
    where other.thread_id=target_thread_id and other.user_id<>auth.uid()
  ) then raise exception 'Thread unavailable'; end if;
  return query select m.id,m.thread_id,m.sender_id,m.body,m.created_at,
    exists(select 1 from public.message_reads r where r.message_id=m.id and r.user_id=auth.uid()),
    exists(select 1 from public.message_reports r where r.message_id=m.id and r.reporter_id=auth.uid())
  from public.messages m where m.thread_id=target_thread_id and m.deleted_at is null order by m.created_at;
end;
$$;

create or replace function public.send_message(target_thread_id uuid,message_body text)
returns table(id uuid,thread_id uuid,sender_id uuid,body text,created_at timestamptz,is_read boolean,is_reported boolean)
language plpgsql security definer set search_path=public as $$
declare created public.messages;
begin
  if not public.is_thread_member(target_thread_id) then raise exception 'Thread membership required'; end if;
  if char_length(btrim(message_body)) not between 1 and 5000 then raise exception 'Message must contain 1-5000 characters'; end if;
  if exists(
    select 1 from public.message_thread_members other
    where other.thread_id=target_thread_id and other.user_id<>auth.uid() and public.is_blocked_pair(other.user_id,auth.uid())
  ) then raise exception 'Messaging is blocked'; end if;
  insert into public.messages(thread_id,sender_id,body) values(target_thread_id,auth.uid(),btrim(message_body)) returning * into created;
  update public.message_threads set updated_at=statement_timestamp() where message_threads.id=target_thread_id;
  delete from public.hidden_message_threads h where h.thread_id=target_thread_id and h.user_id=auth.uid();
  return query select created.id,created.thread_id,created.sender_id,created.body,created.created_at,false,false;
end;
$$;

create or replace function public.delete_message(target_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin update public.messages set deleted_at=statement_timestamp() where id=target_id and sender_id=auth.uid();
if not found then raise exception 'Only the sender may delete a message'; end if; end;
$$;
create or replace function public.hide_message_thread(target_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin if not public.is_thread_member(target_id) then raise exception 'Thread membership required'; end if;
insert into public.hidden_message_threads(thread_id,user_id) values(target_id,auth.uid()) on conflict do update set hidden_at=statement_timestamp(); end;
$$;
create or replace function public.report_message(target_message_id uuid,report_reason text,report_note text default '')
returns void language plpgsql security definer set search_path=public as $$
begin if not exists(select 1 from public.messages m where m.id=target_message_id and public.is_thread_member(m.thread_id)) then raise exception 'Message unavailable'; end if;
insert into public.message_reports(message_id,reporter_id,reason,note) values(target_message_id,auth.uid(),report_reason,left(coalesce(report_note,''),1000)) on conflict(message_id,reporter_id) do nothing; end;
$$;

revoke all on function public.get_message_threads() from public;
revoke all on function public.create_or_get_message_thread(uuid) from public;
revoke all on function public.get_thread_messages(uuid) from public;
revoke all on function public.send_message(uuid,text) from public;
revoke all on function public.delete_message(uuid) from public;
revoke all on function public.hide_message_thread(uuid) from public;
revoke all on function public.report_message(uuid,text,text) from public;
grant execute on function public.get_message_threads() to authenticated;
grant execute on function public.create_or_get_message_thread(uuid) to authenticated;
grant execute on function public.get_thread_messages(uuid) to authenticated;
grant execute on function public.send_message(uuid,text) to authenticated;
grant execute on function public.delete_message(uuid) to authenticated;
grant execute on function public.hide_message_thread(uuid) to authenticated;
grant execute on function public.report_message(uuid,text,text) to authenticated;
