begin;

alter table public.profile_privacy
  add column workout_stats_audience text not null default 'private'
  constraint profile_privacy_workout_stats_audience
    check (workout_stats_audience in ('public', 'friends', 'gym', 'private'));

-- Snapshot backup remains owner-only under its existing RLS policy. Explicit
-- table privileges let authenticated owners use the sync API on clean installs.
grant select, insert, update, delete on public.completed_workout_snapshots to authenticated;

-- Keep profile and sharing choices in the existing atomic mobile save.
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
  if coalesce((profile->>'updates_primary_gym')::boolean, false) then
    if profile->>'new_primary_gym_id' is null then
      update public.gym_memberships set is_primary = false where user_id = caller and left_at is null;
    else
      perform public.join_gym((profile->>'new_primary_gym_id')::uuid, true);
    end if;
  end if;
end;
$$;

-- Aggregate only. The owner-only completed_workout_snapshots policy remains intact.
create function public.get_shared_workout_stats(target_user_id uuid)
returns table(workout_count bigint, recent_workout_count bigint, latest_workout_at timestamptz)
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
begin
  if auth.uid() is null
    or public.is_blocked_pair(auth.uid(), target_user_id)
    or not public.can_view_profile(target_user_id)
    or not exists (
      select 1 from public.profile_privacy pp
      where pp.user_id = target_user_id
        and public.can_view_profile_field(target_user_id, pp.workout_stats_audience)
    )
  then
    return;
  end if;

  return query
    select count(*),
      count(*) filter (where s.completed_at >= pg_catalog.statement_timestamp() - interval '7 days'),
      max(s.completed_at)
    from public.completed_workout_snapshots s
    where s.owner_id = target_user_id;
end;
$$;

revoke all on function public.get_shared_workout_stats(uuid) from public, anon;
grant execute on function public.get_shared_workout_stats(uuid) to authenticated;

commit;
