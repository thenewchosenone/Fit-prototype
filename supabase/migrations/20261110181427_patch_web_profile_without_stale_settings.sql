begin;

-- Apply only fields edited on the website, preserving settings changed in the
-- app since the form opened. Keep username and profile writes in one transaction.
create function public.save_own_profile_web_patch(changes jsonb, expected jsonb)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  current_values jsonb;
  merged jsonb;
  field text;
  allowed constant text[] := array[
    'display_name', 'bio', 'username', 'preferred_unit', 'years_experience',
    'city_id', 'city', 'region', 'country_code', 'sex_category', 'height_cm',
    'profile_audience', 'location_audience', 'gym_audience',
    'bodyweight_audience', 'show_lift_videos', 'onboarding_completed'
  ];
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if changes is null or expected is null or jsonb_typeof(changes) <> 'object'
     or jsonb_typeof(expected) <> 'object' then
    raise exception using errcode = '22023', message = 'Profile changes must be objects';
  end if;
  if exists (select 1 from jsonb_object_keys(changes) k where not (k = any(allowed)))
     or exists (select 1 from jsonb_object_keys(changes) k where not (expected ? k))
     or exists (select 1 from jsonb_object_keys(expected) k where not (changes ? k)) then
    raise exception using errcode = '22023', message = 'Invalid profile fields';
  end if;
  perform 1 from public.profiles where id = caller for update;
  if not found then raise exception using errcode = 'P0002', message = 'Profile not found'; end if;
  perform 1 from public.profile_private_details where user_id = caller for update;
  if not found then raise exception using errcode = 'P0002', message = 'Private details not found'; end if;
  perform 1 from public.profile_privacy where user_id = caller for update;
  if not found then raise exception using errcode = 'P0002', message = 'Privacy not found'; end if;

  select to_jsonb(p) || to_jsonb(d) || to_jsonb(v) into current_values
  from public.profiles p
  join public.profile_private_details d on d.user_id = p.id
  join public.profile_privacy v on v.user_id = p.id
  where p.id = caller;
  for field in select jsonb_object_keys(changes) loop
    if field in ('show_lift_videos', 'onboarding_completed') then
      if jsonb_typeof(changes->field) <> 'boolean' or jsonb_typeof(expected->field) <> 'boolean' then
        raise exception using errcode = '22023', message = 'Invalid profile boolean';
      end if;
    elsif field in ('years_experience', 'height_cm') then
      if jsonb_typeof(changes->field) not in ('number', 'null') or jsonb_typeof(expected->field) not in ('number', 'null') then
        raise exception using errcode = '22023', message = 'Invalid profile number';
      end if;
    elsif jsonb_typeof(changes->field) not in ('string', 'null') or jsonb_typeof(expected->field) not in ('string', 'null') then
      raise exception using errcode = '22023', message = 'Invalid profile value';
    end if;
    if current_values->field is distinct from expected->field
       and current_values->field is distinct from changes->field then
      raise exception using errcode = '40001', message = 'Profile settings changed on another device';
    end if;
  end loop;
  if changes ? 'onboarding_completed' and changes->>'onboarding_completed' <> 'true' then
    raise exception using errcode = '22023', message = 'Onboarding completion cannot be cleared here';
  end if;
  if changes ? 'years_experience' and ((changes->>'years_experience')::numeric < 0
     or (changes->>'years_experience')::numeric > 100
     or trunc((changes->>'years_experience')::numeric) <> (changes->>'years_experience')::numeric) then
    raise exception using errcode = '22023', message = 'Years training must be between 0 and 100';
  end if;
  if changes = '{}'::jsonb then return; end if;
  merged := current_values || changes;
  if changes ? 'username' and changes->>'username' is distinct from current_values->>'username' then
    perform public.change_username(current_values->>'username', changes->>'username');
  end if;
  perform public.save_own_profile_web(
    merged->>'display_name', merged->>'bio', merged->>'preferred_unit',
    (merged->>'birth_date')::date, merged->>'sex_category', (merged->>'height_cm')::numeric,
    (merged->>'city_id')::uuid, merged->>'city', merged->>'region', merged->>'country_code',
    (merged->>'years_experience')::smallint, merged->>'experience_level',
    merged->>'profile_audience', merged->>'age_band_audience', merged->>'division_audience',
    merged->>'location_audience', merged->>'gym_audience', merged->>'friend_list_audience',
    merged->>'bodyweight_audience', (merged->>'show_lift_videos')::boolean,
    (merged->>'onboarding_completed')::boolean
  );
end;
$$;

revoke all on function public.save_own_profile_web_patch(jsonb, jsonb) from public, anon;
grant execute on function public.save_own_profile_web_patch(jsonb, jsonb) to authenticated;

commit;
