-- Keep current profile weight aligned with the chronologically latest history
-- row when an athlete edits an older bodyweight check-in.
create or replace function public.save_bodyweight_checkin(
  p_id uuid,
  p_weight numeric,
  p_recorded_at timestamptz,
  p_notes text default ''
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
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
      notes = excluded.notes;

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

comment on function public.save_bodyweight_checkin(uuid, numeric, timestamptz, text) is
  'Atomically saves an owner bodyweight history row and sets current private profile bodyweight from the latest dated row.';

create or replace function public.delete_bodyweight_checkin(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
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

revoke all on function public.delete_bodyweight_checkin(uuid) from public, anon;
grant execute on function public.delete_bodyweight_checkin(uuid) to authenticated;

comment on function public.delete_bodyweight_checkin(uuid) is
  'Atomically deletes an owner bodyweight history row and restores current private profile bodyweight from the latest remaining dated row.';
