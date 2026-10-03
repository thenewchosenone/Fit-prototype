-- Bodyweight history is owner-only, but authenticated clients need explicit
-- table privileges in addition to the existing row-level security policy.
revoke all on table public.bodyweight_records from public, anon, authenticated;
grant select, insert, update on table public.bodyweight_records to authenticated;

-- Save the history row and authoritative current bodyweight together so the
-- app and website cannot observe a half-finished check-in.
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

  update public.profile_private_details
  set bodyweight_lb = p_weight
  where user_id = viewer_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
end;
$$;

revoke all on function public.save_bodyweight_checkin(uuid, numeric, timestamptz, text)
  from public, anon, authenticated;
grant execute on function public.save_bodyweight_checkin(uuid, numeric, timestamptz, text)
  to authenticated;

comment on function public.save_bodyweight_checkin(uuid, numeric, timestamptz, text) is
  'Atomically saves an owner bodyweight history row and current private profile bodyweight.';
