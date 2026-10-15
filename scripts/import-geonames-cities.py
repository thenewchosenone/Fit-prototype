#!/usr/bin/env python3
"""
Build canonical location CSVs from GeoNames for LiftRank launch.

Default source is GeoNames cities1000, which is broad enough for launch without
shipping every tiny locality. Use --dataset allCountries for exhaustive import.

Example:
  python3 scripts/import-geonames-cities.py --dataset cities1000 --out supabase/seed/geonames

Then import with psql or Supabase SQL using the generated COPY commands file:
  psql "$DATABASE_URL" -f supabase/seed/geonames/import.sql
"""

from __future__ import annotations

import argparse
import csv
import io
import sys
import urllib.request
import zipfile
from pathlib import Path


GEONAMES_BASE = "https://download.geonames.org/export/dump"
CITY_FEATURE_CLASS = "P"


def download_text(url: str) -> str:
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read().decode("utf-8")


def download_zip_member(url: str, member_name: str) -> io.TextIOWrapper:
    with urllib.request.urlopen(url, timeout=300) as response:
        data = response.read()
    archive = zipfile.ZipFile(io.BytesIO(data))
    return io.TextIOWrapper(archive.open(member_name), encoding="utf-8")


def load_countries() -> dict[str, tuple[str, int | None]]:
    text = download_text(f"{GEONAMES_BASE}/countryInfo.txt")
    countries: dict[str, tuple[str, int | None]] = {}
    for row in csv.reader((line for line in text.splitlines() if line and not line.startswith("#")), delimiter="\t"):
        if len(row) < 17:
            continue
        iso = row[0]
        name = row[4]
        geoname_id = int(row[16]) if row[16].isdigit() else None
        countries[iso] = (name, geoname_id)
    return countries


def load_regions() -> dict[tuple[str, str], tuple[str, int | None]]:
    text = download_text(f"{GEONAMES_BASE}/admin1CodesASCII.txt")
    regions: dict[tuple[str, str], tuple[str, int | None]] = {}
    for row in csv.reader(text.splitlines(), delimiter="\t"):
        if len(row) < 4 or "." not in row[0]:
            continue
        country_code, region_code = row[0].split(".", 1)
        geoname_id = int(row[3]) if row[3].isdigit() else None
        regions[(country_code, region_code)] = (row[1], geoname_id)
    return regions


def normalize_dataset_name(dataset: str) -> str:
    dataset = dataset.strip()
    if dataset.endswith(".zip"):
        dataset = dataset[:-4]
    return dataset


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", default="cities1000", help="GeoNames dataset name: cities1000, cities5000, cities15000, or allCountries")
    parser.add_argument("--out", default="supabase/seed/geonames", help="Output directory for generated CSVs and import.sql")
    parser.add_argument("--min-population", type=int, default=1000, help="Minimum city population to include")
    parser.add_argument("--countries", default="", help="Optional comma-separated ISO country filter, e.g. US,CA,GB")
    args = parser.parse_args()

    dataset = normalize_dataset_name(args.dataset)
    out_dir = Path(args.out)
    country_filter = {code.strip().upper() for code in args.countries.split(",") if code.strip()}

    countries = load_countries()
    regions = load_regions()
    city_member = f"{dataset}.txt"
    city_file = download_zip_member(f"{GEONAMES_BASE}/{dataset}.zip", city_member)

    used_countries: set[str] = set()
    used_regions: set[tuple[str, str]] = set()
    city_rows: list[dict[str, object]] = []

    for row in csv.reader(city_file, delimiter="\t"):
        if len(row) < 19:
            continue
        geoname_id = int(row[0])
        name = row[1]
        ascii_name = row[2] or name
        latitude = row[4]
        longitude = row[5]
        feature_class = row[6]
        country_code = row[8]
        region_code = row[10]
        population = int(row[14] or 0)
        timezone = row[17]

        if feature_class != CITY_FEATURE_CLASS:
            continue
        if country_filter and country_code not in country_filter:
            continue
        if population < args.min_population:
            continue
        if country_code not in countries:
            continue

        used_countries.add(country_code)
        if region_code:
            used_regions.add((country_code, region_code))
        city_rows.append({
            "geoname_id": geoname_id,
            "country_code": country_code,
            "region_code": region_code,
            "name": name,
            "ascii_name": ascii_name,
            "latitude": latitude,
            "longitude": longitude,
            "population": population,
            "timezone": timezone,
        })

    country_rows = [
        {"code": code, "name": countries[code][0], "geoname_id": countries[code][1] or ""}
        for code in sorted(used_countries)
    ]
    region_rows = [
        {
            "country_code": country_code,
            "code": region_code,
            "name": regions.get((country_code, region_code), (region_code, None))[0],
            "geoname_id": regions.get((country_code, region_code), ("", None))[1] or "",
        }
        for country_code, region_code in sorted(used_regions)
    ]

    write_csv(out_dir / "location_countries.csv", ["code", "name", "geoname_id"], country_rows)
    write_csv(out_dir / "location_regions.csv", ["country_code", "code", "name", "geoname_id"], region_rows)
    write_csv(out_dir / "location_cities.csv", ["geoname_id", "country_code", "region_code", "name", "ascii_name", "latitude", "longitude", "population", "timezone"], city_rows)

    (out_dir / "import.sql").write_text(
        """\\copy public.location_countries(code, name, geoname_id) from 'location_countries.csv' with (format csv, header true)
\\copy public.location_regions(country_code, code, name, geoname_id) from 'location_regions.csv' with (format csv, header true)
\\copy public.location_cities(geoname_id, country_code, region_code, name, ascii_name, latitude, longitude, population, timezone) from 'location_cities.csv' with (format csv, header true)

update public.location_cities c
set region_id = r.id
from public.location_regions r
where r.country_code = c.country_code and r.code = c.region_code;
""",
        encoding="utf-8",
    )

    print(f"Wrote {len(country_rows)} countries, {len(region_rows)} regions, {len(city_rows)} cities to {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
