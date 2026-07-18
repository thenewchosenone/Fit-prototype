begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);
select has_function(
  'public','get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text'],
  'server-computed ranked lift query exists'
);
select function_privs_are(
  'public','get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text'],
  'authenticated',array['EXECUTE'],'leaderboards require authentication'
);

select * from finish();
rollback;
