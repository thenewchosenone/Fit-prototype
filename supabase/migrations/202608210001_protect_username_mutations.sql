-- Protect usernames from being overwritten by unrelated profile saves.
-- Username changes must go through the dedicated, explicit RPC below.

create table if not exists public.profile_username_changes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  old_username text not null,
  new_username text not null,
  changed_at timestamptz not null default now()
);

create index if not exists profile_username_changes_user_changed_at
  on public.profile_username_changes (user_id, changed_at desc);

alter table public.profile_username_changes enable row level security;
revoke all on public.profile_username_changes from public, anon, authenticated;

create or replace function public.protect_profile_identity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if (new.username is distinct from old.username or new.handle is distinct from old.handle)
     and coalesce(current_setting('app.username_change_user', true), '') <> old.id::text then
    raise exception using errcode = '42501', message = 'Username changes require the dedicated change flow';
  end if;
  return new;
end;
$$;

revoke execute on function public.protect_profile_identity() from public, anon, authenticated;
drop trigger if exists protect_profile_identity on public.profiles;
create trigger protect_profile_identity
before update of username, handle on public.profiles
for each row execute function public.protect_profile_identity();

drop function if exists public.claim_username(text);

create or replace function public.change_username(
  current_username text,
  desired_username text
)
returns text
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  normalized_current text := lower(btrim(current_username, ' @'));
  normalized text := lower(btrim(desired_username, ' @'));
  stored_username text;
begin
  if caller is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  if normalized !~ '^[a-z0-9_]{3,24}$' then
    raise exception using errcode = '23514', message = 'Username must contain 3-24 lowercase letters, numbers, or underscores';
  end if;

  select p.username
    into stored_username
  from public.profiles p
  where p.id = caller
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
  if lower(stored_username) <> normalized_current then
    raise exception using errcode = '40001', message = 'Profile changed; reload before changing the username';
  end if;
  if lower(stored_username) = normalized then
    return stored_username;
  end if;

  perform set_config('app.username_change_user', caller::text, true);
  update public.profiles p
  set username = normalized,
      handle = '@' || normalized
  where p.id = caller;

  insert into public.profile_username_changes (user_id, old_username, new_username)
  values (caller, stored_username, normalized);

  return normalized;
exception when unique_violation then
  raise exception using errcode = '23505', message = 'Username is already in use';
end;
$$;

revoke execute on function public.change_username(text, text) from public, anon;
grant execute on function public.change_username(text, text) to authenticated;
