begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(16);

select has_table('public', 'profile_reports', 'profile reports exist');
select has_function('public', 'report_profile', array['uuid', 'text', 'text'], 'profile report RPC exists');
select enum_has_labels('public', 'lift_report_reason', array[
  'Incorrect weight', 'Mismatched exercise', 'Unusable or edited video', 'Depth',
  'Range of motion', 'Lockout', 'Other', 'Harassment or bullying', 'Hate speech',
  'Nudity or sexual content', 'Violence or dangerous behavior', 'Spam or scam'
], 'lift reports include integrity and safety reasons');
select ok(
  (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'report_profile'),
  'profile report RPC is security definer'
);

create or replace function pg_temp.sqlstate_of(command text)
returns text
language plpgsql
as $$
begin
  execute command;
  return null;
exception when others then
  return sqlstate;
end;
$$;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('60000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'reporter@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('60000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'reported@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$select public.report_profile('60000000-0000-0000-0000-000000000002', 'Harassment or bullying', 'Repeated abusive profile text')$$,
  'an authenticated user can report another profile'
);
select is((select count(*)::integer from public.profile_reports), 1, 'one open profile report is stored');
select is((select reason from public.profile_reports), 'Harassment or bullying', 'the selected reason is stored');
select lives_ok(
  $$select public.report_profile('60000000-0000-0000-0000-000000000002', 'Hate speech', 'Updated details')$$,
  'a repeated open report updates safely'
);
select is((select count(*)::integer from public.profile_reports), 1, 'a reporter cannot create duplicate open reports');
select is((select note from public.profile_reports), 'Updated details', 'repeat reporting updates the note');
select throws_ok(
  $$select public.report_profile('60000000-0000-0000-0000-000000000001', 'Other', '')$$,
  '23514', 'You cannot report yourself', 'self-reporting is rejected'
);
select throws_ok(
  $$select public.report_profile('60000000-0000-0000-0000-000000000099', 'Other', '')$$,
  'P0002', 'Profile not found', 'missing profiles cannot be reported'
);
select is(
  pg_temp.sqlstate_of($$insert into public.profile_reports(reported_user_id, reporter_id, reason) values ('60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000001', 'Other')$$),
  '42501', 'direct report insertion is denied'
);

select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.profile_reports), 0, 'a reported user cannot read the report');

reset role;
select ok(has_function_privilege('authenticated', 'public.report_profile(uuid,text,text)', 'EXECUTE'), 'authenticated users can execute the report RPC');
select ok(not has_function_privilege('anon', 'public.report_profile(uuid,text,text)', 'EXECUTE'), 'anonymous users cannot execute the report RPC');
select is(
  (select position('search_path=' in array_to_string(p.proconfig, ',')) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'report_profile'),
  1,
  'profile report RPC fixes its search path'
);

select * from finish();
rollback;
