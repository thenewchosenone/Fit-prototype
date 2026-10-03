-- Compact server-computed leaderboard results. RLS/profile privacy remain in
-- force when the client subsequently fetches lift and profile detail.
create or replace function public.get_ranked_lift_ids(
  exercise_id text,
  ranking_type text,
  gym_id uuid,
  city text,
  region text,
  country text,
  age_band text,
  sex_category text,
  weight_min_kg numeric,
  weight_max_kg numeric,
  verified_only boolean,
  time_range text
)
returns table(rank bigint, lift_id uuid, user_id uuid, score double precision, rank_movement integer, bodyweight_visible boolean)
language sql
stable
security definer
set search_path = public
as $$
with eligible as (
  select
    l.*,
    case when l.unit='kg' then l.weight::double precision else l.weight::double precision * 0.45359237 end as weight_kg,
    case when l.bodyweight is null then null else l.bodyweight::double precision * 0.45359237 end as bodyweight_kg
  from public.lift_submissions l
  join public.profile_private_details pd on pd.user_id=l.user_id
  join public.profile_privacy pp on pp.user_id=l.user_id
  where l.visibility='Public'
    and l.reps=1 and l.is_actual_one_rep_max and l.competitive_movement is not null
    and l.moderation_status <> 'rejected'
    and l.leaderboard_eligible_at is not null and l.leaderboard_eligible_at <= statement_timestamp()
    and (not verified_only or l.evidence_status='video_backed')
    and not public.is_blocked_pair(l.user_id,auth.uid())
    and (exercise_id is null or l.competitive_movement::text = case replace(lower(exercise_id),'-','_')
      when 'bench' then 'barbell_bench_press' when 'squat' then 'back_squat' when 'deadlift' then 'conventional_deadlift'
      when 'press' then 'standing_barbell_overhead_press' when 'barbell_overhead_press' then 'standing_barbell_overhead_press'
      when 'barbell_row' then 'bent_over_barbell_row' else replace(lower(exercise_id),'-','_') end)
    and (gym_id is null or l.gym_id = gym_id::text)
    and (city is null or (lower(pd.city)=lower(city) and public.can_view_profile_field(l.user_id,pp.location_audience)))
    and (region is null or (lower(pd.region)=lower(region) and public.can_view_profile_field(l.user_id,pp.location_audience)))
    and (country is null or (lower(pd.country_code)=lower(country) and public.can_view_profile_field(l.user_id,pp.location_audience)))
    and (age_band is null or (public.age_band_from_birth_date(pd.birth_date)=age_band and public.can_view_profile_field(l.user_id,pp.age_band_audience)))
    and (sex_category is null or (lower(pd.sex_category)=lower(sex_category) and public.can_view_profile_field(l.user_id,pp.division_audience)))
    and (weight_min_kg is null or l.bodyweight::double precision * 0.45359237 > weight_min_kg)
    and (weight_max_kg is null or l.bodyweight::double precision * 0.45359237 <= weight_max_kg)
    and case time_range
      when 'This week' then l.performed_at >= statement_timestamp() - interval '7 days'
      when 'This month' then l.performed_at >= statement_timestamp() - interval '1 month'
      when 'Last 90 days' then l.performed_at >= statement_timestamp() - interval '90 days'
      when 'This year' then l.performed_at >= date_trunc('year',statement_timestamp())
      else true end
), best_by_movement as (
  select distinct on (user_id,competitive_movement) * from eligible
  order by user_id,competitive_movement,weight_kg desc,performed_at asc
), scored as (
  select
    b.user_id,
    (array_agg(b.id order by b.weight_kg desc))[1] as lift_id,
    case
      when ranking_type in ('Total','Relative total') then
        coalesce(max(b.weight_kg) filter(where b.competitive_movement='barbell_bench_press'),0)
        + coalesce(max(b.weight_kg) filter(where b.competitive_movement='back_squat'),0)
        + coalesce(max(b.weight_kg) filter(where b.competitive_movement in ('conventional_deadlift','sumo_deadlift')),0)
      when ranking_type='Pound-for-pound' then max(b.weight_kg/nullif(b.bodyweight_kg,0))
      else max(b.weight_kg)
    end * case when ranking_type='Relative total' then 1/nullif(max(b.bodyweight_kg),0) else 1 end as score
  from best_by_movement b
  where ranking_type not in ('Total','Relative total')
     or b.competitive_movement in ('barbell_bench_press','back_squat','conventional_deadlift','sumo_deadlift')
  group by b.user_id
), ranked as (
  select dense_rank() over(order by score desc) as rank,lift_id,user_id,score from scored
)
select ranked.rank,ranked.lift_id,ranked.user_id,ranked.score,0,
  public.can_view_profile_field(ranked.user_id,pp.bodyweight_audience)
from ranked join public.profile_privacy pp on pp.user_id=ranked.user_id
order by ranked.rank,ranked.user_id;
$$;

revoke all on function public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text) from public;
grant execute on function public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text) to authenticated;
