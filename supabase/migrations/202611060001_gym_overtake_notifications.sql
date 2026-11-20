begin;

-- The inbox uses owner-scoped RLS; clients may read and mark read, never author events.
revoke all on public.notifications from public, anon, authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

alter table public.profile_privacy add column gym_overtake_alerts boolean not null default false;

-- Coalesce repeated overtakes to one alert per gym/movement and UTC day.
create unique index notifications_gym_overtake_daily
on public.notifications (user_id, (destination->>'gymID'), (destination->>'exerciseID'), ((created_at at time zone 'UTC')::date))
where kind = 'gym_overtake';

-- Settings edits are field-scoped. Compare under row locks so a stale device
-- cannot overwrite a newer value; repeating an already-applied request is safe.
create or replace function public.save_own_settings(changes jsonb, expected jsonb)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  current_values jsonb;
  field text;
  destination text;
  allowed constant text[] := array[
    'preferred_unit', 'training_focus', 'profile_audience', 'age_band_audience',
    'division_audience', 'bodyweight_audience', 'location_audience', 'gym_audience',
    'friend_list_audience', 'show_lift_videos', 'workout_stats_audience',
    'share_workout_starts_with_friends', 'share_prs_with_friends', 'gym_overtake_alerts'
  ];
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if changes is null or expected is null or jsonb_typeof(changes) <> 'object'
     or jsonb_typeof(expected) <> 'object' then
    raise exception using errcode = '22023', message = 'Settings must be objects';
  end if;
  if exists (select 1 from jsonb_object_keys(changes) k where not (k = any(allowed)))
     or exists (select 1 from jsonb_object_keys(changes) k where not (expected ? k))
     or exists (select 1 from jsonb_object_keys(expected) k where not (changes ? k)) then
    raise exception using errcode = '22023', message = 'Invalid settings fields';
  end if;
  perform 1 from public.profiles where id = caller for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
  perform 1 from public.profile_private_details where user_id = caller for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Private details not found';
  end if;
  perform 1 from public.profile_privacy where user_id = caller for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Privacy not found';
  end if;
  select to_jsonb(d) || to_jsonb(p) into current_values
  from public.profile_private_details d join public.profile_privacy p using (user_id)
  where d.user_id = caller;

  for field in select jsonb_object_keys(changes) loop
    if jsonb_typeof(changes->field) not in ('string', 'null')
       or jsonb_typeof(expected->field) not in ('string', 'null')
       or (field <> 'training_focus' and changes->>field is null) then
      raise exception using errcode = '22023', message = 'Invalid settings value';
    end if;
    if current_values->>field is distinct from expected->>field
       and current_values->>field is distinct from changes->>field then
      raise exception using errcode = '40001', message = 'Settings changed on another device';
    end if;
  end loop;

  for field in select jsonb_object_keys(changes) loop
    if current_values->>field is not distinct from changes->>field then continue; end if;
    destination := case when field in ('preferred_unit', 'training_focus')
      then 'profile_private_details' else 'profile_privacy' end;
    -- Identifiers come exclusively from the allowlist above; values stay bound.
    execute format('update public.%I set %I = $1%s where user_id = $2',
      destination, field, case when field in ('show_lift_videos',
        'share_workout_starts_with_friends', 'share_prs_with_friends', 'gym_overtake_alerts')
        then '::boolean' else '' end)
    using changes->>field, caller;
  end loop;
end;
$$;
revoke all on function public.save_own_settings(jsonb, jsonb) from public, anon;
grant execute on function public.save_own_settings(jsonb, jsonb) to authenticated;


-- Match production get_ranked_lift_ids verified eligibility for every old/new comparison.
create function public.is_gym_alert_lift_eligible(l public.lift_submissions)
returns boolean language sql stable set search_path = pg_catalog as $$
  select coalesce(l.visibility = 'Public' and l.reps = 1 and l.is_actual_one_rep_max
    and l.user_id not in ('11111111-1111-4111-8111-111111111111'::uuid,
      '22222222-2222-4222-8222-222222222222'::uuid,'33333333-3333-4333-8333-333333333333'::uuid)
    and l.id not in ('aaaaaaaa-0001-4001-8001-aaaaaaaaaaaa'::uuid,'aaaaaaaa-0002-4002-8002-aaaaaaaaaaaa'::uuid,
      'bbbbbbbb-0001-4001-8001-bbbbbbbbbbbb'::uuid,'bbbbbbbb-0002-4002-8002-bbbbbbbbbbbb'::uuid,
      'cccccccc-0001-4001-8001-cccccccccccc'::uuid,'cccccccc-0002-4002-8002-cccccccccccc'::uuid)
    and l.competitive_movement is not null and l.moderation_status = 'clear'
    and l.disputed_at is null and l.leaderboard_eligible_at <= statement_timestamp()
    and l.evidence_status = 'video_backed'
    and l.verification in ('Video Verified', 'Community Verified', 'Competition Verified', 'Moderator Verified')
    and l.video_asset_id is not null, false)
$$;
revoke all on function public.is_gym_alert_lift_eligible(public.lift_submissions) from public, anon, authenticated;

create function public.notify_gym_overtake()
returns trigger language plpgsql security definer set search_path = pg_catalog as $$
declare
  target_gym uuid := new.gym_uuid;
  new_kg double precision;
  previous_best double precision;
  old_kg double precision := 0;
  owner_band text;
  owner_sex text;
