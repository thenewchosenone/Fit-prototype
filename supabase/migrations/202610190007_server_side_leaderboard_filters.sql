begin;

do $migration$
declare
  definition text;
  updated_definition text;
  original_rep_filter text := 'and (($13 is null and l.reps = 1 and l.is_actual_one_rep_max) or ($13 is not null and l.reps = $13 and ($13 <> 1 or l.is_actual_one_rep_max)))';
  extended_filters text := 'and (($13 is null and l.reps = 1 and l.is_actual_one_rep_max) or ($13 is not null and l.reps = $13 and ($13 <> 1 or l.is_actual_one_rep_max)))
    and ($14 is null or (pd.city_id = $14 and public.can_view_profile_field(l.user_id, pp.location_audience)))
    and ($15 is null or lower(pd.experience_level) = lower($15))
    and ($16 is null or l.evidence_status::text = $16)';
begin
  select pg_catalog.pg_get_functiondef(
    'public.get_ranked_lift_ids(text,text,uuid,text,text,text,text,text,numeric,numeric,boolean,text,integer)'::pg_catalog.regprocedure
  ) into definition;

  if definition is null then
    raise exception 'the exact-repetition leaderboard overload is required';
  end if;

  updated_definition := pg_catalog.regexp_replace(
    definition,
    'repetition_count integer\s*\)',
    'repetition_count integer, city_id_filter uuid, experience_level_filter text, evidence_filter text)',
    'i'
  );
  updated_definition := pg_catalog.replace(updated_definition, original_rep_filter, extended_filters);

  if updated_definition = definition
    or pg_catalog.strpos(updated_definition, 'city_id_filter uuid, experience_level_filter text, evidence_filter text)') = 0
    or pg_catalog.strpos(updated_definition, '$14 is null or (pd.city_id = $14') = 0
    or pg_catalog.strpos(updated_definition, '$15 is null or lower(pd.experience_level)') = 0
    or pg_catalog.strpos(updated_definition, '$16 is null or l.evidence_status::text = $16') = 0
    or pg_catalog.strpos(pg_catalog.upper(updated_definition), 'SECURITY DEFINER') = 0
    or pg_catalog.strpos(updated_definition, 'SET search_path TO ''pg_catalog''') = 0
  then
    raise exception 'server-side leaderboard filters were not added safely';
  end if;

  execute updated_definition;
end;
$migration$;

revoke all on function public.get_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, boolean, text, integer, uuid, text, text) from public;
revoke all on function public.get_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, boolean, text, integer, uuid, text, text) from anon;
grant execute on function public.get_ranked_lift_ids(text, text, uuid, text, text, text, text, text, numeric, numeric, boolean, text, integer, uuid, text, text) to authenticated;

commit;
