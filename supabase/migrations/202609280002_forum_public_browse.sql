-- Let signed-out visitors browse public training groups and discussions.
-- Mutations and private/restricted content remain protected by the existing
-- authenticated policies and can_view_forum_* helpers.
grant usage on schema public to anon;
grant select on public.forum_communities to anon;
grant select on public.forum_posts to anon;
grant select on public.forum_comments to anon;

create policy "public forum communities visible"
  on public.forum_communities for select to anon
  using (public.can_view_forum_community(id));

create policy "public forum posts visible"
  on public.forum_posts for select to anon
  using (public.can_view_forum_post(id));

create policy "public forum comments visible"
  on public.forum_comments for select to anon
  using (public.can_view_forum_post(post_id));
