-- Forward-only correction for deployed forum notification functions.
-- This migration is source-only until the production migration workflow is approved.
create or replace function public.notify_forum_reply()
returns trigger language plpgsql security definer set search_path=pg_catalog, public as $$
declare recipient uuid; post_title text;
begin
  select coalesce(parent.author_id,post.author_id),post.title into recipient,post_title
  from public.forum_posts post
  left join public.forum_comments parent on parent.id=new.parent_comment_id
  where post.id=new.post_id;
  if recipient is not null and recipient<>new.author_id and not public.is_blocked_pair(recipient,new.author_id) then
    insert into public.notifications(user_id,title,body,kind,destination)
    values(recipient,'New reply',left(coalesce(post_title,'Community discussion'),160),'forum_reply',
      jsonb_build_object('kind','forumPost','targetID',new.post_id,'commentID',new.id));
  end if;
  return new;
end;$$;

revoke all on function public.notify_forum_reply() from public;
