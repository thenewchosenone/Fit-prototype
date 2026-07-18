create table public.forum_communities (
  id uuid primary key, slug text not null unique, name text not null, summary text not null default '', details text not null default '',
  category text not null, symbol_name text not null default 'person.3.fill', accent_hex text not null default '#3578FF',
  visibility text not null check(visibility in ('Public','Restricted','Invite Only')),
  rules jsonb not null default '[]', available_tags jsonb not null default '[]', staff_owner_id uuid references public.profiles(id),
  archived_at timestamptz, created_at timestamptz not null default now()
);
create table public.forum_memberships (
  id uuid primary key default gen_random_uuid(), community_id uuid not null references public.forum_communities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade, role text not null default 'Member',
  status text not null default 'Joined', notification_level text not null default 'Mentions and replies', joined_at timestamptz,
  muted_until timestamptz,banned_at timestamptz,restriction_reason text,invited_by uuid references public.profiles(id),
  unique(community_id,user_id)
);
create table public.forum_posts (
  id uuid primary key,community_id uuid references public.forum_communities(id),gym_id uuid references public.gyms(id),
  author_id uuid not null references public.profiles(id),kind text not null,title text not null,body text not null,tag text,
  attachments jsonb not null default '[]',poll jsonb,lift_id uuid references public.lift_submissions(id),workout_id uuid,
  link_url text,challenge_id uuid,is_pinned boolean not null default false,is_locked boolean not null default false,
  removed_at timestamptz,removal_reason text,created_at timestamptz not null default now(),edited_at timestamptz,
  check((community_id is null)<>(gym_id is null))
);
create table public.forum_comments (
  id uuid primary key,post_id uuid not null references public.forum_posts(id) on delete cascade,parent_comment_id uuid references public.forum_comments(id),
  author_id uuid not null references public.profiles(id),body text not null,created_at timestamptz not null default now(),edited_at timestamptz,
  removed_at timestamptz,removal_reason text
);
create table public.forum_post_votes(post_id uuid references public.forum_posts(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,value smallint check(value in(-1,1)),primary key(post_id,user_id));
create table public.forum_comment_votes(comment_id uuid references public.forum_comments(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,value smallint check(value in(-1,1)),primary key(comment_id,user_id));
create table public.forum_post_saves(post_id uuid references public.forum_posts(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,created_at timestamptz default now(),primary key(post_id,user_id));
create table public.forum_post_watches(post_id uuid references public.forum_posts(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,created_at timestamptz default now(),primary key(post_id,user_id));
create table public.forum_poll_votes(post_id uuid references public.forum_posts(id) on delete cascade,option_id uuid not null,user_id uuid references public.profiles(id) on delete cascade,created_at timestamptz default now(),primary key(post_id,user_id));
create table public.forum_reports(id uuid primary key default gen_random_uuid(),community_id uuid references public.forum_communities(id),target_type text not null,target_id uuid not null,reporter_id uuid references public.profiles(id),reason text not null,note text not null default '',status text not null default 'Open',created_at timestamptz default now(),resolved_at timestamptz,resolved_by uuid references public.profiles(id),unique(target_type,target_id,reporter_id));
create table public.forum_moderation_actions(id uuid primary key default gen_random_uuid(),community_id uuid references public.forum_communities(id),moderator_id uuid references public.profiles(id),kind text not null,target_id uuid not null,reason text not null default '',created_at timestamptz default now());

insert into public.forum_communities(id,slug,name,summary,category,visibility) values
('f1000000-0000-0000-0000-000000000001','powerlifting','Powerlifting','The big three, meets, and programming.','Training','Public'),
('f1000000-0000-0000-0000-000000000002','bodybuilding','Bodybuilding','Hypertrophy, posing, and physique development.','Training','Public'),
('f1000000-0000-0000-0000-000000000003','form-checks','Form Checks','Constructive technique feedback.','Coaching','Public'),
('f1000000-0000-0000-0000-000000000004','programming','Programming','Share and discuss training plans.','Training','Public'),
('f1000000-0000-0000-0000-000000000005','meet-prep','Meet Prep','Competition preparation and logistics.','Competition','Restricted'),
('f1000000-0000-0000-0000-000000000006','garage-gyms','Garage Gyms','Home gym training and equipment.','Lifestyle','Public'),
('f1000000-0000-0000-0000-000000000007','beginners','New Lifters','A welcoming place to learn.','Training','Public'),
('f1000000-0000-0000-0000-000000000008','moderator-desk','Moderator Desk','Private safety coordination.','Staff','Invite Only')
on conflict(id) do nothing;

create or replace function public.can_view_forum_community(target uuid)
returns boolean language sql stable security definer set search_path=public as $$
select exists(select 1 from public.forum_communities c where c.id=target and c.archived_at is null and (
c.visibility<>'Invite Only' or exists(select 1 from public.forum_memberships m where m.community_id=c.id and m.user_id=auth.uid() and m.status in('Joined','Muted')))); $$;
create or replace function public.can_view_forum_post(target uuid)
returns boolean language sql stable security definer set search_path=public as $$
select exists(select 1 from public.forum_posts p where p.id=target and not public.is_blocked_pair(p.author_id,auth.uid()) and (
(p.community_id is not null and public.can_view_forum_community(p.community_id)) or
(p.gym_id is not null and exists(select 1 from public.gym_memberships gm where gm.gym_id=p.gym_id and gm.user_id=auth.uid() and gm.left_at is null)))); $$;

create or replace function public.join_forum_community(target_community_id uuid,request_note text default '') returns text
language plpgsql security definer set search_path=public as $$ declare v text; s text; begin
select visibility into v from public.forum_communities where id=target_community_id and archived_at is null;if v is null then raise exception 'Community unavailable';end if;
s:=case when v='Restricted' then 'Pending' when v='Invite Only' then null else 'Joined' end;if s is null then raise exception 'Invitation required';end if;
insert into public.forum_memberships(community_id,user_id,status,joined_at,restriction_reason) values(target_community_id,auth.uid(),s,case when s='Joined' then now() end,left(request_note,1000))
on conflict(community_id,user_id) do update set status=excluded.status,joined_at=excluded.joined_at,restriction_reason=excluded.restriction_reason;return s;end;$$;
create or replace function public.leave_forum_community(target_community_id uuid) returns void language sql security definer set search_path=public as $$update public.forum_memberships set status='Left' where community_id=target_community_id and user_id=auth.uid()$$;
create or replace function public.moderate_forum_post(target_post_id uuid,action text,reason text default '') returns void language plpgsql security definer set search_path=public as $$declare c uuid;begin select community_id into c from public.forum_posts where id=target_post_id;if not(public.is_admin() or exists(select 1 from public.forum_memberships where community_id=c and user_id=auth.uid() and role in('Moderator','Admin','Staff') and status='Joined'))then raise exception 'Moderator permission required';end if;
update public.forum_posts set is_pinned=case when action='Pinned' then true when action='Unpinned' then false else is_pinned end,is_locked=case when action='Locked' then true when action='Unlocked' then false else is_locked end,removed_at=case when action='Removed' then now() when action='Restored' then null else removed_at end,removal_reason=case when action='Restored' then null when action='Removed' then left(reason,1000) else removal_reason end where id=target_post_id;
insert into public.forum_moderation_actions(community_id,moderator_id,kind,target_id,reason)values(c,auth.uid(),action,target_post_id,left(reason,1000));end;$$;

alter table public.forum_communities enable row level security;alter table public.forum_memberships enable row level security;alter table public.forum_posts enable row level security;alter table public.forum_comments enable row level security;alter table public.forum_post_votes enable row level security;alter table public.forum_comment_votes enable row level security;alter table public.forum_post_saves enable row level security;alter table public.forum_post_watches enable row level security;alter table public.forum_poll_votes enable row level security;alter table public.forum_reports enable row level security;alter table public.forum_moderation_actions enable row level security;
create policy "forum communities visible" on public.forum_communities for select to authenticated using(public.can_view_forum_community(id));
create policy "forum memberships own read" on public.forum_memberships for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy "forum posts visible" on public.forum_posts for select to authenticated using(public.can_view_forum_post(id));
create policy "forum posts member insert" on public.forum_posts for insert to authenticated with check(author_id=auth.uid() and not public.is_blocked_pair(author_id,auth.uid()) and ((community_id is not null and exists(select 1 from public.forum_memberships m where m.community_id=forum_posts.community_id and m.user_id=auth.uid() and m.status='Joined'))or(gym_id is not null and exists(select 1 from public.gym_memberships gm where gm.gym_id=forum_posts.gym_id and gm.user_id=auth.uid() and gm.left_at is null))));
create policy "forum comments visible" on public.forum_comments for select to authenticated using(public.can_view_forum_post(post_id));
create policy "forum comments member insert" on public.forum_comments for insert to authenticated with check(author_id=auth.uid() and public.can_view_forum_post(post_id) and not exists(select 1 from public.forum_posts p where p.id=post_id and p.is_locked));
create policy "forum post votes visible" on public.forum_post_votes for select to authenticated using(public.can_view_forum_post(post_id));create policy "forum post votes own" on public.forum_post_votes for all to authenticated using(user_id=auth.uid())with check(user_id=auth.uid() and public.can_view_forum_post(post_id));
create policy "forum comment votes visible" on public.forum_comment_votes for select to authenticated using(exists(select 1 from public.forum_comments c where c.id=comment_id and public.can_view_forum_post(c.post_id)));create policy "forum comment votes own" on public.forum_comment_votes for all to authenticated using(user_id=auth.uid())with check(user_id=auth.uid());
create policy "forum saves own" on public.forum_post_saves for all to authenticated using(user_id=auth.uid())with check(user_id=auth.uid() and public.can_view_forum_post(post_id));create policy "forum watches own" on public.forum_post_watches for all to authenticated using(user_id=auth.uid())with check(user_id=auth.uid() and public.can_view_forum_post(post_id));create policy "forum polls own" on public.forum_poll_votes for all to authenticated using(user_id=auth.uid())with check(user_id=auth.uid() and public.can_view_forum_post(post_id));
create policy "forum reports own insert" on public.forum_reports for insert to authenticated with check(reporter_id=auth.uid());create policy "forum reports scoped read" on public.forum_reports for select to authenticated using(reporter_id=auth.uid() or public.is_admin());create policy "forum moderation scoped read" on public.forum_moderation_actions for select to authenticated using(moderator_id=auth.uid() or public.is_admin());

revoke all on function public.join_forum_community(uuid,text) from public;revoke all on function public.leave_forum_community(uuid) from public;revoke all on function public.moderate_forum_post(uuid,text,text) from public;
grant execute on function public.join_forum_community(uuid,text) to authenticated;grant execute on function public.leave_forum_community(uuid) to authenticated;grant execute on function public.moderate_forum_post(uuid,text,text) to authenticated;

create or replace function public.can_view_profile(target_user_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
select auth.uid() is not null and not public.is_blocked_pair(target_user_id,auth.uid()) and coalesce(public.can_view_profile_field(
target_user_id,(select pp.profile_audience from public.profile_privacy pp where pp.user_id=target_user_id)),false);$$;

create or replace function public.get_followed_activity()
returns table(id uuid,user_id uuid,username text,display_name text,title text,detail text,lift_id uuid,created_at timestamptz,is_liked boolean,is_saved boolean)
language sql stable security definer set search_path=public as $$
with visible as (
  select p.*,case when p.author_id=auth.uid() or public.are_friends(p.author_id,auth.uid()) then 0 else 1 end priority
  from public.forum_posts p
  where p.removed_at is null and public.can_view_forum_post(p.id)
    and (p.author_id=auth.uid() or public.are_friends(p.author_id,auth.uid()) or exists(
      select 1 from public.forum_memberships m where m.community_id=p.community_id and m.user_id=auth.uid() and m.status in('Joined','Muted')))
)
select p.id,p.author_id,pr.username,pr.display_name,p.title,left(p.body,500),p.lift_id,p.created_at,
exists(select 1 from public.forum_post_votes v where v.post_id=p.id and v.user_id=auth.uid() and v.value=1),
exists(select 1 from public.forum_post_saves s where s.post_id=p.id and s.user_id=auth.uid())
from visible p join public.profiles pr on pr.id=p.author_id order by p.priority,p.created_at desc limit 100;$$;
