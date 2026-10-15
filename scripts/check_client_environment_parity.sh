#!/bin/zsh

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
website_root="${1:-${LIFTRANK_WEBSITE_DIR:-}}"

if [[ -z "$website_root" ]]; then
  print -u2 "Usage: $0 /absolute/path/to/lift-rivals-website"
  exit 2
fi

website_config="$website_root/supabase-config.js"
if [[ ! -f "$website_config" ]]; then
  print -u2 "Website Supabase configuration was not found at $website_config"
  exit 2
fi

website_url="$(awk -F '"' '/LIFTRANK_SUPABASE_URL/ { print $2; exit }' "$website_config")"
website_key="$(awk -F '"' '/LIFTRANK_SUPABASE_ANON_KEY/ { print $2; exit }' "$website_config")"

if [[ -z "$website_url" || -z "$website_key" ]]; then
  print -u2 "Website production Supabase URL or publishable key is missing."
  exit 1
fi

release_settings="$(xcodebuild -project "$repository_root/LiftRank.xcodeproj" -scheme LiftRank -configuration Release -showBuildSettings 2>/dev/null)"
debug_settings="$(xcodebuild -project "$repository_root/LiftRank.xcodeproj" -scheme LiftRank -configuration Debug -showBuildSettings 2>/dev/null)"

setting_value() {
  local settings="$1"
  local name="$2"
  print -r -- "$settings" | awk -F ' = ' -v key="$name" '$1 ~ "^[[:space:]]*" key "$" { print $2; exit }'
}

release_url="$(setting_value "$release_settings" LIFTRANK_SUPABASE_URL)"
release_key="$(setting_value "$release_settings" LIFTRANK_SUPABASE_ANON_KEY)"
debug_url="$(setting_value "$debug_settings" LIFTRANK_SUPABASE_URL)"

if [[ "$release_url" != "$website_url" ]]; then
  print -u2 "Release app and website point at different Supabase projects."
  exit 1
fi

if [[ "$release_key" != "$website_key" ]]; then
  print -u2 "Release app and website use different production publishable keys."
  exit 1
fi

if [[ "$debug_url" == "$release_url" ]]; then
  print -u2 "Debug and Release unexpectedly share one Supabase project; staging isolation is missing."
  exit 1
fi

if [[ "$release_url" != https://*.supabase.co || "$debug_url" != https://*.supabase.co ]]; then
  print -u2 "A configured Supabase URL is malformed."
  exit 1
fi

print -r -- "Client environment parity passed."
print -r -- "Release app and website share production project: ${release_url#https://}"
print -r -- "Debug remains isolated on staging project: ${debug_url#https://}"
