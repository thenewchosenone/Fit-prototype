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

This script performs a static source/configuration preflight for:
- Apple Sign in with Apple entitlement wiring
- APNs entitlement and environment settings
- auth callback path handling
- production mail/notification function prerequisites (secret presence is not provider verification)

It does not contact APNs or the SMTP provider. Provider setup and delivery still
require the manual evidence below. The unified summary labels this row
`publish_readiness.services_static_preflight`.

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

### iOS gates (required before release)

Skipped or unavailable iOS gates leave the release run incomplete.

1. Unit suite on oldest supported iOS simulator
2. Unit suite on latest supported iOS simulator
3. UI suite on oldest supported iOS simulator
4. UI suite on latest supported iOS simulator
5. Unsigned Release build validation

### Backend/security gates

- `./scripts/test_backend_foundation.sh`
  - run once; the script runs the suite after two clean database resets
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
- `IOS_OLDEST_SIMULATOR_DESTINATION` (required for the oldest-iOS tests; select an installed iOS 17 simulator explicitly)
- `IOS_LATEST_SIMULATOR_DESTINATION` (default iPhone 17 Pro Max)
- `IOS_UI_SIGNED_ACCOUNT_READY=1` only after preparing the signed simulator artifacts and accounts for both destinations described below; otherwise both full UI targets are recorded as skipped/incomplete. This flag records readiness; the script does not validate signing or account setup.
- `LIFTRANK_RELEASE_REPORT_DIR` (optional output root)
- `LIFTRANK_RELEASE_RUN_ID` (optional identifier)
- `LIFTRANK_RELEASE_COMMAND_TIMEOUT` (command timeout control)

Disabled or unavailable gates make the overall result `INCOMPLETE` (exit 2), not a pass. The service preflight can pass with warnings; those warnings still require external evidence. Confirm that the selected latest destination actually uses the intended current iOS runtime.

The full UI gate runs `xcodebuild test` in Debug separately for each selected simulator, which rebuilds and installs the test app. Each run retains its `.xcresult` bundle and is marked incomplete if XCTest reports any skipped tests. Before setting the readiness flag, confirm that each resulting simulator app is signed with the required entitlements and uses the intended staging backend, then prepare the account on that destination. After the run, record the resulting app/build identity, signing state, backend, and destination for each gate; the flag itself does not validate any of these conditions.

Use a fresh, empty evidence directory for every run. The script refuses to
overwrite a nonempty report directory. `LIFTRANK_RELEASE_COMMAND_TIMEOUT` must
be a positive integer in seconds; timed commands are force-killed after a
five-second termination grace period if they ignore the initial timeout signal.

The gate report records the Git revision and working-tree status, but does not snapshot dirty or untracked file contents. Before the final candidate run, preserve an immutable source snapshot and record its fingerprint alongside the signed artifact path, artifact fingerprint, configuration, backend, and destination details.

### Simulator sign-in and session checks

Use this sequence whenever a new simulator build will be used to sign in to a real account:

1. For each oldest and latest simulator destination, record the source snapshot and fingerprint, build configuration, backend URL, signing state, entitlements, and installed artifact fingerprint. Debug targets staging; Release targets production. Do not infer the backend from the sign-in screen. Check the compiled app's `Info.plist` or build settings before testing.
2. Use a **signed** simulator build for a real sign-in and session-restoration test. `CODE_SIGNING_ALLOWED=NO` is appropriate for compilation and UI tests that use mocks, but not for real Supabase authentication. Install the exact signed artifact being tested and keep its path with the result. Do not erase the app or simulator data as a default retry.
3. If sign-in reports “session expired,” inspect the installed app's entitlements and simulator `securityd` output before blaming the password or backend. The October 27 unsigned Release simulator build failed with `errSecMissingEntitlement` (-34018), which prevented keychain-backed Supabase session storage; see `docs/release-readiness.md` under “Build 49 TestFlight preparation.” A successful password request in that build did not prove session persistence.
4. If simulator signing is unavailable, use the existing `work/release-readiness-20261026/simulator-session-workaround/` copy only for a labeled, temporary sign-in smoke test. It uses memory-backed auth storage, so sign-in after process relaunch and production release behavior remain unverified. Do not merge that storage change into the release app or call its result a release sign-in pass.
5. Verify the signed-in Home screen, then terminate and relaunch the signed app to verify session restoration. Test the actual TestFlight binary on a physical iPhone separately. If either fails, save the exact build, configuration, error, and relevant device logs; diagnose that failure before changing auth implementation.

### Physical-phone review with a live account

Use the production backend when the user wants to sign in to their live account. Debug defaults to staging, whose accounts are separate; a previous Debug installation does not establish the intended environment for the next review. Use the latest Release configuration to retain Apple sign-in, and verify the compiled backend before installation. For a direct development installation, use the existing matching development identity/profile and command-line signing/APNs overrides without changing the project’s production defaults. Verify the application identifier, keychain access, Apple sign-in entitlement, and APNs entitlement against that profile. Install over the existing app without uninstalling or resetting data, then let the user sign in with their usual method. Record installation separately from confirmed account/session behavior.

### Password recovery acceptance

Native recovery requests must redirect to `liftrank://auth-callback?type=recovery`, on the same installation that requested the email. The app retains the PKCE verifier; sending its code to a browser cannot complete the exchange. Keep the recovery email link as `{{ .ConfirmationURL }}` and allow the exact native callback URL in each environment. The query marker preserves recovery intent when Supabase appends its PKCE code. Show the password form after exchange succeeds, independently of profile loading.

The repository React app uses `#/reset-password` and PKCE: open the email in the same browser and device that requested it. The separately hosted SiteGround website uses `/login/?mode=reset`; its `public_html/site.js` and `supabase-web.js` are not built from `src/`. Both web implementations require a verified recovery event or successful recovery-token exchange for the current account, rather than accepting any existing session. New reset passwords require 10 characters; sign-in must not impose a new-password length rule on existing credentials.

On November 3, 2026, production project `ikjgbsrlriqiusuvezco` was inspected read-only: the reset template uses `{{ .ConfirmationURL }}` and its redirect allowlist already includes both the marked native callback and both web routes. No Supabase configuration or database changes were made. SiteGround's two live JavaScript files were patched and their public responses compared byte-for-byte with the tested candidates. Original files, candidates, patch script, and mocked service regression tests are retained in `work/password-recovery-siteground/` for review and rollback.

Validation: 6 focused native tests passed in an unsigned Debug build with mocked authentication on iPhone 17 / iOS 26.5; 63 React tests passed, including 7 recovery regressions; 4 mocked live-service regressions passed; TypeScript and live JavaScript syntax checks passed. Native build evidence: `/tmp/liftrivals-password-recovery-tests-final.log` and `/tmp/liftrivals-password-recovery-build/Logs/Test/`. The browser smoke test showed the request-link form without a recovery session and no console errors. This is not a signed-account or email-delivery acceptance pass.

Before release, use a disposable account to verify email delivery, cold/warm native callbacks, successful password update and new-password sign-in, expired/reused links, mismatched/short passwords, profile-service failure, cancellation, and an existing browser session for another account. Confirm that an invalid link never changes the pre-existing account. Test browser recovery separately from native PKCE; restarting an uncompleted browser recovery requires a new email link. Record session revocation behavior and the exact signed native artifact. Mocked tests and an unsigned simulator build do not establish real email delivery or keychain persistence.

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
The first [GitHub Actions run](https://github.com/thenewchosenone/Fit-prototype/actions/runs/41764623275)
also passed all 10 guard tests, 7 mocked web tests, and the live staging suite,
including verified deletion of both disposable accounts.

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
