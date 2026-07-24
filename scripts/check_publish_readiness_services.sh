#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENTITLEMENTS="$ROOT/LiftRankApp/LiftRank.entitlements"
PROJECT_PLIST="$ROOT/LiftRankApp/Info.plist"
IOS_UI="$ROOT/LiftRankApp/Views/MainTabView.swift"
PGBUILD="$ROOT/LiftRank.xcodeproj/project.pcbproj"
if [ ! -f "$ROOT/LiftRank.xcodeproj/project.pbxproj" ]; then
  PGBUILD="$ROOT/LiftRank.xcodeproj/project.pbxproj"
fi
if [ ! -f "$PGBUILD" ]; then
  PGBUILD="$ROOT/LiftRank.xcodeproj/project.pbxproj"
fi
STRICT_MODE="${LIFTRANK_SERVICE_CHECK_STRICT:-0}"

failures=0
warns=0

log() { printf '%s\n' "$1"; }
status() { printf '\n%s\n' "$1"; }
pass() { log "[PASS] $1"; }
warn() { warns=$((warns+1)); log "[WARN] $1"; }
fail() { failures=$((failures+1)); log "[FAIL] $1"; }

status "LiftRank Step #1 readiness checks (Apple + APNs + mail)"

if [ -f "$ENTITLEMENTS" ]; then
  if grep -q "com\.apple\.developer\.applesignin" "$ENTITLEMENTS" \
     && grep -q "aps-environment" "$ENTITLEMENTS"; then
    pass "Entitlements include Apple Sign In and APNs entries."
  else
    fail "Missing required entitlement entries in LiftRank.entitlements."
  fi
else
  fail "Missing entitlements file: $ENTITLEMENTS"
fi

if [ -f "$PROJECT_PLIST" ] && grep -q "<string>liftrank</string>" "$PROJECT_PLIST"; then
  pass "Custom URL scheme 'liftrank' is configured in Info.plist."
else
  fail "Missing custom URL scheme 'liftrank' in Info.plist."
fi

if rg -q "auth-callback" \
  "$ROOT/LiftRankApp/Services/SupabaseServiceSupport.swift" \
  "$ROOT/LiftRankApp/Services/SupabaseServices.swift" 2>/dev/null; then
  pass "Auth callback URL in client code is set to liftrank://auth-callback."
else
  fail "Auth callback URL is missing in client authentication service."
fi

if [ -f "$IOS_UI" ]; then
  if grep -q "SignInWithAppleButton" "$IOS_UI" && grep -q "appleNonce" "$IOS_UI"; then
    pass "Authentication UI exposes Sign in with Apple with nonce wiring."
  else
    fail "Sign in with Apple code path is incomplete in MainTabView."
  fi
else
  fail "Could not inspect MainTabView.swift."
fi

if [ -f "$PGBUILD" ]; then
  if grep -q "APS_ENVIRONMENT" "$PGBUILD"; then
    pass "Xcode project build settings define APS_ENVIRONMENT (per configuration)."
  else
    warn "APS_ENVIRONMENT is not present in project build settings; add Debug/Release values before archive."
  fi
else
  fail "Missing project.pbxproj file."
fi

missing_vars=()
for name in APNS_TEAM_ID APNS_KEY_ID APNS_PRIVATE_KEY APNS_BUNDLE_ID; do
  if [ -z "${!name:-}" ]; then
    missing_vars+=("$name")
  fi
done
if (( ${#missing_vars[@]} == 0 )); then
  pass "APNs runtime variables are available in current shell."
else
  warn "APNs runtime variables not set in shell (${missing_vars[*]}). Configure these in production Edge Function secrets and capture evidence from staging/production function logs."
fi

if [ -z "${NOTIFICATION_DELIVERY_SECRET:-}" ]; then
  warn "NOTIFICATION_DELIVERY_SECRET is not set locally; keep it server-side only and verify via function logs."
else
  pass "NOTIFICATION_DELIVERY_SECRET exists in shell (do not reuse in client code)."
fi

# SMTP verification is environment-specific and must be confirmed in Supabase Auth settings.
if [ -n "${SMTP_HOST:-}" ] || [ -n "${SMTP_PORT:-}" ] || [ -n "${SMTP_USER:-}" ] || [ -n "${SMTP_PASSWORD:-}" ] || [ -n "${SMTP_SENDER_NAME:-}" ] || [ -n "${SMTP_SENDER_EMAIL:-}" ]; then
  if [ -n "${SMTP_HOST:-}" ] && [ -n "${SMTP_PORT:-}" ] && [ -n "${SMTP_USER:-}" ] && [ -n "${SMTP_PASSWORD:-}" ] && [ -n "${SMTP_SENDER_NAME:-}" ] && [ -n "${SMTP_SENDER_EMAIL:-}" ]; then
    pass "SMTP variables are present in current shell."
  else
    warn "Partial SMTP variables found; do not pass mailer verification with partial config."
  fi
else
  warn "SMTP credentials are not provided locally; validate production Auth email provider in Supabase dashboard and run load test."
fi

status "\nNext manual Step #1 evidence actions:"
log "1) Open Apple Developer -> Identifiers -> com.liftrank.app and confirm:"
log "   - Sign in with Apple entitlement is enabled"
log "   - App ID is associated with current bundle ID and Team ID 32TGWTQNP8"
log "2) Open App Store Connect -> Certificates, Identifiers & Profiles and confirm:"
log "   - Production push profile installed and matches Release configuration"
log "   - App ID has Notifications enabled"
log "3) In Xcode: open Signing & Capabilities and confirm both Sign in with Apple and Push Notifications are checked."
log "4) In Supabase production project, set function secrets for APNs and run a signed push smoke:"
log "   - APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY, APNS_BUNDLE_ID, NOTIFICATION_DELIVERY_SECRET"
log "   - Trigger send-notifications with a staged user and confirm APNs response status 200 and delivery timestamp update"
log "5) In Supabase production Auth settings, confirm custom SMTP is connected; send 100 recovery/sign-up emails and verify throttling/throughput."

if (( failures > 0 )); then
  status "\nResult: BLOCKED. Resolve the failed items before continue."
  exit 1
fi

if (( warns > 0 )); then
  if [ "$STRICT_MODE" = "1" ]; then
    status "\nResult: WARNINGS -> strict mode enabled; treat warnings as blocking."
    exit 1
  fi
  status "\nResult: READY to continue with manual verification items above."
else
  status "\nResult: READY"
fi
