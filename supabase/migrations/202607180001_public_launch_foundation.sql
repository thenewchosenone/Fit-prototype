-- LiftRank public-launch foundation. Forward-only and safe to apply after the
-- identity/social and exercise-catalog migrations.

create type public.competitive_movement as enum (
  'barbell_bench_press', 'back_squat', 'conventional_deadlift', 'sumo_deadlift',
  'standing_barbell_overhead_press', 'dumbbell_bench_press', 'bent_over_barbell_row'
);
create type public.lift_evidence_status as enum ('self_reported', 'video_backed');
create type public.lift_moderation_status as enum ('clear', 'under_review', 'replacement_requested', 'rejected');
create type public.lift_report_reason as enum ('Incorrect weight', 'Mismatched exercise', 'Unusable or edited video', 'Depth', 'Range of motion', 'Lockout', 'Other');

alter table public.exercises drop constraint if exists exercises_ranking_movement_check;
update public.exercises set ranking_movement = case id
  when 'barbell-bench-press' then 'barbell_bench_press'
  when 'back-squat' then 'back_squat'
  when 'conventional-deadlift' then 'conventional_deadlift'
  when 'sumo-deadlift' then 'sumo_deadlift'
  when 'standing-barbell-overhead-press' then 'standing_barbell_overhead_press'
  when 'dumbbell-bench-press' then 'dumbbell_bench_press'
  when 'barbell-row' then 'bent_over_barbell_row'
  else null end;
alter table public.exercises add constraint exercises_ranking_movement_check check (
  ranking_movement is null or ranking_movement in ('barbell_bench_press','back_squat','conventional_deadlift','sumo_deadlift','standing_barbell_overhead_press','dumbbell_bench_press','bent_over_barbell_row')
);

alter table public.lift_submissions
  add column if not exists competitive_movement public.competitive_movement,
  add column if not exists repetitions integer not null default 1 check (repetitions > 0),
  add column if not exists is_actual_one_rep_max boolean not null default false,
  add column if not exists evidence_status public.lift_evidence_status not null default 'self_reported',
  add column if not exists moderation_status public.lift_moderation_status not null default 'clear',
  add column if not exists weight_per_hand boolean not null default false,
  add column if not exists leaderboard_eligible_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

