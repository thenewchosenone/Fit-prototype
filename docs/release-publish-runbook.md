# Lift Rivals Publish Readiness Runbook

_Last updated: July 23, 2026_

## 1) Release track and ownership (weekly cadence)

Run a publish dry run every Monday before any new release branch freeze.

- **Release Lead**: gate orchestration, evidence bundle, freeze/release notes
- **iOS QA Lead**: simulator/device matrix, UI pass, packaging
- **Web QA Lead**: web/build/perf/e2e smoke and auth-route checks
- **Backend & Security Lead**: SQL/RLS/security checks, privacy/compliance gates
- **Ops/Tools Lead**: App Store Connect staging, cert/provisioning, APNs/audit artifacts

## 2) Standard release branch flow

1. Freeze features on current integration branch
2. Run local release gates:
   - `./scripts/release-gates.sh`
3. Push release branch and run CI on matching environments
4. Open evidence bundle and sign-off checklist
5. Run two-account staging rehearsal with real accounts (manual)
6. Run physical-device pass and TestFlight upload verification

## 3) Automated gate command set

### 3a) Service readiness preflight (Step #1)

Run before local gates each release cycle:

- `./scripts/check_publish_readiness_services.sh`

This script validates in-repo configuration for:
- Apple Sign in with Apple entitlement wiring
- APNs entitlement and environment settings
- auth callback path handling
- production mail/notification function prerequisites (requires manual confirmation where secrets are intentionally environment-only)

When run via `./scripts/release-gates.sh`, the output is captured as:
- `release-evidence/<RUN_ID>/ios-services-readiness.log`
- `release-evidence/<RUN_ID>/release-evidence.md` (summary entry)

If `LIFTRANK_SERVICE_CHECK_STRICT=1`, warning-level findings will fail the script.

### Baseline web commands (required)

- `pnpm test`
- `pnpm test:e2e`
- `pnpm test:demo`
- `pnpm perf`
- `pnpm build`
- `pnpm test:release-routes`

### iOS gates (best-effort local)

1. Unit suite on oldest supported iOS simulator
2. Unit suite on latest supported iOS simulator
3. UI suite on oldest supported iOS simulator
4. UI suite on latest supported iOS simulator
5. Unsigned Release build validation

### Backend/security gates

- `./scripts/test_backend_foundation.sh`
  - run twice (two clean resets)
- SQL migration chain checks in isolated environments
- RLS and security policy spot-checks tied to auth/session routes

### Feature and evidence flags

All gate output writes to `release-evidence/<RUN_ID>/`:

- `release-evidence.md`: human-readable evidence notes
- `summary.txt`: step|status|log
- `<step>.log`: command output for each step

## 4) Gating environment variables

- `RUN_WEB_FRONTEND_GATES` (default `1`)
- `RUN_IOS_GATES` (default `1`)
- `RUN_BACKEND_GATES` (default `1`)
- `RELEASE_GATES_STRICT` (`1` to enforce hard-fail semantics)
- `IOS_OLDEST_SIMULATOR_DESTINATION` (default iPhone 8)
- `IOS_LATEST_SIMULATOR_DESTINATION` (default iPhone 17 Pro Max)
- `LIFTRANK_RELEASE_REPORT_DIR` (optional output root)
- `LIFTRANK_RELEASE_RUN_ID` (optional identifier)
- `LIFTRANK_RELEASE_COMMAND_TIMEOUT` (command timeout control)

## 5) Remaining/remaining blockers (to be filled before publish)

- **Service gate outcome checklist**
  - Apple Sign in with Apple enabled for production App ID and associated services.
  - Push Notifications entitlement and production signing profile verified.
  - `send-notifications` function has APNs secrets and returns successful delivery updates in production.
  - Supabase Auth custom email is switched to production SMTP and validated with recovery + signup load traffic.
  - End-to-end Sign in with Apple, signup, password recovery, and account unlink flows validated on both small/large physical devices.

- Sign in with Apple + entitlement end-to-end behavior
- APNs key/bundle setup and production token lifecycle
- SMTP production throughput verification for auth emails
- Two-account rehearsal of signup/onboarding/lift flow/report/block/delete
- Legal/privacy/accessibility final review and App Store metadata
- Physical-device short/large screens smoke passes
- TestFlight and Organizer validation
