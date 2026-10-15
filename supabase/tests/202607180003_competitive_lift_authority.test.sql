begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);
select has_trigger('public','lift_submissions','competitive_lift_authority','competitive authority trigger exists');
select has_trigger('public','lift_moderation_audit','moderation_audit_immutable','moderation audit is immutable');
select has_function('public','complete_lift_media_upload',array['uuid','uuid','text','text','bigint'],'server completes media uploads');
select has_function('public','get_lift_media_for_playback',array['uuid'],'playback authorization exists');
select has_function('public','moderate_lift',array['uuid','text','text'],'moderator decision function exists');
select has_function('public','get_moderation_queue_ids',array[]::text[],'moderation queue exists');
select function_privs_are('public','complete_lift_media_upload',array['uuid','uuid','text','text','bigint'],'authenticated',array['EXECUTE'],'media completion is authenticated');
select function_privs_are('public','moderate_lift',array['uuid','text','text'],'authenticated',array['EXECUTE'],'moderation RPC is authenticated and checks admin internally');
select policy_cmd_is('storage','objects','lift videos visible playback','SELECT','visible playback policy is read-only');
select policy_roles_are('storage','objects','lift videos visible playback',array['authenticated'],'playback requires authentication');

select * from finish();
rollback;
