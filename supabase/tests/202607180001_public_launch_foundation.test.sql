begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(13);

select has_type('public', 'competitive_movement', 'canonical movement type exists');
select enum_has_labels('public', 'competitive_movement', array[
  'barbell_bench_press','back_squat','conventional_deadlift','sumo_deadlift',
  'standing_barbell_overhead_press','dumbbell_bench_press','bent_over_barbell_row'
], 'exactly seven canonical movements are ranked');
select has_table('public', 'lift_media_assets', 'private media metadata exists');
select has_table('public', 'lift_votes', 'lift votes exist');
select has_table('public', 'lift_reports', 'lift reports exist');
select has_table('public', 'lift_moderation_audit', 'immutable moderation audit exists');
select has_table('public', 'user_blocks', 'blocking exists');
select has_table('public', 'workout_plan_documents', 'versioned plans exist');
select has_table('public', 'completed_workout_snapshots', 'immutable workout snapshots exist');
select has_table('public', 'device_tokens', 'push device registrations exist');
select has_table('public', 'notifications', 'in-app notifications exist');
select has_table('public', 'legal_acceptances', 'legal acceptance history exists');
select has_table('public', 'analytics_events', 'privacy-first launch analytics exist');

select * from finish();
rollback;
