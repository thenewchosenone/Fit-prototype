-- Focused v1 social surface: mutual connections sharing complete workouts.
-- Forums and messages remain intact but are not dependencies of this feed.

create table public.workout_shares (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  workout_id uuid not null,
  title text not null check (char_length(title) between 1 and 120),
  detail text not null default '' check (char_length(detail) <= 1000),
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  unique (owner_id, workout_id),
  foreign key (owner_id, workout_id)
    references public.completed_workout_snapshots(owner_id, id) on delete cascade
);

create table public.workout_share_likes (
  share_id uuid not null references public.workout_shares(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (share_id, user_id)
);

create table public.workout_share_comments (
  id uuid primary key default gen_random_uuid(),
  share_id uuid not null references public.workout_shares(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  removed_at timestamptz
);

create table public.workout_share_reports (
  id uuid primary key default gen_random_uuid(),
  share_id uuid not null references public.workout_shares(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null,
  note text not null default '' check (char_length(note) <= 1000),
  status text not null default 'Open' check (status in ('Open','Resolved','Dismissed')),
  created_at timestamptz not null default now(),
  unique (share_id, reporter_id)
);

create or replace function public.can_view_workout_share(target_share_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.workout_shares share
    where share.id=target_share_id and share.removed_at is null
      and not public.is_blocked_pair(share.owner_id,auth.uid())
      and (share.owner_id=auth.uid() or public.are_friends(share.owner_id,auth.uid()))
  );
$$;

-- The focused feed adds workout_id and aggregate counts to the legacy forum
-- feed's row type. PostgreSQL cannot replace a function when OUT columns
-- change, so explicitly replace the zero-argument overload.
drop function if exists public.get_followed_activity();
create function public.get_followed_activity()
returns table(id uuid,user_id uuid,username text,display_name text,title text,detail text,lift_id uuid,workout_id uuid,created_at timestamptz,is_liked boolean,is_saved boolean,like_count integer,comment_count integer)
language sql stable security definer set search_path=public as $$
  select share.id,share.owner_id,profile.username,profile.display_name,share.title,share.detail,
    null::uuid,share.workout_id,share.created_at,
    exists(select 1 from public.workout_share_likes likes where likes.share_id=share.id and likes.user_id=auth.uid()),
    false,
    (select count(*)::integer from public.workout_share_likes likes where likes.share_id=share.id),
    (select count(*)::integer from public.workout_share_comments comments where comments.share_id=share.id and comments.removed_at is null)
  from public.workout_shares share join public.profiles profile on profile.id=share.owner_id
  where public.can_view_workout_share(share.id)
  order by share.created_at desc limit 100;
$$;

create or replace function public.search_profile_cards(search_query text,result_limit integer default 20)
returns table(id uuid,username text,display_name text,avatar_path text,bio text,discipline text,training_goal text,age_band text,sex_category text,city text,region text,primary_gym_id uuid,primary_gym_name text)
language sql stable security definer set search_path=public as $$
  select card.* from public.profiles profile
  cross join lateral public.get_profile_card(profile.id) card
  where profile.id<>auth.uid()
    and not public.is_blocked_pair(profile.id,auth.uid())
    and (profile.username ilike '%'||left(btrim(search_query),50)||'%' or profile.display_name ilike '%'||left(btrim(search_query),50)||'%')
  order by profile.display_name limit greatest(1,least(result_limit,50));
$$;

create or replace function public.share_completed_workout(target_workout_id uuid,share_title text,share_detail text default '')
returns uuid language plpgsql security definer set search_path=public as $$
declare result uuid;
begin
  if not exists(select 1 from public.completed_workout_snapshots where owner_id=auth.uid() and id=target_workout_id) then raise exception 'Workout not found'; end if;
  insert into public.workout_shares(owner_id,workout_id,title,detail)
  values(auth.uid(),target_workout_id,left(btrim(share_title),120),left(btrim(share_detail),1000))
  on conflict(owner_id,workout_id) do update set title=excluded.title,detail=excluded.detail,removed_at=null
  returning id into result;
  return result;
end;$$;

create or replace function public.remove_workout_share(target_share_id uuid)
returns void language sql security definer set search_path=public as $$
  update public.workout_shares set removed_at=now() where id=target_share_id and owner_id=auth.uid();
$$;

create or replace function public.set_workout_share_liked(target_share_id uuid,liked boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.can_view_workout_share(target_share_id) then raise exception 'permission denied'; end if;
  if liked then insert into public.workout_share_likes(share_id,user_id) values(target_share_id,auth.uid()) on conflict do nothing;
  else delete from public.workout_share_likes where share_id=target_share_id and user_id=auth.uid(); end if;
end;$$;

create or replace function public.get_workout_share_comments(target_share_id uuid)
returns table(id uuid,activity_id uuid,author_id uuid,author_name text,body text,created_at timestamptz)
language sql stable security definer set search_path=public as $$
  select comment.id,comment.share_id,comment.author_id,profile.display_name,comment.body,comment.created_at
  from public.workout_share_comments comment join public.profiles profile on profile.id=comment.author_id
  where comment.share_id=target_share_id and comment.removed_at is null and public.can_view_workout_share(target_share_id)
  order by comment.created_at;
$$;

create or replace function public.add_workout_share_comment(target_share_id uuid,comment_body text)
returns table(id uuid,activity_id uuid,author_id uuid,author_name text,body text,created_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare inserted public.workout_share_comments;
begin
  if not public.can_view_workout_share(target_share_id) then raise exception 'permission denied'; end if;
  insert into public.workout_share_comments(share_id,author_id,body)
  values(target_share_id,auth.uid(),left(btrim(comment_body),1000)) returning * into inserted;
  return query select inserted.id,inserted.share_id,inserted.author_id,profile.display_name,inserted.body,inserted.created_at from public.profiles profile where profile.id=inserted.author_id;
end;$$;

create or replace function public.report_workout_share(target_share_id uuid,report_reason text,report_note text default '')
returns void language plpgsql security definer set search_path=public as $$
declare owner uuid;
begin
  select owner_id into owner from public.workout_shares where id=target_share_id and removed_at is null;
  if owner is null or owner=auth.uid() or public.is_blocked_pair(owner,auth.uid()) then raise exception 'permission denied'; end if;
  insert into public.workout_share_reports(share_id,reporter_id,reason,note)
  values(target_share_id,auth.uid(),left(report_reason,80),left(report_note,1000))
  on conflict(share_id,reporter_id) do update set reason=excluded.reason,note=excluded.note,status='Open',created_at=now();
end;$$;

create or replace function public.notify_workout_share_comment()
returns trigger language plpgsql security definer set search_path=public as $$
declare recipient uuid;
begin
  select owner_id into recipient from public.workout_shares where id=new.share_id;
  if recipient<>new.author_id and not public.is_blocked_pair(recipient,new.author_id) then
    insert into public.notifications(user_id,title,body,kind,destination)
    values(recipient,'New workout comment',left(new.body,160),'workout_comment',jsonb_build_object('kind','workoutShare','targetID',new.share_id));
  end if;
  return new;
end;$$;
create trigger workout_share_comment_notification after insert on public.workout_share_comments for each row execute function public.notify_workout_share_comment();

alter table public.workout_shares enable row level security;
alter table public.workout_share_likes enable row level security;
alter table public.workout_share_comments enable row level security;
alter table public.workout_share_reports enable row level security;
create policy "workout shares connection read" on public.workout_shares for select to authenticated using(public.can_view_workout_share(id));
create policy "workout shares owner insert" on public.workout_shares for insert to authenticated with check(owner_id=auth.uid());
create policy "workout shares owner update" on public.workout_shares for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "workout likes connection access" on public.workout_share_likes for all to authenticated using(user_id=auth.uid() and public.can_view_workout_share(share_id)) with check(user_id=auth.uid() and public.can_view_workout_share(share_id));
create policy "workout comments connection read" on public.workout_share_comments for select to authenticated using(public.can_view_workout_share(share_id));
create policy "workout comments author insert" on public.workout_share_comments for insert to authenticated with check(author_id=auth.uid() and public.can_view_workout_share(share_id));
create policy "workout reports own access" on public.workout_share_reports for all to authenticated
  using(reporter_id=auth.uid() or public.is_admin())
  with check(reporter_id=auth.uid() or public.is_admin());

revoke all on function public.can_view_workout_share(uuid) from public,anon;
revoke all on function public.get_followed_activity() from public,anon;
revoke all on function public.search_profile_cards(text,integer) from public,anon;
revoke all on function public.share_completed_workout(uuid,text,text) from public,anon;
revoke all on function public.remove_workout_share(uuid) from public,anon;
revoke all on function public.set_workout_share_liked(uuid,boolean) from public,anon;
revoke all on function public.get_workout_share_comments(uuid) from public,anon;
revoke all on function public.add_workout_share_comment(uuid,text) from public,anon;
revoke all on function public.report_workout_share(uuid,text,text) from public,anon;
grant execute on function public.get_followed_activity() to authenticated;
grant execute on function public.search_profile_cards(text,integer) to authenticated;
grant execute on function public.share_completed_workout(uuid,text,text) to authenticated;
grant execute on function public.remove_workout_share(uuid) to authenticated;
grant execute on function public.set_workout_share_liked(uuid,boolean) to authenticated;
grant execute on function public.get_workout_share_comments(uuid) to authenticated;
grant execute on function public.add_workout_share_comment(uuid,text) to authenticated;
grant execute on function public.report_workout_share(uuid,text,text) to authenticated;
revoke all on function public.notify_workout_share_comment() from public;
