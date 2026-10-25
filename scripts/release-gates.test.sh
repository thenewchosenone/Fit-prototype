#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/liftrank-release-gates-test.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    printf 'Expected to find %s in %s\n' "$expected" "$file" >&2
    return 1
  fi
}

metadata_fixture="$TEMP_ROOT/app-store-launch-metadata.md"
cp "$ROOT/docs/app-store-launch-metadata.md" "$metadata_fixture"
LIFTRANK_LAUNCH_METADATA_PATH="$metadata_fixture" "$ROOT/scripts/check_launch_metadata.sh" >"$TEMP_ROOT/metadata-valid.output"
assert_contains "$TEMP_ROOT/metadata-valid.output" 'Launch metadata gate passed.'
sed '/^- Support:/d' "$metadata_fixture" > "$TEMP_ROOT/metadata-missing-support.md"
if LIFTRANK_LAUNCH_METADATA_PATH="$TEMP_ROOT/metadata-missing-support.md" "$ROOT/scripts/check_launch_metadata.sh" >"$TEMP_ROOT/metadata-missing-support.output"; then
  printf 'Launch metadata gate accepted a handoff without its support URL.\n' >&2
  exit 1
fi
assert_contains "$TEMP_ROOT/metadata-missing-support.output" 'missing: - Support:'

migrations_fixture="$TEMP_ROOT/migrations"
mkdir -p "$migrations_fixture"
touch "$migrations_fixture/202610190001_alpha.sql" "$migrations_fixture/202610190002_beta.sql"
"$ROOT/scripts/check_migration_versions.sh" "$migrations_fixture" >/dev/null
touch "$migrations_fixture/202610190001_collision.sql"
if "$ROOT/scripts/check_migration_versions.sh" "$migrations_fixture" >"$TEMP_ROOT/migration-check.output" 2>&1; then
  printf 'Migration version check accepted duplicate versions.\n' >&2
  exit 1
fi
assert_contains "$TEMP_ROOT/migration-check.output" '202610190001'
assert_contains "$TEMP_ROOT/migration-check.output" '202610190001_alpha.sql'
assert_contains "$TEMP_ROOT/migration-check.output" '202610190001_collision.sql'

run_gate() {
  local run_id="$1"
  local path="$2"
  local strict="$3"
  local web="$4"
  local ios="$5"
  local backend="$6"
  local output="$TEMP_ROOT/$run_id.output"
  local status=0

  env -u APNS_TEAM_ID -u APNS_KEY_ID -u APNS_PRIVATE_KEY -u APNS_BUNDLE_ID \
    -u NOTIFICATION_DELIVERY_SECRET -u SMTP_HOST -u SMTP_PORT -u SMTP_USER \
    -u SMTP_PASSWORD -u SMTP_SENDER_NAME -u SMTP_SENDER_EMAIL \
    PATH="$path" \
    LIFTRANK_RELEASE_RUN_ID="$run_id" \
    LIFTRANK_RELEASE_REPORT_DIR="$TEMP_ROOT/$run_id" \
    RELEASE_GATES_STRICT="$strict" \
    RUN_WEB_FRONTEND_GATES="$web" \
    RUN_IOS_GATES="$ios" \
    RUN_BACKEND_GATES="$backend" \
    "$ROOT/scripts/release-gates.sh" >"$output" 2>&1 || status=$?

  printf '%s\n' "$status" > "$TEMP_ROOT/$run_id.status"
}

for strict in 0 1; do
  run_id="disabled-$strict"
  run_gate "$run_id" "$PATH" "$strict" 0 0 0
  if [[ "$(<"$TEMP_ROOT/$run_id.status")" -eq 0 ]]; then
    printf 'Release gate passed with all required groups disabled (strict=%s).\n' "$strict" >&2
    exit 1
  fi
  assert_contains "$TEMP_ROOT/$run_id/summary.txt" 'required_gate_group.web_frontend|fail|'
  assert_contains "$TEMP_ROOT/$run_id/summary.txt" 'required_gate_group.ios|fail|'
  assert_contains "$TEMP_ROOT/$run_id/summary.txt" 'required_gate_group.backend|fail|'
  assert_contains "$TEMP_ROOT/$run_id/release-evidence.md" '- status: BLOCKED'
  if [[ "$strict" -eq 1 ]]; then
    assert_contains "$TEMP_ROOT/$run_id/summary.txt" 'publish_readiness.services|fail|'
  else
    assert_contains "$TEMP_ROOT/$run_id/summary.txt" 'publish_readiness.services|pass|'
  fi
done

test_bin="$TEMP_ROOT/bin"
mkdir -p "$test_bin"
for source in /bin/* /usr/bin/*; do
  [[ -x "$source" ]] || continue
  [[ "${source##*/}" == xcodebuild ]] && continue
  ln -sf "$source" "$test_bin/${source##*/}"
done
if PATH="$test_bin" command -v xcodebuild >/dev/null 2>&1; then
  printf 'Test PATH unexpectedly exposes xcodebuild.\n' >&2
  exit 1
fi

run_gate skipped-ios "$test_bin" 0 0 1 0
if [[ "$(<"$TEMP_ROOT/skipped-ios.status")" -eq 0 ]]; then
  printf 'Release gate passed with required iOS checks skipped.\n' >&2
  exit 1
fi
assert_contains "$TEMP_ROOT/skipped-ios/summary.txt" 'ios.unit.minimum_supported_ios|skip|'
assert_contains "$TEMP_ROOT/skipped-ios/summary.txt" 'ios.release_unsigned_simulator_build|skip|'
assert_contains "$TEMP_ROOT/skipped-ios/release-evidence.md" '- status: BLOCKED'
assert_contains "$TEMP_ROOT/skipped-ios.output" 'required gates failed or were skipped'

printf 'Release gate regression checks passed.\n'
