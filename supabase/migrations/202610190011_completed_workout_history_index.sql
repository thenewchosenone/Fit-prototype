create index if not exists completed_workout_snapshots_owner_completed_id_idx
  on public.completed_workout_snapshots (owner_id, completed_at, id);
