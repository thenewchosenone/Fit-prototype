-- Forum runtime privileges for the browser and iOS clients.
-- RLS remains the authorization boundary; these grants only allow the
-- authenticated role to reach the policies and security-definer RPCs.
grant usage on schema public to authenticated;

grant select on public.forum_communities to authenticated;
grant select on public.forum_memberships to authenticated;
grant select, insert on public.forum_posts to authenticated;
grant select, insert on public.forum_comments to authenticated;
grant select, insert, update, delete on public.forum_post_votes to authenticated;
grant select, insert, update, delete on public.forum_comment_votes to authenticated;
grant select, insert, update, delete on public.forum_post_saves to authenticated;
grant select, insert, update, delete on public.forum_post_watches to authenticated;
grant select, insert, update, delete on public.forum_poll_votes to authenticated;
grant select, insert on public.forum_reports to authenticated;
grant select on public.forum_moderation_actions to authenticated;

grant execute on function public.join_forum_community(uuid, text) to authenticated;
grant execute on function public.leave_forum_community(uuid) to authenticated;
grant execute on function public.moderate_forum_post(uuid, text, text) to authenticated;
