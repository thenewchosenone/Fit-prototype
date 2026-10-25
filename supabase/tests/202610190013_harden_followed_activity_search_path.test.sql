begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(4);
select ok(
  (select prosecdef from pg_proc where oid = 'public.get_followed_activity()'::regprocedure),
  'followed activity remains security definer'
);
select ok(
  (select 'search_path=pg_catalog' = any(proconfig) from pg_proc where oid = 'public.get_followed_activity()'::regprocedure),
  'followed activity resolves only trusted catalog objects implicitly'
);
select ok(
  has_function_privilege('authenticated', 'public.get_followed_activity()', 'EXECUTE'),
  'authenticated users retain followed-activity access'
);
select ok(
  not has_function_privilege('anon', 'public.get_followed_activity()', 'EXECUTE')
    and not exists (
      select 1
      from pg_proc p,
           lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) privilege
      where p.oid = 'public.get_followed_activity()'::regprocedure
        and privilege.grantee = 0
        and privilege.privilege_type = 'EXECUTE'
    ),
  'anonymous and public roles remain unable to execute followed activity'
);

select * from finish();
rollback;
