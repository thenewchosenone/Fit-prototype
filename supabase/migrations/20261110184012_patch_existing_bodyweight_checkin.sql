begin;

-- Serialize all supported check-in writes before changing history or deriving
-- current weight, including calls from existing native clients.
create or replace function public.save_bodyweight_checkin(
  p_id uuid,
  p_weight numeric,
  p_recorded_at timestamptz,
  p_notes text default ''
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  viewer_id uuid := auth.uid();
  latest_weight numeric;
begin
  if viewer_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_id is null or p_recorded_at is null then
    raise exception using errcode = '22023', message = 'A check-in id and date are required';
  end if;
  if p_weight is null or p_weight < 40 or p_weight > 1500 then
    raise exception using errcode = '22023', message = 'Bodyweight must be between 40 and 1500 pounds';
  end if;
  perform 1 from public.profiles where id = viewer_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'Profile not found'; end if;

  if exists (
    select 1
    from public.bodyweight_records
    where id = p_id and user_id <> viewer_id
  ) then
    raise exception using errcode = '42501', message = 'Bodyweight check-in belongs to another athlete';
  end if;

  insert into public.bodyweight_records (id, user_id, weight, recorded_at, notes)
  values (p_id, viewer_id, p_weight, p_recorded_at, coalesce(p_notes, ''))
  on conflict (id) do update
  set weight = excluded.weight,
      recorded_at = excluded.recorded_at,
      notes = excluded.notes
  where public.bodyweight_records.user_id = viewer_id;
  if not found then
    raise exception using errcode = '42501', message = 'Bodyweight check-in belongs to another athlete';
  end if;

  select record.weight
  into latest_weight
  from public.bodyweight_records as record
  where record.user_id = viewer_id
  order by record.recorded_at desc, record.id asc
  limit 1;

  update public.profile_private_details as details
  set bodyweight_lb = latest_weight
  where details.user_id = viewer_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
end;
$$;

create or replace function public.delete_bodyweight_checkin(p_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  viewer_id uuid := auth.uid();
  latest_weight numeric;
  deleted_count integer;
begin
  if viewer_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_id is null then
    raise exception using errcode = '22023', message = 'A check-in id is required';
  end if;

  perform 1 from public.profiles where id = viewer_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'Profile not found'; end if;

  delete from public.bodyweight_records
  where id = p_id and user_id = viewer_id;
  get diagnostics deleted_count = row_count;
  if deleted_count = 0 then
    if exists (select 1 from public.bodyweight_records where id = p_id and user_id <> viewer_id) then
      raise exception using errcode = '42501', message = 'Bodyweight check-in belongs to another athlete';
    end if;
    raise exception using errcode = 'P0002', message = 'Bodyweight check-in not found';
  end if;

  select record.weight
  into latest_weight
  from public.bodyweight_records as record
  where record.user_id = viewer_id
  order by record.recorded_at desc, record.id asc
  limit 1;

  update public.profile_private_details as details
  set bodyweight_lb = latest_weight
  where details.user_id = viewer_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
end;
$$;

-- Editing is distinct from creating/retrying an upsert: a deleted check-in must
-- stay deleted, and changes in untouched fields belong to the newer snapshot.
create function public.patch_own_bodyweight_checkin(target_record_id uuid, changes jsonb, expected jsonb)
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
begin
  if caller is null then raise exception using errcode = '42501', message = 'Authentication required'; end if;
  if changes is null or expected is null or jsonb_typeof(changes) <> 'object' or jsonb_typeof(expected) <> 'object' then
    raise exception using errcode = '22023', message = 'Check-in changes must be objects';
  end if;
  if exists (select 1 from jsonb_object_keys(changes) k where k not in ('weight','recorded_at','notes'))
    or exists (select 1 from jsonb_object_keys(changes) k where not (expected ? k))
    or exists (select 1 from jsonb_object_keys(expected) k where not (changes ? k)) then
    raise exception using errcode = '22023', message = 'Invalid check-in fields';
  end if;
  perform 1 from public.profiles where id = caller for update;
  if not found then raise exception using errcode = 'P0002', message = 'Profile not found'; end if;
  select to_jsonb(r) into current_values from public.bodyweight_records r
  where r.id = target_record_id and r.user_id = caller for update;
  if not found then raise exception using errcode = 'P0002', message = 'Check-in is unavailable or was deleted'; end if;
  for field in select jsonb_object_keys(changes) loop
    if jsonb_typeof(changes->field) <> (case when field='weight' then 'number' else 'string' end)
      or jsonb_typeof(expected->field) <> (case when field='weight' then 'number' else 'string' end) then
      raise exception using errcode = '22023', message = 'Invalid check-in value';
    end if;
    if field = 'recorded_at' then
      if (current_values->>field)::timestamptz is distinct from (expected->>field)::timestamptz
        and (current_values->>field)::timestamptz is distinct from (changes->>field)::timestamptz then
        raise exception using errcode = '40001', message = 'Check-in changed on another device';
      end if;
    elsif current_values->field is distinct from expected->field
      and current_values->field is distinct from changes->field then
      raise exception using errcode = '40001', message = 'Check-in changed on another device';
    end if;
  end loop;
  if changes = '{}'::jsonb then return; end if;
  merged := current_values || changes;
  perform public.save_bodyweight_checkin(target_record_id, (merged->>'weight')::numeric,
    (merged->>'recorded_at')::timestamptz, merged->>'notes');
end;
$$;

revoke all on function public.patch_own_bodyweight_checkin(uuid,jsonb,jsonb) from public, anon;
grant execute on function public.patch_own_bodyweight_checkin(uuid,jsonb,jsonb) to authenticated;

commit;
