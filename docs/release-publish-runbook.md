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

### Disposable staging authentication tests

`pnpm test:staging-auth` runs server-side SDK integration checks against the Debug
project only: `dfpvamnucwyafxklnjwt`. The runner rejects every other URL, including
production, before creating a client. No migrations or Auth settings are changed.
Use Node 24 and the existing locked dependencies (`pnpm install --frozen-lockfile`).

Configure these values in a gitignored `.env.staging-auth` file, with file permissions
restricted to the owner (`chmod 600 .env.staging-auth`). Obtain both keys from this
staging project; do not paste secrets into chat, pass them as command-line arguments,
prefix the server key with `VITE_`, or include them in a browser/iOS build:

```dotenv
STAGING_AUTH_URL=https://dfpvamnucwyafxklnjwt.supabase.co
STAGING_AUTH_PUBLIC_KEY=<staging publishable or anon key>
STAGING_AUTH_SERVER_KEY=<staging secret or service-role key>
```

```sh
pnpm test:staging-auth:guards       # Local safety/cleanup tests; no credentials needed
pnpm test:staging-auth --check      # Validate configuration without network requests
pnpm test:staging-auth             # Create, exercise, and delete disposable accounts
pnpm test:staging-auth --cleanup-stale
```

Each live run creates two confirmed accounts at reserved `example.test` addresses,
with random passwords kept only in memory and server-owned suite/run markers in
`app_metadata`. It checks unauthenticated password-update rejection, sign-in,
incorrect passwords, session refresh, a generated recovery token and
`PASSWORD_RECOVERY` event, weak-password rejection, password update, token reuse,
old/new password behavior, session restoration into a fresh SDK client, and a second
account remaining unchanged after invalid recovery. Admin privileges are used only
for fixtures, token generation, and cleanup; user operations use the public key.

Cleanup runs after success or failure, rechecks the server-owned marker and exact
test email before each deletion, and confirms account absence. A cleanup failure
fails the run and prints only the affected account ID. The next run (or
`--cleanup-stale`) removes only matching suite accounts older than 24 hours, covering
process termination or a lost account-creation response. Recent test accounts and
all unmarked accounts are preserved. Tests do not upload media or create workouts.

These are **API recovery tests**, not email-delivery, public signup, actual expired-link,
PKCE redirect, web-form, iOS callback, keychain, or physical-device acceptance tests.
Supabase's [admin link generator](https://supabase.com/docs/reference/javascript/auth-admin-generatelink)
supplies a token without sending mail. Wrong and reused tokens are checked, but the
runner does not wait an hour for expiry or weaken the expiry policy. The existing
`tests/authRecovery.test.tsx` covers web-form behavior with a mocked SDK. Actual
email/PKCE acceptance still needs a controlled test inbox; the runner does not claim
to test email delivery. Staging's schema/settings may also differ from production.

For GitHub execution, configure the `staging-auth` environment with
`STAGING_AUTH_PUBLIC_KEY` and `STAGING_AUTH_SERVER_KEY` secrets, restricted to the
trusted `main` and `codex/staging-auth` branches. `.github/workflows/staging-auth.yml`
runs the guard tests, mocked web recovery tests, and this live suite after relevant
pushes to either branch. Manual dispatch becomes available after the workflow reaches
the default branch. It does not run on pull requests or a timer, publish the
app, or expose the server key to dependency installation. It must be committed and
pushed, and the secrets configured, before GitHub can run it. Local checks need no
new dependencies.

November 3 setup verification: 10 local runner guard/cleanup tests and the 7 existing
mocked web recovery tests passed. Runner syntax, workflow YAML, and whitespace checks
passed. After explicit owner authorization, existing staging keys were stored in
owner-only, gitignored `.env.staging-auth` and the branch-restricted GitHub environment.
The first live API run (`8e261fc4-4412-438f-a543-bfe90ff31e88`) passed all checks and
verified deletion of both disposable accounts. GitHub activation uses a dedicated
branch because `main` still contains an older web app without the Auth dependency.

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
