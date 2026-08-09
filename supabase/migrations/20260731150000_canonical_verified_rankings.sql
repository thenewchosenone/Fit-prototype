begin;
-- Normalize hosted beta fields before creating the canonical public views. The
-- same idempotent block is repeated in the latest migration so environments
-- that already applied this migration receive the compatibility boundary too.
alter table public.profile_privacy
  add column if not exists show_lift_videos boolean not null default true;

alter table public.lift_submissions
  add column if not exists gym_uuid uuid,
  add column if not exists status text not null default 'pending',
  add column if not exists bodyweight_class text,
  add column if not exists review_status text not null default 'pending',
  add column if not exists evidence_public boolean not null default false,
  add column if not exists evidence_storage_path text,
  add column if not exists pending_evidence_storage_path text,
  add column if not exists approved_evidence_storage_path text,
  add column if not exists disputed_at timestamptz,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists review_note text;

update public.lift_submissions
set gym_uuid = gym_id::uuid
where gym_uuid is null and gym_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

create or replace function public.synchronize_lift_gym_uuid()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.gym_uuid := case
    when new.gym_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then new.gym_id::uuid
    else null
  end;
  return new;
end;
$$;

drop trigger if exists a_synchronize_lift_gym_uuid on public.lift_submissions;
create trigger a_synchronize_lift_gym_uuid
before insert or update of gym_id on public.lift_submissions
for each row execute function public.synchronize_lift_gym_uuid();

create or replace function public.public_profile_show_gym(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select coalesce(
    (
      select pp.profile_audience = 'public' and pp.gym_audience = 'public'
      from public.profile_privacy pp
      where pp.user_id = target_user_id
    ),
    false
  )
$$;

revoke all on function public.public_profile_show_gym(uuid) from public;
grant execute on function public.public_profile_show_gym(uuid) to anon, authenticated;

-- Keep gym affiliation out of every public lift payload when the athlete has
-- hidden it. Approved evidence can remain part of the private owner record,
-- but an official public proof must also be intentionally public.
create or replace view public.public_lifts as
select
  ls.id,
  ls.user_id as athlete_id,
  p.display_name as athlete_display_name,
  p.handle as athlete_handle,
  ls.exercise_id,
  coalesce(e.display_name, initcap(replace(ls.exercise_id, '-', ' '))) as exercise,
  case when public.public_profile_show_gym(ls.user_id) then ls.gym_uuid::text else null end as gym_id,
  ls.weight,
  ls.unit,
  ls.reps,
  ls.bodyweight,
  ls.verification,
  ls.evidence_public and pp.show_lift_videos as evidence_public,
  case
    when ls.evidence_public and pp.show_lift_videos then coalesce(ls.approved_evidence_storage_path, ls.evidence_storage_path)
    else null
  end as evidence_storage_path,
  ls.disputed_at is not null or ls.review_status = 'disputed' as disputed,
  ls.caption,
  ls.performed_at,
  ls.created_at
from public.lift_submissions ls
join public.profiles p on p.id = ls.user_id
join public.profile_privacy pp on pp.user_id = p.id
left join public.exercises e on e.id = ls.exercise_id
where pp.profile_audience = 'public'
  and ls.visibility = 'Public'::public.lift_visibility
  and ls.review_status = 'approved'
  and ls.disputed_at is null
  and ls.verification in ('Video Verified', 'Community Verified', 'Competition Verified', 'Moderator Verified')
  and (
    nullif(ls.approved_evidence_storage_path, '') is not null
    or nullif(ls.evidence_storage_path, '') is not null
    or ls.video_asset_id is not null
  )
  and ls.id not in (
    'aaaaaaaa-0001-4001-8001-aaaaaaaaaaaa'::uuid,
    'aaaaaaaa-0002-4002-8002-aaaaaaaaaaaa'::uuid,
    'bbbbbbbb-0001-4001-8001-bbbbbbbbbbbb'::uuid,
    'bbbbbbbb-0002-4002-8002-bbbbbbbbbbbb'::uuid,
    'cccccccc-0001-4001-8001-cccccccccccc'::uuid,
    'cccccccc-0002-4002-8002-cccccccccccc'::uuid
  );

create or replace view public.public_athletes as
select
  p.id,
  p.username,
  p.display_name as public_display_name,
  p.handle,
  p.bio,
  case when pp.location_audience = 'public' then pd.city else null end as city,
  case when pp.location_audience = 'public' then pd.region else null end as region,
  case when pp.location_audience = 'public' then pd.country_code else null end as country_code,
  pd.experience_level,
  public.public_profile_show_gym(p.id) as show_gym,
  pp.show_lift_videos,
  coalesce(stats.verified_lift_count, 0) as verified_lift_count,
  coalesce(stats.total_weight, 0::numeric) as total_weight
from public.profiles p
join public.profile_privacy pp on pp.user_id = p.id
left join public.profile_private_details pd on pd.user_id = p.id
left join lateral (
  select
    count(*)::integer as verified_lift_count,
    sum(ls.weight) as total_weight
  from public.lift_submissions ls
  where ls.user_id = p.id
    and pp.show_lift_videos
    and ls.evidence_public
    and ls.visibility = 'Public'::public.lift_visibility
    and ls.review_status = 'approved'
    and ls.disputed_at is null
    and ls.verification in ('Video Verified', 'Community Verified', 'Competition Verified', 'Moderator Verified')
    and (
      nullif(ls.approved_evidence_storage_path, '') is not null
      or nullif(ls.evidence_storage_path, '') is not null
      or ls.video_asset_id is not null
    )
) stats on true
where pp.profile_audience = 'public'
  and p.id not in (
    '11111111-1111-4111-8111-111111111111'::uuid,
    '22222222-2222-4222-8222-222222222222'::uuid,
    '33333333-3333-4333-8333-333333333333'::uuid
  );

-- This is the canonical ranking contract used by the iOS app. Official mode
-- requires an approved public video. Total and Relative total require a valid
-- squat, bench, and deadlift, matching the app's 3-lift completion UI.
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
set search_path = public, pg_catalog
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
    and (
      not $11
      or (
        l.review_status = 'approved'
        and l.evidence_status = 'video_backed'
        and l.evidence_public
        and pp.show_lift_videos
        and l.verification in ('Video Verified', 'Community Verified', 'Competition Verified', 'Moderator Verified')
        and (
          nullif(l.approved_evidence_storage_path, '') is not null
          or nullif(l.evidence_storage_path, '') is not null
          or l.video_asset_id is not null
        )
      )
    )
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
    and case $12
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
        max(b.weight_kg) filter (where b.total_family = 'bench')
        + max(b.weight_kg) filter (where b.total_family = 'squat')
        + max(b.weight_kg) filter (where b.total_family = 'deadlift')
      when m.name = 'relative total' then (
        max(b.weight_kg) filter (where b.total_family = 'bench')
        + max(b.weight_kg) filter (where b.total_family = 'squat')
        + max(b.weight_kg) filter (where b.total_family = 'deadlift')
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
      or count(distinct b.total_family) = 3
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

revoke all on function public.get_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, boolean, text) from public;
grant execute on function public.get_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, boolean, text) to authenticated;

