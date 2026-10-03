create table if not exists public.location_countries (
  code text primary key check (code = upper(code) and char_length(code) = 2),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.location_regions (
  id uuid primary key default gen_random_uuid(),
  country_code text not null references public.location_countries(code) on delete cascade,
  code text not null,
  name text not null,
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
  population integer,
  created_at timestamptz not null default now(),
  unique(country_code, region_code, ascii_name)
);

create index if not exists location_cities_country_region_search_idx
  on public.location_cities(country_code, region_code, search_name);

alter table public.location_countries enable row level security;
alter table public.location_regions enable row level security;
alter table public.location_cities enable row level security;

drop policy if exists "location countries public read" on public.location_countries;
drop policy if exists "location regions public read" on public.location_regions;
drop policy if exists "location cities public read" on public.location_cities;

create policy "location countries public read" on public.location_countries for select using (true);
create policy "location regions public read" on public.location_regions for select using (true);
create policy "location cities public read" on public.location_cities for select using (true);

revoke all on public.location_countries, public.location_regions, public.location_cities from anon, authenticated;
grant select on public.location_countries, public.location_regions, public.location_cities to anon, authenticated;

insert into public.location_countries(code, name)
values ('US', 'United States')
on conflict (code) do nothing;

insert into public.location_regions(country_code, code, name)
values ('US', 'FL', 'Florida')
on conflict (country_code, code) do update set name = excluded.name;

insert into public.location_cities(country_code, region_id, region_code, name, ascii_name)
select 'US', r.id, 'FL', city.name, city.name
from public.location_regions r
cross join (values ('Cutler Bay'), ('Homestead')) as city(name)
where r.country_code = 'US' and r.code = 'FL'
on conflict (country_code, region_code, ascii_name) do nothing;

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
  select c.id,
         c.name,
         r.name,
         c.country_code,
         country.name,
         c.population
  from public.location_cities c
  join public.location_countries country on country.code = c.country_code
  left join public.location_regions r
    on r.country_code = c.country_code and r.code = c.region_code
  where c.country_code = upper(nullif(btrim(country_code_filter), ''))
    and (
      nullif(btrim(region_filter), '') is null
      or lower(coalesce(r.name, c.region_code, '')) = lower(btrim(region_filter))
    )
    and lower(c.search_name) like '%' || lower(btrim(search_query)) || '%'
  order by c.population desc nulls last, c.name
  limit least(greatest(coalesce(result_limit, 8), 1), 20);
$$;

grant execute on function public.search_cities(text, text, text, integer) to anon, authenticated;
