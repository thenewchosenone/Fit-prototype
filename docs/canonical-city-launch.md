# Canonical city launch data

Lift Rivals should save a canonical city, not free-form city text. The iOS app now searches `public.search_cities(...)` while the user types and saves `city_id` when a backend result is selected.

## Generate GeoNames import files

```bash
python3 scripts/import-geonames-cities.py --dataset cities1000 --out supabase/seed/geonames
```

Use `--dataset allCountries --min-population 0` only if you truly want every GeoNames populated place. For launch, `cities1000` is the recommended balance.

Optional focused launch import:

```bash
python3 scripts/import-geonames-cities.py --dataset cities1000 --countries US,CA,GB,IE,AU,NZ,ZA --out supabase/seed/geonames
```

## Import into Supabase

Apply the forward-only migration first:

```bash
supabase migration up
```

Then import generated CSVs from the generated folder:

```bash
cd supabase/seed/geonames
psql "$DATABASE_URL" -f import.sql
```

## Product rule

Users may type any spelling, but they can only save one of the canonical suggestions. When `city_id` is present, the database derives `city`, `region`, and `country_code` from `location_cities`.
