begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);
select has_table('public','workout_shares','focused workout shares exist');
select has_table('public','workout_share_likes','workout share likes exist');
select has_table('public','workout_share_comments','workout share comments exist');
select has_table('public','workout_share_reports','workout share reporting exists');
select has_function('public','get_followed_activity',array[]::text[],'connection activity is server authorized');
select has_function('public','search_profile_cards',array['text','integer'],'athlete discovery is server authorized');
select has_function('public','share_completed_workout',array['uuid','text','text'],'completed workout sharing exists');
select has_function('public','remove_workout_share',array['uuid'],'owners can remove a share');
select has_function('public','set_workout_share_liked',array['uuid','boolean'],'connection likes exist');
select has_function('public','get_workout_share_comments',array['uuid'],'connection comments are readable through an RPC');
select has_function('public','add_workout_share_comment',array['uuid','text'],'connection comments are writable through an RPC');
select has_function('public','report_workout_share',array['uuid','text','text'],'shared workouts can be reported');
select has_function('public','can_view_workout_share',array['uuid'],'share visibility is centralized');
select policies_are(
  'public','workout_shares',
  array['workout shares connection read','workout shares owner insert','workout shares owner update'],
  'workout shares remain connection-readable and owner-writable'
);
select policies_are(
  'public','workout_share_likes',array['workout likes connection access'],
  'likes remain scoped to the authenticated connection'
);
select policies_are(
  'public','workout_share_comments',array['workout comments author insert','workout comments connection read'],
  'comments remain connection-readable and author-writable'
);
select policies_are(
  'public','workout_share_reports',array['workout reports own access'],
  'reports remain reporter or moderator scoped'
);

select * from finish();
rollback;
