begin;
select plan(6);

select ok(
  not has_table_privilege('authenticated', 'public.lift_submissions', 'SELECT'),
  'authenticated clients cannot read complete lift rows'
);
select ok(
  not has_column_privilege('authenticated', 'public.lift_submissions', 'bodyweight', 'SELECT'),
  'authenticated clients cannot select the raw lift bodyweight column'
);
select ok(
  not has_column_privilege('authenticated', 'public.lift_submissions', 'bodyweight_class', 'SELECT'),
  'authenticated clients cannot select derived bodyweight class'
);
select ok(
  has_column_privilege('authenticated', 'public.lift_submissions', 'weight', 'SELECT'),
  'authenticated clients retain access to non-sensitive lift fields'
);
select ok(
  (select prosecdef from pg_proc where oid = 'public.get_visible_lift_submissions(uuid,uuid[],integer,integer)'::regprocedure),
  'privacy-filtered lift reads execute with controlled definer privileges'
);
select ok(
  (select 'search_path=pg_catalog' = any(proconfig) from pg_proc where oid = 'public.get_visible_lift_submissions(uuid,uuid[],integer,integer)'::regprocedure),
  'privacy-filtered lift reads pin the search path'
);

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('99100000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'lift-bodyweight-viewer@example.test', '', '{}', '{}', now(), now()),
  ('99100000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'lift-bodyweight-owner@example.test', '', '{}', '{}', now(), now())
on conflict (id) do nothing;

insert into public.profiles(id, username, handle, display_name)
values
  ('99100000-0000-0000-0000-000000000001', 'lift_bw_viewer', '@lift_bw_viewer', 'Viewer'),
  ('99100000-0000-0000-0000-000000000002', 'lift_bw_owner', '@lift_bw_owner', 'Owner')
on conflict (id) do nothing;

insert into public.profile_privacy(user_id, profile_audience, bodyweight_audience)
values
  ('99100000-0000-0000-0000-000000000001', 'public', 'private'),
  ('99100000-0000-0000-0000-000000000002', 'public', 'private')
on conflict (user_id) do update set bodyweight_audience = excluded.bodyweight_audience;

set local role authenticated;
select set_config('request.jwt.claim.sub', '99100000-0000-0000-0000-000000000002', true);
insert into public.lift_submissions(id, user_id, exercise_id, gym_id, weight, unit, reps, bodyweight, visibility, performed_at)
values ('99100000-0000-0000-0000-000000000021', '99100000-0000-0000-0000-000000000002', 'bench', null, 225, 'lb', 1, 190, 'Public', now());

select set_config('request.jwt.claim.sub', '99100000-0000-0000-0000-000000000001', true);
do $$
begin
  begin
    perform bodyweight from public.lift_submissions where id = '99100000-0000-0000-0000-000000000021';
    raise exception 'Raw bodyweight query unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
  if (select (row->>'bodyweight') is not null
      from public.get_visible_lift_submissions(null, array['99100000-0000-0000-0000-000000000021']::uuid[], 10, 0) row) then
    raise exception 'Private bodyweight leaked through lift read RPC';
  end if;
  if not exists (
    select 1 from public.get_visible_lift_submissions(null, array['99100000-0000-0000-0000-000000000021']::uuid[], 10, 0) row
    where (row->>'weight')::numeric = 225
  ) then
    raise exception 'RPC did not preserve visible non-sensitive lift fields';
  end if;
end
$$;
select * from finish();
rollback;
