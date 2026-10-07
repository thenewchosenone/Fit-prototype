-- Forward-only forum integrity and moderation corrections.
-- Do not apply remotely without an explicit production deployment review.

create or replace function public.can_moderate_forum_community(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select target_community_id is not null and (
    public.is_admin()
    or exists (
      select 1
      from public.forum_memberships m
      where m.community_id = target_community_id
        and m.user_id = auth.uid()
        and m.status = 'Joined'
        and m.role in ('Moderator', 'Admin', 'Staff')
        and m.banned_at is null
    )
  );
$$;

create or replace function public.can_view_forum_post(target uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.forum_posts p
    where p.id = target
      and not public.is_blocked_pair(p.author_id, auth.uid())
      and (p.removed_at is null or p.author_id = auth.uid() or public.can_moderate_forum_community(p.community_id))
      and (
        (p.community_id is not null and public.can_view_forum_community(p.community_id))
        or (p.gym_id is not null and exists (
          select 1
          from public.gym_memberships gm
          where gm.gym_id = p.gym_id
            and gm.user_id = auth.uid()
            and gm.left_at is null
        ))
      )
  );
$$;

create or replace function public.forum_comment_parent_matches_post()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if new.parent_comment_id is not null and not exists (
    select 1
    from public.forum_comments parent
    where parent.id = new.parent_comment_id
      and parent.post_id = new.post_id
  ) then
    raise exception 'Reply parent must belong to the same discussion';
  end if;
  return new;
end;
$$;

drop trigger if exists forum_comment_parent_post_guard on public.forum_comments;
create trigger forum_comment_parent_post_guard
before insert or update of post_id, parent_comment_id on public.forum_comments
for each row execute function public.forum_comment_parent_matches_post();

drop policy if exists "forum posts visible" on public.forum_posts;
create policy "forum posts visible"
on public.forum_posts for select to authenticated
using (public.can_view_forum_post(id));

drop policy if exists "forum posts member insert" on public.forum_posts;
create policy "forum posts member insert"
on public.forum_posts for insert to authenticated
with check (
  author_id = auth.uid()
  and not public.is_blocked_pair(author_id, auth.uid())
  and (
    (community_id is not null and exists (
      select 1
      from public.forum_memberships m
      where m.community_id = forum_posts.community_id
        and m.user_id = auth.uid()
        and m.status = 'Joined'
        and m.banned_at is null
    ))
    or (gym_id is not null and exists (
      select 1
      from public.gym_memberships gm
      where gm.gym_id = forum_posts.gym_id
        and gm.user_id = auth.uid()
        and gm.left_at is null
    ))
  )
);

drop policy if exists "forum comments visible" on public.forum_comments;
create policy "forum comments visible"
on public.forum_comments for select to authenticated
using (
  (removed_at is null or author_id = auth.uid() or exists (
    select 1
    from public.forum_posts p
    where p.id = forum_comments.post_id
      and public.can_moderate_forum_community(p.community_id)
  ))
  and public.can_view_forum_post(post_id)
);

drop policy if exists "forum comments member insert" on public.forum_comments;
create policy "forum comments member insert"
on public.forum_comments for insert to authenticated
with check (
  author_id = auth.uid()
  and public.can_view_forum_post(post_id)
  and not exists (
    select 1
    from public.forum_posts p
    join public.forum_memberships m on m.community_id = p.community_id
    where p.id = forum_comments.post_id
      and m.user_id = auth.uid()
      and (m.banned_at is not null or m.status <> 'Joined')
  )
  and not exists (
    select 1
    from public.forum_posts p
    where p.id = forum_comments.post_id
      and p.is_locked
  )
);

revoke all on function public.can_moderate_forum_community(uuid) from public, anon;
grant execute on function public.can_moderate_forum_community(uuid) to authenticated;
