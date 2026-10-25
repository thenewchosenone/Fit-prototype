-- LiftRank canonical exercise identity catalog.
-- Exercise identity is intentionally separate from competitive ranking movement.

create table public.exercise_catalog_versions (
  version integer primary key check (version > 0),
  schema_version integer not null default 1 check (schema_version = 1),
  is_current boolean not null default false,
  published_at timestamptz not null default now(),
  notes text not null default '' check (char_length(notes) <= 1000)
);

create unique index exercise_catalog_one_current_version
  on public.exercise_catalog_versions ((is_current)) where is_current;

create table public.exercises (
  id text primary key check (id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  display_name text not null check (char_length(display_name) between 2 and 120),
  status text not null default 'active' check (status in ('active', 'retired')),
  ranking_movement text check (
    ranking_movement is null or ranking_movement in
      ('bench_press', 'back_squat', 'deadlift', 'overhead_press')
  ),
  catalog_version integer not null references public.exercise_catalog_versions(version),
  metadata jsonb not null default '{"schema_version":1}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint exercise_metadata_schema check (
    metadata ? 'schema_version'
    and jsonb_typeof(metadata -> 'schema_version') = 'number'
    and (metadata ->> 'schema_version')::integer = 1
  )
);

create table public.exercise_aliases (
  alias text primary key check (alias ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{1,159}$'),
  exercise_id text not null references public.exercises(id) on update cascade on delete restrict,
  source_platform text not null check (source_platform in ('ios', 'web', 'shared', 'legacy')),
  classification text not null check (
    classification in ('exact', 'alias', 'variation', 'duplicate')
  ),
  created_at timestamptz not null default now()
);

create index exercise_aliases_exercise_id on public.exercise_aliases(exercise_id);
create index exercises_active_name on public.exercises(display_name) where status = 'active';
create index exercises_ranking_movement on public.exercises(ranking_movement)
  where ranking_movement is not null;

create trigger exercises_updated_at
before update on public.exercises
for each row execute function public.set_server_updated_at();

insert into public.exercise_catalog_versions(version, is_current, notes)
values (1, true, 'Initial iOS and web identifier reconciliation')
on conflict (version) do nothing;

insert into public.exercises(id, display_name, ranking_movement, catalog_version, metadata) values
  ('barbell-bench-press', 'Barbell Bench Press', 'bench_press', 1, '{"schema_version":1,"body_part":"Chest","equipment":"Barbell","movement_type":"Horizontal Push"}'),
  ('incline-barbell-bench-press', 'Incline Barbell Bench Press', null, 1, '{"schema_version":1,"body_part":"Upper Chest","equipment":"Barbell","movement_type":"Horizontal Push"}'),
  ('dumbbell-bench-press', 'Dumbbell Bench Press', null, 1, '{"schema_version":1,"body_part":"Chest","equipment":"Dumbbell","movement_type":"Horizontal Push"}'),
  ('machine-chest-press', 'Machine Chest Press', null, 1, '{"schema_version":1,"body_part":"Chest","equipment":"Machine","movement_type":"Horizontal Push"}'),
  ('cable-fly', 'Cable Fly', null, 1, '{"schema_version":1,"body_part":"Chest","equipment":"Cable","movement_type":"Isolation"}'),
  ('pec-deck', 'Pec Deck', null, 1, '{"schema_version":1,"body_part":"Chest","equipment":"Machine","movement_type":"Isolation"}'),
  ('back-squat', 'Back Squat', 'back_squat', 1, '{"schema_version":1,"body_part":"Quads","equipment":"Barbell","movement_type":"Squat"}'),
  ('front-squat', 'Front Squat', null, 1, '{"schema_version":1,"body_part":"Quads","equipment":"Barbell","movement_type":"Squat"}'),
  ('leg-press', 'Leg Press', null, 1, '{"schema_version":1,"body_part":"Quads","equipment":"Machine","movement_type":"Squat"}'),
  ('hack-squat', 'Hack Squat', null, 1, '{"schema_version":1,"body_part":"Quads","equipment":"Machine","movement_type":"Squat"}'),
  ('leg-extension', 'Leg Extension', null, 1, '{"schema_version":1,"body_part":"Quads","equipment":"Machine","movement_type":"Isolation"}'),
  ('conventional-deadlift', 'Conventional Deadlift', 'deadlift', 1, '{"schema_version":1,"body_part":"Full Body","equipment":"Barbell","movement_type":"Hinge"}'),
  ('sumo-deadlift', 'Sumo Deadlift', 'deadlift', 1, '{"schema_version":1,"body_part":"Full Body","equipment":"Barbell","movement_type":"Hinge"}'),
  ('romanian-deadlift', 'Romanian Deadlift', null, 1, '{"schema_version":1,"body_part":"Hamstrings","equipment":"Barbell","movement_type":"Hinge"}'),
  ('lying-leg-curl', 'Lying Leg Curl', null, 1, '{"schema_version":1,"body_part":"Hamstrings","equipment":"Machine","movement_type":"Isolation"}'),
  ('barbell-hip-thrust', 'Barbell Hip Thrust', null, 1, '{"schema_version":1,"body_part":"Glutes","equipment":"Barbell","movement_type":"Hinge"}'),
  ('lat-pulldown', 'Lat Pulldown', null, 1, '{"schema_version":1,"body_part":"Lats","equipment":"Cable","movement_type":"Vertical Pull"}'),
  ('pull-up', 'Pull-Up', null, 1, '{"schema_version":1,"body_part":"Lats","equipment":"Bodyweight","movement_type":"Vertical Pull"}'),
  ('barbell-row', 'Barbell Row', null, 1, '{"schema_version":1,"body_part":"Back","equipment":"Barbell","movement_type":"Horizontal Pull"}'),
  ('seated-cable-row', 'Seated Cable Row', null, 1, '{"schema_version":1,"body_part":"Back","equipment":"Cable","movement_type":"Horizontal Pull"}'),
  ('standing-barbell-overhead-press', 'Standing Barbell Overhead Press', 'overhead_press', 1, '{"schema_version":1,"body_part":"Shoulders","equipment":"Barbell","movement_type":"Vertical Push"}'),
  ('dumbbell-lateral-raise', 'Dumbbell Lateral Raise', null, 1, '{"schema_version":1,"body_part":"Shoulders","equipment":"Dumbbell","movement_type":"Isolation"}'),
  ('cable-face-pull', 'Cable Face Pull', null, 1, '{"schema_version":1,"body_part":"Rear Delts","equipment":"Cable","movement_type":"Isolation"}'),
  ('barbell-curl', 'Barbell Curl', null, 1, '{"schema_version":1,"body_part":"Biceps","equipment":"Barbell","movement_type":"Isolation"}'),
  ('dumbbell-curl', 'Dumbbell Curl', null, 1, '{"schema_version":1,"body_part":"Biceps","equipment":"Dumbbell","movement_type":"Isolation"}'),
  ('triceps-pushdown', 'Triceps Pushdown', null, 1, '{"schema_version":1,"body_part":"Triceps","equipment":"Cable","movement_type":"Isolation"}'),
  ('dip', 'Dip', null, 1, '{"schema_version":1,"body_part":"Chest/Triceps","equipment":"Bodyweight","movement_type":"Vertical Push"}'),
  ('cable-crunch', 'Cable Crunch', null, 1, '{"schema_version":1,"body_part":"Core","equipment":"Cable","movement_type":"Core"}'),
  ('plank', 'Plank', null, 1, '{"schema_version":1,"body_part":"Core","equipment":"Bodyweight","movement_type":"Core","tracking_type":"Time"}')
on conflict (id) do nothing;

insert into public.exercise_aliases(alias, exercise_id, source_platform, classification) values
  ('bench_press', 'barbell-bench-press', 'ios', 'alias'),
  ('barbell-bench', 'barbell-bench-press', 'web', 'alias'),
  ('incline_bench_press', 'incline-barbell-bench-press', 'ios', 'alias'),
  ('incline-bench', 'incline-barbell-bench-press', 'web', 'alias'),
  ('db_bench_press', 'dumbbell-bench-press', 'ios', 'alias'),
  ('db-bench', 'dumbbell-bench-press', 'web', 'alias'),
  ('machine_chest_press', 'machine-chest-press', 'ios', 'alias'),
  ('machine-chest', 'machine-chest-press', 'web', 'alias'),
  ('cable_fly', 'cable-fly', 'ios', 'alias'),
  ('pec_deck', 'pec-deck', 'ios', 'alias'),
  ('squat', 'back-squat', 'ios', 'alias'),
  ('front_squat', 'front-squat', 'ios', 'alias'),
  ('leg_press', 'leg-press', 'ios', 'alias'),
  ('hack_squat', 'hack-squat', 'ios', 'alias'),
  ('leg_extension', 'leg-extension', 'ios', 'alias'),
  ('deadlift', 'conventional-deadlift', 'web', 'alias'),
  ('conventional_deadlift', 'conventional-deadlift', 'ios', 'alias'),
  ('sumo_deadlift', 'sumo-deadlift', 'ios', 'alias'),
  ('rdl', 'romanian-deadlift', 'web', 'alias'),
  ('romanian_deadlift', 'romanian-deadlift', 'ios', 'alias'),
  ('leg-curl', 'lying-leg-curl', 'web', 'alias'),
  ('lying_leg_curl', 'lying-leg-curl', 'ios', 'alias'),
  ('hip-thrust', 'barbell-hip-thrust', 'web', 'alias'),
  ('barbell_hip_thrust', 'barbell-hip-thrust', 'ios', 'alias'),
  ('lat_pulldown', 'lat-pulldown', 'ios', 'alias'),
  ('pull_up', 'pull-up', 'ios', 'alias'),
  ('barbell_row', 'barbell-row', 'ios', 'alias'),
  ('seated-row', 'seated-cable-row', 'web', 'alias'),
  ('seated_cable_row', 'seated-cable-row', 'ios', 'alias'),
  ('ohp', 'standing-barbell-overhead-press', 'web', 'alias'),
  ('overhead_press', 'standing-barbell-overhead-press', 'ios', 'alias'),
  ('lateral-raise', 'dumbbell-lateral-raise', 'web', 'alias'),
  ('db_lateral_raise', 'dumbbell-lateral-raise', 'ios', 'alias'),
  ('face-pull', 'cable-face-pull', 'web', 'alias'),
  ('face_pull', 'cable-face-pull', 'ios', 'alias'),
  ('barbell_curl', 'barbell-curl', 'ios', 'alias'),
  ('db-curl', 'dumbbell-curl', 'web', 'alias'),
  ('db_curl', 'dumbbell-curl', 'ios', 'alias'),
  ('tricep-pushdown', 'triceps-pushdown', 'web', 'alias'),
  ('triceps_pressdown', 'triceps-pushdown', 'ios', 'alias'),
  ('weighted_dip', 'dip', 'ios', 'variation'),
  ('cable_crunch', 'cable-crunch', 'ios', 'alias')
on conflict (alias) do nothing;

create or replace function public.resolve_exercise_identifier(identifier text)
returns table (
  id text,
  display_name text,
  status text,
  ranking_movement text,
  metadata jsonb
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select e.id, e.display_name, e.status, e.ranking_movement, e.metadata
  from public.exercises e
  where e.id = identifier
  union all
  select e.id, e.display_name, e.status, e.ranking_movement, e.metadata
  from public.exercise_aliases a
  join public.exercises e on e.id = a.exercise_id
  where a.alias = identifier
    and not exists (select 1 from public.exercises direct where direct.id = identifier)
  limit 1
$$;

alter table public.exercise_catalog_versions enable row level security;
alter table public.exercises enable row level security;
alter table public.exercise_aliases enable row level security;

create policy "catalog versions authenticated read"
  on public.exercise_catalog_versions for select to authenticated using (true);
create policy "exercises authenticated read"
  on public.exercises for select to authenticated using (true);
create policy "exercise aliases authenticated read"
  on public.exercise_aliases for select to authenticated using (true);

revoke all on public.exercise_catalog_versions from public, anon, authenticated;
revoke all on public.exercises from public, anon, authenticated;
revoke all on public.exercise_aliases from public, anon, authenticated;
grant select on public.exercise_catalog_versions, public.exercises, public.exercise_aliases to authenticated;

revoke execute on function public.resolve_exercise_identifier(text) from public, anon;
grant execute on function public.resolve_exercise_identifier(text) to authenticated;

