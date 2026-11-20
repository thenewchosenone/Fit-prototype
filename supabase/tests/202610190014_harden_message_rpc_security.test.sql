begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);

with expected_functions(oid) as (values
  ('public.get_message_threads()'::regprocedure::oid),
  ('public.create_or_get_message_thread(uuid)'::regprocedure::oid),
  ('public.get_thread_messages(uuid)'::regprocedure::oid),
  ('public.send_message(uuid,text)'::regprocedure::oid),
  ('public.delete_message(uuid)'::regprocedure::oid),
  ('public.hide_message_thread(uuid)'::regprocedure::oid),
  ('public.report_message(uuid,text,text)'::regprocedure::oid)
)
select ok(
  (select count(*) = 7 and bool_and(p.prosecdef)
      and bool_and('search_path=pg_catalog' = any(p.proconfig))
   from expected_functions f join pg_proc p using (oid)),
  'all message RPCs remain security definers on the pinned catalog-only path'
);

with expected_functions(oid) as (values
  ('public.get_message_threads()'::regprocedure::oid),
  ('public.create_or_get_message_thread(uuid)'::regprocedure::oid),
  ('public.get_thread_messages(uuid)'::regprocedure::oid),
  ('public.send_message(uuid,text)'::regprocedure::oid),
  ('public.delete_message(uuid)'::regprocedure::oid),
  ('public.hide_message_thread(uuid)'::regprocedure::oid),
  ('public.report_message(uuid,text,text)'::regprocedure::oid)
)
select ok(
  (select count(*) = 7
      and bool_and(has_function_privilege('authenticated', f.oid, 'EXECUTE'))
      and bool_and(not has_function_privilege('anon', f.oid, 'EXECUTE'))
      and bool_and(not has_function_privilege('service_role', f.oid, 'EXECUTE'))
   from expected_functions f)
  and not exists (
    select 1
    from expected_functions f
    join pg_proc p using (oid)
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) privilege
    where privilege.grantee = 0 and privilege.privilege_type = 'EXECUTE'
  ),
  'message RPC execution remains authenticated-only'
);

select * from finish();
rollback;
