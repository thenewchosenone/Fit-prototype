-- LiftRank authenticated data foundation. Public exercise and gym catalogs remain bundled.
create extension if not exists pgcrypto;
create type public.app_role as enum ('Member', 'Moderator', 'Admin');
create type public.lift_visibility as enum ('Public', 'Friends', 'Private');
create type public.vote_value as enum ('-1', '1');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 60),
  handle text not null unique check (handle ~ '^@[A-Za-z0-9_]{3,24}$'),
  role public.app_role not null default 'Member',
  bio text not null default '' check (char_length(bio) <= 1000),
  discipline text not null default 'General Strength',
  training_goal text not null default '',
  professional_credential text,
  credential_verified boolean not null default false,
  hide_gym boolean not null default false,
  hide_location boolean not null default false,
  hide_age boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function public.create_profile_for_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, display_name, handle)
  values (new.id, coalesce(nullif(new.raw_user_meta_data->>'display_name',''), 'LiftRank Member'), coalesce(nullif(new.raw_user_meta_data->>'handle',''), '@user_' || left(replace(new.id::text,'-',''), 8)));
  return new;
end $$;
create trigger auth_user_profile after insert on auth.users for each row execute function public.create_profile_for_new_user();

create function public.protect_profile_authority() returns trigger language plpgsql as $$
begin
  if auth.uid() = old.id and (new.role <> old.role or new.credential_verified <> old.credential_verified) then raise exception 'Role and credential verification are server controlled'; end if;
  new.updated_at = now(); return new;
end $$;
create trigger protect_profile_authority before update on public.profiles for each row execute function public.protect_profile_authority();

create table public.gym_memberships (
  user_id uuid references public.profiles(id) on delete cascade,
  gym_id text not null,
  created_at timestamptz not null default now(),
  primary key(user_id, gym_id)
);
create function public.limit_gym_memberships() returns trigger language plpgsql as $$
begin if (select count(*) from public.gym_memberships where user_id = new.user_id) >= 3 then raise exception 'A user may join at most three gyms'; end if; return new; end $$;
create trigger limit_gym_memberships before insert on public.gym_memberships for each row execute function public.limit_gym_memberships();

create table public.training_group_memberships (
  user_id uuid references public.profiles(id) on delete cascade,
  group_id text not null,
  created_at timestamptz not null default now(),
  primary key(user_id, group_id)
);
create table public.group_moderators (group_id text not null, user_id uuid references public.profiles(id) on delete cascade, primary key(group_id,user_id));
create table public.group_bans (group_id text not null, user_id uuid references public.profiles(id) on delete cascade, moderator_id uuid references public.profiles(id), reason text not null, created_at timestamptz not null default now(), primary key(group_id,user_id));

create table public.lift_submissions (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  exercise_id text not null, gym_id text not null, weight numeric not null check(weight > 0), unit text not null check(unit in ('lb','kg')),
  reps integer not null check(reps between 1 and 100), bodyweight numeric check(bodyweight > 0), visibility public.lift_visibility not null default 'Public',
  verification text not null default 'Self Reported', caption text not null default '' check(char_length(caption)<=1000), performed_at timestamptz not null, created_at timestamptz not null default now()
);
create table public.bodyweight_records (id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade, weight numeric not null check(weight>0), recorded_at timestamptz not null, notes text not null default '', created_at timestamptz not null default now());

