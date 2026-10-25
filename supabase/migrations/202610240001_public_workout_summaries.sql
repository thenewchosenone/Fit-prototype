begin;

-- Return a limited summary, never the private snapshot payload or its notes.
create function public.get_profile_workout_summaries(target_user_id uuid)
returns table(id uuid, name text, completed_at timestamptz, duration double precision,
              set_count integer, exercise_names text[])
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.can_view_profile(target_user_id) then
    return;
  end if;

  return query
  with history as materialized (
    select s.id, s.completed_at,
      case when pg_catalog.jsonb_typeof(s.payload) = 'string'
        then pg_catalog.convert_from(pg_catalog.decode(s.payload #>> '{}', 'base64'), 'UTF8')::jsonb
        else s.payload end as workout
    from public.completed_workout_snapshots s
    where s.owner_id = target_user_id
  )
  select h.id, pg_catalog.left(h.workout->>'name', 120), h.completed_at,
    greatest(0, (h.workout->>'duration')::double precision),
    (select count(*)::integer from pg_catalog.jsonb_array_elements(h.workout->'sets') s
      where s->>'isComplete' = 'true' and s->>'isWarmup' = 'false'),
    array(select pg_catalog.left(e->>'exerciseName', 120)
      from pg_catalog.jsonb_array_elements(h.workout->'exercises') e
      where exists(select 1 from pg_catalog.jsonb_array_elements(h.workout->'sets') s
        where s->>'prescriptionID' = e->>'id'
          and s->>'isComplete' = 'true' and s->>'isWarmup' = 'false'))
  from history h
  -- Older snapshots without an explicit sharing decision remain private.
  where h.workout->>'isPublic' = 'true'
  order by h.completed_at desc, h.id
  limit 100;
end;
$$;

revoke all on function public.get_profile_workout_summaries(uuid) from public, anon;
grant execute on function public.get_profile_workout_summaries(uuid) to authenticated;

commit;
