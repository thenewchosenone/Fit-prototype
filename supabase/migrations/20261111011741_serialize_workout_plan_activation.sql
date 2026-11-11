begin;
set local lock_timeout = '5s';

create function public.decode_workout_plan_document(encoded jsonb, document_id uuid)
returns jsonb
language plpgsql immutable strict
set search_path = pg_catalog
as $$
declare
  base64 text := encoded #>> '{}';
  bytes bytea;
  source_document json;
  document jsonb;
  active_flag jsonb;
begin
  if jsonb_typeof(encoded) is distinct from 'string' then
    raise exception using errcode = '22023', message = 'Invalid synced workout plan payload';
  end if;
  bytes := decode(base64, 'base64');
  if translate(encode(bytes, 'base64'), E'\r\n', '') <> base64 then
    raise exception using errcode = '22023', message = 'Invalid synced workout plan encoding';
  end if;
  source_document := convert_from(bytes, 'UTF8')::json;
  if json_typeof(source_document) is distinct from 'object'
     or json_typeof(source_document -> 'plan') is distinct from 'object' then
    raise exception using errcode = '22023', message = 'Invalid synced workout plan identity or active state';
  end if;
  -- Swift and jsonb can choose different values when JSON repeats a key.
  if (select count(*) from json_each(source_document) where key = 'plan') <> 1
     or exists (
       select 1 from json_each(source_document -> 'plan')
       where key in ('id', 'isActive') group by key having count(*) > 1
     ) then
    raise exception using errcode = '22023', message = 'Duplicate synced workout plan identity or active state';
  end if;
  document := source_document::jsonb;
  active_flag := document #> '{plan,isActive}';
  if (document #>> '{plan,id}')::uuid is distinct from document_id
     or (active_flag is not null and jsonb_typeof(active_flag) not in ('null', 'boolean')) then
    raise exception using errcode = '22023', message = 'Invalid synced workout plan identity or active state';
  end if;
  return document;
end;
$$;

create function public.workout_plan_document_is_active(encoded jsonb, document_id uuid)
returns boolean
language sql immutable strict
set search_path = pg_catalog
as $$
  select coalesce((public.decode_workout_plan_document(encoded, document_id) #>> '{plan,isActive}')::boolean, true);
$$;

-- A legacy payload or duplicate active selection requires a separate reviewed repair.
-- Keep writes out of the table while checking the initial invariant and installing the triggers.
lock table public.workout_plan_documents in share row exclusive mode;
do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.workout_plan_documents'::regclass
      and tgfoid = to_regprocedure('public.reject_deleted_workout_plan_reinsert()')
      and (tgtype::integer & 23) = 23 and tgenabled in ('O', 'A')
  ) then
    raise exception 'Install the workout plan deletion and identity guard before activation';
  end if;
  if exists (
    select 1 from public.workout_plan_documents
    group by owner_id
    having count(*) filter (where public.workout_plan_document_is_active(payload, id)) > 1
  ) then
    raise exception using errcode = '23514', message = 'Resolve existing multiple active programs before installing activation';
  end if;
end;
$$;

create function public.lock_workout_plan_owner(owner_user_id uuid)
returns void
language plpgsql
set search_path = pg_catalog
as $$
begin
  if current_setting('transaction_isolation') not in ('read committed', 'read uncommitted') then
    raise exception using errcode = '25000', message = 'Workout plan writes require read committed isolation';
  end if;
  perform 1 from public.profiles where id = owner_user_id for no key update;
end;
$$;

create function public.lock_workout_plan_write()
returns trigger
language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  owner_user_id uuid := auth.uid();
begin
  if owner_user_id is null then
    -- Auth administration can cascade account deletion without an owner JWT.
    if tg_op = 'DELETE' then return null; end if;
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  perform public.lock_workout_plan_owner(owner_user_id);
  return null;
end;
$$;

create trigger lock_workout_plan_write
before insert or update or delete on public.workout_plan_documents
for each statement execute function public.lock_workout_plan_write();

create function public.reconcile_workout_plan_activation()
returns trigger
language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  owner_user_id uuid := auth.uid();
  activations uuid[];
begin
  if owner_user_id is null or exists (select 1 from new_plans where owner_id <> owner_user_id) then
    raise exception using errcode = '42501', message = 'Workout plan write must match its owner';
  end if;
  if tg_op = 'INSERT' then
    select array_agg(id) into activations from new_plans
    where public.workout_plan_document_is_active(payload, id);
  else
    select array_agg(n.id) into activations from new_plans n join old_plans o using (owner_id, id)
    where case when public.workout_plan_document_is_active(n.payload, n.id)
      then not public.workout_plan_document_is_active(o.payload, o.id) else false end;
  end if;

  if cardinality(activations) > 1 then
    raise exception using errcode = '23514', message = 'Select one active program per change';
  end if;
  if cardinality(activations) = 1 and exists (
    select 1 from public.workout_plan_documents where owner_id = owner_user_id
      and id = activations[1] and public.workout_plan_document_is_active(payload, id)
  ) then
    -- The original statement has finished visiting rows. A nested deactivation
    -- has no false-to-true transition and therefore stops here on its own.
    update public.workout_plan_documents
    set payload = to_jsonb(translate(encode(convert_to(jsonb_set(
          public.decode_workout_plan_document(payload, id), '{plan,isActive}', 'false'
        )::text, 'UTF8'), 'base64'), E'\r\n', '')),
        revision = revision + 1,
        updated_at = clock_timestamp()
    where owner_id = owner_user_id and id <> activations[1]
      and public.workout_plan_document_is_active(payload, id);
  end if;
  if exists (
    select 1 from public.workout_plan_documents where owner_id = owner_user_id
      and public.workout_plan_document_is_active(payload, id)
    offset 1
  ) then
    raise exception using errcode = '23514', message = 'Only one synced program can be active';
  end if;
  return null;
end;
$$;

create trigger reconcile_workout_plan_insert
after insert on public.workout_plan_documents
referencing new table as new_plans for each statement
execute function public.reconcile_workout_plan_activation();

create trigger reconcile_workout_plan_update
after update on public.workout_plan_documents
referencing old table as old_plans new table as new_plans for each statement
execute function public.reconcile_workout_plan_activation();

create function public.set_active_workout_plan(
  target_plan_id uuid, expected_target_revision integer,
  expected_active_id uuid, expected_active_revision integer
)
returns jsonb
language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  owner_user_id uuid := auth.uid();
  active_id uuid;
  active_revision integer;
  target_revision integer;
begin
  if owner_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  perform public.lock_workout_plan_owner(owner_user_id);

  select id, revision into active_id, active_revision from public.workout_plan_documents
  where owner_id = owner_user_id and public.workout_plan_document_is_active(payload, id);
  if active_id is distinct from expected_active_id or active_revision is distinct from expected_active_revision then
    raise exception using errcode = '40001', message = 'Active program changed. Reload your programs.';
  end if;

  if target_plan_id is not null then
    select revision into target_revision from public.workout_plan_documents
    where owner_id = owner_user_id and id = target_plan_id;
    if not found then
      raise exception using errcode = 'P0002', message = 'Program is no longer available';
    end if;
  end if;
  if target_revision is distinct from expected_target_revision then
    raise exception using errcode = '40001', message = 'Program changed. Reload your programs.';
  end if;
  if target_plan_id is distinct from active_id then
    update public.workout_plan_documents
    set payload = to_jsonb(translate(encode(convert_to(jsonb_set(
          public.decode_workout_plan_document(payload, id), '{plan,isActive}', to_jsonb(target_plan_id is not null)
        )::text, 'UTF8'), 'base64'), E'\r\n', '')),
        revision = revision + 1,
        updated_at = clock_timestamp()
    where owner_id = owner_user_id and id = coalesce(target_plan_id, active_id);
    if not found then
      raise exception using errcode = 'P0002', message = 'Program is no longer available';
    end if;
  end if;

  -- Read the displaced row after its trigger has bumped its revision.
  return (
    select coalesce(jsonb_agg(to_jsonb(plan) order by plan.id), '[]'::jsonb)
    from public.workout_plan_documents plan
    where plan.owner_id = owner_user_id and plan.id in (active_id, target_plan_id)
  );
end;
$$;

revoke all on function public.decode_workout_plan_document(jsonb, uuid),
  public.workout_plan_document_is_active(jsonb, uuid), public.lock_workout_plan_owner(uuid),
  public.lock_workout_plan_write(), public.reconcile_workout_plan_activation()
from public, anon, authenticated;
revoke all on function public.set_active_workout_plan(uuid, integer, uuid, integer) from public, anon;
grant execute on function public.set_active_workout_plan(uuid, integer, uuid, integer) to authenticated;

commit;
