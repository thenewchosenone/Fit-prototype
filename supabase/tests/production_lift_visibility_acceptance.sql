-- Production-safe lift visibility acceptance. Every data mutation is rolled
-- back; only the returned visibility matrix is retained as evidence.
begin;

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

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0',
  true
);

insert into public.lift_submissions (
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max
) values
  (
    '91000000-0000-4000-8000-000000000001',
    '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0',
    'bench', null, 123, 'lb', 1, 188,
    'Friends', 'Self Reported', 'Temporary friends visibility acceptance',
    now(), true
  ),
  (
    '91000000-0000-4000-8000-000000000002',
    '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0',
    'bench', null, 124, 'lb', 1, 188,
    'Private', 'Self Reported', 'Temporary private visibility acceptance',
    now(), true
  );

create or replace function pg_temp.can_see_lift_as(viewer_id uuid, lift_id uuid)
returns boolean
language plpgsql
as $$
declare
  visible boolean;
begin
  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  select exists (
    select 1 from public.lift_submissions where id = lift_id
  ) into visible;
  return visible;
end;
$$;

select
  viewer.label,
  pg_temp.can_see_lift_as(
    viewer.id,
    '91000000-0000-4000-8000-000000000001'
  ) as sees_friends_lift,
  pg_temp.can_see_lift_as(
    viewer.id,
    '91000000-0000-4000-8000-000000000002'
  ) as sees_private_lift
from (values
  ('unrelated', 'da42a9e6-8898-45f4-8dbb-a14e2d3f8100'::uuid),
  ('same_gym', '22222222-2222-4222-8222-222222222222'::uuid),
  ('accepted_friend', '34123c1d-87d9-46fa-b776-098efcc28ef0'::uuid),
  ('owner', '1d053cb7-efe8-4ead-8e2e-ab4abf5bc9c0'::uuid)
) as viewer(label, id)
order by viewer.label;

rollback;
