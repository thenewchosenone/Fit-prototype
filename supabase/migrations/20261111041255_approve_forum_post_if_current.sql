-- Approve the active discussion that was actually reviewed, without restoring it.
create function public.approve_forum_post_if_current(
  target_post_id uuid,
  expected_snapshot jsonb,
  reason text default ''
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  community uuid;
  reviewed_post public.forum_posts%rowtype;
  snapshot jsonb;
begin
  if auth.uid() is null then
    raise exception using errcode='42501',message='Moderator permission required';
  end if;
  select post.community_id into community
  from public.forum_posts as post
  where post.id=target_post_id and post.removed_at is null;
  if not found or not (public.is_admin() or public.can_moderate_forum_community(community)) then
    raise exception using errcode='42501',message='Discussion review is unavailable';
  end if;

  select post.* into reviewed_post
  from public.forum_posts as post
  where post.id=target_post_id and post.removed_at is null
  for update;
  if not found or not (public.is_admin() or public.can_moderate_forum_community(reviewed_post.community_id)) then
    raise exception using errcode='42501',message='Discussion review is unavailable';
  end if;

  snapshot=pg_catalog.jsonb_build_object(
    'author_id',reviewed_post.author_id,'community_id',reviewed_post.community_id,'gym_id',reviewed_post.gym_id,
    'kind',reviewed_post.kind,'title',reviewed_post.title,'body',reviewed_post.body,'tag',reviewed_post.tag,
    'attachments',reviewed_post.attachments,'poll',reviewed_post.poll,'link_url',reviewed_post.link_url,
    'lift_id',reviewed_post.lift_id,'workout_id',reviewed_post.workout_id,
    'review_pending',(pg_catalog.to_jsonb(reviewed_post)->>'media_reviewed_at') is null
  );
  if expected_snapshot is distinct from snapshot then
    raise exception using errcode='40001',message='This discussion changed. Reload it and review the current content before approving.';
  end if;
  perform public.moderate_forum_post(target_post_id,'Restored',reason);
end;
$$;

revoke all on function public.approve_forum_post_if_current(uuid,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.approve_forum_post_if_current(uuid,jsonb,text) to authenticated;
