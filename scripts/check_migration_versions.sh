#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
migrations_dir="${1:-$ROOT/supabase/migrations}"

if [[ ! -d "$migrations_dir" ]]; then
  printf 'Migration directory not found: %s\n' "$migrations_dir" >&2
  exit 2
fi

duplicates="$({
  for migration in "$migrations_dir"/*.sql; do
    [[ -f "$migration" ]] || continue
    filename="${migration##*/}"
    version="${filename%%_*}"
    if [[ "$version" =~ ^[0-9]{12}$ ]]; then
      printf '%s\n' "$version"
    fi
  done
} | sort | uniq -d)"

if [[ -n "$duplicates" ]]; then
  printf 'Duplicate Supabase migration version(s) in %s:\n%s\n' "$migrations_dir" "$duplicates" >&2
  while IFS= read -r version; do
    for migration in "$migrations_dir"/"$version"_*.sql; do
      [[ -f "$migration" ]] && printf '  %s\n' "${migration##*/}" >&2
    done
  done <<< "$duplicates"
  exit 1
fi

printf 'Supabase migration versions are unique in %s.\n' "$migrations_dir"
