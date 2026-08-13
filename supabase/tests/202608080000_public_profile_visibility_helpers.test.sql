begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);
select has_column('public', 'lift_submissions', 'gym_uuid', 'canonical lift gym UUID exists');
select has_column('public', 'lift_submissions', 'approved_evidence_storage_path', 'canonical approved evidence path exists');
select has_column('public', 'lift_submissions', 'review_status', 'canonical review status exists');
select has_column('public', 'lift_submissions', 'bodyweight_class', 'legacy public bodyweight-class filter remains compatible');
select has_column('public', 'profile_privacy', 'show_lift_videos', 'video privacy preference exists');
select has_function('public', 'public_profile_show_gym', array['uuid'], 'public gym visibility helper exists');
select is_definer('public', 'public_profile_show_gym', array['uuid'], 'public gym visibility is evaluated server-side');
select ok(has_function_privilege('anon', 'public.public_profile_show_gym(uuid)', 'EXECUTE'), 'anonymous public views can evaluate public gym visibility');
select ok(has_function_privilege('authenticated', 'public.public_profile_show_gym(uuid)', 'EXECUTE'), 'authenticated public views use the same helper');
select ok(has_column_privilege('authenticated', 'public.profile_privacy', 'show_lift_videos', 'UPDATE'), 'athletes can update public video visibility');

select * from finish();
rollback;