-- Public pages consume the same canonical ranks. Official website mode is
-- always verified-only; the legacy verified_only argument remains only for API
-- compatibility and cannot make self-reported records public.
create or replace function public.get_public_leaderboard_v3(
  ranking_type text default 'total',
  target_city text default null,
  target_gym_id uuid default null,
  target_exercise_id text default null,
  target_bodyweight_class text default null,
  verification_level text default null,
  verified_only boolean default true
)
returns setof jsonb
language sql
stable
security definer
set search_path = public, pg_catalog
as $function$
with canonical as (
  select *
  from public.get_ranked_lift_ids(
    $4,
    case replace(lower(coalesce($1, 'total')), '_', ' ')
      when 'pfp' then 'Pound-for-pound'
      when 'pound-for-pound' then 'Pound-for-pound'
      when 'relative' then 'Relative total'
      when 'relative total' then 'Relative total'
      when 'improved' then 'Most improved'
      when 'most improved' then 'Most improved'
      else initcap(replace(lower(coalesce($1, 'total')), '_', ' '))
    end,
    $3,
    $2,
    null,
    null,
    null,
    null,
    null,
    null,
    true,
    'All time'
  )
), visible as (
  select
    c.user_id as athlete_id,
    pa.public_display_name,
    pa.handle,
    pa.city,
    pa.region,
    case when pa.show_gym then g.id end as gym_id,
    case when pa.show_gym then g.name end as gym_name,
    pl.id as latest_lift_id,
    pl.exercise as latest_exercise,
    pl.weight as latest_weight,
    pl.unit as latest_unit,
    pl.verification as latest_verification,
    pa.verified_lift_count,
    case replace(lower(coalesce($1, 'total')), '_', ' ')
      when 'absolute' then c.score * 2.2046226218
      when 'total' then c.score * 2.2046226218
      else c.score
    end as score
  from canonical c
  join public.public_athletes pa on pa.id = c.user_id
  join public.public_lifts pl on pl.id = c.lift_id
  join public.lift_submissions src on src.id = c.lift_id
  left join public.gyms g on g.id::text = pl.gym_id and g.status = 'active' and pa.show_gym
  where ($5 is null or src.bodyweight_class = $5)
), ranked as (
  select
    dense_rank() over (order by score desc)::integer as rank,
    visible.*
  from visible
  where score is not null and score > 0
)
select jsonb_build_object(
  'rank', rank,
  'athlete_id', athlete_id,
  'public_display_name', public_display_name,
  'handle', handle,
  'city', city,
  'region', region,
  'gym_id', gym_id,
  'gym_name', gym_name,
  'latest_lift_id', latest_lift_id,
  'latest_exercise', latest_exercise,
  'latest_weight', latest_weight,
  'latest_unit', latest_unit,
  'latest_verification', latest_verification,
  'score', score,
  'verified_lift_count', verified_lift_count
)
from ranked
order by rank, public_display_name;
$function$;

revoke all on function public.get_public_leaderboard_v3(text, text, uuid, text, text, text, boolean) from public;
grant execute on function public.get_public_leaderboard_v3(text, text, uuid, text, text, text, boolean) to anon, authenticated;

commit;
