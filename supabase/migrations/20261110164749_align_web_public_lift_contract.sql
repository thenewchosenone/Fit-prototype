begin;

-- A narrow projection for profile/proof reads. Do not change canonical ranking
-- authority, native RPCs, existing RLS, or legacy views used by other clients.
create function public.get_public_lift_records(
  target_athlete_id uuid default null,
  target_lift_id uuid default null
)
returns setof jsonb
language sql stable security definer
set search_path = pg_catalog
as $$
  select jsonb_build_object(
    'id', l.id,
    'athlete_id', l.user_id,
    'athlete_name', p.display_name,
    'athlete_handle', p.handle,
    'exercise_id', l.exercise_id,
    'exercise', coalesce(e.display_name, initcap(replace(l.exercise_id, '-', ' '))),
    'gym_id', case when public.public_profile_show_gym(l.user_id) then l.gym_uuid end,
    'weight', l.weight,
    'unit', l.unit,
    'reps', l.reps,
    'bodyweight', case when pp.bodyweight_audience = 'public' or public.can_view_profile_field(l.user_id, pp.bodyweight_audience) then l.bodyweight end,
    'verification', l.verification,
    'evidence_status', l.evidence_status,
    'evidence_available', l.evidence_status = 'video_backed' and pp.show_lift_videos and l.video_asset_id is not null,
    'video_asset_id', case when pp.show_lift_videos and l.evidence_status = 'video_backed' then l.video_asset_id end,
    'is_actual_one_rep_max', l.is_actual_one_rep_max,
    'competitive_movement', l.competitive_movement,
    'caption', l.caption,
    'performed_at', l.performed_at,
    'created_at', l.created_at
  )
  from public.lift_submissions l
  join public.profiles p on p.id = l.user_id
  join public.profile_privacy pp on pp.user_id = p.id
  left join public.exercises e on e.id = l.exercise_id
  where ($1 is not null or $2 is not null)
    and ($1 is null or l.user_id = $1)
    and ($2 is null or l.id = $2)
    and pp.profile_audience = 'public'
    and l.visibility = 'Public'
    and l.moderation_status = 'clear'
    and l.disputed_at is null
    and l.evidence_status in ('self_reported', 'video_backed')
    and (l.evidence_status <> 'video_backed' or l.video_asset_id is not null)
    -- Match the existing anonymous website's video-backed scope. Signed-in
    -- viewers may also read intentionally public self-reported submissions.
    and (auth.uid() is not null or (l.evidence_status = 'video_backed' and pp.show_lift_videos))
    and (auth.uid() is null or not public.is_blocked_pair(l.user_id, auth.uid()))
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
  order by l.performed_at desc, l.id;
$$;
revoke all on function public.get_public_lift_records(uuid, uuid) from public;
grant execute on function public.get_public_lift_records(uuid, uuid) to anon, authenticated;

-- Keep the deployed web signature. Delegate scores and ordering to the app's
-- canonical function, then join the current projection instead of legacy views.
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
language sql stable security definer
set search_path = pg_catalog
as $$
with canonical as (
  select * from public.get_ranked_lift_ids(
    $4,
    case replace(lower(coalesce($1, 'total')), '_', ' ')
      when 'pfp' then 'Pound-for-pound'
      when 'relative' then 'Relative total'
      when 'improved' then 'Most improved'
      else initcap(replace(lower(coalesce($1, 'total')), '_', ' '))
    end,
    $3, $2, null::text, null::text, null::text, null::text,
    null::numeric, null::numeric, $7, 'All time'
  )
), visible as (
  select c.*, record.value as lift,
    case when $1 in ('total', 'absolute') then c.score * 2.2046226218487757 else c.score end as web_score,
    case when pp.location_audience = 'public' then pd.city else null::text end as visible_city,
    case when pp.location_audience = 'public' then pd.region else null::text end as visible_region,
    case when public.public_profile_show_gym(c.user_id) then g.name else null::text end as visible_gym,
    (select count(*) from public.get_public_lift_records(c.user_id, null) item where (item ->> 'evidence_available')::boolean) as video_count
  from canonical c
  join public.lift_submissions src on src.id = c.lift_id
  join public.profile_privacy pp on pp.user_id = c.user_id
  left join public.profile_private_details pd on pd.user_id = c.user_id
  left join public.gyms g on g.id = src.gym_uuid and g.status = 'active'
  cross join lateral public.get_public_lift_records(c.user_id, c.lift_id) record(value)
  where ($5 is null or src.bodyweight_class = $5)
    and ($6 is null or src.verification::text = $6)
), ranked as (
  select dense_rank() over (order by web_score desc) as web_rank, visible.* from visible
)
select jsonb_build_object(
  'rank', web_rank, 'athlete_id', user_id,
  'public_display_name', lift ->> 'athlete_name', 'handle', lift ->> 'athlete_handle',
  'city', visible_city, 'region', visible_region,
  'gym_id', lift -> 'gym_id', 'gym_name', visible_gym,
  'latest_lift_id', lift_id, 'latest_exercise_id', lift ->> 'exercise_id',
  'latest_exercise', lift ->> 'exercise', 'latest_weight', lift -> 'weight',
  'latest_unit', lift ->> 'unit', 'latest_reps', lift -> 'reps',
  'latest_verification', lift ->> 'verification',
  'latest_evidence_available', lift -> 'evidence_available',
  'score', web_score, 'verified_lift_count', video_count
) from ranked order by web_rank, user_id;
$$;
revoke all on function public.get_public_leaderboard_v3(text,text,uuid,text,text,text,boolean) from public;
grant execute on function public.get_public_leaderboard_v3(text,text,uuid,text,text,text,boolean) to anon, authenticated;

commit;
