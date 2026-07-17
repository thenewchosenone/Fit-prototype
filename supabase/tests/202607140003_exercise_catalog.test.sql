begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(20);

select has_table('public', 'exercise_catalog_versions', 'catalog versions exist');
select has_table('public', 'exercises', 'canonical exercises exist');
select has_table('public', 'exercise_aliases', 'legacy aliases exist');
select is((select count(*)::integer from public.exercise_catalog_versions where is_current), 1, 'one current catalog version exists');
select is((select count(*)::integer from public.exercises where ranking_movement is not null), 5, 'five exercises map to ranked movements');
select is((select count(*)::integer from public.exercise_aliases a left join public.exercises e on e.id = a.exercise_id where e.id is null), 0, 'every alias resolves to one exercise');
select is((select count(*)::integer from public.exercise_aliases), (select count(distinct alias)::integer from public.exercise_aliases), 'aliases are globally unique');
select is((select id from public.resolve_exercise_identifier('bench_press')), 'barbell-bench-press', 'iOS bench alias resolves');
select is((select id from public.resolve_exercise_identifier('barbell-bench')), 'barbell-bench-press', 'web bench alias resolves');
select is((select id from public.resolve_exercise_identifier('sumo_deadlift')), 'sumo-deadlift', 'sumo remains a distinct exercise');
select is((select ranking_movement from public.resolve_exercise_identifier('sumo_deadlift')), 'deadlift', 'sumo maps to competitive deadlift');
select is((select ranking_movement from public.resolve_exercise_identifier('incline_bench_press')), null, 'incline bench is not competition bench');

select throws_ok(
  $$insert into public.exercises(id, display_name, ranking_movement, catalog_version) values ('bad-movement', 'Bad Movement', 'curl', 1)$$,
  '23514', null, 'invalid ranking movement is rejected'
);
select throws_ok(
  $$insert into public.exercises(id, display_name, catalog_version) values ('Bad_ID', 'Bad ID', 1)$$,
  '23514', null, 'canonical IDs must be lowercase hyphenated'
);
select throws_ok(
  $$insert into public.exercises(id, display_name, catalog_version, metadata) values ('bad-metadata', 'Bad Metadata', 1, '[]')$$,
  '23514', null, 'metadata must follow the object schema boundary'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select ok((select count(*) from public.exercises where status = 'active') > 20, 'authenticated users can read active catalog entries');
select is((select id from public.resolve_exercise_identifier('deadlift')), 'conventional-deadlift', 'authenticated users can use resolver');
select throws_ok(
  $$insert into public.exercises(id, display_name, catalog_version) values ('client-write', 'Client Write', 1)$$,
  '42501', null, 'normal clients cannot modify catalog'
);

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select count(*) from public.exercises$$,
  '42501',
  'permission denied for table exercises',
  'anonymous users cannot browse beta catalog'
);
select is(
  has_function_privilege('anon', 'public.resolve_exercise_identifier(text)', 'EXECUTE'),
  false,
  'anonymous users cannot execute the resolver'
);

reset role;
select * from finish();
rollback;
