begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(26);

select has_function(
  'public', 'save_bodyweight_checkin', array['uuid', 'numeric', 'timestamp with time zone', 'text'],
  'bodyweight check-in RPC exists after the forward correction'
);
select is_definer(
  'public', 'save_bodyweight_checkin', array['uuid', 'numeric', 'timestamp with time zone', 'text'],
  'bodyweight correction remains server-authoritative'
);
select is(
  (select position('search_path=' in array_to_string(p.proconfig, ','))
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'save_bodyweight_checkin'),
  1,
  'bodyweight correction fixes its search path'
);
select ok(
  has_function_privilege('authenticated', 'public.save_bodyweight_checkin(uuid,numeric,timestamptz,text)', 'EXECUTE'),
  'authenticated athletes can save bodyweight check-ins'
);
select ok(
  not has_function_privilege('anon', 'public.save_bodyweight_checkin(uuid,numeric,timestamptz,text)', 'EXECUTE'),
  'anonymous users cannot save bodyweight check-ins'
);
select has_function(
  'public', 'delete_bodyweight_checkin', array['uuid'],
  'owner bodyweight delete RPC exists'
);
select is_definer(
  'public', 'delete_bodyweight_checkin', array['uuid'],
  'bodyweight delete remains server-authoritative'
);
select is(
  (select position('search_path=' in array_to_string(p.proconfig, ','))
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'delete_bodyweight_checkin'),
  1,
  'bodyweight delete fixes its search path'
);
select ok(
  has_function_privilege('authenticated', 'public.delete_bodyweight_checkin(uuid)', 'EXECUTE'),
  'authenticated athletes can delete bodyweight check-ins'
);
select ok(
  not has_function_privilege('anon', 'public.delete_bodyweight_checkin(uuid)', 'EXECUTE'),
  'anonymous users cannot delete bodyweight check-ins'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('92000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bodyweight-latest-one@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('92000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bodyweight-latest-two@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '92000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$select public.save_bodyweight_checkin('93000000-0000-0000-0000-000000000001', 205, '2026-01-01T11:45:00Z', 'Older entry')$$,
  'an athlete can create the first dated entry'
);
select is(
  (select bodyweight_lb from public.profile_private_details where user_id = auth.uid()),
  205::numeric,
  'first dated entry becomes current bodyweight'
);
select lives_ok(
  $$select public.save_bodyweight_checkin('93000000-0000-0000-0000-000000000002', 198, '2026-02-01T11:45:00Z', 'Newer entry')$$,
  'an athlete can create a newer dated entry'
);
select is(
  (select bodyweight_lb from public.profile_private_details where user_id = auth.uid()),
  198::numeric,
  'newest dated entry becomes current bodyweight'
);
select lives_ok(
  $$select public.save_bodyweight_checkin('93000000-0000-0000-0000-000000000001', 203, '2026-01-01T11:45:00Z', 'Edited older entry')$$,
  'an athlete can edit an older dated entry'
);
select is(
  (select bodyweight_lb from public.profile_private_details where user_id = auth.uid()),
  198::numeric,
  'editing an older entry preserves the newest current bodyweight'
);
select lives_ok(
  $$select public.save_bodyweight_checkin('93000000-0000-0000-0000-000000000001', 202, '2026-03-01T11:45:00Z', 'Moved latest entry')$$,
  'an athlete can move a dated entry to a newer date'
);
select is(
  (select bodyweight_lb from public.profile_private_details where user_id = auth.uid()),
  202::numeric,
  'editing an entry to the latest date makes its weight current'
);
select lives_ok(
  $$select public.delete_bodyweight_checkin('93000000-0000-0000-0000-000000000002')$$,
  'an athlete can delete an older owned check-in'
);
select is(
  (select bodyweight_lb from public.profile_private_details where user_id = auth.uid()),
  202::numeric,
  'deleting an older entry preserves the current latest bodyweight'
);
select lives_ok(
  $$select public.save_bodyweight_checkin('93000000-0000-0000-0000-000000000002', 198, '2026-02-01T11:45:00Z', 'Restore older entry')$$,
  'an athlete can add another dated row after deletion'
);
select lives_ok(
  $$select public.delete_bodyweight_checkin('93000000-0000-0000-0000-000000000001')$$,
  'an athlete can delete an owned check-in'
);
select is(
  (select bodyweight_lb from public.profile_private_details where user_id = auth.uid()),
  198::numeric,
  'deleting the latest entry restores the latest remaining bodyweight'
);

select set_config('request.jwt.claim.sub', '92000000-0000-0000-0000-000000000002', true);
select is(
  (select count(*)::integer from public.bodyweight_records),
  0,
  'another athlete cannot read the check-ins'
);
select throws_ok(
  $$select public.save_bodyweight_checkin('93000000-0000-0000-0000-000000000002', 199, now(), 'Not mine')$$,
  '42501', 'Bodyweight check-in belongs to another athlete',
  'another athlete cannot edit an existing check-in id'
);
select throws_ok(
  $$select public.delete_bodyweight_checkin('93000000-0000-0000-0000-000000000002')$$,
  '42501', 'Bodyweight check-in belongs to another athlete',
  'another athlete cannot delete an existing check-in'
);

select * from finish();
rollback;
