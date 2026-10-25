begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);
select has_table('public', 'web_push_subscriptions', 'browser push endpoints are stored separately');
select ok((select relrowsecurity from pg_class where oid = 'public.web_push_subscriptions'::regclass), 'browser push rows enforce RLS');
select ok(not has_table_privilege('anon', 'public.web_push_subscriptions', 'SELECT'), 'anonymous clients cannot read push endpoints');
select ok(not has_table_privilege('authenticated', 'public.web_push_subscriptions', 'SELECT'), 'authenticated clients cannot read push endpoint secrets');
select ok(not has_table_privilege('authenticated', 'public.web_push_subscriptions', 'INSERT'), 'clients register only through the owner RPC');
select ok(not has_table_privilege('authenticated', 'public.web_push_subscriptions', 'UPDATE'), 'clients cannot alter subscription secrets directly');
select ok(not has_table_privilege('authenticated', 'public.web_push_subscriptions', 'DELETE'), 'clients revoke subscriptions only through the owner RPC');
select ok(has_table_privilege('service_role', 'public.web_push_subscriptions', 'SELECT'), 'delivery service can read active subscriptions');
select has_column('public', 'notifications', 'web_push_sent_at', 'web push has independent delivery state');
select has_function('public', 'register_own_web_push_subscription', array['jsonb'], 'owner subscription registration exists');
select has_function('public', 'revoke_own_web_push_subscription', array['text'], 'owner subscription revocation exists');
select ok(has_function_privilege('authenticated', 'public.register_own_web_push_subscription(jsonb)', 'EXECUTE'), 'authenticated users can register their browser');
select ok(not has_function_privilege('anon', 'public.register_own_web_push_subscription(jsonb)', 'EXECUTE'), 'anonymous users cannot register a browser');
select ok(has_function_privilege('authenticated', 'public.revoke_own_web_push_subscription(text)', 'EXECUTE'), 'authenticated users can revoke their browser');
select ok(not has_function_privilege('anon', 'public.revoke_own_web_push_subscription(text)', 'EXECUTE'), 'anonymous users cannot revoke browser subscriptions');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('92000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','web-push-owner@example.test','','{}','{}',now(),now()),
  ('92000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','web-push-other@example.test','','{}','{}',now(),now());
insert into public.profiles(id, username, handle, display_name) values
  ('92000000-0000-4000-8000-000000000001','web_push_owner','@web_push_owner','Web Push Owner'),
  ('92000000-0000-4000-8000-000000000002','web_push_other','@web_push_other','Web Push Other')
on conflict(id) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
select lives_ok(
  $$select public.register_own_web_push_subscription('{"endpoint":"https://fcm.googleapis.com/fcm/send/test-endpoint","keys":{"auth":"0123456789abcdef","p256dh":"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"}}'::jsonb)$$,
  'owner registers a validated browser endpoint'
);
select throws_ok(
  $$select public.register_own_web_push_subscription('{"endpoint":"http://127.0.0.1/private","keys":{"auth":"0123456789abcdef","p256dh":"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"}}'::jsonb)$$,
  '22023', 'Invalid web push subscription', 'unsafe push endpoints are rejected'
);
select throws_ok(
  $$select public.register_own_web_push_subscription('{"endpoint":"https://fcm.googleapis.com/fcm/send/missing-key","keys":{"p256dh":"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"}}'::jsonb)$$,
  '22023', 'Invalid web push subscription', 'subscriptions without authentication keys are rejected'
);
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000002',true);
select throws_ok(
  $$select public.register_own_web_push_subscription('{"endpoint":"https://fcm.googleapis.com/fcm/send/test-endpoint","keys":{"auth":"0123456789abcdef","p256dh":"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"}}'::jsonb)$$,
  '42501', 'Subscription belongs to another account', 'another account cannot claim an existing browser endpoint'
);
select is(public.revoke_own_web_push_subscription('https://fcm.googleapis.com/fcm/send/test-endpoint'), false, 'another account cannot revoke this endpoint');
reset role;
select is((select count(*)::integer from public.web_push_subscriptions where endpoint='https://fcm.googleapis.com/fcm/send/test-endpoint' and user_id='92000000-0000-4000-8000-000000000001'), 1, 'cross-account revocation leaves the owner endpoint intact');
set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-4000-8000-000000000001',true);
select is(public.revoke_own_web_push_subscription('https://fcm.googleapis.com/fcm/send/test-endpoint'), true, 'owner can revoke the browser endpoint');
reset role;

select * from finish();
rollback;
