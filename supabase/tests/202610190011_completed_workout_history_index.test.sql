begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);

select has_index(
  'public', 'completed_workout_snapshots', 'completed_workout_snapshots_owner_completed_id_idx',
  'workout history has an owner-scoped ordered lookup index'
);

select ok(
  (select pg_catalog.pg_get_indexdef(indexrelid) like '%(owner_id, completed_at, id)%'
   from pg_catalog.pg_index indexrelid
   join pg_catalog.pg_class index_name on index_name.oid = indexrelid.indexrelid
   where index_name.relname = 'completed_workout_snapshots_owner_completed_id_idx'),
  'workout history index matches its stable owner/date/id ordering'
);

select * from finish();
rollback;
