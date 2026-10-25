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
