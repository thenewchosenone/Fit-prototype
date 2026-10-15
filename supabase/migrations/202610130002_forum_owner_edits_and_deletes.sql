-- Let authors correct their own forum content. Deletion is a server-timestamped
-- soft delete so replies and moderation context remain intact.
grant update (title, body) on public.forum_posts to authenticated;
grant update (body) on public.forum_comments to authenticated;

drop policy if exists "forum posts author update" on public.forum_posts;
create policy "forum posts author update"
on public.forum_posts for update to authenticated
using (author_id = auth.uid() and removed_at is null and public.can_view_forum_post(id))
with check (author_id = auth.uid() and removed_at is null and public.can_view_forum_post(id));

drop policy if exists "forum comments author update" on public.forum_comments;
create policy "forum comments author update"
on public.forum_comments for update to authenticated
using (author_id = auth.uid() and removed_at is null and public.can_view_forum_post(post_id))
with check (author_id = auth.uid() and removed_at is null and public.can_view_forum_post(post_id));

create or replace function public.delete_own_forum_post(target_post_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.forum_posts
  set removed_at = pg_catalog.clock_timestamp()
  where id = target_post_id
    and author_id = auth.uid()
    and removed_at is null;

  if not found then
    raise exception using errcode = '42501', message = 'Post not found or not owned by this account';
  end if;
end;
$$;

create or replace function public.delete_own_forum_comment(target_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.forum_comments
  set removed_at = pg_catalog.clock_timestamp()
  where id = target_comment_id
    and author_id = auth.uid()
    and removed_at is null;

  if not found then
    raise exception using errcode = '42501', message = 'Comment not found or not owned by this account';
  end if;
end;
$$;

revoke all on function public.delete_own_forum_post(uuid) from public, anon;
revoke all on function public.delete_own_forum_comment(uuid) from public, anon;
grant execute on function public.delete_own_forum_post(uuid) to authenticated;
grant execute on function public.delete_own_forum_comment(uuid) to authenticated;
