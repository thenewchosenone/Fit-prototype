begin;

alter table public.profile_privacy
  add column share_workout_starts_with_friends boolean not null default false,
  add column share_prs_with_friends boolean not null default false;

create table public.friend_training_activity (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('workout_started', 'top_lift')),
  source_id uuid not null,
  occurred_at timestamptz not null default statement_timestamp(),
  unique (owner_id, kind, source_id)
);
create index friend_training_activity_recent on public.friend_training_activity (occurred_at desc, id);
alter table public.friend_training_activity enable row level security;
create policy "friend training activity owner read" on public.friend_training_activity
  for select to authenticated using (owner_id = auth.uid());
revoke all on public.friend_training_activity from public, anon, authenticated;

create function public.record_friend_workout_start(workout_id uuid, expected_owner_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid();
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if caller is distinct from expected_owner_id then
    raise exception using errcode = '42501', message = 'Workout belongs to another account';
  end if;
  if workout_id is null then
    raise exception using errcode = '22023', message = 'Workout ID is required';
  end if;
  if exists (
    select 1 from public.profile_privacy pp
    where pp.user_id = caller and pp.share_workout_starts_with_friends
  ) then
    insert into public.friend_training_activity (owner_id, kind, source_id)
    values (caller, 'workout_started', workout_id)
    on conflict (owner_id, kind, source_id) do nothing;
  end if;
end;
$$;

create function public.record_friend_top_lift(lift_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  lift public.lift_submissions%rowtype;
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  select * into lift from public.lift_submissions l
  where l.id = lift_id and l.user_id = caller;
  if not found then
    raise exception using errcode = '42501', message = 'Lift is not owned by this account';
  end if;
  if not exists (
    select 1 from public.profile_privacy pp
    where pp.user_id = caller and pp.share_prs_with_friends
  ) or lift.visibility not in ('Public', 'Friends')
    or lift.moderation_status <> 'clear'
    or lift.disputed_at is not null
    or lift.competitive_movement is null
    or lift.reps <> 1
    or not coalesce(lift.is_actual_one_rep_max, false)
    or exists (
      select 1 from public.lift_submissions other
      where other.user_id = caller and other.id <> lift.id
        and other.competitive_movement = lift.competitive_movement
        and other.visibility in ('Public', 'Friends')
        and other.moderation_status = 'clear'
        and other.disputed_at is null
        and other.reps = 1 and other.is_actual_one_rep_max
        and (case when other.unit = 'kg' then other.weight else other.weight * 0.45359237 end)
          >= (case when lift.unit = 'kg' then lift.weight else lift.weight * 0.45359237 end)
    )
  then
    return;
  end if;
  insert into public.friend_training_activity (owner_id, kind, source_id)
  values (caller, 'top_lift', lift_id)
  on conflict (owner_id, kind, source_id) do nothing;
end;
$$;

create function public.get_friend_training_activity()
returns table(id uuid, owner_id uuid, display_name text, kind text, source_id uuid, occurred_at timestamptz)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select e.id, e.owner_id, p.display_name, e.kind, e.source_id, e.occurred_at
  from public.friend_training_activity e
  join public.profiles p on p.id = e.owner_id
  join public.profile_privacy pp on pp.user_id = e.owner_id
  where public.are_friends(auth.uid(), e.owner_id)
    and not public.is_blocked_pair(auth.uid(), e.owner_id)
    and public.can_view_profile(e.owner_id)
    and (
      (e.kind = 'workout_started' and pp.share_workout_starts_with_friends)
      or (e.kind = 'top_lift' and pp.share_prs_with_friends and exists (
        select 1 from public.lift_submissions l
        where l.id = e.source_id and l.user_id = e.owner_id
          and l.visibility in ('Public', 'Friends')
          and l.moderation_status = 'clear' and l.disputed_at is null
      ))
    )
  order by e.occurred_at desc, e.id
  limit 50;
$$;

revoke all on function public.record_friend_workout_start(uuid, uuid) from public, anon;
revoke all on function public.record_friend_top_lift(uuid) from public, anon;
revoke all on function public.get_friend_training_activity() from public, anon;
grant execute on function public.record_friend_workout_start(uuid, uuid) to authenticated;
grant execute on function public.record_friend_top_lift(uuid) to authenticated;
grant execute on function public.get_friend_training_activity() to authenticated;

-- Persist both event choices with the rest of the profile in one transaction.
create or replace function public.save_own_profile_mobile(profile jsonb)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid();
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  perform 1 from public.profiles p where p.id = caller for update;
  perform public.save_own_profile_web(
    profile->>'new_display_name', profile->>'new_bio', profile->>'new_preferred_unit',
    (profile->>'new_birth_date')::date, profile->>'new_sex_category', (profile->>'new_height_cm')::numeric,
    (profile->>'new_city_id')::uuid, profile->>'new_city', profile->>'new_region', profile->>'new_country_code',
    (profile->>'new_years_experience')::smallint, profile->>'new_experience_level',
    profile->>'new_profile_audience', profile->>'new_age_band_audience', profile->>'new_division_audience',
    profile->>'new_location_audience', profile->>'new_gym_audience', profile->>'new_friend_list_audience',
    profile->>'new_bodyweight_audience', (profile->>'new_show_lift_videos')::boolean,
    (profile->>'complete_onboarding')::boolean
  );
  update public.profiles set avatar_path = profile->>'new_avatar_path' where id = caller;
  update public.profile_private_details
  set bodyweight_lb = (profile->>'new_bodyweight_pounds')::numeric,
      training_focus = profile->>'new_training_focus'
  where user_id = caller;
  if profile ? 'new_workout_stats_audience' then
    update public.profile_privacy
    set workout_stats_audience = profile->>'new_workout_stats_audience'
    where user_id = caller;
  end if;
  if profile ? 'new_share_workout_starts_with_friends' or profile ? 'new_share_prs_with_friends' then
    update public.profile_privacy
    set share_workout_starts_with_friends = case
          when profile ? 'new_share_workout_starts_with_friends'
            then (profile->>'new_share_workout_starts_with_friends')::boolean
          else share_workout_starts_with_friends end,
        share_prs_with_friends = case
          when profile ? 'new_share_prs_with_friends'
            then (profile->>'new_share_prs_with_friends')::boolean
          else share_prs_with_friends end
    where user_id = caller;
  end if;
  if coalesce((profile->>'updates_primary_gym')::boolean, false) then
    if profile->>'new_primary_gym_id' is null then
      update public.gym_memberships set is_primary = false where user_id = caller and left_at is null;
    else
      perform public.join_gym((profile->>'new_primary_gym_id')::uuid, true);
    end if;
  end if;
end;
$$;

commit;
