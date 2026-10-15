begin;

insert into auth.users(id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select ('99000000-0000-0000-0000-00000000000' || n)::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'privacy-role-' || n || '@example.test', '', '{}', '{}', now(), now()
from generate_series(1,5) n;
insert into public.profiles(id, username, handle, display_name)
select ('99000000-0000-0000-0000-00000000000' || n)::uuid, 'privacy_role_' || n, '@privacy_role_' || n, 'Privacy role ' || n
from generate_series(1,5) n on conflict(id) do nothing;
insert into public.profile_private_details(user_id)
select ('99000000-0000-0000-0000-00000000000' || n)::uuid from generate_series(1,5) n on conflict do nothing;
insert into public.profile_privacy(user_id)
select ('99000000-0000-0000-0000-00000000000' || n)::uuid from generate_series(1,5) n on conflict do nothing;
insert into public.location_countries(code,name) values('CA','Canada') on conflict do nothing;
insert into public.location_regions(id,country_code,code,name)
values('99000000-0000-0000-0000-000000000010','CA','ON','Ontario') on conflict do nothing;
insert into public.location_cities(id,country_code,region_id,region_code,name,ascii_name,latitude,longitude,population,timezone)
select '99000000-0000-0000-0000-000000000011','CA',id,code,'Toronto','Toronto',43.65,-79.38,1000000,'America/Toronto'
from public.location_regions where country_code='CA' and name='Ontario';
insert into public.gyms(id,name,status) values
('99000000-0000-0000-0000-000000000020','Privacy gym one','active'),
('99000000-0000-0000-0000-000000000021','Privacy gym two','active');
insert into public.gym_memberships(user_id,gym_id,is_primary) values
('99000000-0000-0000-0000-000000000001','99000000-0000-0000-0000-000000000020',true),
('99000000-0000-0000-0000-000000000001','99000000-0000-0000-0000-000000000021',false),
('99000000-0000-0000-0000-000000000003','99000000-0000-0000-0000-000000000020',true);
insert into public.friend_relationships(user_low_id,user_high_id,requested_by,status,responded_at)
values('99000000-0000-0000-0000-000000000001','99000000-0000-0000-0000-000000000002','99000000-0000-0000-0000-000000000001','accepted',now());
insert into public.user_blocks(blocker_id,blocked_id)
values('99000000-0000-0000-0000-000000000001','99000000-0000-0000-0000-000000000005');

create function pg_temp.profile_payload(overrides jsonb default '{}') returns jsonb language sql as $$
select '{"new_display_name":"Privacy Owner","new_bio":"Training","new_preferred_unit":"kg",
"new_birth_date":"1990-01-02","new_sex_category":"male","new_height_cm":180,
"new_city_id":"99000000-0000-0000-0000-000000000011","new_city":"stale city","new_region":"stale region","new_country_code":"US",
"new_years_experience":5,"new_experience_level":"intermediate","new_profile_audience":"public",
"new_age_band_audience":"public","new_division_audience":"friends","new_location_audience":"gym",
"new_gym_audience":"public","new_friend_list_audience":"private","new_bodyweight_audience":"private",
"new_show_lift_videos":true,"complete_onboarding":true,"new_bodyweight_pounds":200,
"new_training_focus":"bodybuilding","new_avatar_path":null,"updates_primary_gym":false}'::jsonb || overrides
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-0000-0000-000000000001',true);
select public.save_own_profile_mobile(pg_temp.profile_payload());
do $$
declare before_details jsonb; before_profile jsonb; before_privacy jsonb; failed boolean := false;
begin
  if not exists(select 1 from public.profile_private_details where user_id=auth.uid() and city='Toronto' and region='Ontario' and country_code='CA' and birth_date='1990-01-02') then
    raise exception 'Canonical location or exact birth date failed';
  end if;
  if (select count(*) from public.gym_memberships where user_id=auth.uid() and is_primary and left_at is null) <> 1 then
    raise exception 'Unrelated save changed primary gym';
  end if;
  select to_jsonb(d) into before_details from public.profile_private_details d where user_id=auth.uid();
  select to_jsonb(p) into before_profile from public.profiles p where id=auth.uid();
  select to_jsonb(p) into before_privacy from public.profile_privacy p where user_id=auth.uid();
  begin
    perform public.save_own_profile_mobile(pg_temp.profile_payload('{"new_display_name":"Must roll back","new_profile_audience":"private","new_show_lift_videos":false,"new_training_focus":"invalid"}'));
  exception when check_violation then failed := true;
  end;
  if not failed then raise exception 'Invalid final write was accepted'; end if;
  if before_details is distinct from (select to_jsonb(d) from public.profile_private_details d where user_id=auth.uid())
     or before_profile is distinct from (select to_jsonb(p) from public.profiles p where id=auth.uid())
     or before_privacy is distinct from (select to_jsonb(p) from public.profile_privacy p where user_id=auth.uid()) then
    raise exception 'Failed save left partial profile or privacy changes';
  end if;
  failed := false;
  begin
    perform public.save_own_profile_mobile(pg_temp.profile_payload('{"new_display_name":"Must also roll back","new_show_lift_videos":false,"updates_primary_gym":true,"new_primary_gym_id":"99000000-0000-0000-0000-000000000099"}'));
  exception when no_data_found then failed := true;
  end;
  if not failed then raise exception 'Unavailable gym was accepted'; end if;
  if before_details is distinct from (select to_jsonb(d) from public.profile_private_details d where user_id=auth.uid())
     or before_profile is distinct from (select to_jsonb(p) from public.profiles p where id=auth.uid())
     or before_privacy is distinct from (select to_jsonb(p) from public.profile_privacy p where user_id=auth.uid()) then
    raise exception 'Final gym failure left partial account changes';
  end if;
  perform public.save_own_profile_mobile(pg_temp.profile_payload('{"updates_primary_gym":true,"new_primary_gym_id":null}'));
  if exists(select 1 from public.gym_memberships where user_id=auth.uid() and is_primary) or
     (select count(*) from public.gym_memberships where user_id=auth.uid() and left_at is null) <> 2 then
    raise exception 'Clearing primary gym changed memberships or left a primary';
  end if;
  perform public.save_own_profile_mobile(pg_temp.profile_payload('{"updates_primary_gym":true,"new_primary_gym_id":"99000000-0000-0000-0000-000000000021"}'));
  if not exists(select 1 from public.gym_memberships where user_id=auth.uid() and gym_id='99000000-0000-0000-0000-000000000021' and is_primary) then
    raise exception 'Replacement primary gym did not persist';
  end if;
