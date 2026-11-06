begin;

-- Rank public self-reported lifts in their own evidence universe before the
-- 200-row API page is applied. Keep the existing all-lift and video queries intact.
create or replace function public.get_self_reported_ranked_lift_ids(
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
  time_range text
)
returns table(
  rank bigint,
  lift_id uuid,
  user_id uuid,
  score double precision,
  rank_movement integer,
  bodyweight_visible boolean
)
language sql
stable
security definer
set search_path = pg_catalog
as $function$
with mode as (
  select replace(lower(coalesce($2, 'Total')), '_', ' ') as name
), eligible as (
  select
    l.*,
    case when l.unit = 'kg' then l.weight::double precision else l.weight::double precision * 0.45359237 end as weight_kg,
    case when l.bodyweight is null then null else l.bodyweight::double precision * 0.45359237 end as bodyweight_kg,
    case
      when l.competitive_movement = 'barbell_bench_press' then 'bench'
      when l.competitive_movement = 'back_squat' then 'squat'
      when l.competitive_movement in ('conventional_deadlift', 'sumo_deadlift') then 'deadlift'
      else null
    end as total_family
  from public.lift_submissions l
  join public.profile_private_details pd on pd.user_id = l.user_id
  join public.profile_privacy pp on pp.user_id = l.user_id
  where pp.profile_audience = 'public'
    and l.visibility = 'Public'
    and l.reps = 1
    and l.is_actual_one_rep_max
    and l.competitive_movement is not null
    and l.moderation_status = 'clear'
    and l.disputed_at is null
    and l.leaderboard_eligible_at is not null
    and l.leaderboard_eligible_at <= statement_timestamp()
    and l.evidence_status = 'self_reported'
    and not public.is_blocked_pair(l.user_id, auth.uid())
    and (
      $1 is null
      or l.competitive_movement::text = case replace(lower($1), '-', '_')
        when 'bench' then 'barbell_bench_press'
        when 'squat' then 'back_squat'
        when 'deadlift' then 'conventional_deadlift'
        when 'press' then 'standing_barbell_overhead_press'
        when 'barbell_overhead_press' then 'standing_barbell_overhead_press'
        when 'barbell_row' then 'bent_over_barbell_row'
        else replace(lower($1), '-', '_')
      end
    )
    and ($3 is null or l.gym_id = $3::text or l.gym_uuid = $3)
    and ($4 is null or (lower(pd.city) = lower($4) and public.can_view_profile_field(l.user_id, pp.location_audience)))
    and ($5 is null or (lower(pd.region) = lower($5) and public.can_view_profile_field(l.user_id, pp.location_audience)))
    and ($6 is null or (lower(pd.country_code) = lower($6) and public.can_view_profile_field(l.user_id, pp.location_audience)))
    and ($7 is null or (public.age_band_from_birth_date(pd.birth_date) = $7 and public.can_view_profile_field(l.user_id, pp.age_band_audience)))
    and ($8 is null or (lower(pd.sex_category) = lower($8) and public.can_view_profile_field(l.user_id, pp.division_audience)))
    and ($9 is null or l.bodyweight::double precision * 0.45359237 > $9)
    and ($10 is null or l.bodyweight::double precision * 0.45359237 <= $10)
    and case $11
      when 'This week' then l.performed_at >= statement_timestamp() - interval '7 days'
      when 'This month' then l.performed_at >= statement_timestamp() - interval '1 month'
      when 'Last 90 days' then l.performed_at >= statement_timestamp() - interval '90 days'
      when 'This year' then l.performed_at >= date_trunc('year', statement_timestamp())
      else true
    end
    and l.user_id not in (
      '11111111-1111-4111-8111-111111111111'::uuid,
      '22222222-2222-4222-8222-222222222222'::uuid,
      '33333333-3333-4333-8333-333333333333'::uuid
    )
    and l.id not in (
      'aaaaaaaa-0001-4001-8001-aaaaaaaaaaaa'::uuid,
      'aaaaaaaa-0002-4002-8002-aaaaaaaaaaaa'::uuid,
      'bbbbbbbb-0001-4001-8001-bbbbbbbbbbbb'::uuid,
      'bbbbbbbb-0002-4002-8002-bbbbbbbbbbbb'::uuid,
      'cccccccc-0001-4001-8001-cccccccccccc'::uuid,
      'cccccccc-0002-4002-8002-cccccccccccc'::uuid
    )
), progress as (
  select
    eligible.*,
    max(weight_kg) over (
      partition by user_id, competitive_movement
      order by performed_at, id
      rows between unbounded preceding and 1 preceding
    ) as prior_best_kg
  from eligible
), best_by_movement as (
  select distinct on (user_id, competitive_movement) *
  from progress
  order by user_id, competitive_movement, weight_kg desc, performed_at asc, id
), scored as (
  select
    b.user_id,
    (array_agg(
      b.id
      order by
        case
          when m.name = 'pound-for-pound' then b.weight_kg / nullif(b.bodyweight_kg, 0)
          when m.name = 'most improved' then ((b.weight_kg - b.prior_best_kg) / nullif(b.prior_best_kg, 0)) * 100
          else b.weight_kg
        end desc nulls last,
        b.performed_at desc,
        b.id
    ))[1] as lift_id,
    case
      when m.name = 'total' then
        coalesce(max(b.weight_kg) filter (where b.total_family = 'bench'), 0)
        + coalesce(max(b.weight_kg) filter (where b.total_family = 'squat'), 0)
        + coalesce(max(b.weight_kg) filter (where b.total_family = 'deadlift'), 0)
      when m.name = 'relative total' then (
        coalesce(max(b.weight_kg) filter (where b.total_family = 'bench'), 0)
        + coalesce(max(b.weight_kg) filter (where b.total_family = 'squat'), 0)
        + coalesce(max(b.weight_kg) filter (where b.total_family = 'deadlift'), 0)
      ) / nullif(max(b.bodyweight_kg), 0)
      when m.name = 'pound-for-pound' then max(b.weight_kg / nullif(b.bodyweight_kg, 0))
      when m.name = 'most improved' then max(((b.weight_kg - b.prior_best_kg) / nullif(b.prior_best_kg, 0)) * 100)
      else max(b.weight_kg)
    end as score
  from best_by_movement b
  cross join mode m
  where m.name not in ('total', 'relative total') or b.total_family is not null
  group by b.user_id, m.name
  having (
      m.name not in ('total', 'relative total')
      or count(distinct b.total_family) >= 1
    )
    and (
      m.name <> 'most improved'
      or max(((b.weight_kg - b.prior_best_kg) / nullif(b.prior_best_kg, 0)) * 100) > 0
    )
), ranked as (
  select
    dense_rank() over (order by score desc) as rank,
    lift_id,
    user_id,
    score
  from scored
  where score is not null and score > 0
)
select
  ranked.rank,
  ranked.lift_id,
  ranked.user_id,
  ranked.score,
  0 as rank_movement,
  public.can_view_profile_field(ranked.user_id, pp.bodyweight_audience) as bodyweight_visible
from ranked
join public.profile_privacy pp on pp.user_id = ranked.user_id
order by ranked.rank, ranked.user_id;
$function$;

revoke all on function public.get_self_reported_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, text) from public, anon;
grant execute on function public.get_self_reported_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, text) to authenticated;

commit;
