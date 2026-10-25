begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

select ok((select relrowsecurity from pg_class where oid = 'public.workout_plan_documents'::regclass), 'workout plans enforce RLS');
select ok(has_table_privilege('authenticated', 'public.workout_plan_documents', 'SELECT'), 'authenticated users can read plans subject to RLS');
select ok(has_table_privilege('authenticated', 'public.workout_plan_documents', 'INSERT'), 'authenticated users can create plans subject to RLS');
select ok(has_table_privilege('authenticated', 'public.workout_plan_documents', 'UPDATE'), 'authenticated users can update plans subject to RLS');
select ok(not has_table_privilege('authenticated', 'public.workout_plan_documents', 'DELETE'), 'plan deletion remains restricted to its RPC');
select ok(not has_table_privilege('anon', 'public.workout_plan_documents', 'SELECT'), 'anonymous users cannot read plans');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('24000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','plan-sync-owner@example.test','','{}','{}',now(),now()),
  ('24000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','plan-sync-other@example.test','','{}','{}',now(),now());
insert into public.profiles(id, username, handle, display_name) values
  ('24000000-0000-4000-8000-000000000001','plan_sync_owner','@plan_sync_owner','Plan Sync Owner'),
  ('24000000-0000-4000-8000-000000000002','plan_sync_other','@plan_sync_other','Plan Sync Other')
on conflict (id) do nothing;
insert into public.workout_plan_documents(id, owner_id, revision, name, payload) values
  ('24000000-0000-4000-8000-000000000003','24000000-0000-4000-8000-000000000001',1,'Owner plan','{}'),
  ('24000000-0000-4000-8000-000000000004','24000000-0000-4000-8000-000000000002',1,'Other plan','{}');

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000001',true);
select is((select count(*)::integer from public.workout_plan_documents), 1, 'owners can read only their own plans');
select lives_ok(
  $$update public.workout_plan_documents set name='Updated owner plan' where id='24000000-0000-4000-8000-000000000003'$$,
  'owners can update their own plans'
);
select is((select name from public.workout_plan_documents where id='24000000-0000-4000-8000-000000000003'), 'Updated owner plan', 'owner update is saved');
select lives_ok(
  $$update public.workout_plan_documents set name='Unauthorized update' where id='24000000-0000-4000-8000-000000000004'$$,
  'cross-owner update is safely filtered'
);
select is((select name from public.workout_plan_documents where owner_id='24000000-0000-4000-8000-000000000002'), null, 'another owner plan is invisible');
select lives_ok(
  $$insert into public.workout_plan_documents(id,owner_id,revision,name,payload) values ('24000000-0000-4000-8000-000000000005','24000000-0000-4000-8000-000000000001',1,'New owner plan','{}')$$,
  'owners can create their own plans'
);
select throws_ok(
  $$insert into public.workout_plan_documents(id,owner_id,revision,name,payload) values ('24000000-0000-4000-8000-000000000006','24000000-0000-4000-8000-000000000002',1,'Forged plan','{}')$$,
  '42501', 'new row violates row-level security policy for table "workout_plan_documents"',
  'owners cannot create a plan for another user'
);
reset role;
select is((select name from public.workout_plan_documents where id='24000000-0000-4000-8000-000000000004'), 'Other plan', 'cross-owner update did not change the server row');

select * from finish();
rollback;
