begin;

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
        (
          exists (
            select 1
            from public.location_city_aliases exact_alias
            where exact_alias.search_alias = normalized.search_query
          )
          and exists (
            select 1
            from public.location_city_aliases city_exact_alias
            where city_exact_alias.city_id = c.id
              and city_exact_alias.search_alias = normalized.search_query
          )
        )
        or (
          not exists (
            select 1
            from public.location_city_aliases exact_alias
            where exact_alias.search_alias = normalized.search_query
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
      )
  )
  select id, city, region, country_code, country_name, population
  from matched
  order by ranking, population desc nulls last, city
  limit (select result_limit from normalized);
$$;

revoke all on function public.search_cities(text, text, text, integer) from public;
grant execute on function public.search_cities(text, text, text, integer) to anon, authenticated;

commit;