end;
$$;

-- Create real uploaded-media references through the trusted finalizer.
insert into public.lift_submissions(id,user_id,exercise_id,weight,unit,reps,bodyweight,visibility,verification,caption,performed_at,is_actual_one_rep_max)
values('99000000-0000-0000-0000-000000000030',auth.uid(),'bench',225,'lb',1,200,'Public','Self Reported','Privacy test',now(),true);
reset role;
insert into storage.objects(bucket_id,name,owner_id)
values('lift-videos','99000000-0000-0000-0000-000000000001/99000000-0000-0000-0000-000000000030/video.mp4','99000000-0000-0000-0000-000000000001');
set local role authenticated;
select public.complete_lift_media_upload('99000000-0000-0000-0000-000000000031','99000000-0000-0000-0000-000000000030','99000000-0000-0000-0000-000000000001/99000000-0000-0000-0000-000000000030/video.mp4','video/mp4',1024);

do $$
declare audience text; sharing boolean; viewer integer; expected boolean; card jsonb; actual boolean;
  owner uuid := '99000000-0000-0000-0000-000000000001';
  asset uuid := '99000000-0000-0000-0000-000000000031';
begin
  foreach audience in array array['public','friends','gym','private'] loop
    foreach sharing in array array[true,false] loop
      perform set_config('request.jwt.claim.sub',owner::text,true);
      update public.profile_privacy set profile_audience=audience,show_lift_videos=sharing where user_id=owner;
      for viewer in 1..5 loop
        perform set_config('request.jwt.claim.sub','99000000-0000-0000-0000-00000000000'||viewer,true);
        expected := viewer=1 or (viewer<>5 and (audience='public' or (audience='friends' and viewer=2) or (audience='gym' and viewer=3)));
        if public.can_view_profile(owner) is distinct from expected then raise exception 'Profile audience mismatch: %, viewer %',audience,viewer; end if;
        select to_jsonb(c) into card from public.get_profile_card(owner) c;
        if (card is not null) is distinct from expected then raise exception 'Profile card audience mismatch'; end if;
        if viewer<>1 and card is not null then
          if card->>'city' is not null and viewer<>3 then raise exception 'Location leaked outside gym audience'; end if;
          if card->>'sex_category' is not null and viewer<>2 then raise exception 'Division leaked outside friend audience'; end if;
          if viewer=3 and card->>'city' is distinct from 'Toronto' then raise exception 'Authorized gym location is missing'; end if;
          if viewer=2 and card->>'sex_category' is distinct from 'male' then raise exception 'Authorized friend division is missing'; end if;
          if exists(select 1 from public.profile_private_details where user_id=owner) then raise exception 'Private account details leaked to visitor'; end if;
        end if;
        expected := viewer=1 or (expected and sharing);
        select exists(select 1 from public.get_lift_media_for_playback(asset)) into actual;
        if actual is distinct from expected then raise exception 'Playback mismatch: %, sharing %, viewer %',audience,sharing,viewer; end if;
        select exists(select 1 from storage.objects where bucket_id='lift-videos' and name='99000000-0000-0000-0000-000000000001/99000000-0000-0000-0000-000000000030/video.mp4') into actual;
        if actual is distinct from expected then raise exception 'Storage bypass or denial: %, sharing %, viewer %',audience,sharing,viewer; end if;
        select exists(select 1 from public.get_playable_lift_media_ids(array[asset])) into actual;
        if actual is distinct from expected then raise exception 'Lift-row video references disagree with playback'; end if;
      end loop;
    end loop;
  end loop;
  perform set_config('request.jwt.claim.sub',owner::text,true);
  update public.profile_privacy set profile_audience='public',show_lift_videos=true where user_id=owner;
