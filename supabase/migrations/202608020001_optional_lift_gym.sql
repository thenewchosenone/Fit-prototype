begin;

alter table public.lift_submissions
  alter column gym_id drop not null;

create or replace function public.enforce_competitive_lift_authority()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid();
begin
  if caller is null then raise exception 'Authentication required'; end if;
  if tg_op = 'INSERT' then
    new.user_id := caller;
    new.evidence_status := 'self_reported';
    new.moderation_status := 'clear';
    new.video_asset_id := null;
    new.verification := 'Self Reported';
  elsif not public.is_admin() then
    new.user_id := old.user_id;
    new.evidence_status := old.evidence_status;
    new.moderation_status := old.moderation_status;
    new.video_asset_id := old.video_asset_id;
    new.competitive_movement := old.competitive_movement;
    new.weight_per_hand := old.weight_per_hand;
    new.verification := old.verification;
  end if;

  new.repetitions := new.reps;
  new.is_actual_one_rep_max := new.is_actual_one_rep_max and new.reps = 1;
  new.competitive_movement := case replace(lower(new.exercise_id), '-', '_')
    when 'bench' then 'barbell_bench_press'::public.competitive_movement
    when 'barbell_bench_press' then 'barbell_bench_press'::public.competitive_movement
    when 'back_squat' then 'back_squat'::public.competitive_movement
    when 'squat' then 'back_squat'::public.competitive_movement
    when 'conventional_deadlift' then 'conventional_deadlift'::public.competitive_movement
    when 'deadlift' then 'conventional_deadlift'::public.competitive_movement
    when 'sumo_deadlift' then 'sumo_deadlift'::public.competitive_movement
    when 'standing_barbell_overhead_press' then 'standing_barbell_overhead_press'::public.competitive_movement
    when 'barbell_overhead_press' then 'standing_barbell_overhead_press'::public.competitive_movement
    when 'dumbbell_bench_press' then 'dumbbell_bench_press'::public.competitive_movement
    when 'barbell_row' then 'bent_over_barbell_row'::public.competitive_movement
    when 'bent_over_barbell_row' then 'bent_over_barbell_row'::public.competitive_movement
    else null end;
  new.weight_per_hand := new.competitive_movement = 'dumbbell_bench_press';
  new.leaderboard_eligible_at := case
    when new.visibility = 'Public' and new.reps = 1 and new.is_actual_one_rep_max and new.competitive_movement is not null
    then coalesce(new.leaderboard_eligible_at, statement_timestamp()) else null end;

  if tg_op = 'INSERT' and new.gym_id is not null and (
    new.gym_id !~* '^[0-9a-f-]{36}$'
    or not exists (
      select 1 from public.gym_memberships gm
      where gm.user_id = caller and gm.gym_id = new.gym_id::uuid and gm.left_at is null
    )
  ) then raise exception 'An active gym membership is required when a gym is supplied'; end if;
  return new;
end;
$$;

commit;
