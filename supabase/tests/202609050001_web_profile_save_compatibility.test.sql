begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);
select has_function(
  'public',
  'save_own_profile_web',
  array[
    'text', 'text', 'text', 'date', 'text', 'numeric', 'uuid', 'text',
    'text', 'text', 'smallint', 'text', 'text', 'text', 'text', 'text',
    'text', 'text', 'text', 'boolean', 'boolean'
  ],
  'web profile save RPC exists with the client contract'
);
select is_definer(
  'public',
  'save_own_profile_web',
  array[
    'text', 'text', 'text', 'date', 'text', 'numeric', 'uuid', 'text',
    'text', 'text', 'smallint', 'text', 'text', 'text', 'text', 'text',
    'text', 'text', 'text', 'boolean', 'boolean'
  ],
  'web profile save runs as a fixed-search-path security definer'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.save_own_profile_web(text,text,text,date,text,numeric,uuid,text,text,text,smallint,text,text,text,text,text,text,text,text,boolean,boolean)',
    'EXECUTE'
  ),
  'anonymous callers cannot execute the web profile save RPC'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.save_own_profile_web(text,text,text,date,text,numeric,uuid,text,text,text,smallint,text,text,text,text,text,text,text,text,boolean,boolean)',
    'EXECUTE'
  ),
  'authenticated callers can execute the web profile save RPC'
);
select ok(
  position('new_gym_audience' in pg_get_functiondef('public.save_own_profile_web(text,text,text,date,text,numeric,uuid,text,text,text,smallint,text,text,text,text,text,text,text,text,boolean,boolean)'::regprocedure)) > 0
  and position('show_lift_videos' in pg_get_functiondef('public.save_own_profile_web(text,text,text,date,text,numeric,uuid,text,text,text,smallint,text,text,text,text,text,text,text,text,boolean,boolean)'::regprocedure)) > 0,
  'web profile save writes gym and video privacy fields'
);
select ok(
  (select column_default like '%private%' from information_schema.columns where table_schema = 'public' and table_name = 'profile_privacy' and column_name = 'profile_audience'),
  'new profiles default to a private profile audience'
);
select ok(
  (select column_default like '%private%' from information_schema.columns where table_schema = 'public' and table_name = 'profile_privacy' and column_name = 'gym_audience'),
  'new profiles default to a private gym audience'
);
select is(
  (select column_default from information_schema.columns where table_schema = 'public' and table_name = 'profile_privacy' and column_name = 'show_lift_videos'),
  'false',
  'new profiles default to hidden approved videos'
);

-- A sole primary gym can be left, leaving the account with no primary gym.
-- Keeping this path in the contract prevents the web UI from trapping users in
-- the first gym they joined while preserving the replacement-primary guard.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values (
  '90000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'gym-leave@example.test', '', '{}', '{}', now(), now()
);
insert into public.gyms (id, name, status)
values ('91000000-0000-0000-0000-000000000001', 'Leave Test Gym', 'active');
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.join_gym('91000000-0000-0000-0000-000000000001', true)$$,
  'a test account can join its first gym'
);
select lives_ok(
  $$select public.leave_gym('91000000-0000-0000-0000-000000000001')$$,
  'a sole primary gym can be left'
);
select is(
  (select count(*)::integer from public.gym_memberships where user_id = '90000000-0000-0000-0000-000000000001' and left_at is null),
  0,
  'leaving the only gym leaves no active membership'
);
select is(
  (select count(*)::integer from public.gym_memberships where user_id = '90000000-0000-0000-0000-000000000001' and left_at is null and is_primary),
  0,
  'leaving the only gym removes the primary designation'
);

select * from finish();
rollback;