begin
  if target_gym is null and new.gym_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    target_gym := new.gym_id::uuid;
  end if;
  if target_gym is null or not public.is_gym_alert_lift_eligible(new) then return new; end if;

  select public.age_band_from_birth_date(d.birth_date), d.sex_category
    into owner_band, owner_sex
  from public.profile_private_details d join public.profile_privacy p using (user_id)
  where d.user_id = new.user_id and p.profile_audience = 'public' and p.show_lift_videos
    and p.age_band_audience = 'public' and p.division_audience = 'public';
  if owner_band is null or owner_sex is null then return new; end if;

  new_kg := new.weight * case when new.unit = 'kg' then 1 else 0.45359237 end;
  if tg_op = 'UPDATE' and public.is_gym_alert_lift_eligible(old)
    and old.competitive_movement = new.competitive_movement
    and (old.gym_uuid = target_gym or old.gym_id = target_gym::text) then
    old_kg := old.weight * case when old.unit = 'kg' then 1 else 0.45359237 end;
  end if;
  select greatest(old_kg, coalesce(max(l.weight * case when l.unit = 'kg' then 1 else 0.45359237 end), 0))
    into previous_best
  from public.lift_submissions l
  where l.user_id = new.user_id and l.id <> new.id
    and l.competitive_movement = new.competitive_movement
    and (l.gym_uuid = target_gym or l.gym_id = target_gym::text)
    and public.is_gym_alert_lift_eligible(l);
  if new_kg <= previous_best then return new; end if;

  insert into public.notifications(user_id, title, body, kind, destination)
  select l.user_id, 'Your gym ranking changed',
    'A verified lift moved ahead of your best in your gym. Open the ranking to compare.',
    'gym_overtake', jsonb_build_object(
      'kind', 'leaderboard', 'gymID', target_gym,
      'exerciseID', new.competitive_movement::text, 'rankingType', 'Absolute',
      'ageGroup', owner_band, 'sexCategory', initcap(owner_sex), 'videoBackedOnly', true)
  from public.lift_submissions l
  join public.profile_privacy p on p.user_id = l.user_id
  join public.profile_private_details d on d.user_id = l.user_id
  where l.user_id <> new.user_id and p.gym_overtake_alerts
    and p.profile_audience = 'public' and p.show_lift_videos and p.age_band_audience = 'public' and p.division_audience = 'public'
    and public.age_band_from_birth_date(d.birth_date) = owner_band and d.sex_category = owner_sex
    and not public.is_blocked_pair(l.user_id, new.user_id)
    and exists (select 1 from public.gym_memberships gm where gm.user_id = l.user_id
      and gm.gym_id = target_gym and gm.left_at is null and gm.is_primary)
    and l.competitive_movement = new.competitive_movement
    and (l.gym_uuid = target_gym or l.gym_id = target_gym::text)
    and public.is_gym_alert_lift_eligible(l)
  group by l.user_id
  having max(l.weight * case when l.unit = 'kg' then 1 else 0.45359237 end) < new_kg
    and max(l.weight * case when l.unit = 'kg' then 1 else 0.45359237 end) >= previous_best
  on conflict do nothing;
  return new;
end;
$$;
revoke all on function public.notify_gym_overtake() from public, anon, authenticated;
create trigger gym_overtake_notification after insert or update on public.lift_submissions
for each row execute function public.notify_gym_overtake();

-- Re-requesting a previously declined/cancelled friendship is also a new request.
create or replace function public.notify_friendship_change()
returns trigger language plpgsql security definer set search_path = pg_catalog as $$
declare recipient uuid; actor uuid; notification_title text;
begin
  if new.status = 'pending' and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    actor := new.requested_by;
    recipient := case when actor = new.user_low_id then new.user_high_id else new.user_low_id end;
    notification_title := 'New friend request';
  elsif tg_op = 'UPDATE' and old.status is distinct from new.status and new.status = 'accepted' then
    recipient := new.requested_by;
    actor := case when recipient = new.user_low_id then new.user_high_id else new.user_low_id end;
    notification_title := 'Friend request accepted';
  else return new;
  end if;
  if not public.is_blocked_pair(recipient, actor) then
    insert into public.notifications(user_id,title,body,kind,destination)
    values(recipient,notification_title,'Open Friends to view the update.','friendship',
      jsonb_build_object('kind','friendRequests'));
  end if;
  return new;
end;
$$;
revoke all on function public.notify_friendship_change() from public, anon, authenticated;

-- A request shares only the participant's display name, even if their full profile is private.
create function public.get_friend_relationship_cards()
returns table(id uuid, user_id uuid, display_name text, is_incoming boolean, is_accepted boolean)
language sql stable security definer set search_path = pg_catalog as $$
  select f.id, p.id, p.display_name, f.requested_by <> auth.uid(), f.status = 'accepted'
  from public.friend_relationships f
  join public.profiles p on p.id = case when f.user_low_id = auth.uid() then f.user_high_id else f.user_low_id end
  where auth.uid() in (f.user_low_id, f.user_high_id) and f.status in ('pending','accepted')
    and not public.is_blocked_pair(auth.uid(), p.id)
  order by f.created_at desc, f.id
$$;
revoke all on function public.get_friend_relationship_cards() from public, anon;
grant execute on function public.get_friend_relationship_cards() to authenticated;

commit;
