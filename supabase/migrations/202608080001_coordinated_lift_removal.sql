begin;
-- Normalize hosted beta fields before creating the canonical public views. The
-- same idempotent block is repeated in the latest migration so environments
-- that already applied this migration receive the compatibility boundary too.
alter table public.profile_privacy
  add column if not exists show_lift_videos boolean not null default true;

grant update (show_lift_videos) on public.profile_privacy to authenticated;

alter table public.lift_submissions
  add column if not exists gym_uuid uuid,
  add column if not exists status text not null default 'pending',
  add column if not exists bodyweight_class text,
  add column if not exists review_status text not null default 'pending',
  add column if not exists evidence_public boolean not null default false,
  add column if not exists evidence_storage_path text,
  add column if not exists pending_evidence_storage_path text,
  add column if not exists approved_evidence_storage_path text,
  add column if not exists disputed_at timestamptz,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists review_note text;

update public.lift_submissions
set gym_uuid = gym_id::uuid
where gym_uuid is null and gym_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

create or replace function public.synchronize_lift_gym_uuid()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.gym_uuid := case
    when new.gym_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then new.gym_id::uuid
    else null
  end;
  return new;
end;
$$;

drop trigger if exists a_synchronize_lift_gym_uuid on public.lift_submissions;
create trigger a_synchronize_lift_gym_uuid
before insert or update of gym_id on public.lift_submissions
for each row execute function public.synchronize_lift_gym_uuid();

create or replace function public.public_profile_show_gym(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select coalesce(
    (
      select pp.profile_audience = 'public' and pp.gym_audience = 'public'
      from public.profile_privacy pp
      where pp.user_id = target_user_id
    ),
    false
  )
$$;

revoke all on function public.public_profile_show_gym(uuid) from public;
grant execute on function public.public_profile_show_gym(uuid) to anon, authenticated;

revoke delete on public.lift_submissions from anon, authenticated;

create table if not exists public.lift_removal_requests (
  id uuid primary key default gen_random_uuid(),
  lift_id uuid not null unique,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'failed')),
  protected_record boolean not null default false,
  lift_snapshot jsonb not null default '{}'::jsonb,
  storage_objects jsonb not null default '[]'::jsonb,
  last_error text,
  requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.lift_removal_requests enable row level security;
revoke all on table public.lift_removal_requests from anon, authenticated;

create or replace function public.prevent_moderation_audit_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if coalesce(pg_catalog.current_setting('liftrank.trusted_lift_removal', true), 'false') = 'true' then
    return old;
  end if;
  raise exception 'Moderation audit entries are immutable';
end;
$$;

create or replace function public.finalize_lift_removal(target_request_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  request_row public.lift_removal_requests%rowtype;
begin
  select * into request_row
  from public.lift_removal_requests
  where id = target_request_id
  for update;

  if not found then
    raise exception 'Removal request not found' using errcode = 'P0002';
  end if;
  if request_row.status = 'completed' then
    return true;
  end if;

  perform pg_catalog.set_config('liftrank.trusted_lift_removal', 'true', true);
  delete from public.lift_moderation_audit where lift_id = request_row.lift_id;
  delete from public.lift_submissions
  where id = request_row.lift_id and user_id = request_row.owner_id;

  update public.lift_removal_requests
  set status = 'completed', completed_at = now(), updated_at = now(), last_error = null
  where id = request_row.id;
  return true;
end;
$$;

revoke all on function public.finalize_lift_removal(uuid) from public, anon, authenticated;
grant execute on function public.finalize_lift_removal(uuid) to service_role;

commit;
