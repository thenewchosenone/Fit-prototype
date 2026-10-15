-- Production-safe relationship/privacy acceptance. Every data mutation is
-- rolled back; only the returned matrix is retained as evidence.
begin;

update public.profile_privacy
set profile_audience = 'public',
    age_band_audience = 'public',
    division_audience = 'friends',
    bodyweight_audience = 'private',
    location_audience = 'gym',
    gym_audience = 'public',
    friend_list_audience = 'private'
where user_id = '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0';

insert into public.friend_relationships (
  user_low_id, user_high_id, requested_by, status, responded_at
) values (
  '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0',
  '34123c1d-87d9-46fa-b776-098efcc28ef0',
  '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0',
  'accepted',
  now()
)
on conflict (user_low_id, user_high_id) do update
set status = 'accepted', responded_at = now();

create or replace function pg_temp.can_view_as(viewer_id uuid, audience text)
returns boolean
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  return public.can_view_profile_field(
    '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0',
    audience
  );
end;
$$;

create or replace function pg_temp.card_as(viewer_id uuid)
returns jsonb
language plpgsql
as $$
declare
  result jsonb;
begin
  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  select to_jsonb(card) into result
  from public.get_profile_card('1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0') card;
  return result;
end;
$$;

select
  viewer.label,
  pg_temp.can_view_as(viewer.id, 'public') as sees_public,
  pg_temp.can_view_as(viewer.id, 'friends') as sees_friends,
  pg_temp.can_view_as(viewer.id, 'gym') as sees_gym,
  pg_temp.can_view_as(viewer.id, 'private') as sees_private,
  pg_temp.card_as(viewer.id) as profile_card
from (values
  ('unrelated', 'da42a9e6-8898-45f4-8dbb-a14e2d3f8100'::uuid),
  ('same_gym', '22222222-2222-4222-8222-222222222222'::uuid),
  ('accepted_friend', '34123c1d-87d9-46fa-b776-098efcc28ef0'::uuid),
  ('owner', '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0'::uuid)
) as viewer(label, id)
order by viewer.label;

rollback;
