begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(5);

select is_definer(
  'public',
  'get_ranked_lift_ids',
  array['text','text','uuid','text','text','text','text','text','numeric','numeric','boolean','text'],
  'leaderboard authority remains security definer'
);

select is(
  (
    select p.proconfig::text
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_ranked_lift_ids'
  ),
  '{search_path=pg_catalog}',
  'leaderboard authority has a fixed search path'
);

select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text)'::regprocedure
    ),
    'l.review_status = ''approved'''
  ) = 0,
  'verified lifts do not require manual pre-approval'
);

select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text)'::regprocedure
    ),
    'l.evidence_public'
  ) = 0,
  'verified eligibility does not depend on an unsupported per-lift toggle'
);

select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text)'::regprocedure
    ),
    'l.video_asset_id is not null'
  ) > 0
  and pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text)'::regprocedure
    ),
    'l.moderation_status = ''clear'''
  ) > 0
  and pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text)'::regprocedure
    ),
    'coalesce(max(b.weight_kg) filter (where b.total_family = ''deadlift''), 0)'
  ) > 0,
  'server-finalized videos remain eligible for partial totals until report-driven moderation intervenes'
);

select * from finish();
rollback;
