#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
METADATA="$ROOT/docs/app-store-launch-metadata.md"
MIGRATION="$ROOT/supabase/migrations/202607240002_profile_avatars.sql"
CONTRACT="$ROOT/supabase/tests/202607240002_profile_avatars.test.sql"

failures=0
fail() { printf '[FAIL] %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf '[PASS] %s\n' "$1"; }

if [[ ! -f "$METADATA" ]]; then
  fail "App Store metadata handoff is missing."
elif rg -q 'REQUIRED_[A-Z_]+' "$METADATA"; then
  fail "App Store metadata still contains REQUIRED_* placeholders."
else
  pass "App Store metadata contains no placeholders."
fi

if [[ -f "$MIGRATION" && -f "$CONTRACT" ]]; then
  pass "Profile-avatar migration and pgTAP contract are present."
else
  fail "Profile-avatar migration or pgTAP contract is missing."
fi

if [[ "$failures" -gt 0 ]]; then
  printf 'Launch metadata gate failed with %d issue(s).\n' "$failures"
  exit 1
fi

printf 'Launch metadata gate passed.\n'
