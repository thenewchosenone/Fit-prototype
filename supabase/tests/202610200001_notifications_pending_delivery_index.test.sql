begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);

select has_index(
  'public', 'notifications', 'notifications_pending_delivery_created_at_idx',
  'pending push notifications have an ordered batch lookup index'
);

select ok(
  (select pg_catalog.pg_get_indexdef(indexrelid.indexrelid) like '%(created_at)%'
      and pg_catalog.pg_get_expr(indexrelid.indpred, indexrelid.indrelid)
        ~ 'push_sent_at IS NULL.*web_push_sent_at IS NULL'
      and indexrelid.indisvalid
   from pg_catalog.pg_index indexrelid
   join pg_catalog.pg_class index_name on index_name.oid = indexrelid.indexrelid
   where index_name.relname = 'notifications_pending_delivery_created_at_idx'),
  'push queue index orders by creation time and includes both pending channels'
);

select * from finish();
rollback;
