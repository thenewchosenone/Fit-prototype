begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);

select has_function(
  'public',
  'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text'],
  'the canonical leaderboard function remains available'
);

select ok(
  position('l.evidence_status = ''video_backed''' in pg_get_functiondef(
    'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text)'::regprocedure
  )) > 0,
  'video-backed evidence remains the only verification gate for video rankings'
);

select * from finish();
rollback;
