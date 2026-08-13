-- LiftRank private-beta identity and social foundation.
--
-- This is intentionally forward-only. The status of 202607120001_security_foundation.sql
-- cannot be confirmed in every environment, so legacy membership/friendship tables are
-- retained under dated names instead of being destroyed.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Profiles and private profile data
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists username text,
  add column if not exists avatar_path text,
  add column if not exists onboarding_completed boolean not null default false;

do $$
declare
  profile_row record;
  candidate text;
  collision_number integer;
begin
  for profile_row in
    select p.id, p.handle from public.profiles p where p.username is null order by p.created_at, p.id
  loop
    candidate := lower(regexp_replace(coalesce(profile_row.handle, ''), '^@', ''));
    if candidate !~ '^[a-z0-9_]{3,24}$' then
      candidate := 'member_' || left(replace(profile_row.id::text, '-', ''), 12);
    end if;

    collision_number := 0;
    while exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(candidate) and p.id <> profile_row.id
    ) loop
      collision_number := collision_number + 1;
      candidate := 'lr_' || left(md5(profile_row.id::text || ':' || collision_number::text), 20);
    end loop;

    update public.profiles p set username = candidate where p.id = profile_row.id;
  end loop;
end;
$$;

alter table public.profiles alter column username set not null;
create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username));
alter table public.profiles drop constraint if exists profiles_username_format;
alter table public.profiles add constraint profiles_username_format
  check (username ~ '^[a-z0-9_]{3,24}$') not valid;
alter table public.profiles validate constraint profiles_username_format;

