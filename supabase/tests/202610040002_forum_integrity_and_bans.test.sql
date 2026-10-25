begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);

select has_function(
  'public',
  'notify_forum_reply',
  array[]::text[],
  'reply notification trigger function exists'
);
select is_definer(
  'public',
  'notify_forum_reply',
  array[]::text[],
  'reply notification is evaluated server-side'
);
select ok(
  (select proconfig @> array['search_path=pg_catalog, public']::text[] from pg_catalog.pg_proc where oid = 'public.notify_forum_reply()'::regprocedure),
  'reply notification uses a fixed search path'
);

select has_function(
  'public',
  'can_moderate_forum_community',
  array['uuid'],
  'moderator authorization helper exists'
);
select is_definer(
  'public',
  'can_moderate_forum_community',
  array['uuid'],
  'moderator authorization is evaluated server-side'
);
select ok(
  (select proconfig @> array['search_path=pg_catalog, public']::text[] from pg_catalog.pg_proc where oid = 'public.can_moderate_forum_community(uuid)'::regprocedure),
  'moderator authorization uses a fixed search path'
);
select ok(
  has_function_privilege('authenticated', 'public.can_moderate_forum_community(uuid)', 'EXECUTE'),
  'authenticated users can evaluate moderator authorization'
);
select ok(
  not has_function_privilege('anon', 'public.can_moderate_forum_community(uuid)', 'EXECUTE'),
  'anonymous users cannot evaluate moderator authorization'
);
select has_function(
  'public',
  'can_view_forum_post',
  array['uuid'],
  'forum post visibility helper exists'
);
select is_definer(
  'public',
  'can_view_forum_post',
  array['uuid'],
  'forum post visibility is evaluated server-side'
);
select ok(
  (select proconfig @> array['search_path=pg_catalog, public']::text[] from pg_catalog.pg_proc where oid = 'public.can_view_forum_post(uuid)'::regprocedure),
  'forum post visibility uses a fixed search path'
);
select has_function(
  'public',
  'forum_comment_parent_matches_post',
  array[]::text[],
  'same-post reply trigger function exists'
);
select has_trigger(
  'public',
  'forum_comments',
  'forum_comment_parent_post_guard',
  'same-post reply parent guard is installed'
);
select policy_cmd_is(
  'public',
  'forum_posts',
  'forum posts visible',
  'SELECT',
  'forum post visibility policy is read-only'
);
select policy_cmd_is(
  'public',
  'forum_posts',
  'forum posts member insert',
  'INSERT',
  'forum post writes use the member insert policy'
);
select policy_cmd_is(
  'public',
  'forum_comments',
  'forum comments visible',
  'SELECT',
  'forum comment visibility is read-only'
);
select policy_cmd_is(
  'public',
  'forum_comments',
  'forum comments member insert',
  'INSERT',
  'forum comment writes use the member insert policy'
);

select * from finish();
rollback;
