begin;

-- A completed public video is sufficient for initial leaderboard eligibility.
-- Reports move a lift to moderation review; the canonical ranking function
-- already excludes every moderation status other than clear.
do $migration$
declare
  definition text;
  updated_definition text;
begin
  select pg_get_functiondef(p.oid)
    into definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_ranked_lift_ids';

  if definition is null then
    raise exception 'get_ranked_lift_ids function is required';
  end if;

  updated_definition := replace(definition, 'l.moderation_status <> ''rejected''', 'l.moderation_status = ''clear''');
  updated_definition := replace(updated_definition, 'l.evidence_status=''video_backed''', 'l.evidence_status=''video_backed'' and l.video_asset_id is not null');

  if updated_definition = definition then
    raise exception 'get_ranked_lift_ids eligibility block was not found';
  end if;

  execute updated_definition;
end;
$migration$;

commit;
