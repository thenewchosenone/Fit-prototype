begin;

-- Keep the 12-argument public leaderboard contract intact. The app uses this
-- overload to rank exact-repetition lifts without changing canonical 1RM mode.
do $migration$
declare
  definition text;
  updated_definition text;
begin
  select pg_catalog.pg_get_functiondef(
    'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text)'::pg_catalog.regprocedure
  ) into definition;

  if definition is null then
    raise exception 'get_ranked_lift_ids(text, ... time_range) is required';
  end if;

  updated_definition := pg_catalog.regexp_replace(
    definition,
    'time_range text\s*\)',
    'time_range text, repetition_count integer)',
    'i'
  );
  updated_definition := pg_catalog.regexp_replace(
    updated_definition,
    'and l\.reps\s*=\s*1\s+and l\.is_actual_one_rep_max',
    'and (($13 is null and l.reps = 1 and l.is_actual_one_rep_max) or ($13 is not null and l.reps = $13 and ($13 <> 1 or l.is_actual_one_rep_max)))',
    'i'
  );

  if updated_definition = definition
    or pg_catalog.strpos(updated_definition, 'repetition_count integer)') = 0
    or pg_catalog.strpos(updated_definition, '$13 is not null and l.reps = $13') = 0
    or pg_catalog.strpos(updated_definition, 'l.is_actual_one_rep_max') = 0
    or pg_catalog.strpos(pg_catalog.upper(updated_definition), 'SECURITY DEFINER') = 0
    or pg_catalog.strpos(updated_definition, 'SET search_path TO ''pg_catalog''') = 0
  then
    raise exception 'exact-repetition leaderboard overload was not built safely';
  end if;

  execute updated_definition;
end;
$migration$;

revoke all on function public.get_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, boolean, text, integer) from public;
revoke all on function public.get_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, boolean, text, integer) from anon;
grant execute on function public.get_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, boolean, text, integer) to authenticated;

commit;
