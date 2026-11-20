begin;

-- These functions are called by trusted trigger/RPC code, not by API clients.
revoke all on function public.refresh_lift_review_state(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.enforce_competitive_lift_authority()
  from public, anon, authenticated, service_role;

-- User actions are authenticated RPCs; the existing explicit authenticated
-- grants are retained while PUBLIC, anon, and service_role execution is removed.
revoke all on function public.vote_on_lift(uuid, integer)
  from public, anon, service_role;
revoke all on function public.report_lift(uuid, text, text)
  from public, anon, service_role;
revoke all on function public.block_user(uuid)
  from public, anon, service_role;
revoke all on function public.unblock_user(uuid)
  from public, anon, service_role;
grant execute on function public.vote_on_lift(uuid, integer) to authenticated;
grant execute on function public.report_lift(uuid, text, text) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;

-- RLS helpers are executable only by the roles whose policies call them.
revoke all on function public.is_admin() from public, anon, service_role;
revoke all on function public.moderates(text) from public, anon, service_role;
revoke all on function public.is_thread_member(uuid) from public, anon, service_role;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.moderates(text) to authenticated;
grant execute on function public.is_thread_member(uuid) to authenticated;

-- Public forum browsing policies also invoke these helpers for anon requests.
revoke all on function public.can_view_forum_community(uuid) from public, service_role;
revoke all on function public.can_view_forum_post(uuid) from public, service_role;
grant execute on function public.can_view_forum_community(uuid) to anon, authenticated;
grant execute on function public.can_view_forum_post(uuid) to anon, authenticated;

commit;
