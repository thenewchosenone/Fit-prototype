begin;

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('99100000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bodyweight-viewer@example.test', '', '{}', '{}', now(), now()),
  ('99100000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bodyweight-owner@example.test', '', '{}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles(id, username, handle, display_name)
values
  ('99100000-0000-0000-0000-000000000001', 'weight_viewer', '@weight_viewer', 'Weight Viewer'),
  ('99100000-0000-0000-0000-000000000002', 'weight_owner', '@weight_owner', 'Weight Owner')
on conflict (id) do nothing;

insert into public.profile_private_details(user_id)
values ('99100000-0000-0000-0000-000000000001'), ('99100000-0000-0000-0000-000000000002')
on conflict (user_id) do nothing;

insert into public.profile_privacy(user_id, profile_audience, bodyweight_audience)
values
  ('99100000-0000-0000-0000-000000000001', 'public', 'private'),
  ('99100000-0000-0000-0000-000000000002', 'public', 'public')
on conflict (user_id) do update set profile_audience = excluded.profile_audience,
  bodyweight_audience = excluded.bodyweight_audience;

insert into public.bodyweight_records(id, user_id, weight, recorded_at, notes)
values
  ('99100000-0000-0000-0000-000000000011', '99100000-0000-0000-0000-000000000002', 190, '2026-10-08 12:00:00+00', ''),
  ('99100000-0000-0000-0000-000000000012', '99100000-0000-0000-0000-000000000002', 188, '2026-10-10 12:00:00+00', '')
on conflict (id) do update set weight = excluded.weight, recorded_at = excluded.recorded_at;

set local role authenticated;
select set_config('request.jwt.claim.sub', '99100000-0000-0000-0000-000000000001', true);

do $$
declare visible_weight numeric; visible_date timestamptz;
begin
  select bodyweight_pounds, bodyweight_last_updated_at
    into visible_weight, visible_date
  from public.get_profile_card('99100000-0000-0000-0000-000000000002');
  if visible_weight <> 188 or visible_date <> '2026-10-10 12:00:00+00'::timestamptz then
    raise exception 'Public profile did not return the latest logged weight and date';
  end if;
end
$$;

reset role;
update public.profile_privacy set bodyweight_audience = 'private'
where user_id = '99100000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub', '99100000-0000-0000-0000-000000000001', true);

do $$
declare visible_weight numeric; visible_date timestamptz;
begin
  select bodyweight_pounds, bodyweight_last_updated_at
    into visible_weight, visible_date
  from public.get_profile_card('99100000-0000-0000-0000-000000000002');
  if visible_weight is not null or visible_date is not null then
    raise exception 'Private bodyweight leaked through public profile card';
  end if;
end
$$;

select set_config('request.jwt.claim.sub', '99100000-0000-0000-0000-000000000002', true);
do $$
declare visible_weight numeric; visible_date timestamptz;
begin
  select bodyweight_pounds, bodyweight_last_updated_at
    into visible_weight, visible_date
  from public.get_profile_card('99100000-0000-0000-0000-000000000002');
  if visible_weight <> 188 or visible_date <> '2026-10-10 12:00:00+00'::timestamptz then
    raise exception 'Owner could not see their own private logged bodyweight';
  end if;
end
$$;

rollback;
