begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(12);

select has_table('public', 'location_countries', 'canonical countries exist');
select has_table('public', 'location_regions', 'canonical regions exist');
select has_table('public', 'location_cities', 'canonical cities exist');
select has_table('public', 'location_city_aliases', 'canonical city aliases exist');
select has_column('public', 'profile_private_details', 'city_id', 'private details can store canonical city id');
select has_function('public', 'search_cities', array['text', 'text', 'text', 'integer'], 'city search rpc exists');

insert into public.location_countries(code, name, geoname_id)
values ('US', 'United States', 6252001)
on conflict do nothing;

insert into public.location_regions(id, country_code, code, name, geoname_id)
values ('30000000-0000-0000-0000-000000000001', 'US', 'FL', 'Florida', 4155751)
on conflict do nothing;

insert into public.location_cities(id, country_code, region_id, region_code, name, ascii_name, latitude, longitude, population, geoname_id, timezone)
values
  ('30000000-0000-0000-0000-000000000101', 'US', '30000000-0000-0000-0000-000000000001', 'FL', 'Miami', 'Miami', 25.7743, -80.1937, 442241, 4164138, 'America/New_York'),
  ('30000000-0000-0000-0000-000000000102', 'US', '30000000-0000-0000-0000-000000000001', 'FL', 'Miami Beach', 'Miami Beach', 25.7907, -80.1300, 82890, 4164143, 'America/New_York')
on conflict do nothing;

insert into public.location_city_aliases(city_id, alias)
values ('30000000-0000-0000-0000-000000000101', 'MIA')
on conflict do nothing;

select is(
  (select count(*)::integer from public.search_cities('US', 'Florida', 'mia', 8)),
  1,
  'alias search returns canonical Miami once'
);

select is(
  (select city from public.search_cities('US', 'Florida', 'miam', 8) limit 1),
  'Miami',
  'prefix search prioritizes larger canonical city'
);

set local role anon;
select is(
  (select count(*)::integer from public.search_cities('US', 'Florida', 'mia', 8)),
  1,
  'anon can search public canonical cities'
);
reset role;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values (
  '30000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'locations@example.test',
  '',
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
)
on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000201', true);

select lives_ok(
  $$
    select public.save_own_profile(
      'Location User', '', 'lb', null, 'male', 180,
      'Ignored City', 'Ignored Region', 'US', 1, 'beginner',
      'public', 'private', 'public', 'public', 'public', 'friends',
      true, '30000000-0000-0000-0000-000000000101'
    )
  $$,
  'authenticated user can save canonical city id'
);

select is(
  (select city from public.profile_private_details where user_id = '30000000-0000-0000-0000-000000000201'),
  'Miami',
  'save derives city from canonical id'
);

select is(
  (select region from public.profile_private_details where user_id = '30000000-0000-0000-0000-000000000201'),
  'Florida',
  'save derives region from canonical id'
);

select throws_ok(
  $$
    select public.save_own_profile(
      'Location User', '', 'lb', null, 'male', 180,
      'Fake', 'Florida', 'US', 1, 'beginner',
      'public', 'private', 'public', 'public', 'public', 'friends',
      true, '30000000-0000-0000-0000-000000009999'
    )
  $$,
  '22023',
  'Choose a valid city',
  'invalid canonical city id is rejected'
);

select * from finish();

rollback;
