begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

select ok(
  has_table_privilege('authenticated', 'public.workout_plan_documents', 'DELETE'),
  'authenticated plan cleanup has its required table privilege'
);
select ok(
  (select relrowsecurity from pg_catalog.pg_class
   where oid = 'public.workout_plan_documents'::regclass),
  'plan ownership row security remains enabled'
);

-- Match the existing production read privilege needed by DELETE ... RETURNING.
grant select on public.workout_plan_documents to authenticated;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  ('d1100000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'plan-delete-' || n || '@example.test', '', '{}'::jsonb,
  jsonb_build_object('display_name', 'Plan Delete ' || n), now(), now()
from generate_series(1, 2) n;

insert into public.workout_plan_documents(id, owner_id, revision, name, payload)
values
  ('d1200000-0000-4000-8000-000000000001', 'd1100000-0000-4000-8000-000000000001', 3, 'Plan (Conflict copy)', '{}'::jsonb),
  ('d1200000-0000-4000-8000-000000000002', 'd1100000-0000-4000-8000-000000000002', 1, 'Other owner plan', '{}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1100000-0000-4000-8000-000000000001', true);
with removed as (
    delete from public.workout_plan_documents
    where id = 'd1200000-0000-4000-8000-000000000001' and revision = 2
    returning id
  )
select is((select count(*) from removed),
  0::bigint, 'cleanup cannot delete a newer plan revision'
);

select set_config('request.jwt.claim.sub', 'd1100000-0000-4000-8000-000000000002', true);
with removed as (
    delete from public.workout_plan_documents
    where id = 'd1200000-0000-4000-8000-000000000001'
    returning id
  )
select is((select count(*) from removed),
  0::bigint, 'another owner cannot delete a plan even when its ID is known'
);

reset role;
select is(
  (select count(*) from public.workout_plan_documents
   where id = 'd1200000-0000-4000-8000-000000000001'),
  1::bigint, 'the protected plan survives the rejected deletions'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1100000-0000-4000-8000-000000000001', true);
with removed as (
    delete from public.workout_plan_documents
    where owner_id = 'd1100000-0000-4000-8000-000000000001'
      and id = 'd1200000-0000-4000-8000-000000000001' and revision = 3
    returning id
  )
select is((select count(*) from removed),
  1::bigint, 'the owner can delete the matching revision and receive confirmation'
);

select set_config('request.jwt.claim.sub', '', true);
with removed as (
    delete from public.workout_plan_documents
    where id = 'd1200000-0000-4000-8000-000000000002'
    returning id
  )
select is((select count(*) from removed),
  0::bigint, 'a missing authenticated identity cannot delete plans'
);

reset role;
select is(
  (select count(*) from public.workout_plan_documents
   where id = 'd1200000-0000-4000-8000-000000000002'),
  1::bigint, 'the other owner plan remains intact'
);

select * from finish();
rollback;