end;
$$;
reset role;
-- Seed each lift audience with database privileges; playback checks use viewers.
update public.lift_submissions set visibility='Friends' where id='99000000-0000-0000-0000-000000000030';
set local role authenticated;
do $$
declare viewer integer; asset uuid := '99000000-0000-0000-0000-000000000031';
begin
  for viewer in 1..4 loop
    perform set_config('request.jwt.claim.sub','99000000-0000-0000-0000-00000000000'||viewer,true);
    if exists(select 1 from public.get_lift_media_for_playback(asset)) is distinct from (viewer in(1,2)) then raise exception 'Friends lift audience failed'; end if;
  end loop;
end;
$$;
reset role;
select set_config('request.jwt.claim.sub','99000000-0000-0000-0000-000000000001',true);
update public.lift_submissions set visibility='Private' where id='99000000-0000-0000-0000-000000000030';
set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-0000-0000-000000000002',true);
do $$ begin
  if exists(select 1 from public.get_lift_media_for_playback('99000000-0000-0000-0000-000000000031')) then raise exception 'Private lift video leaked to friend'; end if;
end $$;
reset role;
-- Seed a server moderation state; clients cannot assign this authority field.
alter table public.lift_submissions disable trigger competitive_lift_authority;
update public.lift_submissions set visibility='Public', moderation_status='under_review'
where id='99000000-0000-0000-0000-000000000030';
alter table public.lift_submissions enable trigger competitive_lift_authority;
set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-0000-0000-000000000002',true);
do $$
begin
  if exists(select 1 from public.get_lift_media_for_playback('99000000-0000-0000-0000-000000000031'))
     or exists(select 1 from public.get_playable_lift_media_ids(array['99000000-0000-0000-0000-000000000031'::uuid]))
     or exists(select 1 from storage.objects where bucket_id='lift-videos' and name='99000000-0000-0000-0000-000000000001/99000000-0000-0000-0000-000000000030/video.mp4') then
    raise exception 'Moderated video remains playable by a visitor';
  end if;
  perform set_config('request.jwt.claim.sub','99000000-0000-0000-0000-000000000001',true);
  if not exists(select 1 from public.get_lift_media_for_playback('99000000-0000-0000-0000-000000000031')) then
    raise exception 'Owner cannot review moderated footage';
  end if;
end;
$$;
reset role;
do $$
begin
  if has_function_privilege('anon','public.save_own_profile_mobile(jsonb)','execute') or
     has_function_privilege('anon','public.get_playable_lift_media_ids(uuid[])','execute') or
     has_function_privilege('anon','public.get_lift_media_for_playback(uuid)','execute') then
    raise exception 'Anonymous caller has account or playback access';
  end if;
end;
$$;
rollback;
