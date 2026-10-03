begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);
select has_table('public', 'profile_training_goals', 'profile goals are stored separately');
select has_function('public', 'replace_own_training_goals', array['text[]'], 'goal replacement RPC exists');
select is_definer('public', 'replace_own_training_goals', array['text[]'], 'goal replacement uses server authority');
select ok(has_function_privilege('authenticated', 'public.replace_own_training_goals(text[])', 'EXECUTE'), 'authenticated users can save goals');
select ok(not has_function_privilege('anon', 'public.replace_own_training_goals(text[])', 'EXECUTE'), 'anonymous users cannot save goals');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
('98000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'goals-one@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
('98000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'goals-two@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '98000000-0000-0000-0000-000000000001', true);
select lives_ok($$select public.replace_own_training_goals(array['get_stronger','represent_gym'])$$, 'owner can replace goals');
select is((select count(*)::integer from public.profile_training_goals), 2, 'owner can read saved goals');

select set_config('request.jwt.claim.sub', '98000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.profile_training_goals), 0, 'another user cannot read goals');

select * from finish();
rollback;
