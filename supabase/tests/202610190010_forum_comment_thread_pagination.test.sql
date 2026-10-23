begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);

select has_index(
  'public', 'forum_comments', 'forum_comments_post_created_id_visible_idx',
  'visible thread comments have an ordered lookup index'
);

select ok(
  (select pg_catalog.pg_get_expr(indexrelid.indpred, indexrelid.indrelid) = '(removed_at IS NULL)'
   from pg_catalog.pg_index indexrelid
   join pg_catalog.pg_class index_name on index_name.oid = indexrelid.indexrelid
   where index_name.relname = 'forum_comments_post_created_id_visible_idx'),
  'thread comment index is scoped to visible comments'
);

select * from finish();
rollback;
