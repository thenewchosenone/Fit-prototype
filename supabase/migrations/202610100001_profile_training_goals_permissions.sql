begin;

-- Keep goal writes behind the owner-scoped RPC, regardless of project defaults.
revoke all on public.profile_training_goals from public, anon, authenticated;
grant select on public.profile_training_goals to authenticated;
revoke all on function public.replace_own_training_goals(text[]) from public, anon;
grant execute on function public.replace_own_training_goals(text[]) to authenticated;

commit;
