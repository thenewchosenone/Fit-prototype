begin;

create or replace function public.visible_lift_bodyweight(target_lift_id uuid)
returns numeric
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select case
    when pp.bodyweight_audience = 'public'
      or public.can_view_profile_field(l.user_id, pp.bodyweight_audience)
    then l.bodyweight
    else null
  end
  from public.lift_submissions l
  join public.profile_privacy pp on pp.user_id = l.user_id
  where l.id = target_lift_id
    and (
      l.visibility = 'Public'
      or l.user_id = auth.uid()
      or (l.visibility = 'Friends' and public.are_friends(l.user_id, auth.uid()))
    )
$$;

revoke all on function public.visible_lift_bodyweight(uuid) from public;
grant execute on function public.visible_lift_bodyweight(uuid) to anon, authenticated;

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
  public.visible_lift_bodyweight(ls.id) as bodyweight,
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

alter view public.public_lifts set (security_invoker = true);

revoke select on table public.lift_submissions from public, anon, authenticated;
grant select (
  id, user_id, exercise_id, gym_id, weight, unit, reps, visibility, verification,
  caption, performed_at, created_at, repetitions, is_actual_one_rep_max,
  competitive_movement, evidence_status, moderation_status, weight_per_hand,
  leaderboard_eligible_at, updated_at, video_asset_id, approved_evidence_storage_path,
  pending_evidence_storage_path, evidence_storage_path, review_status, evidence_public,
  gym_uuid, status, reviewed_at, reviewed_by,
  review_note, disputed_at
) on table public.lift_submissions to anon, authenticated;
grant select on table public.public_lifts to anon, authenticated;

create function public.get_visible_lift_submissions(
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
  where (target_user_id is null or l.user_id = target_user_id)
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

commit;
