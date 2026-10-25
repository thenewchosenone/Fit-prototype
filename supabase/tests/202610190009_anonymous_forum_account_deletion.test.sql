begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(16);

select is(
  (select count(*)::integer
   from pg_constraint
   where contype = 'f'
     and confrelid = 'public.profiles'::regclass
     and confdeltype in ('a', 'r')),
  0,
  'no profile foreign key can block account deletion'
);

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('99000000-0000-4000-8000-000000000901', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'anonymous-forum-author@example.test', '', '{}', '{}', now(), now()),
  ('99000000-0000-4000-8000-000000000902', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'anonymous-forum-peer@example.test', '', '{}', '{}', now(), now()),
  ('99000000-0000-4000-8000-000000000903', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'anonymous-forum-reporter@example.test', '', '{}', '{}', now(), now());

update public.forum_communities
set staff_owner_id = '99000000-0000-4000-8000-000000000901'
where id = 'f1000000-0000-0000-0000-000000000001';

insert into public.forum_memberships(community_id, user_id, role, status, invited_by)
values ('f1000000-0000-0000-0000-000000000001', '99000000-0000-4000-8000-000000000902', 'Member', 'Joined', '99000000-0000-4000-8000-000000000901');

insert into public.forum_posts(id, community_id, author_id, kind, title, body)
values ('99000000-0000-4000-8000-000000000911', 'f1000000-0000-0000-0000-000000000001', '99000000-0000-4000-8000-000000000901', 'Discussion', 'Retained discussion', 'Retained body');

insert into public.forum_comments(id, post_id, author_id, body)
values ('99000000-0000-4000-8000-000000000912', '99000000-0000-4000-8000-000000000911', '99000000-0000-4000-8000-000000000901', 'Retained comment');

insert into public.forum_reports(community_id, target_type, target_id, reporter_id, reason, resolved_by)
values ('f1000000-0000-0000-0000-000000000001', 'Post', '99000000-0000-4000-8000-000000000911', '99000000-0000-4000-8000-000000000901', 'Other', '99000000-0000-4000-8000-000000000901');

insert into public.forum_moderation_actions(community_id, moderator_id, kind, target_id, reason)
values ('f1000000-0000-0000-0000-000000000001', '99000000-0000-4000-8000-000000000901', 'Reviewed', '99000000-0000-4000-8000-000000000911', 'Audit fixture');

insert into public.group_bans(group_id, user_id, moderator_id, reason)
values ('powerlifting', '99000000-0000-4000-8000-000000000902', '99000000-0000-4000-8000-000000000901', 'Audit fixture');

insert into public.moderation_actions(actor_id, group_id, action, target_type, target_id)
values ('99000000-0000-4000-8000-000000000901', 'powerlifting', 'Reviewed', 'Post', 'retained-post');

insert into public.profile_reports(reported_user_id, reporter_id, reason, status, resolved_at, resolved_by)
values ('99000000-0000-4000-8000-000000000902', '99000000-0000-4000-8000-000000000903', 'Other', 'Resolved', now(), '99000000-0000-4000-8000-000000000901');

insert into public.gyms(id, name, status)
values ('99000000-0000-4000-8000-000000000920', 'Account deletion test gym', 'active');

insert into public.gym_memberships(user_id, gym_id)
values ('99000000-0000-4000-8000-000000000902', '99000000-0000-4000-8000-000000000920');

set local role authenticated;
select set_config('request.jwt.claim.sub', '99000000-0000-4000-8000-000000000902', true);
insert into public.lift_submissions(user_id, exercise_id, gym_id, weight, unit, reps, performed_at, reviewed_by)
values ('99000000-0000-4000-8000-000000000902', 'barbell_bench_press', '99000000-0000-4000-8000-000000000920', 100, 'kg', 1, now(), '99000000-0000-4000-8000-000000000901');
reset role;

insert into public.lift_moderation_audit(lift_id, actor_id, event, resulting_status, note)
select id, '99000000-0000-4000-8000-000000000901', 'reviewed', 'clear', 'Audit fixture'
from public.lift_submissions
where user_id = '99000000-0000-4000-8000-000000000902';

select throws_ok(
  $$update public.lift_moderation_audit set actor_id = null where note = 'Audit fixture'$$,
  'P0001',
  'Moderation audit entries are immutable',
  'moderation audit remains immutable to direct updates'
);

delete from auth.users where id = '99000000-0000-4000-8000-000000000901';

select is((select count(*)::integer from public.profiles where id = '99000000-0000-4000-8000-000000000901'), 0, 'deleted account profile is removed');
select is((select count(*)::integer from public.forum_posts where id = '99000000-0000-4000-8000-000000000911'), 1, 'forum post survives account deletion');
select is((select author_id from public.forum_posts where id = '99000000-0000-4000-8000-000000000911'), null::uuid, 'forum post author is anonymized');
select is((select count(*)::integer from public.forum_comments where id = '99000000-0000-4000-8000-000000000912'), 1, 'forum comment survives account deletion');
select is((select author_id from public.forum_comments where id = '99000000-0000-4000-8000-000000000912'), null::uuid, 'forum comment author is anonymized');
select is((select staff_owner_id from public.forum_communities where id = 'f1000000-0000-0000-0000-000000000001'), null::uuid, 'deleted staff owner is detached');
select is((select invited_by from public.forum_memberships where community_id = 'f1000000-0000-0000-0000-000000000001' and user_id = '99000000-0000-4000-8000-000000000902'), null::uuid, 'deleted inviter is detached');
select is((select (reporter_id is null and resolved_by is null) from public.forum_reports where target_id = '99000000-0000-4000-8000-000000000911'), true, 'forum report references are anonymized');
select is((select moderator_id from public.forum_moderation_actions where target_id = '99000000-0000-4000-8000-000000000911'), null::uuid, 'forum moderator reference is anonymized');
select is((select moderator_id from public.group_bans where group_id = 'powerlifting' and user_id = '99000000-0000-4000-8000-000000000902'), null::uuid, 'group-ban moderator reference is anonymized');
select is((select actor_id from public.moderation_actions where target_id = 'retained-post'), null::uuid, 'moderation audit actor reference is anonymized');
select is((select reviewed_by from public.lift_submissions where user_id = '99000000-0000-4000-8000-000000000902'), null::uuid, 'deleted lift reviewer reference is anonymized');
select is((select actor_id from public.lift_moderation_audit where note = 'Audit fixture'), null::uuid, 'deleted lift-audit actor reference is anonymized');
select is((select resolved_by from public.profile_reports where reporter_id = '99000000-0000-4000-8000-000000000903'), null::uuid, 'deleted profile-report resolver reference is anonymized');

select * from finish();
rollback;