create table public.lift_media_assets (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  lift_id uuid not null references public.lift_submissions(id) on delete cascade,
  storage_path text not null unique,
  content_type text not null check (content_type like 'video/%'),
  byte_count bigint not null check (byte_count >= 0),
  upload_completed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table public.lift_submissions add column if not exists video_asset_id uuid references public.lift_media_assets(id);

create table public.lift_votes (
  lift_id uuid not null references public.lift_submissions(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  value smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (lift_id, voter_id)
);
create table public.lift_reports (
  id uuid primary key default gen_random_uuid(),
  lift_id uuid not null references public.lift_submissions(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason public.lift_report_reason not null,
  note text not null default '' check (char_length(note) <= 1000),
  closed_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index lift_reports_one_open_per_user on public.lift_reports(lift_id, reporter_id) where closed_at is null;
create table public.lift_moderation_audit (
  id uuid primary key default gen_random_uuid(),
  lift_id uuid not null references public.lift_submissions(id) on delete cascade,
  actor_id uuid references public.profiles(id),
  event text not null,
  prior_status public.lift_moderation_status,
  resulting_status public.lift_moderation_status not null,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.workout_plan_documents (
  id uuid not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  revision integer not null default 1 check (revision > 0),
  name text not null check (char_length(name) between 1 and 120),
  payload jsonb not null,
  conflict_of_revision integer,
  is_conflict_copy boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
create table public.completed_workout_snapshots (
  id uuid not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  payload jsonb not null,
  completed_at timestamptz not null,
  uploaded_at timestamptz not null default now(),
  primary key (owner_id, id)
);

create table public.device_tokens (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_id text not null,
  token text not null,
  environment text not null check (environment in ('sandbox', 'production')),
  revoked_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (user_id, device_id)
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  kind text not null,
  destination jsonb not null default '{"kind":"home"}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  document_kind text not null,
  document_version text not null,
  accepted_at timestamptz not null default now(),
  unique (user_id, document_kind, document_version)
);
create table public.analytics_events (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (name in ('signup_completed','onboarding_completed','first_workout_started','workout_completed','pr_submitted','video_backed_pr_submitted','workout_shared','weekly_return')),
  properties jsonb not null default '{}',
  occurred_at timestamptz not null,
  created_at timestamptz not null default now()
);

create or replace function public.is_blocked_pair(left_id uuid, right_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.user_blocks where (blocker_id=left_id and blocked_id=right_id) or (blocker_id=right_id and blocked_id=left_id));
$$;

create or replace function public.refresh_lift_review_state(target_lift_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare open_reports integer; vote_score integer; old_status public.lift_moderation_status;
begin
  select moderation_status into old_status from public.lift_submissions where id=target_lift_id for update;
  select count(*) into open_reports from public.lift_reports where lift_id=target_lift_id and closed_at is null;
  select coalesce(sum(value),0) into vote_score from public.lift_votes where lift_id=target_lift_id;
  if old_status='clear' and (open_reports >= 3 or vote_score <= -5) then
    update public.lift_submissions set moderation_status='under_review', updated_at=now() where id=target_lift_id;
    insert into public.lift_moderation_audit(lift_id,event,prior_status,resulting_status,note)
      values(target_lift_id,'automatic_trigger',old_status,'under_review',format('%s open reports; vote score %s',open_reports,vote_score));
  end if;
end $$;

create or replace function public.vote_on_lift(lift_id uuid, vote_value integer)
returns void language plpgsql security definer set search_path = public as $$
declare owner uuid;
begin
  select user_id into owner from public.lift_submissions where id=lift_id;
  if owner is null or owner=auth.uid() or public.is_blocked_pair(owner,auth.uid()) then raise exception 'permission denied'; end if;
  if vote_value is null then delete from public.lift_votes where lift_votes.lift_id=vote_on_lift.lift_id and voter_id=auth.uid();
  else insert into public.lift_votes(lift_id,voter_id,value) values(lift_id,auth.uid(),vote_value)
    on conflict (lift_id,voter_id) do update set value=excluded.value, created_at=now(); end if;
  perform public.refresh_lift_review_state(lift_id);
end $$;

create or replace function public.report_lift(lift_id uuid, report_reason text, report_note text default '')
returns void language plpgsql security definer set search_path = public as $$
declare owner uuid;
begin
  select user_id into owner from public.lift_submissions where id=lift_id;
  if owner is null or owner=auth.uid() or public.is_blocked_pair(owner,auth.uid()) then raise exception 'permission denied'; end if;
  insert into public.lift_reports(lift_id,reporter_id,reason,note) values(lift_id,auth.uid(),report_reason::public.lift_report_reason,report_note);
  perform public.refresh_lift_review_state(lift_id);
end $$;

create or replace function public.block_user(target_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if target_user_id=auth.uid() then raise exception 'cannot block yourself'; end if;
  insert into public.user_blocks(blocker_id,blocked_id) values(auth.uid(),target_user_id) on conflict do nothing;
  delete from public.friend_relationships where user_low_id in (auth.uid(),target_user_id) and user_high_id in (auth.uid(),target_user_id);
  delete from public.friendships where requester_id in (auth.uid(),target_user_id) and addressee_id in (auth.uid(),target_user_id);
end $$;
create or replace function public.unblock_user(target_user_id uuid)
returns void language sql security definer set search_path = public as $$ delete from public.user_blocks where blocker_id=auth.uid() and blocked_id=target_user_id $$;

create or replace function public.get_followed_activity()
returns table(id uuid,user_id uuid,username text,display_name text,title text,detail text,lift_id uuid,created_at timestamptz,is_liked boolean,is_saved boolean)
language sql stable security definer set search_path = public as $$
  select p.id,p.author_id,coalesce(pr.username,'member'),pr.display_name,p.title,left(p.body,500),null::uuid,p.created_at,
    exists(select 1 from public.post_votes v where v.post_id=p.id and v.user_id=auth.uid() and v.value=1),
    exists(select 1 from public.post_saves s where s.post_id=p.id and s.user_id=auth.uid())
  from public.community_posts p join public.profiles pr on pr.id=p.author_id
  where p.removed_at is null and not public.is_blocked_pair(p.author_id,auth.uid())
    and (p.author_id=auth.uid() or public.are_friends(p.author_id,auth.uid()))
  order by p.created_at desc limit 100;
$$;

alter table public.lift_media_assets enable row level security;
alter table public.lift_votes enable row level security;
alter table public.lift_reports enable row level security;
alter table public.lift_moderation_audit enable row level security;
alter table public.user_blocks enable row level security;
alter table public.workout_plan_documents enable row level security;
alter table public.completed_workout_snapshots enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;
alter table public.legal_acceptances enable row level security;
alter table public.analytics_events enable row level security;

create policy "media owner read" on public.lift_media_assets for select using(owner_id=auth.uid());
create policy "votes visible lifts read" on public.lift_votes for select using(exists(select 1 from public.lift_submissions l where l.id=lift_id));
create policy "reports own insert" on public.lift_reports for insert with check(reporter_id=auth.uid());
create policy "reports own or moderator read" on public.lift_reports for select using(reporter_id=auth.uid() or public.is_admin());
create policy "lift audit moderator read" on public.lift_moderation_audit for select using(public.is_admin());
create policy "blocks owner all" on public.user_blocks for all using(blocker_id=auth.uid()) with check(blocker_id=auth.uid());
create policy "plans owner all" on public.workout_plan_documents for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "completed owner all" on public.completed_workout_snapshots for all using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "tokens owner all" on public.device_tokens for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "notifications owner read" on public.notifications for select using(user_id=auth.uid());
create policy "notifications owner update" on public.notifications for update using(user_id=auth.uid());
create policy "legal owner insert read" on public.legal_acceptances for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "analytics owner insert" on public.analytics_events for insert with check(user_id=auth.uid());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('lift-videos','lift-videos',false,524288000,array['video/quicktime','video/mp4']) on conflict (id) do nothing;
create policy "lift videos owner upload" on storage.objects for insert to authenticated
  with check(bucket_id='lift-videos' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "lift videos owner read" on storage.objects for select to authenticated
  using(bucket_id='lift-videos' and (storage.foldername(name))[1]=auth.uid()::text);

grant execute on function public.vote_on_lift(uuid,integer) to authenticated;
grant execute on function public.report_lift(uuid,text,text) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.get_followed_activity() to authenticated;
