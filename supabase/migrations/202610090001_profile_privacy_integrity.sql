begin;

-- One transaction for the mobile form, including all privacy fields and the
-- explicitly requested primary-gym change. No caller-supplied account ID.
create function public.save_own_profile_mobile(profile jsonb)
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
  if coalesce((profile->>'updates_primary_gym')::boolean, false) then
    if profile->>'new_primary_gym_id' is null then
      update public.gym_memberships set is_primary = false where user_id = caller and left_at is null;
    else
      perform public.join_gym((profile->>'new_primary_gym_id')::uuid, true);
    end if;
  end if;
end;
$$;
revoke all on function public.save_own_profile_mobile(jsonb) from public, anon;
grant execute on function public.save_own_profile_mobile(jsonb) to authenticated;

-- Report-driven moderation publishes trusted uploaded videos immediately.
-- Owners can review their own footage; other viewers need both audiences,
-- the video-sharing preference, and clear moderation status.
create function public.can_play_lift_video(video_storage_path text)
returns boolean
language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is not null and exists (
    select 1 from public.lift_media_assets a
    join public.lift_submissions l on l.id = a.lift_id
    join public.profile_privacy pp on pp.user_id = l.user_id
    where a.storage_path = video_storage_path
      and (a.owner_id = auth.uid() or (
        pp.show_lift_videos and public.can_view_profile(l.user_id)
        and l.evidence_status = 'video_backed' and l.moderation_status = 'clear'
        and (l.visibility = 'Public' or (l.visibility = 'Friends' and public.are_friends(l.user_id, auth.uid())))
        and not public.is_blocked_pair(l.user_id, auth.uid())
      ))
  )
$$;
revoke all on function public.can_play_lift_video(text) from public, anon;
grant execute on function public.can_play_lift_video(text) to authenticated;

create or replace function public.get_lift_media_for_playback(asset_id uuid)
returns table(id uuid, owner_id uuid, storage_path text, content_type text, byte_count bigint, created_at timestamptz)
language sql stable security definer
set search_path = pg_catalog
as $$
  select a.id, a.owner_id, a.storage_path, a.content_type, a.byte_count, a.created_at
  from public.lift_media_assets a
  where a.id = asset_id and public.can_play_lift_video(a.storage_path)
$$;
revoke all on function public.get_lift_media_for_playback(uuid) from public, anon;
grant execute on function public.get_lift_media_for_playback(uuid) to authenticated;

drop policy "lift videos visible playback" on storage.objects;
create policy "lift videos visible playback" on storage.objects for select to authenticated
using (bucket_id = 'lift-videos' and public.can_play_lift_video(name));

create function public.get_playable_lift_media_ids(asset_ids uuid[])
returns setof uuid
language sql stable security definer
set search_path = pg_catalog
as $$
  select a.id from public.lift_media_assets a
  where a.id = any(asset_ids) and public.can_play_lift_video(a.storage_path)
$$;
revoke all on function public.get_playable_lift_media_ids(uuid[]) from public, anon;
grant execute on function public.get_playable_lift_media_ids(uuid[]) to authenticated;

commit;
