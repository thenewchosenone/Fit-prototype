-- Apply the same profile visibility rule to direct REST reads as to the lift RPC.
begin;
drop policy if exists "lift profile visibility guard" on public.lift_submissions;
create policy "lift profile visibility guard" on public.lift_submissions
as restrictive for select to authenticated
using (public.can_view_profile(user_id));
commit;
