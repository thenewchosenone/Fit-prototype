begin;

do $migration$
declare
  definition text;
  updated_definition text;
begin
  select pg_catalog.pg_get_functiondef(p.oid)
  into definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_ranked_lift_ids';

  if definition is null then
    raise exception 'get_ranked_lift_ids function is required';
  end if;

  updated_definition := pg_catalog.regexp_replace(
    definition,
    $pattern$l\.review_status\s*=\s*'approved'\s*and\s*$pattern$,
    '',
    'g'
  );
  updated_definition := pg_catalog.regexp_replace(
    updated_definition,
    $pattern$l\.evidence_public\s*and\s*$pattern$,
    '',
    'g'
  );
  updated_definition := pg_catalog.regexp_replace(
    updated_definition,
    $pattern$and\s+nullif\(l\.approved_evidence_storage_path,\s*''\)\s+is\s+not\s+null$pattern$,
    'and l.video_asset_id is not null',
    'g'
  );
  updated_definition := pg_catalog.replace(
    updated_definition,
    'max(b.weight_kg) filter (where b.total_family = ''bench'')',
    'coalesce(max(b.weight_kg) filter (where b.total_family = ''bench''), 0)'
  );
  updated_definition := pg_catalog.replace(
    updated_definition,
    'max(b.weight_kg) filter (where b.total_family = ''squat'')',
    'coalesce(max(b.weight_kg) filter (where b.total_family = ''squat''), 0)'
  );
  updated_definition := pg_catalog.replace(
    updated_definition,
    'max(b.weight_kg) filter (where b.total_family = ''deadlift'')',
    'coalesce(max(b.weight_kg) filter (where b.total_family = ''deadlift''), 0)'
  );
  updated_definition := pg_catalog.replace(
    updated_definition,
    'SET search_path TO ''public'', ''pg_catalog''',
    'SET search_path TO ''pg_catalog'''
  );

  if updated_definition = definition
    or pg_catalog.strpos(updated_definition, 'l.review_status = ''approved''') > 0
    or pg_catalog.strpos(updated_definition, 'l.evidence_public') > 0
    or pg_catalog.strpos(updated_definition, 'l.video_asset_id is not null') = 0
    or pg_catalog.strpos(updated_definition, 'coalesce(max(b.weight_kg) filter (where b.total_family = ''deadlift''), 0)') = 0
    or pg_catalog.strpos(updated_definition, 'SET search_path TO ''pg_catalog''') = 0
  then
    raise exception 'verified leaderboard eligibility block was not updated safely';
  end if;

  execute updated_definition;
end;
$migration$;

commit;
