begin;

-- Settings edits are field-scoped. Compare under row locks so a stale device
-- cannot overwrite a newer value; repeating an already-applied request is safe.
create function public.save_own_settings(changes jsonb, expected jsonb)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  current_values jsonb;
  field text;
  destination text;
  allowed constant text[] := array[
    'preferred_unit', 'training_focus', 'profile_audience', 'age_band_audience',
    'division_audience', 'bodyweight_audience', 'location_audience', 'gym_audience',
    'friend_list_audience', 'show_lift_videos', 'workout_stats_audience',
    'share_workout_starts_with_friends', 'share_prs_with_friends'
  ];
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if changes is null or expected is null or jsonb_typeof(changes) <> 'object'
     or jsonb_typeof(expected) <> 'object' then
    raise exception using errcode = '22023', message = 'Settings must be objects';
  end if;
  if exists (select 1 from jsonb_object_keys(changes) k where not (k = any(allowed)))
     or exists (select 1 from jsonb_object_keys(changes) k where not (expected ? k))
     or exists (select 1 from jsonb_object_keys(expected) k where not (changes ? k)) then
    raise exception using errcode = '22023', message = 'Invalid settings fields';
  end if;
  perform 1 from public.profiles where id = caller for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
  perform 1 from public.profile_private_details where user_id = caller for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Private details not found';
  end if;
  perform 1 from public.profile_privacy where user_id = caller for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Privacy not found';
  end if;
  select to_jsonb(d) || to_jsonb(p) into current_values
  from public.profile_private_details d join public.profile_privacy p using (user_id)
  where d.user_id = caller;

  for field in select jsonb_object_keys(changes) loop
    if jsonb_typeof(changes->field) not in ('string', 'null')
       or jsonb_typeof(expected->field) not in ('string', 'null')
       or (field <> 'training_focus' and changes->>field is null) then
      raise exception using errcode = '22023', message = 'Invalid settings value';
    end if;
    if current_values->>field is distinct from expected->>field
       and current_values->>field is distinct from changes->>field then
      raise exception using errcode = '40001', message = 'Settings changed on another device';
    end if;
  end loop;

  for field in select jsonb_object_keys(changes) loop
    if current_values->>field is not distinct from changes->>field then continue; end if;
    destination := case when field in ('preferred_unit', 'training_focus')
      then 'profile_private_details' else 'profile_privacy' end;
    -- Identifiers come exclusively from the allowlist above; values stay bound.
    execute format('update public.%I set %I = $1%s where user_id = $2',
      destination, field, case when field in ('show_lift_videos',
        'share_workout_starts_with_friends', 'share_prs_with_friends')
        then '::boolean' else '' end)
    using changes->>field, caller;
  end loop;
end;
$$;
revoke all on function public.save_own_settings(jsonb, jsonb) from public, anon;
grant execute on function public.save_own_settings(jsonb, jsonb) to authenticated;

commit;
