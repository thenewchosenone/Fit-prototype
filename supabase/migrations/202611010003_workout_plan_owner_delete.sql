begin;

-- Conflict-copy cleanup uses the existing owner-only row policy.
grant delete on public.workout_plan_documents to authenticated;

commit;
