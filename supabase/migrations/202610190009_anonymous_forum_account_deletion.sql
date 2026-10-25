alter table public.forum_posts alter column author_id drop not null;
alter table public.forum_comments alter column author_id drop not null;
alter table public.moderation_actions alter column actor_id drop not null;

alter table public.group_bans drop constraint group_bans_moderator_id_fkey;
alter table public.group_bans add constraint group_bans_moderator_id_fkey
  foreign key (moderator_id) references public.profiles(id) on delete set null;

alter table public.moderation_actions drop constraint moderation_actions_actor_id_fkey;
alter table public.moderation_actions add constraint moderation_actions_actor_id_fkey
  foreign key (actor_id) references public.profiles(id) on delete set null;

alter table public.forum_communities drop constraint forum_communities_staff_owner_id_fkey;
alter table public.forum_communities add constraint forum_communities_staff_owner_id_fkey
  foreign key (staff_owner_id) references public.profiles(id) on delete set null;

alter table public.forum_memberships drop constraint forum_memberships_invited_by_fkey;
alter table public.forum_memberships add constraint forum_memberships_invited_by_fkey
  foreign key (invited_by) references public.profiles(id) on delete set null;

alter table public.forum_posts drop constraint forum_posts_author_id_fkey;
alter table public.forum_posts add constraint forum_posts_author_id_fkey
  foreign key (author_id) references public.profiles(id) on delete set null;

alter table public.forum_comments drop constraint forum_comments_author_id_fkey;
alter table public.forum_comments add constraint forum_comments_author_id_fkey
  foreign key (author_id) references public.profiles(id) on delete set null;

alter table public.forum_reports drop constraint forum_reports_reporter_id_fkey;
alter table public.forum_reports add constraint forum_reports_reporter_id_fkey
  foreign key (reporter_id) references public.profiles(id) on delete set null;

alter table public.forum_reports drop constraint forum_reports_resolved_by_fkey;
alter table public.forum_reports add constraint forum_reports_resolved_by_fkey
  foreign key (resolved_by) references public.profiles(id) on delete set null;

alter table public.forum_moderation_actions drop constraint forum_moderation_actions_moderator_id_fkey;
alter table public.forum_moderation_actions add constraint forum_moderation_actions_moderator_id_fkey
  foreign key (moderator_id) references public.profiles(id) on delete set null;

alter table public.lift_moderation_audit drop constraint lift_moderation_audit_actor_id_fkey;
alter table public.lift_moderation_audit add constraint lift_moderation_audit_actor_id_fkey
  foreign key (actor_id) references public.profiles(id) on delete set null;

alter table public.lift_submissions drop constraint lift_submissions_reviewed_by_fkey;
alter table public.lift_submissions add constraint lift_submissions_reviewed_by_fkey
  foreign key (reviewed_by) references public.profiles(id) on delete set null;

alter table public.profile_reports drop constraint profile_reports_resolved_by_fkey;
alter table public.profile_reports add constraint profile_reports_resolved_by_fkey
  foreign key (resolved_by) references public.profiles(id) on delete set null;

create or replace function public.prevent_moderation_audit_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if coalesce(pg_catalog.current_setting('liftrank.trusted_lift_removal', true), 'false') = 'true' then
    return old;
  end if;
  if tg_op = 'UPDATE'
    and pg_catalog.pg_trigger_depth() > 1
    and old.actor_id is not null
    and new.actor_id is null
    and (pg_catalog.to_jsonb(new) - 'actor_id') = (pg_catalog.to_jsonb(old) - 'actor_id')
  then
    return new;
  end if;
  raise exception 'Moderation audit entries are immutable';
end;
$$;

