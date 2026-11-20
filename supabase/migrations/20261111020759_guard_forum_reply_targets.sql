-- A reply and a removal or lock on either target must have a definite order.
create schema if not exists private;

create function private.guard_forum_reply_targets()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  actor uuid := auth.uid();
  api_caller boolean := pg_catalog.current_setting('role', true) in ('anon', 'authenticated')
    or session_user in ('anon', 'authenticated');
begin
  -- The outer role survives SECURITY DEFINER. Preserve trusted maintenance
  -- inserts without a JWT, while checking API callers before taking row locks.
  if api_caller
     and (actor is null or new.author_id is distinct from actor
          or not public.can_view_forum_post(new.post_id)) then
    raise exception using errcode = '42501', message = 'Reply target is unavailable';
  end if;

  -- SHARE permits simultaneous replies and conflicts with non-key updates.
  -- Lock the post before the parent, with the live predicates in the queries
  -- so READ COMMITTED rechecks them after a competing writer commits.
  perform 1
  from public.forum_posts as post
  where post.id = new.post_id
    and post.removed_at is null
    and not post.is_locked
  for share;
  if not found then
    raise exception using errcode = '42501', message = 'Reply target is unavailable';
  end if;

  if new.parent_comment_id is not null then
    perform 1
    from public.forum_comments as parent
    where parent.id = new.parent_comment_id
      and parent.post_id = new.post_id
      and parent.removed_at is null
    for share;
    if not found then
      raise exception using errcode = '42501', message = 'Reply target is unavailable';
    end if;
  end if;

  -- An edit can reset attachment approval while the post lock is pending.
  -- Check visibility again in a fresh statement after the target locks.
  if api_caller and not public.can_view_forum_post(new.post_id) then
    raise exception using errcode = '42501', message = 'Reply target is unavailable';
  end if;

  return new;
end;
$$;

revoke all on function private.guard_forum_reply_targets() from public, anon, authenticated, service_role;

create trigger forum_comment_reply_target_guard
before insert on public.forum_comments
for each row execute function private.guard_forum_reply_targets();
