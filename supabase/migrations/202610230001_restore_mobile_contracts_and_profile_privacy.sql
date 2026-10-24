-- Restore mobile RPC contracts and profile privacy on installations with partial migration history.
-- Preserve previously applied migrations and existing view columns.
begin;

create table if not exists public.workout_plan_deletions (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid not null,
  deleted_at timestamptz not null default now(),
  primary key (owner_id, plan_id)
);

alter table public.workout_plan_deletions enable row level security;
revoke all on table public.workout_plan_deletions from anon, authenticated;
grant select on table public.workout_plan_deletions to authenticated;

drop policy if exists "plan deletion owner read" on public.workout_plan_deletions;
create policy "plan deletion owner read" on public.workout_plan_deletions
for select to authenticated using (owner_id = (select auth.uid()));

create or replace function public.delete_own_workout_plan(target_plan_id uuid)
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

create or replace function public.reject_deleted_workout_plan_reinsert()
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

drop trigger if exists prevent_deleted_workout_plan_reinsert on public.workout_plan_documents;
create trigger prevent_deleted_workout_plan_reinsert
before insert on public.workout_plan_documents
for each row execute function public.reject_deleted_workout_plan_reinsert();

drop function if exists public.get_profile_cards(uuid[]);
-- Expose the latest logged bodyweight on public profile cards only when the
-- viewer is allowed by the owner's existing bodyweight privacy setting.
drop function if exists public.search_profile_cards(text, integer);
drop function if exists public.get_profile_card(uuid);

create function public.get_profile_card(target_user_id uuid)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_path text,
  bio text,
  discipline text,
  training_goal text,
  age_band text,
  sex_category text,
  city text,
  region text,
  primary_gym_id uuid,
  primary_gym_name text,
  bodyweight_pounds numeric,
  bodyweight_last_updated_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_path,
    p.bio,
    p.discipline,
    p.training_goal,
    case when public.can_view_profile_field(p.id, pp.age_band_audience)
      then public.age_band_from_birth_date(pd.birth_date) end,
    case when public.can_view_profile_field(p.id, pp.division_audience)
      then pd.sex_category end,
    case when public.can_view_profile_field(p.id, pp.location_audience)
      then pd.city end,
    case when public.can_view_profile_field(p.id, pp.location_audience)
      then pd.region end,
    case when public.can_view_profile_field(p.id, pp.gym_audience)
      then gm.gym_id end,
    case when public.can_view_profile_field(p.id, pp.gym_audience)
      then g.name end,
    case when public.can_view_profile_field(p.id, pp.bodyweight_audience)
      then bw.weight end,
    case when public.can_view_profile_field(p.id, pp.bodyweight_audience)
      then bw.recorded_at end
  from public.profiles p
  join public.profile_privacy pp on pp.user_id = p.id
  left join public.profile_private_details pd on pd.user_id = p.id
  left join public.gym_memberships gm
    on gm.user_id = p.id and gm.is_primary and gm.left_at is null
  left join public.gyms g on g.id = gm.gym_id
  left join lateral (
    select r.weight, r.recorded_at
    from public.bodyweight_records r
    where r.user_id = p.id
    order by r.recorded_at desc, r.id desc
    limit 1
  ) bw on true
  where p.id = target_user_id
    and public.can_view_profile(p.id)
$$;

create function public.search_profile_cards(search_query text, result_limit integer default 20)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_path text,
  bio text,
  discipline text,
  training_goal text,
  age_band text,
  sex_category text,
  city text,
  region text,
  primary_gym_id uuid,
  primary_gym_name text,
  bodyweight_pounds numeric,
  bodyweight_last_updated_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select card.*
  from public.profiles profile
  cross join lateral public.get_profile_card(profile.id) card
  where profile.id <> auth.uid()
    and not public.is_blocked_pair(profile.id, auth.uid())
    and (
      profile.username ilike '%' || left(btrim(search_query), 50) || '%'
      or profile.display_name ilike '%' || left(btrim(search_query), 50) || '%'
    )
  order by profile.display_name
  limit greatest(1, least(result_limit, 50))
$$;

revoke all on function public.get_profile_card(uuid) from public, anon;
revoke all on function public.search_profile_cards(text, integer) from public, anon;
grant execute on function public.get_profile_card(uuid) to authenticated;
grant execute on function public.search_profile_cards(text, integer) to authenticated;

comment on function public.get_profile_card(uuid) is
  'Returns profile card fields filtered by each owner privacy setting, including the latest logged bodyweight and date when visible.';

create function public.get_profile_cards(target_user_ids uuid[])
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_path text,
  bio text,
  discipline text,
  training_goal text,
  age_band text,
  sex_category text,
  city text,
  region text,
  primary_gym_id uuid,
  primary_gym_name text,
  bodyweight_pounds numeric,
  bodyweight_last_updated_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select card.*
  from pg_catalog.unnest(target_user_ids) with ordinality as requested(user_id, ordinal)
  cross join lateral public.get_profile_card(requested.user_id) card
  where auth.uid() is not null
    and pg_catalog.cardinality(target_user_ids) <= 200
  order by requested.ordinal
$$;

revoke all on function public.get_profile_cards(uuid[]) from public, anon;
grant execute on function public.get_profile_cards(uuid[]) to authenticated;