create table public.community_posts (
  id uuid primary key default gen_random_uuid(), author_id uuid not null references public.profiles(id) on delete cascade, group_id text not null,
  category text not null, title text not null check(char_length(title) between 3 and 180), body text not null check(char_length(body) between 1 and 10000),
  media_url text check(media_url is null or media_url ~ '^https://'), is_locked boolean not null default false, removed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.post_votes (post_id uuid references public.community_posts(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, value smallint not null check(value in (-1,1)), primary key(post_id,user_id));
create table public.post_saves (post_id uuid references public.community_posts(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, created_at timestamptz not null default now(), primary key(post_id,user_id));
create table public.comments (
  id uuid primary key default gen_random_uuid(), post_id uuid not null references public.community_posts(id) on delete cascade, author_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.comments(id) on delete cascade, body text not null check(char_length(body) between 1 and 5000), deleted_at timestamptz, removed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.comment_votes (comment_id uuid references public.comments(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, value smallint not null check(value in (-1,1)), primary key(comment_id,user_id));

create table public.friendships (requester_id uuid references public.profiles(id) on delete cascade, addressee_id uuid references public.profiles(id) on delete cascade, status text not null check(status in ('Pending','Accepted','Declined')), created_at timestamptz not null default now(), primary key(requester_id,addressee_id), check(requester_id<>addressee_id));
create table public.message_threads (id uuid primary key default gen_random_uuid(), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.message_thread_members (thread_id uuid references public.message_threads(id) on delete cascade, user_id uuid references public.profiles(id) on delete cascade, primary key(thread_id,user_id));
create table public.messages (id uuid primary key default gen_random_uuid(), thread_id uuid not null references public.message_threads(id) on delete cascade, sender_id uuid not null references public.profiles(id) on delete cascade, body text not null check(char_length(body) between 1 and 5000), deleted_at timestamptz, created_at timestamptz not null default now());
create table public.community_reports (id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id) on delete cascade, target_type text not null check(target_type in ('Post','Comment')), target_id uuid not null, reason text not null, note text not null default '', status text not null default 'Open' check(status in ('Open','Resolved')), created_at timestamptz not null default now());
create table public.moderation_actions (id uuid primary key default gen_random_uuid(), actor_id uuid not null references public.profiles(id), group_id text, action text not null, target_type text not null, target_id text not null, reason text not null default '', created_at timestamptz not null default now());

create function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and role='Admin') $$;
create function public.moderates(group_key text) returns boolean language sql stable security definer set search_path=public as $$ select public.is_admin() or exists(select 1 from group_moderators where group_id=group_key and user_id=auth.uid()) $$;
create function public.are_friends(left_id uuid,right_id uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from friendships where status='Accepted' and ((requester_id=left_id and addressee_id=right_id) or (requester_id=right_id and addressee_id=left_id))) $$;
create function public.is_thread_member(thread_key uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from message_thread_members where thread_id=thread_key and user_id=auth.uid()) $$;

alter table public.profiles enable row level security;
create policy "profiles public read" on public.profiles for select using(true);
create policy "profiles own update" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
alter table public.gym_memberships enable row level security;
create policy "memberships public read" on public.gym_memberships for select using(true);
create policy "memberships own insert" on public.gym_memberships for insert with check(user_id=auth.uid());
create policy "memberships own delete" on public.gym_memberships for delete using(user_id=auth.uid());
alter table public.training_group_memberships enable row level security;
create policy "group memberships public read" on public.training_group_memberships for select using(true);
create policy "group memberships own insert" on public.training_group_memberships for insert with check(user_id=auth.uid());
create policy "group memberships own delete" on public.training_group_memberships for delete using(user_id=auth.uid());
alter table public.group_moderators enable row level security;
create policy "group moderators public read" on public.group_moderators for select using(true);
alter table public.group_bans enable row level security;
create policy "group bans scoped read" on public.group_bans for select using(user_id=auth.uid() or public.moderates(group_id));
alter table public.lift_submissions enable row level security;
create policy "lift visibility" on public.lift_submissions for select using(visibility='Public' or user_id=auth.uid() or (visibility='Friends' and public.are_friends(user_id,auth.uid())));
create policy "lift own insert" on public.lift_submissions for insert with check(user_id=auth.uid());
create policy "lift own update" on public.lift_submissions for update using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "lift own delete" on public.lift_submissions for delete using(user_id=auth.uid());
alter table public.bodyweight_records enable row level security;
create policy "bodyweight owner only" on public.bodyweight_records for all using(user_id=auth.uid()) with check(user_id=auth.uid());
alter table public.community_posts enable row level security;
create policy "posts public read" on public.community_posts for select using(removed_at is null or author_id=auth.uid() or public.moderates(group_id));
create policy "posts member insert" on public.community_posts for insert with check(author_id=auth.uid() and not exists(select 1 from group_bans where group_id=community_posts.group_id and user_id=auth.uid()));
create policy "posts owner update" on public.community_posts for update using(author_id=auth.uid()) with check(author_id=auth.uid());
alter table public.comments enable row level security;
create policy "comments public read" on public.comments for select using(removed_at is null or author_id=auth.uid());
create policy "comments member insert" on public.comments for insert with check(author_id=auth.uid() and exists(select 1 from community_posts p where p.id=post_id and not p.is_locked and p.removed_at is null and not exists(select 1 from group_bans b where b.group_id=p.group_id and b.user_id=auth.uid())));
create policy "comments owner update" on public.comments for update using(author_id=auth.uid()) with check(author_id=auth.uid());
alter table public.post_votes enable row level security; create policy "post votes read" on public.post_votes for select using(true); create policy "post votes own" on public.post_votes for all using(user_id=auth.uid()) with check(user_id=auth.uid());
alter table public.comment_votes enable row level security; create policy "comment votes read" on public.comment_votes for select using(true); create policy "comment votes own" on public.comment_votes for all using(user_id=auth.uid()) with check(user_id=auth.uid());
alter table public.post_saves enable row level security; create policy "saves owner only" on public.post_saves for all using(user_id=auth.uid()) with check(user_id=auth.uid());
alter table public.friendships enable row level security;
create policy "friendships participant read" on public.friendships for select using(requester_id=auth.uid() or addressee_id=auth.uid());
create policy "friendships requester insert" on public.friendships for insert with check(requester_id=auth.uid() and status='Pending');
create policy "friendships participant update" on public.friendships for update using(requester_id=auth.uid() or addressee_id=auth.uid());
alter table public.message_threads enable row level security; create policy "thread members read" on public.message_threads for select using(public.is_thread_member(id));
alter table public.message_thread_members enable row level security; create policy "thread membership read" on public.message_thread_members for select using(public.is_thread_member(thread_id));
alter table public.messages enable row level security; create policy "messages participants read" on public.messages for select using(public.is_thread_member(messages.thread_id)); create policy "messages participants insert" on public.messages for insert with check(sender_id=auth.uid() and public.is_thread_member(messages.thread_id));
alter table public.community_reports enable row level security; create policy "reports own insert" on public.community_reports for insert with check(reporter_id=auth.uid()); create policy "reports scoped read" on public.community_reports for select using(reporter_id=auth.uid() or public.is_admin());
alter table public.moderation_actions enable row level security; create policy "audit admin read" on public.moderation_actions for select using(public.is_admin());

create index on public.lift_submissions(user_id, performed_at desc);
create index on public.community_posts(group_id, created_at desc);
create index on public.comments(post_id, created_at);
create index on public.messages(thread_id, created_at);
