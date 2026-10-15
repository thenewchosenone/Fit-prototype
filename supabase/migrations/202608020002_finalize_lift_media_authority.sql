begin;

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
  elsif not public.is_admin()
    and coalesce(pg_catalog.current_setting('liftrank.trusted_media_finalize', true), 'false') <> 'true'
  then
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

create or replace function public.complete_lift_media_upload(
  target_asset_id uuid, target_lift_id uuid, uploaded_storage_path text,
  uploaded_content_type text, uploaded_byte_count bigint
)
returns table(id uuid, owner_id uuid, storage_path text, content_type text, byte_count bigint, created_at timestamptz)
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid(); prior public.lift_moderation_status;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  select l.moderation_status into prior
  from public.lift_submissions l
  where l.id = target_lift_id and l.user_id = caller
  for update;
  if prior is null then raise exception 'Lift not found'; end if;
  if uploaded_storage_path !~ ('^' || caller::text || '/' || target_lift_id::text || '/')
     or not exists (
       select 1 from storage.objects o
       where o.bucket_id = 'lift-videos'
         and o.name = uploaded_storage_path
         and o.owner_id = caller::text
     )
  then raise exception 'Completed upload not found'; end if;

  insert into public.lift_media_assets(id, owner_id, lift_id, storage_path, content_type, byte_count)
  values(target_asset_id, caller, target_lift_id, uploaded_storage_path, uploaded_content_type, uploaded_byte_count);
  perform pg_catalog.set_config('liftrank.trusted_media_finalize', 'true', true);
  update public.lift_submissions l set
    video_asset_id = target_asset_id,
    evidence_status = 'video_backed',
    verification = 'Video Verified',
    moderation_status = case when prior = 'replacement_requested' then 'under_review' else prior end,
    updated_at = statement_timestamp()
  where l.id = target_lift_id;
  perform pg_catalog.set_config('liftrank.trusted_media_finalize', 'false', true);
  return query
    select a.id, a.owner_id, a.storage_path, a.content_type, a.byte_count, a.created_at
    from public.lift_media_assets a
    where a.id = target_asset_id;
end;
$$;

commit;