comment on function public.get_profile_cards(uuid[]) is
  'Returns privacy-filtered profile cards for up to 200 requested users, preserving request order.';

-- Derive the current mobile overload from the installed canonical ranking query.
do $migration$
declare
  definition text;
  updated_definition text;
begin
  definition := pg_catalog.pg_get_functiondef('public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text)'::pg_catalog.regprocedure);
  updated_definition := pg_catalog.regexp_replace(definition, 'time_range text\s*\)', 'time_range text, repetition_count integer, city_id_filter uuid, experience_level_filter text, evidence_filter text)', 'i');
  updated_definition := pg_catalog.regexp_replace(updated_definition,
    'and l\.reps\s*=\s*1\s+and l\.is_actual_one_rep_max',
    'and (($13 is null and l.reps = 1 and l.is_actual_one_rep_max) or ($13 is not null and l.reps = $13 and ($13 <> 1 or l.is_actual_one_rep_max)))
    and ($14 is null or (pd.city_id = $14 and public.can_view_profile_field(l.user_id, pp.location_audience)))
    and ($15 is null or lower(pd.experience_level) = lower($15))
    and ($16 is null or l.evidence_status::text = $16)', 'i');
  if pg_catalog.strpos(updated_definition, 'repetition_count integer, city_id_filter uuid') = 0
    or pg_catalog.strpos(updated_definition, '$14 is null or (pd.city_id = $14') = 0
    or pg_catalog.strpos(updated_definition, '$15 is null or lower(pd.experience_level)') = 0
    or pg_catalog.strpos(updated_definition, '$16 is null or l.evidence_status::text = $16') = 0
    or pg_catalog.strpos(pg_catalog.upper(updated_definition), 'SECURITY DEFINER') = 0
    or pg_catalog.strpos(updated_definition, 'SET search_path TO ''pg_catalog''') = 0
  then raise exception 'Canonical leaderboard definition does not match the required mobile contract'; end if;
  execute updated_definition;
end;
$migration$;
revoke all on function public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text,integer,uuid,text,text) from public, anon;
grant execute on function public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text,integer,uuid,text,text) to authenticated;

-- Definer reads must enforce profile privacy as well as lift visibility.
create or replace function public.get_visible_lift_submissions(
  target_user_id uuid default null,
  target_ids uuid[] default null,
  page_limit integer default 500,
  page_offset integer default 0
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  return query
  select
    (pg_catalog.to_jsonb(l) - 'bodyweight' - 'bodyweight_class')
      || pg_catalog.jsonb_build_object(
        'bodyweight', case
          when l.user_id = auth.uid()
            or public.can_view_profile_field(l.user_id, pp.bodyweight_audience)
          then l.bodyweight
          else null
        end,
        'bodyweight_class', case
          when l.user_id = auth.uid()
            or public.can_view_profile_field(l.user_id, pp.bodyweight_audience)
          then l.bodyweight_class
          else null
        end
      )
  from public.lift_submissions l
  join public.profile_privacy pp on pp.user_id = l.user_id
  where public.can_view_profile(l.user_id)
    and (target_user_id is null or l.user_id = target_user_id)
    and (target_ids is null or l.id = any(target_ids))
    and (
      l.visibility = 'Public'
      or l.user_id = auth.uid()
      or (l.visibility = 'Friends' and public.are_friends(l.user_id, auth.uid()))
    )
  order by l.performed_at desc, l.id
  limit least(greatest(coalesce(page_limit, 500), 1), 500)
  offset greatest(coalesce(page_offset, 0), 0);
end;
$$;

revoke all on function public.get_visible_lift_submissions(uuid, uuid[], integer, integer) from public, anon;
grant execute on function public.get_visible_lift_submissions(uuid, uuid[], integer, integer) to authenticated;

drop policy if exists "profile avatars authenticated read" on storage.objects;
create policy "profile avatars authenticated read" on storage.objects
for select to authenticated
using (
  bucket_id = 'profile-avatars'
  and exists (
    select 1
    from public.profiles p
    where p.id::text = (storage.foldername(name))[1]
      and public.can_view_profile(p.id)
  )
);

-- Internal trigger helpers must not be directly callable through the API.
revoke all on function public.refresh_lift_review_state(uuid) from public, anon, authenticated, service_role;
revoke all on function public.enforce_competitive_lift_authority() from public, anon, authenticated, service_role;

-- Keep the installed view projections, including any extra compatibility columns.
do $migration$
declare
  definition text;
  view_name text;
  identity_column text;
begin
  for view_name, identity_column in select * from (values ('public_athletes', 'id'), ('public_lifts', 'athlete_id')) as views(name, identity_column)
  loop
    definition := pg_catalog.pg_get_viewdef(('public.' || view_name)::pg_catalog.regclass, true);
    if pg_catalog.strpos(definition, 'is_blocked_pair') = 0 then
      execute pg_catalog.format('create or replace view public.%I as select visible.* from (%s) visible where auth.uid() is null or not public.is_blocked_pair(visible.%I, auth.uid())', view_name, pg_catalog.rtrim(definition, E'; \n'), identity_column);
    end if;
  end loop;
end;
$migration$;
commit;
