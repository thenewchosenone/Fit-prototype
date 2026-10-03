begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

select has_table('public', 'device_tokens', 'notification device registry exists');
select has_column('public', 'device_tokens', 'device_id', 'device id is stored');
select has_column('public', 'device_tokens', 'token', 'APNs token is stored');
select has_column('public', 'device_tokens', 'environment', 'APNs environment is explicit');
select has_column('public', 'device_tokens', 'revoked_at', 'token revocation is tracked');
select has_function('public', 'register_device_token', array['uuid', 'text', 'text', 'text'], 'device registration function exists');
select has_function('public', 'revoke_device_token', array['text'], 'device revocation function exists');
select policies_are(
  'public',
  'device_tokens',
  array['tokens owner all'],
  'clients can only access their own device registrations'
);

select * from finish();
rollback;
