create table if not exists public.location_countries (
  code text primary key check (code = upper(code) and char_length(code) = 2),
  name text not null,
  geoname_id integer unique,
  created_at timestamptz not null default now()
);

create table if not exists public.location_regions (
  id uuid primary key default gen_random_uuid(),
  country_code text not null references public.location_countries(code) on delete cascade,
  code text not null,
  name text not null,
  geoname_id integer unique,
  created_at timestamptz not null default now(),
  unique(country_code, code),
  unique(country_code, name)
);

create table if not exists public.location_cities (
  id uuid primary key default gen_random_uuid(),
  country_code text not null references public.location_countries(code) on delete cascade,
  region_id uuid references public.location_regions(id) on delete set null,
  region_code text,
  name text not null,
  ascii_name text not null,
  search_name text generated always as (lower(coalesce(ascii_name, name))) stored,
  latitude numeric,
  longitude numeric,
  population integer,
  geoname_id integer unique,
  timezone text,
  created_at timestamptz not null default now(),
  unique(country_code, region_code, ascii_name, geoname_id)
);

create table if not exists public.location_city_aliases (
  city_id uuid not null references public.location_cities(id) on delete cascade,
  alias text not null,
  search_alias text generated always as (lower(alias)) stored,
  created_at timestamptz not null default now(),
  primary key(city_id, alias)
);

create index if not exists location_regions_country_name_idx on public.location_regions(country_code, name);
create index if not exists location_cities_country_region_search_idx on public.location_cities(country_code, region_code, search_name);
create index if not exists location_cities_population_idx on public.location_cities(population desc nulls last);
create index if not exists location_city_aliases_search_idx on public.location_city_aliases(search_alias);

alter table public.profile_private_details
  add column if not exists city_id uuid references public.location_cities(id) on delete set null;

create index if not exists profile_private_details_city_id_idx on public.profile_private_details(city_id);

alter table public.location_countries enable row level security;
alter table public.location_regions enable row level security;
alter table public.location_cities enable row level security;
alter table public.location_city_aliases enable row level security;

drop policy if exists "location countries public read" on public.location_countries;
drop policy if exists "location regions public read" on public.location_regions;
drop policy if exists "location cities public read" on public.location_cities;
drop policy if exists "location city aliases public read" on public.location_city_aliases;

create policy "location countries public read" on public.location_countries for select using (true);
create policy "location regions public read" on public.location_regions for select using (true);
create policy "location cities public read" on public.location_cities for select using (true);
create policy "location city aliases public read" on public.location_city_aliases for select using (true);

revoke all on public.location_countries from anon, authenticated;
revoke all on public.location_regions from anon, authenticated;
revoke all on public.location_cities from anon, authenticated;
revoke all on public.location_city_aliases from anon, authenticated;

grant select on public.location_countries, public.location_regions, public.location_cities, public.location_city_aliases to anon, authenticated;
grant update (city_id) on public.profile_private_details to authenticated;

create or replace function public.search_cities(
  country_code_filter text,
  region_filter text,
  search_query text,
  result_limit integer default 8
)
returns table(
  id uuid,
  city text,
  region text,
  country_code text,
  country_name text,
  population integer
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  with normalized as (
    select
      upper(nullif(btrim(country_code_filter), '')) as country_code_filter,
      lower(nullif(btrim(region_filter), '')) as region_filter,
      lower(nullif(btrim(search_query), '')) as search_query,
      least(greatest(coalesce(result_limit, 8), 1), 20) as result_limit
  ),
  matched as (
    select
      c.id,
      c.name as city,
      coalesce(r.name, c.region_code, '') as region,
      c.country_code,
      country.name as country_name,
      c.population,
      case
        when c.search_name = normalized.search_query then 0
        when c.search_name like normalized.search_query || '%' then 1
        when exists (
          select 1
          from public.location_city_aliases a
          where a.city_id = c.id
            and a.search_alias like normalized.search_query || '%'
        ) then 2
        else 3
      end as ranking
    from public.location_cities c
    join public.location_countries country on country.code = c.country_code
    left join public.location_regions r on r.id = c.region_id
    cross join normalized
    where normalized.search_query is not null
      and char_length(normalized.search_query) >= 2
      and c.country_code = normalized.country_code_filter
      and (
        normalized.region_filter is null
        or lower(coalesce(r.name, '')) = normalized.region_filter
        or lower(coalesce(c.region_code, '')) = normalized.region_filter
      )
      and (
        c.search_name like normalized.search_query || '%'
        or c.search_name like '%' || normalized.search_query || '%'
        or exists (
          select 1
          from public.location_city_aliases a
          where a.city_id = c.id
            and (
              a.search_alias like normalized.search_query || '%'
              or a.search_alias like '%' || normalized.search_query || '%'
            )
        )
      )
  )
  select id, city, region, country_code, country_name, population
  from matched
  order by ranking, population desc nulls last, city
  limit (select result_limit from normalized);
$$;

grant execute on function public.search_cities(text, text, text, integer) to anon, authenticated;

drop function if exists public.save_own_profile(
  text, text, text, date, text, numeric, text, text, text, smallint, text,
  text, text, text, text, text, text, boolean
);

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
  complete_onboarding boolean default false,
  new_city_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  caller uuid := auth.uid();
  canonical_city record;
  saved_city text;
  saved_region text;
  saved_country_code text;
begin
  if caller is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  if new_city_id is not null then
    select c.id, c.name, coalesce(r.name, c.region_code, '') as region, c.country_code
    into canonical_city
    from public.location_cities c
    left join public.location_regions r on r.id = c.region_id
    where c.id = new_city_id;

    if canonical_city.id is null then
      raise exception using errcode = '22023', message = 'Choose a valid city';
    end if;

    saved_city := canonical_city.name;
    saved_region := canonical_city.region;
    saved_country_code := canonical_city.country_code;
  else
    saved_city := nullif(btrim(new_city), '');
    saved_region := nullif(btrim(new_region), '');
    saved_country_code := nullif(upper(btrim(new_country_code)), '');
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
    city_id, city, region, country_code, years_experience, experience_level
  ) values (
    caller, new_birth_date, new_sex_category, new_preferred_unit, new_height_cm,
    new_city_id, saved_city, saved_region, saved_country_code, new_years_experience,
    new_experience_level
  )
  on conflict (user_id) do update set
    birth_date = excluded.birth_date,
    sex_category = excluded.sex_category,
    preferred_unit = excluded.preferred_unit,
    height_cm = excluded.height_cm,
    city_id = excluded.city_id,
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

grant execute on function public.save_own_profile(
  text, text, text, date, text, numeric, text, text, text, smallint, text,
  text, text, text, text, text, text, boolean, uuid
) to authenticated;
