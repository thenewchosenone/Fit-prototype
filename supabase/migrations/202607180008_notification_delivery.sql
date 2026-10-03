alter table public.notifications add column push_sent_at timestamptz;

create or replace function public.notify_message_recipient()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.notifications(user_id,title,body,kind,destination)
  select member.user_id,'New message',left(new.body,160),'message',
    jsonb_build_object('kind','messageThread','targetID',new.thread_id)
  from public.message_thread_members member
  where member.thread_id=new.thread_id and member.user_id<>new.sender_id
    and not public.is_blocked_pair(member.user_id,new.sender_id);
  return new;
end;$$;

create trigger message_notification after insert on public.messages
for each row execute function public.notify_message_recipient();

create or replace function public.notify_forum_reply()
returns trigger language plpgsql security definer set search_path=public as $$
declare recipient uuid; post_title text;
begin
  select coalesce(parent.author_id,post.author_id),post.title into recipient,post_title
  from public.forum_posts post
  left join public.forum_comments parent on parent.id=new.parent_comment_id
  where post.id=new.post_id;
  if recipient is not null and recipient<>new.author_id and not public.is_blocked_pair(recipient,new.author_id) then
    insert into public.notifications(user_id,title,body,kind,destination)
    values(recipient,'New reply',left(coalesce(post_title,'Community discussion'),160),'forum_reply',
      jsonb_build_object('kind','forumPost','targetID',new.post_id));
  end if;
  return new;
end;$$;

create trigger forum_reply_notification after insert on public.forum_comments
for each row execute function public.notify_forum_reply();

create or replace function public.notify_friendship_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare recipient uuid; notification_title text;
begin
  if tg_op='INSERT' and new.status='pending' then
    recipient:=case when new.requested_by=new.user_low_id then new.user_high_id else new.user_low_id end;
    notification_title:='New friend request';
  elsif tg_op='UPDATE' and old.status is distinct from new.status and new.status='accepted' then
    recipient:=new.requested_by;
    notification_title:='Friend request accepted';
  else return new;
  end if;
  if not public.is_blocked_pair(recipient,new.requested_by) then
    insert into public.notifications(user_id,title,body,kind,destination)
    values(recipient,notification_title,'Open LiftRank to view the update.','friendship',
      jsonb_build_object('kind','friendRequests'));
  end if;
  return new;
end;$$;

create trigger friendship_notification after insert or update of status on public.friend_relationships
for each row execute function public.notify_friendship_change();

create or replace function public.notify_lift_moderation()
returns trigger language plpgsql security definer set search_path=public as $$
declare recipient uuid; notification_title text;
begin
  select user_id into recipient from public.lift_submissions where id=new.lift_id;
  notification_title:=case
    when new.resulting_status='under_review' then 'Lift under review'
    when new.resulting_status='replacement_requested' then 'Replacement video requested'
    when new.resulting_status='rejected' then 'Lift review completed'
    else 'Lift review cleared' end;
  insert into public.notifications(user_id,title,body,kind,destination)
  values(recipient,notification_title,left(coalesce(nullif(new.note,''),'Open the lift for details.'),160),'lift_moderation',
    jsonb_build_object('kind','lift','targetID',new.lift_id));
  return new;
end;$$;

create trigger lift_moderation_notification after insert on public.lift_moderation_audit
for each row execute function public.notify_lift_moderation();

revoke all on function public.notify_message_recipient() from public;
revoke all on function public.notify_forum_reply() from public;
revoke all on function public.notify_friendship_change() from public;
revoke all on function public.notify_lift_moderation() from public;

