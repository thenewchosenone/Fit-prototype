begin;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
('98000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'focus-one@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now()),
('98000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'focus-two@example.test', '', '{}'::jsonb, '{}'::jsonb, now(), now());

-- Keep the fixture explicit so this test still exercises persistence if the auth
-- profile trigger is disabled in a local harness.
insert into public.profiles (id, display_name, handle, username)
values
('98000000-0000-0000-0000-000000000011', 'Focus One', '@focus_one', 'focus_one'),
('98000000-0000-0000-0000-000000000012', 'Focus Two', '@focus_two', 'focus_two')
on conflict (id) do nothing;

insert into public.profile_private_details (user_id)
values
('98000000-0000-0000-0000-000000000011'),
('98000000-0000-0000-0000-000000000012')
on conflict (user_id) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', '98000000-0000-0000-0000-000000000011', true);

do $$
declare focus text;
begin
  foreach focus in array array['bodybuilding', 'powerlifting', 'generalFitness', 'mixed'] loop
    update public.profile_private_details set training_focus = focus
      where user_id = auth.uid();
    if (select training_focus from public.profile_private_details where user_id = auth.uid()) is distinct from focus then
      raise exception 'Owner focus did not persist';
    end if;
  end loop;
  begin
    update public.profile_private_details set training_focus = 'invalid' where user_id = auth.uid();
    raise exception 'Invalid focus was accepted';
  exception when check_violation then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '98000000-0000-0000-0000-000000000012', true);
do $$
declare changed integer;
begin
  if exists (select 1 from public.profile_private_details where user_id = '98000000-0000-0000-0000-000000000011') then
    raise exception 'Another account can read private focus';
  end if;
  update public.profile_private_details set training_focus = 'bodybuilding'
    where user_id = '98000000-0000-0000-0000-000000000011';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'Another account can update private focus'; end if;
end;
$$;

reset role;
do $$
begin
  if has_column_privilege('anon', 'public.profile_private_details', 'training_focus', 'UPDATE') then
    raise exception 'Anonymous users can update private focus';
  end if;
  if (select training_focus from public.profile_private_details where user_id = '98000000-0000-0000-0000-000000000011') <> 'mixed' then
    raise exception 'Owner focus changed during cross-account write';
  end if;
end;
$$;

rollback;
