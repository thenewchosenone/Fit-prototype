begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(29);

select has_function('public', 'delete_own_forum_post', array['uuid'], 'post deletion RPC exists');
select has_function('public', 'delete_own_forum_comment', array['uuid'], 'comment deletion RPC exists');
select is_definer('public', 'delete_own_forum_post', array['uuid'], 'post deletion checks ownership server-side');
select is_definer('public', 'delete_own_forum_comment', array['uuid'], 'comment deletion checks ownership server-side');
select ok(position('search_path=pg_catalog, public' in pg_get_functiondef('public.delete_own_forum_post(uuid)'::regprocedure)) > 0, 'post deletion has a fixed search path');
select ok(position('search_path=pg_catalog, public' in pg_get_functiondef('public.delete_own_forum_comment(uuid)'::regprocedure)) > 0, 'comment deletion has a fixed search path');
select ok(has_function_privilege('authenticated', 'public.delete_own_forum_post(uuid)', 'EXECUTE'), 'authenticated users can request own post deletion');
select ok(not has_function_privilege('anon', 'public.delete_own_forum_post(uuid)', 'EXECUTE'), 'anonymous users cannot request post deletion');
select ok(has_function_privilege('authenticated', 'public.delete_own_forum_comment(uuid)', 'EXECUTE'), 'authenticated users can request own comment deletion');
select ok(not has_function_privilege('anon', 'public.delete_own_forum_comment(uuid)', 'EXECUTE'), 'anonymous users cannot request comment deletion');
select ok(has_column_privilege('authenticated', 'public.forum_posts', 'title', 'UPDATE'), 'authors can update post titles');
select ok(not has_column_privilege('authenticated', 'public.forum_posts', 'is_pinned', 'UPDATE'), 'authors cannot update moderator post fields');
select ok(has_column_privilege('authenticated', 'public.forum_comments', 'body', 'UPDATE'), 'authors can update comment bodies');
select policy_cmd_is('public', 'forum_posts', 'forum posts author update', 'UPDATE', 'post edits are constrained by an owner policy');
select policy_cmd_is('public', 'forum_comments', 'forum comments author update', 'UPDATE', 'comment edits are constrained by an owner policy');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('61000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-owner@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('61000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'forum-other@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.forum_memberships(community_id, user_id, status)
values
  ('f1000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', 'Joined'),
  ('f1000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000002', 'Joined');

insert into public.forum_posts(id, community_id, author_id, kind, title, body)
values
  ('61000000-0000-0000-0000-000000000010', 'f1000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', 'Discussion', 'Original title', 'Original post'),
  ('61000000-0000-0000-0000-000000000011', 'f1000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000002', 'Discussion', 'Other title', 'Other post');

insert into public.forum_comments(id, post_id, author_id, body)
values
  ('61000000-0000-0000-0000-000000000020', '61000000-0000-0000-0000-000000000010', '61000000-0000-0000-0000-000000000001', 'Original comment'),
  ('61000000-0000-0000-0000-000000000021', '61000000-0000-0000-0000-000000000010', '61000000-0000-0000-0000-000000000002', 'Other comment');

set local role authenticated;
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000001', true);
select lives_ok($$update public.forum_posts set title = 'Edited title', body = 'Edited post' where id = '61000000-0000-0000-0000-000000000010'$$, 'the author can edit their post');
select is((select title from public.forum_posts where id = '61000000-0000-0000-0000-000000000010'), 'Edited title', 'post edit is persisted');
select lives_ok($$update public.forum_comments set body = 'Edited comment' where id = '61000000-0000-0000-0000-000000000020'$$, 'the author can edit their comment');
select is((select body from public.forum_comments where id = '61000000-0000-0000-0000-000000000020'), 'Edited comment', 'comment edit is persisted');

select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000002', true);
select is((with changed as (update public.forum_posts set title = 'Hijacked' where id = '61000000-0000-0000-0000-000000000010' returning 1) select count(*)::integer from changed), 0, 'another member cannot edit the post');
select is((with changed as (update public.forum_comments set body = 'Hijacked' where id = '61000000-0000-0000-0000-000000000020' returning 1) select count(*)::integer from changed), 0, 'another member cannot edit the comment');
select throws_ok($$select public.delete_own_forum_post('61000000-0000-0000-0000-000000000010')$$, '42501', 'Post not found or not owned by this account', 'another member cannot delete the post');
select throws_ok($$select public.delete_own_forum_comment('61000000-0000-0000-0000-000000000020')$$, '42501', 'Comment not found or not owned by this account', 'another member cannot delete the comment');
select is((select removed_at is null from public.forum_posts where id = '61000000-0000-0000-0000-000000000010'), true, 'rejected post deletion leaves the post visible');
select is((select removed_at is null from public.forum_comments where id = '61000000-0000-0000-0000-000000000020'), true, 'rejected comment deletion leaves the comment visible');

select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000001', true);
select lives_ok($$select public.delete_own_forum_comment('61000000-0000-0000-0000-000000000020')$$, 'the author can delete their comment');
select ok((select removed_at is not null from public.forum_comments where id = '61000000-0000-0000-0000-000000000020'), 'comment deletion is a soft delete');
select lives_ok($$select public.delete_own_forum_post('61000000-0000-0000-0000-000000000010')$$, 'the author can delete their post');
select ok((select removed_at is not null from public.forum_posts where id = '61000000-0000-0000-0000-000000000010'), 'post deletion is a soft delete');

reset role;
select * from finish();
rollback;
