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
