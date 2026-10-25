begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(5);
select policies_are(
  'public', 'legal_acceptances',
  array['legal owner insert', 'legal owner read'],
  'legal acceptance exposes only append and owner-read policies'
);
select policy_roles_are('public', 'legal_acceptances', 'legal owner read', array['authenticated'], 'read is authenticated only');
select policy_cmd_is('public', 'legal_acceptances', 'legal owner read', 'SELECT', 'read policy cannot mutate rows');
select policy_roles_are('public', 'legal_acceptances', 'legal owner insert', array['authenticated'], 'insert is authenticated only');
select policy_cmd_is('public', 'legal_acceptances', 'legal owner insert', 'INSERT', 'acceptance policy is insert only');

select * from finish();
rollback;
