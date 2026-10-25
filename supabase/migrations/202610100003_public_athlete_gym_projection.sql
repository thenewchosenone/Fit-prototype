begin;

-- Public athlete pages need the primary gym name that iOS receives from the
-- profile card. Expose it only when both profile and gym audiences are public.
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
  coalesce(stats.total_weight, 0::numeric) as total_weight,
  case when public.public_profile_show_gym(p.id) then gm.gym_id else null end as primary_gym_id,
  case when public.public_profile_show_gym(p.id) then g.name else null end as primary_gym_name
from public.profiles p
join public.profile_privacy pp on pp.user_id = p.id
left join public.profile_private_details pd on pd.user_id = p.id
left join public.gym_memberships gm
  on gm.user_id = p.id and gm.is_primary and gm.left_at is null
left join public.gyms g on g.id = gm.gym_id
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

commit;
