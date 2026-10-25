begin;
select plan(8);

select ok(
  (select prosecdef from pg_proc where oid = 'public.is_blocked_pair(uuid,uuid)'::regprocedure),
  'block-pair lookup runs with controlled definer privileges'
);
select ok(
  (select 'search_path=pg_catalog' = any(proconfig) from pg_proc where oid = 'public.is_blocked_pair(uuid,uuid)'::regprocedure),
  'block-pair lookup pins its search path'
);
select ok(has_function_privilege('anon', 'public.is_blocked_pair(uuid,uuid)', 'EXECUTE'), 'public athlete view can evaluate block status anonymously');
select ok(has_function_privilege('authenticated', 'public.is_blocked_pair(uuid,uuid)', 'EXECUTE'), 'authenticated profile paths can evaluate block status');

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('98000000-0000-4000-8000-000000000201', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'block-view-target@example.test', '', '{}', '{}', now(), now()),
  ('98000000-0000-4000-8000-000000000202', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'block-viewer@example.test', '', '{}', '{}', now(), now());

update public.profile_privacy
set profile_audience = 'public'
where user_id = '98000000-0000-4000-8000-000000000201';

set local role authenticated;
select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000202', true);
select is(
  (select count(*)::integer from public.public_athletes where id = '98000000-0000-4000-8000-000000000201'),
  1,
  'unblocked authenticated viewers can discover public athletes'
);
reset role;

insert into public.user_blocks(blocker_id, blocked_id)
values ('98000000-0000-4000-8000-000000000202', '98000000-0000-4000-8000-000000000201');
set local role authenticated;
select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000202', true);
select is(
  (select count(*)::integer from public.public_athletes where id = '98000000-0000-4000-8000-000000000201'),
  0,
  'an authenticated block hides the target from athlete discovery'
);
reset role;

delete from public.user_blocks
where blocker_id = '98000000-0000-4000-8000-000000000202'
  and blocked_id = '98000000-0000-4000-8000-000000000201';
insert into public.user_blocks(blocker_id, blocked_id)
values ('98000000-0000-4000-8000-000000000201', '98000000-0000-4000-8000-000000000202');
set local role authenticated;
select set_config('request.jwt.claim.sub', '98000000-0000-4000-8000-000000000202', true);
select is(
  (select count(*)::integer from public.public_athletes where id = '98000000-0000-4000-8000-000000000201'),
  0,
  'a reverse-direction block also hides the target from athlete discovery'
);
reset role;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (select count(*)::integer from public.public_athletes where id = '98000000-0000-4000-8000-000000000201'),
  1,
  'anonymous public profiles remain visible without an authenticated block relationship'
);
reset role;

select * from finish();
rollback;
