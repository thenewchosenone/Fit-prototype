-- Make competitive eligibility, evidence, and moderation server-authoritative.

create or replace function public.enforce_competitive_lift_authority()
returns trigger
language plpgsql
security definer
set search_path = public
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

  if tg_op = 'INSERT' and (
    new.gym_id !~* '^[0-9a-f-]{36}$'
    or not exists (
      select 1 from public.gym_memberships gm
      where gm.user_id = caller and gm.gym_id = new.gym_id::uuid and gm.left_at is null
    )
  ) then raise exception 'An active gym membership is required'; end if;
  return new;
end;
$$;

drop trigger if exists competitive_lift_authority on public.lift_submissions;
create trigger competitive_lift_authority
before insert or update on public.lift_submissions
for each row execute function public.enforce_competitive_lift_authority();

create or replace function public.complete_lift_media_upload(
  target_asset_id uuid, target_lift_id uuid, uploaded_storage_path text,
  uploaded_content_type text, uploaded_byte_count bigint
)
returns table(id uuid, owner_id uuid, storage_path text, content_type text, byte_count bigint, created_at timestamptz)
language plpgsql
security definer
set search_path = public, storage
as $$
declare caller uuid := auth.uid(); prior public.lift_moderation_status;
begin
  if caller is null then raise exception 'Authentication required'; end if;
  select l.moderation_status into prior from public.lift_submissions l where l.id = target_lift_id and l.user_id = caller for update;
  if prior is null then raise exception 'Lift not found'; end if;
  if uploaded_storage_path !~ ('^' || caller::text || '/' || target_lift_id::text || '/')
     or not exists (select 1 from storage.objects o where o.bucket_id = 'lift-videos' and o.name = uploaded_storage_path and o.owner_id = caller::text)
  then raise exception 'Completed upload not found'; end if;

  insert into public.lift_media_assets(id, owner_id, lift_id, storage_path, content_type, byte_count)
  values(target_asset_id, caller, target_lift_id, uploaded_storage_path, uploaded_content_type, uploaded_byte_count);
  update public.lift_submissions l set
    video_asset_id = target_asset_id,
    evidence_status = 'video_backed',
    verification = 'Video Verified',
    moderation_status = case when prior = 'replacement_requested' then 'under_review' else prior end,
    updated_at = statement_timestamp()
  where l.id = target_lift_id;
  return query select a.id,a.owner_id,a.storage_path,a.content_type,a.byte_count,a.created_at
    from public.lift_media_assets a where a.id = target_asset_id;
end;
$$;

create or replace function public.get_lift_media_for_playback(asset_id uuid)
returns table(id uuid, owner_id uuid, storage_path text, content_type text, byte_count bigint, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select a.id,a.owner_id,a.storage_path,a.content_type,a.byte_count,a.created_at
  from public.lift_media_assets a
  join public.lift_submissions l on l.id = a.lift_id
  where a.id = asset_id
    and (a.owner_id = auth.uid() or l.visibility = 'Public' or (l.visibility = 'Friends' and public.are_friends(l.user_id, auth.uid())))
    and not public.is_blocked_pair(l.user_id, auth.uid());
$$;

create or replace function public.moderate_lift(lift_id uuid, decision text, note text default '')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare prior public.lift_moderation_status; resulting public.lift_moderation_status;
begin
  if not public.is_admin() then raise exception 'Moderator permission required'; end if;
  select moderation_status into prior from public.lift_submissions where id = lift_id for update;
  if prior is null then raise exception 'Lift not found'; end if;
  resulting := case decision when 'uphold' then 'clear'::public.lift_moderation_status
    when 'reject' then 'rejected'::public.lift_moderation_status
    when 'request_replacement' then 'replacement_requested'::public.lift_moderation_status
    else null end;
  if resulting is null then raise exception 'Unsupported decision'; end if;
  update public.lift_submissions set
    moderation_status = resulting,
    evidence_status = case when decision = 'reject' then 'self_reported'::public.lift_evidence_status else evidence_status end,
    verification = case when decision = 'reject' then 'Rejected' else verification end,
    updated_at = statement_timestamp()
  where id = lift_id;
  if decision in ('uphold','reject') then update public.lift_reports set closed_at = statement_timestamp() where lift_reports.lift_id = moderate_lift.lift_id and closed_at is null; end if;
  insert into public.lift_moderation_audit(lift_id,actor_id,event,prior_status,resulting_status,note)
  values(lift_id,auth.uid(),'moderator_' || decision,prior,resulting,left(coalesce(note,''),1000));
end;
$$;

create or replace function public.get_moderation_queue_ids()
returns table(lift_id uuid)
language sql stable security definer set search_path = public as $$
  select id from public.lift_submissions
  where public.is_admin() and moderation_status in ('under_review','replacement_requested')
  order by updated_at;
$$;

create or replace function public.prevent_moderation_audit_mutation()
returns trigger language plpgsql set search_path = pg_catalog as $$
begin raise exception 'Moderation audit entries are immutable'; end;
$$;
drop trigger if exists moderation_audit_immutable on public.lift_moderation_audit;
create trigger moderation_audit_immutable before update or delete on public.lift_moderation_audit
for each row execute function public.prevent_moderation_audit_mutation();

create policy "lift videos visible playback" on storage.objects for select to authenticated
using (
  bucket_id = 'lift-videos'
  and exists (
    select 1 from public.lift_media_assets a
    join public.lift_submissions l on l.id = a.lift_id
    where a.storage_path = name
      and (a.owner_id = auth.uid() or l.visibility = 'Public' or (l.visibility = 'Friends' and public.are_friends(l.user_id,auth.uid())))
      and not public.is_blocked_pair(l.user_id,auth.uid())
  )
);

revoke all on function public.complete_lift_media_upload(uuid,uuid,text,text,bigint) from public;
revoke all on function public.get_lift_media_for_playback(uuid) from public;
revoke all on function public.moderate_lift(uuid,text,text) from public;
revoke all on function public.get_moderation_queue_ids() from public;
grant execute on function public.complete_lift_media_upload(uuid,uuid,text,text,bigint) to authenticated;
grant execute on function public.get_lift_media_for_playback(uuid) to authenticated;
grant execute on function public.moderate_lift(uuid,text,text) to authenticated;
grant execute on function public.get_moderation_queue_ids() to authenticated;
