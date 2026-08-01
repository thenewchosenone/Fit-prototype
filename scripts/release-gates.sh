#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
run_id="${LIFTRANK_RELEASE_RUN_ID:-$(date +%Y-%m-%d_%H-%M-%S)}"
report_dir="${LIFTRANK_RELEASE_REPORT_DIR:-$ROOT/release-evidence/$run_id}"
mkdir -p "$report_dir"
required_scheme_file="$ROOT/LiftRank.xcodeproj/xcshareddata/xcschemes/LiftRank.xcscheme"
required_scheme_name="LiftRank"
services_check_script="$ROOT/scripts/check_publish_readiness_services.sh"
metadata_check_script="$ROOT/scripts/check_launch_metadata.sh"

evidence_file="$report_dir/release-evidence.md"
summary_file="$report_dir/summary.txt"
source_state_file="$report_dir/source-state.txt"

run_web_frontend="${RUN_WEB_FRONTEND_GATES:-1}"
run_ios="${RUN_IOS_GATES:-1}"
run_backend="${RUN_BACKEND_GATES:-1}"
strict_mode="${RELEASE_GATES_STRICT:-0}"
command_timeout="${LIFTRANK_RELEASE_COMMAND_TIMEOUT:-1800}"

pass_count=0
fail_count=0
skip_count=0

command_exists() {
  local command_name="$1"

  if [[ -x "$command_name" ]]; then
    return 0
  fi

  command -v "$command_name" >/dev/null 2>&1
}

capture_source_state() {
  source_revision="unavailable"
  source_tree_state="unavailable"

  if command_exists git && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    source_revision="$(git -C "$ROOT" rev-parse HEAD)"
    git -C "$ROOT" status --short > "$source_state_file"
    if [[ -s "$source_state_file" ]]; then
      source_tree_state="dirty"
    else
      source_tree_state="clean"
      printf 'Working tree clean.\n' > "$source_state_file"
    fi
  else
    printf 'Git source metadata unavailable.\n' > "$source_state_file"
  fi
}

capture_status() {
  local status="$1"
  local label="$2"
  local log_name="$3"
  local step_log="$report_dir/$log_name.log"

  printf '%s|%s|%s\n' "$label" "$status" "$step_log" >> "$summary_file"

  case "$status" in
    pass) pass_count=$((pass_count + 1)) ;;
    fail) fail_count=$((fail_count + 1)) ;;
    skip) skip_count=$((skip_count + 1)) ;;
  esac
}

log() {
  printf '%s\n' "$1"
  printf '%s\n' "$1" >> "$evidence_file"
}

run_step() {
  local label="$1"
  local log_name="$2"
  shift 2

  local status="pass"
  local step_log="$report_dir/$log_name.log"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local rc=0

  log "\n[$timestamp] START: $label"

  set +e
  if command_exists timeout; then
    timeout "$command_timeout" "$@" 2>&1 | tee "$step_log"
  else
    "$@" 2>&1 | tee "$step_log"
  fi
  rc=${PIPESTATUS[0]}
  set -e

  if [ "$rc" -ne 0 ]; then
    status="fail"
    log "[$timestamp] FAIL: $label (log: $step_log)"
  else
    log "[$timestamp] PASS: $label (log: $step_log)"
  fi

  capture_status "$status" "$label" "$log_name"

  if [ "$status" = "fail" ] && [ "$strict_mode" -eq 1 ]; then
    log "Strict mode enabled: continuing execution and collecting evidence."
  fi
}

run_optional() {
  local label="$1"
  local log_name="$2"
  local dependency="$3"
  shift 3

  local step_log="$report_dir/$log_name.log"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  if ! command_exists "$dependency"; then
    printf 'Dependency unavailable: %s\n' "$dependency" > "$step_log"
    log "[$timestamp] SKIP: $label (dependency unavailable: $dependency)"
    capture_status "skip" "$label" "$log_name"
    return 0
  fi

  run_step "$label" "$log_name" "$dependency" "$@"
}

verify_baseline_scheme() {
  local log_name="required-scheme"
  local step_log="$report_dir/$log_name.log"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  if [ ! -f "$required_scheme_file" ]; then
    cat > "$step_log" <<EOF
Required scheme file not found:
  $required_scheme_file
EOF
    log "[$timestamp] FAIL: required baseline iOS scheme missing: $required_scheme_file"
    capture_status fail "required_scheme" "$log_name"
    return
  fi

  if ! grep -q "<Scheme" "$required_scheme_file"; then
    cat > "$step_log" <<EOF
Scheme file exists but appears invalid:
  $required_scheme_file
EOF
    log "[$timestamp] FAIL: invalid baseline iOS scheme file: $required_scheme_file"
    capture_status fail "required_scheme" "$log_name"
    return
  fi

  echo "Validated baseline scheme file: $required_scheme_file" > "$step_log"
  log "[$timestamp] PASS: baseline iOS scheme present: $required_scheme_name"
  capture_status pass "required_scheme" "$log_name"
}

