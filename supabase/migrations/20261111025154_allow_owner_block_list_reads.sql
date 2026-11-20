-- Friends and Forum read only the signed-in account's own block list.
-- The existing owner RLS policy enforces row visibility.
grant select (blocker_id, blocked_id, created_at)
on public.user_blocks to authenticated;
