begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select has_table('public', 'bodyweight_records', 'bodyweight history exists');
select has_function(
  'public', 'save_bodyweight_checkin', array['uuid', 'numeric', 'timestamp with time zone', 'text'],
  'atomic bodyweight check-in RPC exists'
);
select is_definer(
  'public', 'save_bodyweight_checkin', array['uuid', 'numeric', 'timestamp with time zone', 'text'],
  'bodyweight check-ins use trusted server authority'
);
select is(
  (select position('search_path=' in array_to_string(p.proconfig, ','))
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'save_bodyweight_checkin'),
  1,
  'bodyweight check-in authority fixes its search path'
);
select ok(has_table_privilege('authenticated', 'public.bodyweight_records', 'SELECT'), 'authenticated owners can read bodyweight history');
select ok(has_table_privilege('authenticated', 'public.bodyweight_records', 'INSERT'), 'authenticated owners can insert bodyweight history');
select ok(has_table_privilege('authenticated', 'public.bodyweight_records', 'UPDATE'), 'authenticated owners can update bodyweight history');
select ok(not has_table_privilege('authenticated', 'public.bodyweight_records', 'DELETE'), 'authenticated clients cannot delete bodyweight history directly');
select ok(not has_table_privilege('anon', 'public.bodyweight_records', 'SELECT'), 'anonymous clients cannot read bodyweight history');
select ok(has_function_privilege('authenticated', 'public.save_bodyweight_checkin(uuid,numeric,timestamptz,text)', 'EXECUTE'), 'authenticated users can save a check-in');
select ok(not has_function_privilege('anon', 'public.save_bodyweight_checkin(uuid,numeric,timestamptz,text)', 'EXECUTE'), 'anonymous users cannot save a check-in');

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
) values
  ('90000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bodyweight-one@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('90000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bodyweight-two@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$select public.save_bodyweight_checkin('91000000-0000-0000-0000-000000000001', 188, '2026-08-09T11:45:00Z', 'Release acceptance')$$,
  'an athlete can save a bodyweight check-in'
);
select is((select weight from public.bodyweight_records where id = '91000000-0000-0000-0000-000000000001'), 188::numeric, 'history stores the new bodyweight');
select is((select bodyweight_lb from public.profile_private_details where user_id = auth.uid()), 188::numeric, 'current private profile weight updates atomically');

select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.bodyweight_records), 0, 'another athlete cannot read the check-in');
select throws_ok(
  $$select public.save_bodyweight_checkin('91000000-0000-0000-0000-000000000001', 199, now(), 'Not mine')$$,
  '42501', 'Bodyweight check-in belongs to another athlete',
  'another athlete cannot replace an existing check-in id'
);
select lives_ok(
  $$insert into public.bodyweight_records(id, user_id, weight, recorded_at) values ('91000000-0000-0000-0000-000000000002', auth.uid(), 199, now())$$,
  'the owner-only table grant supports local history synchronization'
);
select is(
  pg_temp.sqlstate_of($$insert into public.bodyweight_records(id, user_id, weight, recorded_at) values ('91000000-0000-0000-0000-000000000003', '90000000-0000-0000-0000-000000000001', 200, now())$$),
  '42501', 'row-level security still rejects cross-owner inserts'
);

select * from finish();
rollback;
