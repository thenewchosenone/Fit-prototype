begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(101);

create function pg_temp.sqlstate_of(command text)
returns text
language plpgsql
as $$
begin
  execute command;
  return null;
exception when others then
  return sqlstate;
end;
$$;


create function pg_temp.check_privacy_controls()
returns setof text
language plpgsql
as $$
declare
  field text;
  target text;
  before_value text;
  after_value text;
  targets text[];
begin
  foreach field in array array[
    'profile_audience', 'age_band_audience', 'division_audience',
    'bodyweight_audience', 'location_audience', 'gym_audience',
    'friend_list_audience', 'workout_stats_audience',
    'show_lift_videos', 'share_workout_starts_with_friends', 'share_prs_with_friends'
  ] loop
    targets := case when field like '%audience' then array['private', 'friends', 'gym', 'public']
      else array['true', 'false'] end;
    foreach target in array targets loop
      select to_jsonb(p)->>field into before_value
        from public.profile_privacy p where user_id = auth.uid();
      return next is(pg_temp.sqlstate_of(format(
        'select public.save_own_settings(%L::jsonb, %L::jsonb)',
        jsonb_build_object(field, target), jsonb_build_object(field, before_value)
      )), null::text, field || ' saves ' || target);
      select to_jsonb(p)->>field into after_value
        from public.profile_privacy p where user_id = auth.uid();
      return next is(after_value, target, field || ' reads back ' || target);
    end loop;
  end loop;
end;
$$;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('b0300000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'settings-owner@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('b0300000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'settings-other@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

update public.profile_private_details
set preferred_unit = 'lb', training_focus = 'bodybuilding'
where user_id in (
  'b0300000-0000-0000-0000-000000000001',
  'b0300000-0000-0000-0000-000000000002'
);
update public.profile_privacy
set profile_audience = 'public'
where user_id in (
  'b0300000-0000-0000-0000-000000000001',
  'b0300000-0000-0000-0000-000000000002'
);
create temp table profile_identity_before on commit drop as
select id, username, role::text as role
from public.profiles
where id = 'b0300000-0000-0000-0000-000000000001';
grant select on profile_identity_before to authenticated;

select has_function('public', 'save_own_settings', array['jsonb', 'jsonb'], 'settings RPC exists');
select ok((select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'save_own_settings'), 'settings RPC runs as security definer');
select ok((select 'search_path=pg_catalog' = any(p.proconfig) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'save_own_settings'), 'settings RPC pins its search path');
select ok(has_function_privilege('authenticated', 'public.save_own_settings(jsonb,jsonb)', 'EXECUTE'), 'authenticated can execute settings RPC');
select ok(not has_function_privilege('anon', 'public.save_own_settings(jsonb,jsonb)', 'EXECUTE'), 'anonymous cannot execute settings RPC');

set local role anon;
select is(pg_temp.sqlstate_of($$select public.save_own_settings('{}'::jsonb, '{}'::jsonb)$$), '42501', 'anonymous invocation is denied');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select is(pg_temp.sqlstate_of($$select public.save_own_settings('{}'::jsonb, '{}'::jsonb)$$), '42501', 'authenticated invocation requires an account');

select set_config('request.jwt.claim.sub', 'b0300000-0000-0000-0000-000000000001', true);
select is(pg_temp.sqlstate_of($$select public.save_own_settings('{"role":"Admin"}'::jsonb, '{"role":"Member"}'::jsonb)$$), '22023', 'authority fields are rejected by the allowlist');
select is((select role::text from public.profiles where id = auth.uid()),
  (select role from profile_identity_before), 'settings cannot change the account role');
select is(pg_temp.sqlstate_of($$select public.save_own_settings('{"user_id":"b0300000-0000-0000-0000-000000000002"}'::jsonb, '{"user_id":"b0300000-0000-0000-0000-000000000002"}'::jsonb)$$), '22023', 'a caller cannot target another account');

select set_config('request.jwt.claim.sub', 'b0300000-0000-0000-0000-000000000002', true);
select is(pg_temp.sqlstate_of($$select public.save_own_settings('{"preferred_unit":"kg"}'::jsonb, '{"preferred_unit":"lb"}'::jsonb)$$), null::text, 'another account can only update its own settings');
select is((select preferred_unit from public.profile_private_details where user_id = auth.uid()), 'kg', 'the caller own setting changes');
reset role;
select is((select preferred_unit from public.profile_private_details where user_id = 'b0300000-0000-0000-0000-000000000001'), 'lb', 'the other account remains unchanged');
set local role authenticated;

select set_config('request.jwt.claim.sub', 'b0300000-0000-0000-0000-000000000001', true);
update public.profile_privacy set profile_audience = 'friends' where user_id = auth.uid();
select is(pg_temp.sqlstate_of($$select public.save_own_settings(
  '{"preferred_unit":"kg","profile_audience":"private"}'::jsonb,
  '{"preferred_unit":"lb","profile_audience":"public"}'::jsonb)$$), '40001', 'same-field conflict rejects the whole request');
select is((select preferred_unit from public.profile_private_details where user_id = auth.uid()), 'lb', 'conflict leaves the otherwise valid detail change unapplied');
select is((select profile_audience from public.profile_privacy where user_id = auth.uid()), 'friends', 'conflict preserves the newer privacy value');

select is(pg_temp.sqlstate_of($$select public.save_own_settings(
  '{"preferred_unit":"kg"}'::jsonb,
  '{"preferred_unit":"lb"}'::jsonb)$$), null::text, 'disjoint setting change is accepted');
select is((select profile_audience from public.profile_privacy where user_id = auth.uid()), 'friends', 'disjoint update preserves another device privacy edit');
select set_config('test.settings_private_details_xmin',
  (select xmin::text from public.profile_private_details where user_id = auth.uid()), true);
select is(pg_temp.sqlstate_of($$select public.save_own_settings(
  '{"preferred_unit":"kg"}'::jsonb,
  '{"preferred_unit":"lb"}'::jsonb)$$), null::text, 'repeating the same settings write is idempotent');
select is((select xmin::text from public.profile_private_details where user_id = auth.uid()),
  current_setting('test.settings_private_details_xmin'), 'idempotent retry does not issue another update');
select is((select username from public.profiles where id = auth.uid()),
  (select username from profile_identity_before), 'settings update preserves profile identity');

select is(pg_temp.sqlstate_of($$select public.save_own_settings(
  '{"training_focus":null}'::jsonb,
  '{"training_focus":"bodybuilding"}'::jsonb)$$), null::text, 'training focus can be explicitly cleared');
select ok((select training_focus is null from public.profile_private_details where user_id = auth.uid()), 'null focus is persisted');
select is(pg_temp.sqlstate_of($$select public.save_own_settings(
  '{"profile_audience":"invalid-audience"}'::jsonb,
  '{"profile_audience":"friends"}'::jsonb)$$), '23514', 'invalid enum value is rejected by the database constraint');
select is((select profile_audience from public.profile_privacy where user_id = auth.uid()), 'friends', 'invalid value leaves stored privacy unchanged');

select * from pg_temp.check_privacy_controls();

select * from finish();
rollback;
