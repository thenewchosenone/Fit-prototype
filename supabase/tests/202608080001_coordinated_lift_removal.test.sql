begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);
select has_table('public', 'lift_removal_requests', 'durable lift removal requests exist');
select has_function('public', 'finalize_lift_removal', array['uuid'], 'trusted removal finalizer exists');
select ok(not has_function_privilege('authenticated', 'public.finalize_lift_removal(uuid)', 'EXECUTE'), 'clients cannot bypass coordinated cleanup');
select ok(has_function_privilege('service_role', 'public.finalize_lift_removal(uuid)', 'EXECUTE'), 'only the service workflow can finalize removal');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '98000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'removal@example.test', '',
  '{}'::jsonb, '{}'::jsonb, now(), now()
);

select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000001', true);

insert into public.lift_submissions (
  id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight,
  visibility, verification, caption, performed_at, is_actual_one_rep_max
) values (
  '98000000-0000-4000-8000-000000000002',
  '98000000-0000-4000-8000-000000000001',
  'bench', null, 225, 'lb', 1, 180,
  'Private', 'Self Reported', '', now(), true
);

insert into public.lift_moderation_audit(lift_id, event, resulting_status)
values ('98000000-0000-4000-8000-000000000002', 'test', 'clear');

insert into public.lift_removal_requests(id, lift_id, owner_id, status, lift_snapshot)
values (
  '98000000-0000-4000-8000-000000000003',
  '98000000-0000-4000-8000-000000000002',
  '98000000-0000-4000-8000-000000000001',
  'processing',
  '{}'::jsonb
);

set local role service_role;
select is(
  public.finalize_lift_removal('98000000-0000-4000-8000-000000000003'),
  true,
  'service workflow finalizes removal'
);
reset role;

select is((select count(*)::integer from public.lift_submissions where id = '98000000-0000-4000-8000-000000000002'), 0, 'submission is deleted');
select is((select count(*)::integer from public.lift_moderation_audit where lift_id = '98000000-0000-4000-8000-000000000002'), 0, 'moderation state is cleaned');
select is((select status from public.lift_removal_requests where id = '98000000-0000-4000-8000-000000000003'), 'completed', 'durable request records completion');

set local role service_role;
select is(
  public.finalize_lift_removal('98000000-0000-4000-8000-000000000003'),
  true,
  'finalization is idempotent'
);
reset role;

select * from finish();
rollback;
