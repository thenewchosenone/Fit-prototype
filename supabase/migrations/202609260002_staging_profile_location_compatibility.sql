alter table public.profile_private_details
  add column if not exists city_id uuid references public.location_cities(id) on delete set null;

drop function if exists public.save_own_profile(
  text, text, text, date, text, numeric, text, text, text, smallint, text,
  text, text, text, text, text, text, boolean
);

create or replace function public.save_own_profile(
  new_display_name text,
  new_bio text,
  new_preferred_unit text,
  new_birth_date date,
  new_sex_category text,
  new_height_cm numeric,
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
  complete_onboarding boolean default false,
  new_city_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  canonical_city record;
  saved_city text;
  saved_region text;
  saved_country_code text;
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  if new_city_id is not null then
    select c.id, c.name, coalesce(r.name, c.region_code, '') as region, c.country_code
    into canonical_city
    from public.location_cities c
    left join public.location_regions r
      on r.country_code = c.country_code and r.code = c.region_code
    where c.id = new_city_id;
    if canonical_city.id is null then
      raise exception using errcode = '22023', message = 'Choose a valid city';
    end if;
    saved_city := canonical_city.name;
    saved_region := canonical_city.region;
    saved_country_code := canonical_city.country_code;
  else
    saved_city := nullif(btrim(new_city), '');
    saved_region := nullif(btrim(new_region), '');
    saved_country_code := nullif(upper(btrim(new_country_code)), '');
  end if;

  update public.profiles
  set display_name = new_display_name, bio = coalesce(new_bio, ''), onboarding_completed = complete_onboarding
  where id = caller;
  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;

  insert into public.profile_private_details (
    user_id, birth_date, sex_category, preferred_unit, height_cm,
    city_id, city, region, country_code, years_experience, experience_level
  ) values (
    caller, new_birth_date, new_sex_category, new_preferred_unit, new_height_cm,
    new_city_id, saved_city, saved_region, saved_country_code, new_years_experience, new_experience_level
  ) on conflict (user_id) do update set
    birth_date = excluded.birth_date, sex_category = excluded.sex_category,
    preferred_unit = excluded.preferred_unit, height_cm = excluded.height_cm,
    city_id = excluded.city_id, city = excluded.city, region = excluded.region,
    country_code = excluded.country_code, years_experience = excluded.years_experience,
    experience_level = excluded.experience_level;

  insert into public.profile_privacy (
    user_id, profile_audience, age_band_audience, division_audience,
    location_audience, gym_audience, friend_list_audience
  ) values (
    caller, new_profile_audience, new_age_band_audience, new_division_audience,
    new_location_audience, new_gym_audience, new_friend_list_audience
  ) on conflict (user_id) do update set
    profile_audience = excluded.profile_audience, age_band_audience = excluded.age_band_audience,
    division_audience = excluded.division_audience, location_audience = excluded.location_audience,
    gym_audience = excluded.gym_audience, friend_list_audience = excluded.friend_list_audience;
end;
$$;

grant execute on function public.save_own_profile(
  text, text, text, date, text, numeric, text, text, text, smallint, text,
  text, text, text, text, text, text, boolean, uuid
) to authenticated;
