begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(5);

select is(
  (select count(*)::integer
   from pg_catalog.pg_proc p
   cross join lateral pg_catalog.aclexplode(
     coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
   ) a
   where p.oid in (
     'public.refresh_lift_review_state(uuid)'::regprocedure,
     'public.vote_on_lift(uuid,integer)'::regprocedure,
     'public.report_lift(uuid,text,text)'::regprocedure,
     'public.block_user(uuid)'::regprocedure,
     'public.unblock_user(uuid)'::regprocedure,
     'public.enforce_competitive_lift_authority()'::regprocedure,
     'public.can_view_forum_community(uuid)'::regprocedure,
     'public.can_view_forum_post(uuid)'::regprocedure,
     'public.is_admin()'::regprocedure,
     'public.moderates(text)'::regprocedure,
     'public.is_thread_member(uuid)'::regprocedure
   )
   and a.grantee = 0
   and a.privilege_type = 'EXECUTE'),
  0,
  'reviewed security-definer functions have no PUBLIC EXECUTE ACL'
);

select ok(
  not has_function_privilege('anon', 'public.refresh_lift_review_state(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.refresh_lift_review_state(uuid)', 'EXECUTE')
  and not has_function_privilege('service_role', 'public.refresh_lift_review_state(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.enforce_competitive_lift_authority()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.enforce_competitive_lift_authority()', 'EXECUTE')
  and not has_function_privilege('service_role', 'public.enforce_competitive_lift_authority()', 'EXECUTE'),
  'internal moderation and trigger functions cannot be invoked directly by API roles'
);

select ok(
  (select bool_and(has_function_privilege('authenticated', signature, 'EXECUTE'))
          and bool_and(not has_function_privilege('anon', signature, 'EXECUTE'))
          and bool_and(not has_function_privilege('service_role', signature, 'EXECUTE'))
   from unnest(array[
     'public.vote_on_lift(uuid,integer)',
     'public.report_lift(uuid,text,text)',
     'public.block_user(uuid)',
     'public.unblock_user(uuid)'
   ]) signature),
  'lift vote/report and block/unblock RPCs are authenticated-only'
);

select ok(
  (select bool_and(has_function_privilege('authenticated', signature, 'EXECUTE'))
          and bool_and(not has_function_privilege('anon', signature, 'EXECUTE'))
          and bool_and(not has_function_privilege('service_role', signature, 'EXECUTE'))
   from unnest(array[
     'public.is_admin()',
     'public.moderates(text)',
     'public.is_thread_member(uuid)'
   ]) signature),
  'authenticated RLS helpers are not executable by anonymous or service roles'
);

select ok(
  (select bool_and(has_function_privilege('anon', signature, 'EXECUTE'))
          and bool_and(has_function_privilege('authenticated', signature, 'EXECUTE'))
          and bool_and(not has_function_privilege('service_role', signature, 'EXECUTE'))
   from unnest(array[
     'public.can_view_forum_community(uuid)',
     'public.can_view_forum_post(uuid)'
   ]) signature),
  'forum visibility helpers are executable by anon/authenticated RLS callers only'
);

select * from finish();
rollback;