create table if not exists public.profile_private_details (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  birth_date date,
  sex_category text check (sex_category is null or sex_category in ('male', 'female', 'open')),
  preferred_unit text not null default 'lb' check (preferred_unit in ('lb', 'kg')),
  height_cm numeric(6,2) check (height_cm is null or height_cm between 50 and 300),
  city text check (city is null or char_length(city) <= 120),
  region text check (region is null or char_length(region) <= 120),
  country_code text check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  years_experience smallint check (years_experience is null or years_experience between 0 and 100),
  experience_level text check (
    experience_level is null or experience_level in
      ('beginner', 'novice', 'intermediate', 'advanced', 'veteran')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_privacy (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  profile_audience text not null default 'public',
  age_band_audience text not null default 'public',
  division_audience text not null default 'public',
  bodyweight_audience text not null default 'private',
  location_audience text not null default 'friends',
  gym_audience text not null default 'public',
  friend_list_audience text not null default 'friends',
  updated_at timestamptz not null default now(),
  constraint profile_privacy_profile_audience check (profile_audience in ('public', 'friends', 'gym', 'private')),
  constraint profile_privacy_age_audience check (age_band_audience in ('public', 'friends', 'gym', 'private')),
  constraint profile_privacy_division_audience check (division_audience in ('public', 'friends', 'gym', 'private')),
  constraint profile_privacy_bodyweight_audience check (bodyweight_audience in ('public', 'friends', 'gym', 'private')),
  constraint profile_privacy_location_audience check (location_audience in ('public', 'friends', 'gym', 'private')),
  constraint profile_privacy_gym_audience check (gym_audience in ('public', 'friends', 'gym', 'private')),
  constraint profile_privacy_friend_list_audience check (friend_list_audience in ('public', 'friends', 'gym', 'private'))
);

insert into public.profile_private_details (user_id)
select p.id from public.profiles p
on conflict (user_id) do nothing;

insert into public.profile_privacy (
  user_id, age_band_audience, location_audience, gym_audience
)
select
  p.id,
  case when p.hide_age then 'private' else 'public' end,
  case when p.hide_location then 'private' else 'public' end,
  case when p.hide_gym then 'private' else 'public' end
from public.profiles p
on conflict (user_id) do nothing;

create or replace function public.set_server_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

drop trigger if exists profile_private_details_updated_at on public.profile_private_details;
create trigger profile_private_details_updated_at
before update on public.profile_private_details
for each row execute function public.set_server_updated_at();

drop trigger if exists profile_privacy_updated_at on public.profile_privacy;
create trigger profile_privacy_updated_at
before update on public.profile_privacy
for each row execute function public.set_server_updated_at();

create or replace function public.protect_profile_authority()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.id := old.id;
  new.role := old.role;
  new.credential_verified := old.credential_verified;
  new.created_at := old.created_at;
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  placeholder text := 'member_' || left(replace(new.id::text, '-', ''), 12);
  collision_number integer := 0;
  requested_display_name text := nullif(btrim(new.raw_user_meta_data ->> 'display_name'), '');
begin
  if requested_display_name is null or char_length(requested_display_name) not between 2 and 60 then
    requested_display_name := 'LiftRank Member';
  end if;

  while exists (
    select 1 from public.profiles p
    where lower(p.username) = lower(placeholder) or p.handle = '@' || placeholder
  ) loop
    collision_number := collision_number + 1;
    placeholder := 'lr_' || left(md5(new.id::text || ':' || collision_number::text), 20);
  end loop;

  insert into public.profiles (id, display_name, handle, username)
  values (new.id, requested_display_name, '@' || placeholder, placeholder)
  on conflict (id) do nothing;

  insert into public.profile_private_details (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.profile_privacy (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists auth_user_profile on auth.users;
create trigger auth_user_profile
after insert on auth.users
for each row execute function public.create_profile_for_new_user();

-- Repair auth accounts created while a profile trigger was absent. Email is never
-- used to construct a public identifier.
do $$
declare
  auth_user record;
  placeholder text;
  collision_number integer;
begin
  for auth_user in
    select u.id
    from auth.users u
    left join public.profiles p on p.id = u.id
    where p.id is null
    order by u.id
  loop
    placeholder := 'member_' || left(replace(auth_user.id::text, '-', ''), 12);
    collision_number := 0;
    while exists (
      select 1 from public.profiles p
      where lower(p.username) = lower(placeholder) or p.handle = '@' || placeholder
    ) loop
      collision_number := collision_number + 1;
      placeholder := 'lr_' || left(md5(auth_user.id::text || ':' || collision_number::text), 20);
    end loop;

    insert into public.profiles (id, display_name, handle, username)
    values (auth_user.id, 'LiftRank Member', '@' || placeholder, placeholder)
    on conflict (id) do nothing;
  end loop;
end;
$$;

insert into public.profile_private_details (user_id)
select p.id from public.profiles p
on conflict (user_id) do nothing;
insert into public.profile_privacy (user_id)
select p.id from public.profiles p
on conflict (user_id) do nothing;

-- -----------------------------------------------------------------------------
-- Canonical gyms and memberships
-- -----------------------------------------------------------------------------

create table if not exists public.gyms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 160),
  brand text check (brand is null or char_length(brand) <= 120),
  address_line_1 text check (address_line_1 is null or char_length(address_line_1) <= 200),
  address_line_2 text check (address_line_2 is null or char_length(address_line_2) <= 200),
  city text check (city is null or char_length(city) <= 120),
  region text check (region is null or char_length(region) <= 120),
  postal_code text check (postal_code is null or char_length(postal_code) <= 24),
  country_code text not null default 'US' check (country_code ~ '^[A-Z]{2}$'),
  latitude numeric(9,6) check (latitude is null or latitude between -90 and 90),
  longitude numeric(9,6) check (longitude is null or longitude between -180 and 180),
  external_source text,
  external_id text,
  status text not null default 'unverified' check (status in ('active', 'unverified', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists gyms_external_identity_unique
  on public.gyms (external_source, external_id)
  where external_source is not null and external_id is not null;

drop trigger if exists gyms_updated_at on public.gyms;
create trigger gyms_updated_at before update on public.gyms
for each row execute function public.set_server_updated_at();

do $$
begin
  if to_regclass('public.gym_memberships') is not null
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'gym_memberships'
         and column_name = 'gym_id'
         and data_type = 'text'
     ) then
    alter table public.gym_memberships rename to gym_memberships_legacy_20260712;
  end if;
end;
$$;

create table if not exists public.gym_memberships (
  user_id uuid not null references public.profiles(id) on delete cascade,
  gym_id uuid not null references public.gyms(id) on delete restrict,
  is_primary boolean not null default false,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (user_id, gym_id),
  constraint gym_membership_primary_is_active check (not is_primary or left_at is null)
);

create unique index if not exists gym_memberships_one_active_primary
  on public.gym_memberships (user_id)
  where is_primary and left_at is null;
create index if not exists gym_memberships_active_user
  on public.gym_memberships (user_id) where left_at is null;
create index if not exists gym_memberships_active_gym
  on public.gym_memberships (gym_id) where left_at is null;

do $$
begin
  if to_regclass('public.gym_memberships_legacy_20260712') is not null then
    insert into public.gyms (name, external_source, external_id, status)
    select distinct
      left(case when char_length(btrim(l.gym_id)) >= 2 then l.gym_id else 'Legacy gym ' || l.gym_id end, 160),
      'legacy', l.gym_id, 'unverified'
    from public.gym_memberships_legacy_20260712 l
    where l.gym_id is not null
    on conflict (external_source, external_id) where external_source is not null and external_id is not null
    do nothing;

    insert into public.gym_memberships (user_id, gym_id, is_primary, joined_at)
    select ranked.user_id, ranked.canonical_gym_id, ranked.membership_order = 1, ranked.created_at
    from (
      select
        l.user_id,
        g.id as canonical_gym_id,
        l.created_at,
        row_number() over (partition by l.user_id order by l.created_at, g.id) as membership_order
      from public.gym_memberships_legacy_20260712 l
      join public.gyms g
        on g.external_source = 'legacy' and g.external_id = l.gym_id
    ) ranked
    where ranked.membership_order <= 3
    on conflict (user_id, gym_id) do nothing;
  end if;
end;
$$;

create or replace function public.enforce_gym_membership_limits()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  active_count integer;
begin
  -- A profile-row lock serializes joins for one user, preventing concurrent
  -- requests from both observing a count below three.
  perform 1 from public.profiles p where p.id = new.user_id for update;

  if tg_op = 'UPDATE' and (new.user_id <> old.user_id or new.gym_id <> old.gym_id) then
    raise exception using errcode = '23514', message = 'Membership identity cannot be changed';
  end if;

  if new.is_primary and new.left_at is not null then
    raise exception using errcode = '23514', message = 'A primary gym membership must be active';
  end if;

  if new.left_at is null then
    if tg_op = 'INSERT' then
      select count(*) into active_count
      from public.gym_memberships gm
      where gm.user_id = new.user_id and gm.left_at is null;
    else
      select count(*) into active_count
      from public.gym_memberships gm
      where gm.user_id = new.user_id
        and gm.left_at is null
        and gm.gym_id <> old.gym_id;
    end if;

    if active_count >= 3 then
      raise exception using errcode = '23514', message = 'A user may join at most three active gyms';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_gym_membership_limits on public.gym_memberships;
create trigger enforce_gym_membership_limits
before insert or update of user_id, gym_id, left_at, is_primary
on public.gym_memberships
for each row execute function public.enforce_gym_membership_limits();

-- -----------------------------------------------------------------------------
-- Canonical friend relationships
-- -----------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.friendships') is not null then
    alter table public.friendships rename to friendships_legacy_20260712;
  end if;
end;
$$;

create table if not exists public.friend_relationships (
  id uuid primary key default gen_random_uuid(),
  user_low_id uuid not null references public.profiles(id) on delete cascade,
  user_high_id uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint friend_relationship_order check (user_low_id::text < user_high_id::text),
  constraint friend_relationship_requester_is_participant check (requested_by in (user_low_id, user_high_id)),
  constraint friend_relationship_pair_unique unique (user_low_id, user_high_id)
);

create index if not exists friend_relationships_low_status
  on public.friend_relationships (user_low_id, status);
create index if not exists friend_relationships_high_status
  on public.friend_relationships (user_high_id, status);

do $$
begin
  if to_regclass('public.friendships_legacy_20260712') is not null then
    insert into public.friend_relationships (
      user_low_id, user_high_id, requested_by, status, created_at, responded_at, updated_at
    )
    select distinct on (normalized.user_low_id, normalized.user_high_id)
      normalized.user_low_id,
      normalized.user_high_id,
      normalized.requester_id,
      normalized.normalized_status,
      normalized.created_at,
      case when normalized.normalized_status = 'pending' then null else normalized.created_at end,
      normalized.created_at
    from (
      select
        case when f.requester_id::text < f.addressee_id::text then f.requester_id else f.addressee_id end as user_low_id,
        case when f.requester_id::text < f.addressee_id::text then f.addressee_id else f.requester_id end as user_high_id,
        f.requester_id,
        case f.status
          when 'Accepted' then 'accepted'
          when 'Declined' then 'declined'
          else 'pending'
        end as normalized_status,
        f.created_at
      from public.friendships_legacy_20260712 f
    ) normalized
    order by
      normalized.user_low_id,
      normalized.user_high_id,
      case normalized.normalized_status when 'accepted' then 1 when 'pending' then 2 else 3 end,
      normalized.created_at desc
    on conflict (user_low_id, user_high_id) do nothing;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Privacy helpers
-- -----------------------------------------------------------------------------

create or replace function public.are_friends(left_id uuid, right_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select coalesce(exists (
    select 1
    from public.friend_relationships fr
    where auth.uid() in (left_id, right_id)
      and fr.status = 'accepted'
      and fr.user_low_id = case when left_id::text < right_id::text then left_id else right_id end
      and fr.user_high_id = case when left_id::text < right_id::text then right_id else left_id end
  ), false)
$$;

create or replace function public.share_active_gym(left_id uuid, right_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select coalesce(exists (
    select 1
    from public.gym_memberships left_membership
    join public.gym_memberships right_membership
      on right_membership.gym_id = left_membership.gym_id
    where auth.uid() in (left_id, right_id)
      and left_membership.user_id = left_id
      and right_membership.user_id = right_id
      and left_membership.left_at is null
      and right_membership.left_at is null
  ), false)
$$;

create or replace function public.can_view_profile_field(target_user_id uuid, audience text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select case
    when auth.uid() is null then false
    when auth.uid() = target_user_id then true
    when audience = 'public' then true
    when audience = 'friends' then public.are_friends(auth.uid(), target_user_id)
    when audience = 'gym' then public.share_active_gym(auth.uid(), target_user_id)
    else false
  end
$$;

create or replace function public.can_view_profile(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select coalesce(public.can_view_profile_field(
    target_user_id,
    (select pp.profile_audience from public.profile_privacy pp where pp.user_id = target_user_id)
  ), false)
$$;

create or replace function public.age_band_from_birth_date(value date)
returns text
language plpgsql
stable
set search_path = pg_catalog
as $$
declare
  years integer;
  lower_bound integer;
begin
  if value is null then return null; end if;
  years := extract(year from age(current_date, value));
  if years < 18 then return 'Under 18'; end if;
  if years <= 24 then return '18-24'; end if;
  if years >= 70 then return '70+'; end if;
  lower_bound := 25 + ((years - 25) / 5) * 5;
  return lower_bound::text || '-' || (lower_bound + 4)::text;
end;
$$;

-- These helpers belong to preserved prototype domains, but they already exist in
-- the database and run with elevated privileges. Harden their lookup behavior
-- without changing their data model or product behavior.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'Admin'::public.app_role
  )
$$;

create or replace function public.moderates(group_key text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select public.is_admin() or exists (
    select 1 from public.group_moderators gm
    where gm.group_id = group_key and gm.user_id = auth.uid()
  )
$$;

create or replace function public.is_thread_member(thread_key uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1 from public.message_thread_members mtm
    where mtm.thread_id = thread_key and mtm.user_id = auth.uid()
  )
$$;

create or replace function public.get_profile_card(target_user_id uuid)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_path text,
  bio text,
  discipline text,
  training_goal text,
  age_band text,
  sex_category text,
  city text,
  region text,
  primary_gym_id uuid,
  primary_gym_name text
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    p.id,
    p.username,
    p.display_name,
    p.avatar_path,
    p.bio,
    p.discipline,
    p.training_goal,
    case when public.can_view_profile_field(p.id, pp.age_band_audience)
      then public.age_band_from_birth_date(pd.birth_date) end,
    case when public.can_view_profile_field(p.id, pp.division_audience)
      then pd.sex_category end,
    case when public.can_view_profile_field(p.id, pp.location_audience)
      then pd.city end,
    case when public.can_view_profile_field(p.id, pp.location_audience)
      then pd.region end,
    case when public.can_view_profile_field(p.id, pp.gym_audience)
      then gm.gym_id end,
    case when public.can_view_profile_field(p.id, pp.gym_audience)
      then g.name end
  from public.profiles p
  join public.profile_privacy pp on pp.user_id = p.id
  left join public.profile_private_details pd on pd.user_id = p.id
  left join public.gym_memberships gm
    on gm.user_id = p.id and gm.is_primary and gm.left_at is null
  left join public.gyms g on g.id = gm.gym_id
  where p.id = target_user_id
    and public.can_view_profile(p.id)
$$;

-- -----------------------------------------------------------------------------
-- Secure mutations
-- -----------------------------------------------------------------------------

create or replace function public.claim_username(desired_username text)
returns text
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  normalized text := lower(btrim(desired_username));
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  if normalized !~ '^[a-z0-9_]{3,24}$' then
    raise exception using errcode = '23514', message = 'Username must contain 3-24 lowercase letters, numbers, or underscores';
  end if;
  update public.profiles p set username = normalized, handle = '@' || normalized where p.id = caller;
  if not found then raise exception using errcode = 'P0002', message = 'Profile not found'; end if;
  return normalized;
exception when unique_violation then
  raise exception using errcode = '23505', message = 'Username is already in use';
end;
$$;

create or replace function public.save_own_profile(
  new_display_name text,
  new_bio text,
  new_preferred_unit text,
  new_birth_date date,
  new_sex_category text,
  new_height_cm numeric,
  new_city text,
  new_region text,
  new_country_code text,
  new_years_experience smallint,
  new_experience_level text,
  new_profile_audience text,
  new_age_band_audience text,
  new_division_audience text,
  new_location_audience text,
  new_gym_audience text,
  new_friend_list_audience text,
  complete_onboarding boolean default false
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  update public.profiles
  set display_name = new_display_name,
      bio = coalesce(new_bio, ''),
      onboarding_completed = complete_onboarding
  where id = caller;

  if not found then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;

  insert into public.profile_private_details (
    user_id, birth_date, sex_category, preferred_unit, height_cm,
    city, region, country_code, years_experience, experience_level
  ) values (
    caller, new_birth_date, new_sex_category, new_preferred_unit, new_height_cm,
    nullif(btrim(new_city), ''), nullif(btrim(new_region), ''),
    nullif(upper(btrim(new_country_code)), ''), new_years_experience,
    new_experience_level
  )
  on conflict (user_id) do update set
    birth_date = excluded.birth_date,
    sex_category = excluded.sex_category,
    preferred_unit = excluded.preferred_unit,
    height_cm = excluded.height_cm,
    city = excluded.city,
    region = excluded.region,
    country_code = excluded.country_code,
    years_experience = excluded.years_experience,
    experience_level = excluded.experience_level;

  insert into public.profile_privacy (
    user_id, profile_audience, age_band_audience, division_audience,
    location_audience, gym_audience, friend_list_audience
  ) values (
    caller, new_profile_audience, new_age_band_audience, new_division_audience,
    new_location_audience, new_gym_audience, new_friend_list_audience
  )
  on conflict (user_id) do update set
    profile_audience = excluded.profile_audience,
    age_band_audience = excluded.age_band_audience,
    division_audience = excluded.division_audience,
    location_audience = excluded.location_audience,
    gym_audience = excluded.gym_audience,
    friend_list_audience = excluded.friend_list_audience;
end;
$$;

create or replace function public.join_gym(target_gym_id uuid, make_primary boolean default false)
returns public.gym_memberships
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  active_count integer;
  result public.gym_memberships;
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  perform 1 from public.profiles p where p.id = caller for update;
  if not found then raise exception using errcode = 'P0002', message = 'Profile not found'; end if;
  if not exists (select 1 from public.gyms g where g.id = target_gym_id and g.status <> 'archived') then
    raise exception using errcode = 'P0002', message = 'Gym is unavailable';
  end if;

  select count(*) into active_count
  from public.gym_memberships gm
  where gm.user_id = caller and gm.left_at is null;

  if exists (
    select 1 from public.gym_memberships gm
    where gm.user_id = caller and gm.gym_id = target_gym_id and gm.left_at is null
  ) then
    if make_primary then
      update public.gym_memberships gm set is_primary = false
      where gm.user_id = caller and gm.left_at is null;
      update public.gym_memberships gm set is_primary = true
      where gm.user_id = caller and gm.gym_id = target_gym_id
      returning gm.* into result;
    else
      select gm.* into result from public.gym_memberships gm
      where gm.user_id = caller and gm.gym_id = target_gym_id;
    end if;
    return result;
  end if;

  if active_count >= 3 then
    raise exception using errcode = '23514', message = 'A user may join at most three active gyms';
  end if;

  if make_primary or active_count = 0 then
    update public.gym_memberships gm set is_primary = false
    where gm.user_id = caller and gm.left_at is null;
  end if;

  insert into public.gym_memberships (user_id, gym_id, is_primary, joined_at, left_at)
  values (caller, target_gym_id, make_primary or active_count = 0, statement_timestamp(), null)
  on conflict (user_id, gym_id) do update
    set left_at = null,
        joined_at = statement_timestamp(),
        is_primary = excluded.is_primary
  returning * into result;
  return result;
end;
$$;

create or replace function public.leave_gym(target_gym_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid();
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  perform 1 from public.profiles p where p.id = caller for update;
  if exists (
    select 1 from public.gym_memberships gm
    where gm.user_id = caller and gm.gym_id = target_gym_id and gm.left_at is null and gm.is_primary
  ) then
    raise exception using errcode = '23514', message = 'Choose another primary gym before leaving';
  end if;
  update public.gym_memberships gm
  set left_at = statement_timestamp(), is_primary = false
  where gm.user_id = caller and gm.gym_id = target_gym_id and gm.left_at is null;
  if not found then raise exception using errcode = 'P0002', message = 'Active gym membership not found'; end if;
end;
$$;

create or replace function public.set_primary_gym(target_gym_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid();
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  perform 1 from public.profiles p where p.id = caller for update;
  if not exists (
    select 1 from public.gym_memberships gm
    where gm.user_id = caller and gm.gym_id = target_gym_id and gm.left_at is null
  ) then
    raise exception using errcode = 'P0002', message = 'Active gym membership not found';
  end if;
  update public.gym_memberships gm set is_primary = false
  where gm.user_id = caller and gm.left_at is null;
  update public.gym_memberships gm set is_primary = true
  where gm.user_id = caller and gm.gym_id = target_gym_id and gm.left_at is null;
end;
$$;

create or replace function public.request_friendship(target_user_id uuid)
returns public.friend_relationships
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  low_id uuid;
  high_id uuid;
  existing public.friend_relationships;
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  if caller = target_user_id then raise exception using errcode = '23514', message = 'Users cannot friend themselves'; end if;
  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception using errcode = 'P0002', message = 'Profile not found';
  end if;
  low_id := case when caller::text < target_user_id::text then caller else target_user_id end;
  high_id := case when caller::text < target_user_id::text then target_user_id else caller end;

  select fr.* into existing from public.friend_relationships fr
  where fr.user_low_id = low_id and fr.user_high_id = high_id
  for update;

  if found and existing.status in ('pending', 'accepted') then
    raise exception using errcode = '23505', message = 'A friendship or pending request already exists';
  elsif found then
    update public.friend_relationships fr
    set requested_by = caller,
        status = 'pending',
        responded_at = null,
        updated_at = statement_timestamp()
    where fr.id = existing.id
    returning fr.* into existing;
    return existing;
  end if;

  insert into public.friend_relationships (user_low_id, user_high_id, requested_by)
  values (low_id, high_id, caller)
  returning * into existing;
  return existing;
end;
$$;

create or replace function public.respond_to_friendship(relationship_id uuid, accept_request boolean)
returns public.friend_relationships
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid(); result public.friend_relationships;
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  select fr.* into result from public.friend_relationships fr where fr.id = relationship_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'Friend request not found'; end if;
  if result.status <> 'pending' then raise exception using errcode = '23514', message = 'Friend request is no longer pending'; end if;
  if caller = result.requested_by or caller not in (result.user_low_id, result.user_high_id) then
    raise exception using errcode = '42501', message = 'Only the recipient may respond to a friend request';
  end if;
  update public.friend_relationships fr
  set status = case when accept_request then 'accepted' else 'declined' end,
      responded_at = statement_timestamp(),
      updated_at = statement_timestamp()
  where fr.id = relationship_id returning fr.* into result;
  return result;
end;
$$;

create or replace function public.cancel_friendship(relationship_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid();
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  update public.friend_relationships fr
  set status = 'cancelled', responded_at = statement_timestamp(), updated_at = statement_timestamp()
  where fr.id = relationship_id and fr.status = 'pending' and fr.requested_by = caller;
  if not found then raise exception using errcode = '42501', message = 'Only the requester may cancel a pending request'; end if;
end;
$$;

create or replace function public.remove_friendship(relationship_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare caller uuid := auth.uid();
begin
  if caller is null then raise exception using errcode = '28000', message = 'Authentication required'; end if;
  update public.friend_relationships fr
  set status = 'cancelled', responded_at = statement_timestamp(), updated_at = statement_timestamp()
  where fr.id = relationship_id
    and fr.status = 'accepted'
    and caller in (fr.user_low_id, fr.user_high_id);
  if not found then raise exception using errcode = '42501', message = 'Accepted friendship not found'; end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- RLS and privileges
-- -----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.profile_private_details enable row level security;
alter table public.profile_privacy enable row level security;
alter table public.gyms enable row level security;
alter table public.gym_memberships enable row level security;
alter table public.friend_relationships enable row level security;

drop policy if exists "profiles public read" on public.profiles;
drop policy if exists "profiles own update" on public.profiles;
drop policy if exists "profiles authenticated read" on public.profiles;
drop policy if exists "profiles owner update" on public.profiles;
create policy "profiles authenticated read" on public.profiles
  for select to authenticated using (public.can_view_profile(id));
create policy "profiles owner update" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "private details owner read" on public.profile_private_details
  for select to authenticated using (user_id = auth.uid());
create policy "private details owner update" on public.profile_private_details
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "privacy owner read" on public.profile_privacy
  for select to authenticated using (user_id = auth.uid());
create policy "privacy owner update" on public.profile_privacy
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "gyms authenticated read" on public.gyms
  for select to authenticated using (status <> 'archived');
create policy "memberships owner read" on public.gym_memberships
  for select to authenticated using (user_id = auth.uid());
create policy "friend relationships participant read" on public.friend_relationships
  for select to authenticated using (auth.uid() in (user_low_id, user_high_id));

-- Retained legacy data is inaccessible to API roles. It remains available to a
-- future reviewed migration that reconciles old lift gym IDs and audit history.
do $$
begin
  if to_regclass('public.gym_memberships_legacy_20260712') is not null then
    drop policy if exists "memberships public read" on public.gym_memberships_legacy_20260712;
    drop policy if exists "memberships own insert" on public.gym_memberships_legacy_20260712;
    drop policy if exists "memberships own delete" on public.gym_memberships_legacy_20260712;
    revoke all on public.gym_memberships_legacy_20260712 from anon, authenticated;
  end if;
  if to_regclass('public.friendships_legacy_20260712') is not null then
    drop policy if exists "friendships participant read" on public.friendships_legacy_20260712;
    drop policy if exists "friendships requester insert" on public.friendships_legacy_20260712;
    drop policy if exists "friendships participant update" on public.friendships_legacy_20260712;
    revoke all on public.friendships_legacy_20260712 from anon, authenticated;
  end if;
end;
$$;

revoke all on public.profiles from anon, authenticated;
revoke all on public.profile_private_details from anon, authenticated;
revoke all on public.profile_privacy from anon, authenticated;
revoke all on public.gyms from anon, authenticated;
revoke all on public.gym_memberships from anon, authenticated;
revoke all on public.friend_relationships from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, bio, avatar_path, onboarding_completed) on public.profiles to authenticated;
grant select on public.profile_private_details to authenticated;
grant update (
  birth_date, sex_category, preferred_unit, height_cm, city, region,
  country_code, years_experience, experience_level
) on public.profile_private_details to authenticated;
grant select on public.profile_privacy to authenticated;
grant update (
  profile_audience, age_band_audience, division_audience, bodyweight_audience,
  location_audience, gym_audience, friend_list_audience
) on public.profile_privacy to authenticated;
grant select on public.gyms, public.gym_memberships, public.friend_relationships to authenticated;

revoke execute on function public.create_profile_for_new_user() from public, anon, authenticated;
revoke execute on function public.set_server_updated_at() from public, anon, authenticated;
revoke execute on function public.protect_profile_authority() from public, anon, authenticated;
revoke execute on function public.enforce_gym_membership_limits() from public, anon, authenticated;
revoke execute on function public.are_friends(uuid, uuid) from public, anon;
revoke execute on function public.share_active_gym(uuid, uuid) from public, anon;
revoke execute on function public.can_view_profile_field(uuid, text) from public, anon;
revoke execute on function public.can_view_profile(uuid) from public, anon;
revoke execute on function public.age_band_from_birth_date(date) from public, anon;
revoke execute on function public.get_profile_card(uuid) from public, anon;
revoke execute on function public.claim_username(text) from public, anon;
revoke execute on function public.save_own_profile(
  text, text, text, date, text, numeric, text, text, text, smallint, text,
  text, text, text, text, text, text, boolean
) from public, anon;
revoke execute on function public.join_gym(uuid, boolean) from public, anon;
revoke execute on function public.leave_gym(uuid) from public, anon;
revoke execute on function public.set_primary_gym(uuid) from public, anon;
revoke execute on function public.request_friendship(uuid) from public, anon;
revoke execute on function public.respond_to_friendship(uuid, boolean) from public, anon;
revoke execute on function public.cancel_friendship(uuid) from public, anon;
revoke execute on function public.remove_friendship(uuid) from public, anon;

grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.share_active_gym(uuid, uuid) to authenticated;
grant execute on function public.can_view_profile_field(uuid, text) to authenticated;
grant execute on function public.can_view_profile(uuid) to authenticated;
grant execute on function public.age_band_from_birth_date(date) to authenticated;
grant execute on function public.get_profile_card(uuid) to authenticated;
grant execute on function public.claim_username(text) to authenticated;
grant execute on function public.save_own_profile(
  text, text, text, date, text, numeric, text, text, text, smallint, text,
  text, text, text, text, text, text, boolean
) to authenticated;
grant execute on function public.join_gym(uuid, boolean) to authenticated;
grant execute on function public.leave_gym(uuid) to authenticated;
grant execute on function public.set_primary_gym(uuid) to authenticated;
grant execute on function public.request_friendship(uuid) to authenticated;
grant execute on function public.respond_to_friendship(uuid, boolean) to authenticated;
grant execute on function public.cancel_friendship(uuid) to authenticated;
grant execute on function public.remove_friendship(uuid) to authenticated;

comment on table public.profile_private_details is
  'Owner-only profile data. Exact birth dates must never be exposed by public profile APIs.';
comment on table public.gym_memberships is
  'Canonical gym membership state. API clients mutate this table only through secured functions.';
comment on table public.friend_relationships is
  'One normalized row per user pair. API clients mutate status only through secured functions.';
