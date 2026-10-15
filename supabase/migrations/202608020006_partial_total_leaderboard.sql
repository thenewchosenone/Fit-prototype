begin;

-- Total rankings represent the best lifts currently logged. A user with only
-- one or two powerlifting movements should still receive a partial total.
do $migration$
declare
  definition text;
  body text;
  updated_body text;
  body_start integer;
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

  body_start := position('AS $function$' in definition) + length('AS $function$');
  body := substr(definition, body_start);
  updated_body := replace(body, '(exercise_id is null or', '($1 is null or');
  updated_body := replace(updated_body, 'replace(lower(exercise_id),''-'',''_'')', 'replace(lower($1),''-'',''_'')');
  updated_body := replace(updated_body, '(ranking_type in', '($2 in');
  updated_body := replace(updated_body, 'ranking_type not in', '$2 not in');
  updated_body := replace(updated_body, 'ranking_type=''Pound-for-pound''', '$2=''Pound-for-pound''');
  updated_body := replace(updated_body, 'ranking_type=''Relative total''', '$2=''Relative total''');
  updated_body := replace(updated_body, '(gym_id is null or', '($3 is null or');
  updated_body := replace(updated_body, 'l.gym_id = gym_id::text', 'l.gym_id = $3::text');
  updated_body := replace(updated_body, '(city is null or', '($4 is null or');
  updated_body := replace(updated_body, 'lower(city)', 'lower($4)');
  updated_body := replace(updated_body, '(region is null or', '($5 is null or');
  updated_body := replace(updated_body, 'lower(region)', 'lower($5)');
  updated_body := replace(updated_body, '(country is null or', '($6 is null or');
  updated_body := replace(updated_body, 'lower(country)', 'lower($6)');
  updated_body := replace(updated_body, '(age_band is null or', '($7 is null or');
  updated_body := replace(updated_body, '=age_band and', '=$7 and');
  updated_body := replace(updated_body, '(sex_category is null or', '($8 is null or');
  updated_body := replace(updated_body, 'lower(sex_category)', 'lower($8)');
  updated_body := replace(updated_body, '(weight_min_kg is null or', '($9 is null or');
  updated_body := replace(updated_body, ' > weight_min_kg)', ' > $9)');
  updated_body := replace(updated_body, '(weight_max_kg is null or', '($10 is null or');
  updated_body := replace(updated_body, ' <= weight_max_kg)', ' <= $10)');
  updated_body := replace(updated_body, '(not verified_only or', '(not $11 or');
  updated_body := replace(updated_body, 'case time_range when', 'case $12 when');
  updated_body := replace(updated_body, 'count(distinct b.total_family) = 3', 'count(distinct b.total_family) >= 1');

  if updated_body = body then
    raise exception 'leaderboard parameter and partial total changes were not found';
  end if;

  execute substr(definition, 1, body_start - 1) || updated_body;
end;
$migration$;

commit;
