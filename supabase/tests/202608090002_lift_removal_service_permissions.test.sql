begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(6);
select ok(has_table_privilege('service_role', 'public.lift_removal_requests', 'SELECT'), 'service workflow can read removal requests');
select ok(has_table_privilege('service_role', 'public.lift_removal_requests', 'INSERT'), 'service workflow can create removal requests');
select ok(has_table_privilege('service_role', 'public.lift_removal_requests', 'UPDATE'), 'service workflow can update removal requests');
select ok(not has_table_privilege('service_role', 'public.lift_removal_requests', 'DELETE'), 'service workflow cannot directly delete removal requests');
select ok(not has_table_privilege('authenticated', 'public.lift_removal_requests', 'SELECT'), 'authenticated clients cannot read removal requests');
select ok(not has_table_privilege('authenticated', 'public.lift_removal_requests', 'INSERT'), 'authenticated clients cannot create removal requests directly');

select * from finish();
rollback;
