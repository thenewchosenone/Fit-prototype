begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);

select has_table('public', 'workout_plan_deletions', 'workout plan deletion tombstones exist');
select ok((select relrowsecurity from pg_class where oid = 'public.workout_plan_deletions'::regclass), 'deletion tombstones enforce RLS');
select has_function('public', 'delete_own_workout_plan', array['uuid'], 'authenticated plan deletion is atomic');
select ok(has_function_privilege('authenticated', 'public.delete_own_workout_plan(uuid)', 'EXECUTE'), 'authenticated owners can delete plans');
select ok(not has_function_privilege('anon', 'public.delete_own_workout_plan(uuid)', 'EXECUTE'), 'anonymous callers cannot delete plans');
select ok(has_table_privilege('authenticated', 'public.workout_plan_deletions', 'SELECT'), 'authenticated users can read their tombstones');
select ok(not has_table_privilege('authenticated', 'public.workout_plan_deletions', 'INSERT'), 'clients cannot forge tombstones');
select ok(not has_table_privilege('authenticated', 'public.workout_plan_deletions', 'UPDATE'), 'clients cannot alter tombstones');
select ok(not has_table_privilege('authenticated', 'public.workout_plan_deletions', 'DELETE'), 'clients cannot remove tombstones');
select has_trigger('public', 'workout_plan_documents', 'prevent_deleted_workout_plan_reinsert', 'deleted plans cannot be reinserted');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('91000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','plan-owner@example.test','','{}','{}',now(),now()),
  ('91000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','plan-other@example.test','','{}','{}',now(),now());
insert into public.profiles(id, username, handle, display_name) values
  ('91000000-0000-4000-8000-000000000001','plan_owner','@plan_owner','Plan Owner'),
  ('91000000-0000-4000-8000-000000000002','plan_other','@plan_other','Other User')
on conflict (id) do nothing;

insert into public.workout_plan_documents(id, owner_id, revision, name, payload)
values ('91000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000001',1,'Offline risk plan','{"plan":{"name":"Offline risk plan"}}');

set local role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select is(public.delete_own_workout_plan('91000000-0000-4000-8000-000000000003'), true, 'owner deletes and tombstones the plan');
select is((select count(*)::integer from public.workout_plan_documents where id='91000000-0000-4000-8000-000000000003'), 0, 'plan row is removed atomically');
select is((select count(*)::integer from public.workout_plan_deletions where plan_id='91000000-0000-4000-8000-000000000003'), 1, 'owner can see the durable tombstone');
select throws_ok(
  $$insert into public.workout_plan_documents(id,owner_id,revision,name,payload) values ('91000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000001',1,'Stale copy','{"plan":{"name":"Stale copy"}}')$$,
  'P0001', 'Workout plan has been deleted', 'stale offline copy cannot restore a deleted plan'
);
select is(public.delete_own_workout_plan('91000000-0000-4000-8000-000000000003'), true, 'deletion retry is idempotent');
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000002',true);
select is((select count(*)::integer from public.workout_plan_deletions where plan_id='91000000-0000-4000-8000-000000000003'), 0, 'another user cannot read the owner tombstone');
select is(public.delete_own_workout_plan('91000000-0000-4000-8000-000000000003'), false, 'another user cannot claim a deletion for the owner plan');
reset role;

select * from finish();
rollback;
