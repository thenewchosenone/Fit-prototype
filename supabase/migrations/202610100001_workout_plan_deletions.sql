create table public.workout_plan_deletions (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid not null,
  deleted_at timestamptz not null default now(),
  primary key (owner_id, plan_id)
);

alter table public.workout_plan_deletions enable row level security;
revoke all on table public.workout_plan_deletions from anon, authenticated;
grant select on table public.workout_plan_deletions to authenticated;

create policy "plan deletion owner read" on public.workout_plan_deletions
for select to authenticated using (owner_id = (select auth.uid()));

create function public.delete_own_workout_plan(target_plan_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_user_id uuid := auth.uid();
begin
  if owner_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  if not exists (
    select 1 from public.workout_plan_documents
    where owner_id = owner_user_id and id = target_plan_id
  ) and not exists (
    select 1 from public.workout_plan_deletions
    where owner_id = owner_user_id and plan_id = target_plan_id
  ) then
    return false;
  end if;

  insert into public.workout_plan_deletions (owner_id, plan_id)
  values (owner_user_id, target_plan_id)
  on conflict (owner_id, plan_id) do nothing;

  delete from public.workout_plan_documents
  where owner_id = owner_user_id and id = target_plan_id;

  return true;
end;
$$;

revoke all on function public.delete_own_workout_plan(uuid) from public, anon;
grant execute on function public.delete_own_workout_plan(uuid) to authenticated;

create function public.reject_deleted_workout_plan_reinsert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
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

create trigger prevent_deleted_workout_plan_reinsert
before insert on public.workout_plan_documents
for each row execute function public.reject_deleted_workout_plan_reinsert();
