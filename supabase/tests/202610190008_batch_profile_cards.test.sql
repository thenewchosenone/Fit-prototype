begin;

select plan(6);

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('99800000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'batch-viewer@example.test', '', '{}', '{}', now(), now()),
  ('99800000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'batch-public@example.test', '', '{}', '{}', now(), now()),
  ('99800000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'batch-private@example.test', '', '{}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles(id, username, handle, display_name)
values
  ('99800000-0000-0000-0000-000000000001', 'batch_viewer', '@batch_viewer', 'Batch Viewer'),
  ('99800000-0000-0000-0000-000000000002', 'batch_public', '@batch_public', 'Batch Public'),
  ('99800000-0000-0000-0000-000000000003', 'batch_private', '@batch_private', 'Batch Private')
on conflict (id) do nothing;

insert into public.profile_private_details(user_id)
values
  ('99800000-0000-0000-0000-000000000001'),
  ('99800000-0000-0000-0000-000000000002'),
  ('99800000-0000-0000-0000-000000000003')
on conflict (user_id) do nothing;

insert into public.profile_privacy(user_id, profile_audience, bodyweight_audience)
values
  ('99800000-0000-0000-0000-000000000001', 'public', 'private'),
  ('99800000-0000-0000-0000-000000000002', 'public', 'public'),
  ('99800000-0000-0000-0000-000000000003', 'private', 'public')
on conflict (user_id) do update set profile_audience = excluded.profile_audience,
  bodyweight_audience = excluded.bodyweight_audience;

select ok(
  (select prosecdef and proconfig = array['search_path=pg_catalog']
   from pg_proc where oid = 'public.get_profile_cards(uuid[])'::regprocedure),
  'batch profile-card RPC is security definer with a fixed search path'
);
select ok(not has_function_privilege('anon', 'public.get_profile_cards(uuid[])', 'execute'), 'anon cannot execute batch profile-card RPC');
select ok(has_function_privilege('authenticated', 'public.get_profile_cards(uuid[])', 'execute'), 'authenticated can execute batch profile-card RPC');

set local role authenticated;
select set_config('request.jwt.claim.sub', '99800000-0000-0000-0000-000000000001', true);

select is(
  (select array_agg(card.id order by card.ordinality)
   from public.get_profile_cards(array[
     '99800000-0000-0000-0000-000000000002'::uuid,
     '99800000-0000-0000-0000-000000000001'::uuid
   ]) with ordinality as card(
     id, username, display_name, avatar_path, bio, discipline, training_goal,
     age_band, sex_category, city, region, primary_gym_id, primary_gym_name,
     bodyweight_pounds, bodyweight_last_updated_at, ordinality
   )),
  array['99800000-0000-0000-0000-000000000002'::uuid, '99800000-0000-0000-0000-000000000001'::uuid],
  'batch results preserve requested order and expose visible profiles'
);

select is(
  (select count(*)::integer from public.get_profile_cards(array[
    '99800000-0000-0000-0000-000000000002'::uuid,
    '99800000-0000-0000-0000-000000000003'::uuid
  ])),
  1,
  'private profile is omitted using the single-card privacy policy'
);

select is(
  (select count(*)::integer from public.get_profile_cards(array_fill('99800000-0000-0000-0000-000000000002'::uuid, array[201]))),
  0,
  'requests above the 200-card batch limit return no cards'
);

select * from finish();
rollback;
