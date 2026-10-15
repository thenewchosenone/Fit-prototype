begin;

create table public.profile_training_goals (
  user_id uuid not null references public.profiles(id) on delete cascade,
  goal_id text not null check (goal_id in (
    'get_stronger', 'compete_locally', 'track_personal_records',
    'compare_weight_class', 'prepare_powerlifting', 'represent_gym'
  )),
  created_at timestamptz not null default now(),
  primary key (user_id, goal_id)
);

alter table public.profile_training_goals enable row level security;
grant select on public.profile_training_goals to authenticated;

create policy profile_training_goals_select_own
on public.profile_training_goals for select to authenticated
using (user_id = (select auth.uid()));

create or replace function public.replace_own_training_goals(goal_ids text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  invalid_goal text;
begin
  select goal into invalid_goal
  from unnest(coalesce(goal_ids, array[]::text[])) as goal
  where goal not in (
    'get_stronger', 'compete_locally', 'track_personal_records',
    'compare_weight_class', 'prepare_powerlifting', 'represent_gym'
  )
  limit 1;

  if invalid_goal is not null then
    raise exception 'Invalid training goal';
  end if;

  delete from public.profile_training_goals where user_id = auth.uid();
  insert into public.profile_training_goals (user_id, goal_id)
  select auth.uid(), goal
  from unnest(coalesce(goal_ids, array[]::text[])) as goal
  on conflict do nothing;
end;
$$;

revoke all on function public.replace_own_training_goals(text[]) from public;
grant execute on function public.replace_own_training_goals(text[]) to authenticated;

commit;
