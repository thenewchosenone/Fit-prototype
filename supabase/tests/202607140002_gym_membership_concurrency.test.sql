create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;

-- The fixture must be committed before independent dblink sessions can see it.
begin;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values (
  '11000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'concurrency@example.test', '',
  '{}'::jsonb, '{}'::jsonb, now(), now()
);

insert into public.gyms (id, name, status) values
  ('21000000-0000-0000-0000-000000000001', 'Concurrency Gym One', 'active'),
  ('21000000-0000-0000-0000-000000000002', 'Concurrency Gym Two', 'active'),
  ('21000000-0000-0000-0000-000000000003', 'Concurrency Gym Three', 'active'),
  ('21000000-0000-0000-0000-000000000004', 'Concurrency Gym Four', 'active');

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true);
select public.join_gym('21000000-0000-0000-0000-000000000001', true);
select public.join_gym('21000000-0000-0000-0000-000000000002', false);
commit;

begin;
select plan(4);

select extensions.dblink_connect('membership_join_a', 'dbname=' || current_database());
select extensions.dblink_connect('membership_join_b', 'dbname=' || current_database());

select is(
  extensions.dblink_send_query(
    'membership_join_a',
    $$
      with claims as materialized (
        select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true)
      ), joined as (
        select public.join_gym('21000000-0000-0000-0000-000000000003', false) from claims
      )
      select 1::integer from joined
    $$
  ),
  1,
  'first competing join is dispatched asynchronously'
);

select is(
  extensions.dblink_send_query(
    'membership_join_b',
    $$
      with claims as materialized (
        select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true)
      ), joined as (
        select public.join_gym('21000000-0000-0000-0000-000000000004', false) from claims
      )
      select 1::integer from joined
    $$
  ),
  1,
  'second competing join is dispatched asynchronously'
);

create or replace function pg_temp.collect_dblink_result(connection_name text)
returns text
language plpgsql
as $$
begin
  perform response.result
  from extensions.dblink_get_result(connection_name) as response(result integer);
  return 'ok';
exception when others then
  return sqlstate;
end;
$$;

create temporary table concurrency_results (result text not null);
insert into concurrency_results values
  (pg_temp.collect_dblink_result('membership_join_a')),
  (pg_temp.collect_dblink_result('membership_join_b'));

select is(
  (select count(*)::integer from concurrency_results where result = 'ok'),
  1,
  'only one of two concurrent third-gym joins succeeds'
);
select is(
  (
    select count(*)::integer
    from public.gym_memberships
    where user_id = '11000000-0000-0000-0000-000000000001'
      and left_at is null
  ),
  3,
  'concurrent joins cannot exceed three active memberships'
);

select extensions.dblink_disconnect('membership_join_a');
select extensions.dblink_disconnect('membership_join_b');

select * from finish();

delete from auth.users where id = '11000000-0000-0000-0000-000000000001';
delete from public.gyms where id in (
  '21000000-0000-0000-0000-000000000001',
  '21000000-0000-0000-0000-000000000002',
  '21000000-0000-0000-0000-000000000003',
  '21000000-0000-0000-0000-000000000004'
);
commit;
