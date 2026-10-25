begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);
select has_column('public','notifications','push_sent_at','push delivery is tracked');
select has_trigger('public','messages','message_notification','messages enqueue notifications');
select has_trigger('public','forum_comments','forum_reply_notification','forum replies enqueue notifications');
select has_trigger('public','friend_relationships','friendship_notification','friend changes enqueue notifications');
select has_trigger('public','lift_moderation_audit','lift_moderation_notification','moderation enqueues notifications');
select has_function('public','notify_message_recipient',array[]::text[],'message notifier exists');
select has_function('public','notify_forum_reply',array[]::text[],'forum notifier exists');
select has_function('public','notify_friendship_change',array[]::text[],'friend notifier exists');
select has_function('public','notify_lift_moderation',array[]::text[],'moderation notifier exists');

select * from finish();
rollback;

