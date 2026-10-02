begin;

-- New accounts should make an intentional privacy choice before publishing a
-- profile, gym affiliation, or approved video. Existing rows are unchanged.
alter table public.profile_privacy
  alter column profile_audience set default 'private',
  alter column gym_audience set default 'private',
  alter column show_lift_videos set default false;

-- The web client sends the city, bodyweight-audience, and video-visibility
-- fields in one RPC. Keep that web contract on top of the canonical mobile
-- save function so privacy writes cannot silently drift between clients.
create or replace function public.save_own_profile_web(
  new_display_name text,
  new_bio text,
  new_preferred_unit text,
  new_birth_date date,
  new_sex_category text,
  new_height_cm numeric,
  new_city_id uuid,
  new_city text,
  new_region text,
  new_country_code text,
  new_years_experience smallint,
  new_experience_level text,
  new_profile_audience text,
  new_age_band_audience text,
  new_division_audience text,
  new_location_audience text,
  new_gym_audience text,
  new_friend_list_audience text,
  new_bodyweight_audience text,
  new_show_lift_videos boolean,
  complete_onboarding boolean
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  perform public.save_own_profile(
    new_display_name,
    new_bio,
    new_preferred_unit,
    new_birth_date,
    new_sex_category,
    new_height_cm,
    new_city,
    new_region,
    new_country_code,
    new_years_experience,
    new_experience_level,
    new_profile_audience,
    new_age_band_audience,
    new_division_audience,
    new_location_audience,
    new_gym_audience,
    new_friend_list_audience,
    complete_onboarding,
    new_city_id
  );

  update public.profile_privacy
  set bodyweight_audience = new_bodyweight_audience,
      show_lift_videos = new_show_lift_videos
  where user_id = caller;

  if not found then
    raise exception using errcode = 'P0002', message = 'Profile privacy not found';
  end if;
end;
$$;

revoke all on function public.save_own_profile_web(
  text, text, text, date, text, numeric, uuid, text, text, text, smallint,
  text, text, text, text, text, text, text, text, boolean, boolean
) from public, anon;
grant execute on function public.save_own_profile_web(
  text, text, text, date, text, numeric, uuid, text, text, text, smallint,
  text, text, text, text, text, text, text, text, boolean, boolean
) to authenticated;

-- Leaving the only active gym is a supported account action. A primary gym
-- cannot be left while another active membership still needs a primary; users
-- must choose that replacement explicitly first. This preserves the existing
-- safety rule while giving the web account page an explicit "no primary gym"
-- path.
create or replace function public.leave_gym(target_gym_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  perform 1 from public.profiles p where p.id = caller for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
  if exists (
    select 1 from public.gym_memberships gm
    where gm.user_id = caller
      and gm.gym_id = target_gym_id
      and gm.left_at is null
      and gm.is_primary
  ) and exists (
    select 1 from public.gym_memberships gm
    where gm.user_id = caller
      and gm.gym_id <> target_gym_id
      and gm.left_at is null
  ) then
    raise exception using errcode = '23514', message = 'Choose another primary gym before leaving';
  end if;
  update public.gym_memberships gm
  set left_at = statement_timestamp(), is_primary = false
  where gm.user_id = caller and gm.gym_id = target_gym_id and gm.left_at is null;
  if not found then
    raise exception using errcode = 'P0002', message = 'Active gym membership not found';
  end if;
end;
$$;

revoke all on function public.leave_gym(uuid) from public, anon;
grant execute on function public.leave_gym(uuid) to authenticated;

commit;