run_xcode_test() {
  local label="$1"
  local destination="$2"
  local target="$3"

  if ! command_exists xcodebuild; then
    local step_log="$report_dir/$(printf '%s' "$label" | tr ' ' '_').log"
    printf 'Dependency unavailable: xcodebuild\n' > "$step_log"
    log "Skipping $label: xcodebuild not available"
    capture_status "skip" "$label" "$(printf '%s' "$label" | tr ' ' '_')"
    return 0
  fi

  local command=(xcodebuild -project LiftRank.xcodeproj -scheme LiftRank -configuration Debug -enableCodeCoverage NO test -destination "$destination" "-only-testing:${target}")
  run_step "$label" "$(printf '%s' "$label" | tr ' ' '_')" "${command[@]}"
}

run_xcode_archive_smoke() {
  local label="$1"
  local destination="$2"

  if ! command_exists xcodebuild; then
    local step_log="$report_dir/$(printf '%s' "$label" | tr ' ' '_').log"
    printf 'Dependency unavailable: xcodebuild\n' > "$step_log"
    log "Skipping $label: xcodebuild not available"
    capture_status "skip" "$label" "$(printf '%s' "$label" | tr ' ' '_')"
    return 0
  fi

  local command=(xcodebuild -project LiftRank.xcodeproj -scheme LiftRank -configuration Release -destination "$destination" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build)
  run_step "$label" "$(printf '%s' "$label" | tr ' ' '_')" "${command[@]}"
}

append_summary() {
  {
    echo
    echo "## Gate summary"
    echo "- pass: $pass_count"
    echo "- fail: $fail_count"
    echo "- skip: $skip_count"
    if [ "$fail_count" -gt 0 ]; then
      echo "- status: BLOCKED"
    else
      echo "- status: PASS"
    fi
  } >> "$evidence_file"
}

printf 'step|status|log\n' > "$summary_file"
capture_source_state

cat > "$evidence_file" <<EVIDENCE
# LiftRank publish-readiness evidence

Run ID: $run_id
Run date: $(date)
Working directory: $ROOT

## Environment

- Web gates enabled: $run_web_frontend
- iOS gates enabled: $run_ios
- Backend gates enabled: $run_backend
- Strict mode: $strict_mode
- Timeout per step (s): $command_timeout

## Source state

- Revision: $source_revision
- Working tree: $source_tree_state
- Full status: $source_state_file
EVIDENCE

verify_baseline_scheme

if [ -x "$services_check_script" ]; then
  run_step "publish_readiness.services" "ios-services-readiness" "$services_check_script"
elif [ -f "$services_check_script" ]; then
  log "Service check script is not executable; attempting fallback run via bash."
  run_step "publish_readiness.services" "ios-services-readiness" bash "$services_check_script"
else
  run_step "publish_readiness.services" "ios-services-readiness" bash ./scripts/check_publish_readiness_services.sh
fi

if [ -x "$metadata_check_script" ]; then
  run_step "publish_readiness.app_store_metadata" "app-store-metadata-readiness" "$metadata_check_script"
else
  run_step "publish_readiness.app_store_metadata" "app-store-metadata-readiness" bash "$metadata_check_script"
fi

if [ "$run_web_frontend" -eq 1 ]; then
  run_step "web.unit" "web-unit" pnpm test
  run_step "web.e2e" "web-e2e" pnpm test:e2e
  run_step "web.e2e_demo" "web-e2e-demo" pnpm test:demo
  run_step "web.performance" "web-perf" pnpm perf
  run_step "web.build" "web-build" pnpm build
  run_step "web.release_smoke_routes" "web-route-smoke" pnpm test:release-routes
else
  log "Web gates disabled via RUN_WEB_FRONTEND_GATES=0"
fi

if [ "$run_ios" -eq 1 ]; then
  old_destination="${IOS_OLDEST_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 8,OS=latest}"
  new_destination="${IOS_LATEST_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest}"

  run_xcode_test "ios.unit.oldest_ios" "$old_destination" LiftRankTests
  run_xcode_test "ios.unit.latest_ios" "$new_destination" LiftRankTests
  run_xcode_test "ios.ui.oldest_ios" "$old_destination" LiftRankUITests
  run_xcode_test "ios.ui.latest_ios" "$new_destination" LiftRankUITests
  run_xcode_archive_smoke "ios.release_signing_validation" "$new_destination"
else
  log "iOS gates disabled via RUN_IOS_GATES=0"
fi

if [ "$run_backend" -eq 1 ]; then
  run_optional "backend.pg_tap_suite" "backend-pgtap" ./scripts/test_backend_foundation.sh
else
  log "Backend gates disabled via RUN_BACKEND_GATES=0"
fi

append_summary
log "\nGate evidence written to: $evidence_file"
log "Machine-readable summary: $summary_file"

if [ "$fail_count" -gt 0 ]; then
  if [ "$strict_mode" -eq 1 ]; then
    echo "FAIL: one or more required gates failed. Review $summary_file for details." | tee -a "$evidence_file"
  else
    echo "FAIL: one or more required gates failed in non-strict mode. Review $summary_file for details." | tee -a "$evidence_file"
  fi
  exit 1
fi

echo "PASS: all automated gates completed." | tee -a "$evidence_file"
