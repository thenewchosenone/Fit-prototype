begin;

-- Reconcile the plan-only contract deployed in 202610230001 with clean resets.
create table if not exists public.workout_plan_deletions (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid not null,
  deleted_at timestamptz not null default now(),
  primary key (owner_id, plan_id)
);
alter table public.workout_plan_deletions enable row level security;
revoke all on public.workout_plan_deletions from public, anon, authenticated;
grant select on public.workout_plan_deletions to authenticated;
drop policy if exists "plan deletion owner read" on public.workout_plan_deletions;
create policy "plan deletion owner read" on public.workout_plan_deletions
for select to authenticated using (owner_id = (select auth.uid()));

-- Keep native owner DML; clients never need schema or bulk-delete privileges.
grant select, insert, update, delete on public.workout_plan_documents to authenticated;
revoke truncate, references, trigger on public.workout_plan_documents from public, anon, authenticated;

create or replace function public.delete_own_workout_plan(target_plan_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  owner_user_id uuid := auth.uid();
begin
  if owner_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  -- Inserts take this same owner lock before checking tombstones/uniqueness.
  perform 1 from public.profiles where id = owner_user_id for no key update;
  if not exists (
    select 1 from public.workout_plan_documents
    where owner_id = owner_user_id and id = target_plan_id
  ) and not exists (
    select 1 from public.workout_plan_deletions
    where owner_id = owner_user_id and plan_id = target_plan_id
  ) then
    return false;
  end if;
  insert into public.workout_plan_deletions(owner_id, plan_id)
  values(owner_user_id, target_plan_id)
  on conflict(owner_id, plan_id) do nothing;
  delete from public.workout_plan_documents
  where owner_id = owner_user_id and id = target_plan_id;
  return true;
end;
$$;
revoke all on function public.delete_own_workout_plan(uuid) from public, anon;
grant execute on function public.delete_own_workout_plan(uuid) to authenticated;

create or replace function public.reject_deleted_workout_plan_reinsert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id or new.owner_id is distinct from old.owner_id then
      raise exception using errcode = '42501', message = 'Workout plan identity cannot change';
    end if;
    -- UPDATE already locks the plan row. Do not invert delete's owner/row order.
    return new;
  end if;
  perform 1 from public.profiles where id = new.owner_id for no key update;
  if exists (
    select 1 from public.workout_plan_deletions
    where owner_id = new.owner_id and plan_id = new.id
  ) then
    raise exception using errcode = 'P0001', message = 'Workout plan has been deleted';
  end if;
  return new;
end;
$$;
revoke all on function public.reject_deleted_workout_plan_reinsert() from public, anon, authenticated;
drop trigger if exists prevent_deleted_workout_plan_reinsert on public.workout_plan_documents;
create trigger prevent_deleted_workout_plan_reinsert
before insert or update on public.workout_plan_documents
for each row execute function public.reject_deleted_workout_plan_reinsert();

commit;
