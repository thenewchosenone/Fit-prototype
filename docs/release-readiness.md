# Lift Rivals release readiness

## Active publish plan

- Primary source for execution: `./scripts/release-gates.sh`  
- Weekly dry-run evidence bundle: `release-evidence/<RUN_ID>/release-evidence.md`
- Route and production hardening check list: `docs/release-publish-runbook.md`
- New command for route/auth smoke checks: `pnpm test:release-routes`

This document records evidence for the 11-phase public-launch plan. A phase is complete only when its automated gates pass and any external verification is explicitly recorded.

## Phase 1 baseline — July 18, 2026

- Working branch: `codex/ios-app`; existing uncommitted product and Supabase work was preserved.
- `git diff --check`: passed.
- iOS unit tests: 122 passed.
- iOS UI tests: 8 passed.
- Web application tests: 92 passed.
- Gym-source parser tests: 10 passed.
- Local Supabase SQL security tests: blocked because PostgreSQL/Supabase CLI and Docker are not installed on this machine. Do not substitute tests against the linked shared project.

## Open external gates

- Provision a distinct production Supabase project; the current linked project is staging.
- Install an isolated PostgreSQL test runtime or run the SQL suite in CI.
- Complete two-account staging smoke tests and physical-device testing.
- Apple Developer membership is required only for production Apple capabilities, TestFlight, signing, and submission.

## Focused v1 launch profile — July 19, 2026

- Production now resolves an explicit focused feature profile: Home, Leaderboards, Track, and Me.
- The launch social loop is mutual connections, athlete discovery, intentionally shared completed workouts, likes, comments, reports, blocking, and in-app/push notifications.
- Connection requests and connection workout activity live on Home; athlete discovery lives in Leaderboards search.
- Community tab, forums, direct messages, communities/gym feeds, polls, saves/watches, and advertising remain in the codebase for staging/debug evaluation but are unavailable in production.
- Completed-workout sharing uses dedicated Supabase tables/RPCs and RLS. The migration is `202607190001_focused_launch.sql`; it must pass its pgTAP test before staging promotion.
- Verification evidence: Debug simulator build passed; the complete iOS unit suite passed 174 tests with zero failures. The app launched successfully to the production account screen.

## Implemented phases

1. **Baseline:** unit, UI, web, parser, and unsigned Release evidence recorded above.
2. **Environment isolation:** Debug targets staging; Release refuses to start until a distinct production URL and public key are configured.
3. **Accounts and legal:** email and nonce-protected Apple authentication paths, account deletion, four-stage onboarding, field audiences, immutable legal acceptance, and privacy-first lifecycle analytics are implemented. Apple account-linking needs physical-account validation.
4. **Workout sync and programs:** active sessions remain local; versioned plans, immutable completed snapshots, offline retries, conflict copies, and cables/free-weight templates are implemented.
5. **Competitive authority:** the seven canonical movements, true-one-rep eligibility, per-hand dumbbell rules, private uploads, server evidence state, review thresholds, moderation actions, and immutable audits are implemented in forward-only migrations.
6. **Rankings and profiles:** verified-first rankings, comparison modes and filters, expandable top-three rows, visible personal placement, public best-lift records, and clickable PR details are implemented.
7. **Social safety:** production forums, followed-first feed, direct messages, blocking, reports, moderation, saves, watches, polls, and membership rules are implemented behind RLS/server functions.
8. **Notifications:** in-app notifications, event-generated notification records, per-install APNs token registration/revocation, and a credential-isolated APNs Edge Function are implemented. Live pushes remain gated on Apple membership, entitlements, credentials, and scheduling the sender.
9. **Design and exercise details:** floating navigation, vertical program previews, volume summaries, semantic system/light/dark surfaces, Reduce Motion media behavior, anatomy fallback, exercise history/records/charts, and five substitutes are implemented. Original/licensed media still requires a rights review before release.
10. **Security and release tooling:** RPC-to-migration coverage was audited, the local database harness now executes every pgTAP file, and production remains fail-closed rather than falling back to mocks.

## Phase 11 release gates still open

- Perform a two-unrelated-account staging rehearsal for signup, media playback, ranking, reporting, blocking, and account deletion.
- Provision production Supabase and validate its configuration separately from staging.
- Complete legal review, accessibility review, App Store privacy answers and metadata, support workflow, and licensed/original media review.
- After joining the Apple Developer Program, add production Sign in with Apple and APNs capabilities, exercise account linking/deletion on physical devices, run TestFlight, and perform the final signed archive validation.

## Phase 11 local verification — July 18, 2026

- Latest unsigned Release simulator build: passed for arm64 and x86_64.
- Latest `git diff --check` and backend harness shell syntax: passed.
- `./scripts/release-gates.sh` now enforces a `publish_readiness.services` preflight step that runs `./scripts/check_publish_readiness_services.sh` before web/iOS/backend gates.
- Web Vitest suite: 92 passed; gym-source parser suite: 10 passed.
- Focused account/backend iOS suite: 13 passed before the final notification-decoding regression test was added; the latest Release build compiles that test's production model changes.
- The subsequent complete simulator run reached UI testing, then Xcode's simulator launch workers stopped materializing. The edit-profile UI case was recorded as failed after a 201-second runner failure; an isolated retry and a unit-only retry stalled before test execution with the same Xcode worker state. CoreSimulator was restarted without erasing data, but did not recover in this run. Re-run the complete unit/UI suite after restarting Xcode/macOS; do not treat this infrastructure failure as a passing release gate.

## Supabase staging validation — July 19, 2026

- Installed an isolated PostgreSQL 15 runtime and ran every migration and pgTAP/RLS test, including the concurrent gym-membership test, against two clean temporary databases. Both resets passed.
- Corrected the media-completion RPC parameter collision, the focused-feed return-type replacement, and the forum profile-visibility function's security-definer search path before remote deployment.
- Corrected the backend harness so indented `not ok` pgTAP output fails the run instead of being reported as a pass.
- Confirmed project `dfpvamnucwyafxklnjwt` is the staging project. Its existing schema matched migrations through `202607180001`; those versions were reconciled into the previously empty migration ledger.
- Applied migrations `202607180002` through `202607190001` to staging and verified that all twelve local and remote migration versions now match.
- Confirmed `delete-account` is active with JWT verification. Deployed `send-notifications` as an active internally authenticated Edge Function with gateway JWT verification disabled, because the function validates `NOTIFICATION_DELIVERY_SECRET` itself.
- Live push delivery remains inactive until `NOTIFICATION_DELIVERY_SECRET`, `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, and `APNS_BUNDLE_ID` are configured. These require the Apple production setup; no placeholder credentials were added.
- The unsigned iOS Simulator build succeeded after the RPC contract correction, confirming the staging-compatible client still compiles.
- A two-unrelated-account staging rehearsal remains open. Migration/RLS validation does not replace the app-level signup, media playback, ranking, reporting, blocking, and account-deletion smoke test.

## Focused-launch connection and verification — July 20, 2026

- Native email recovery now returns through `liftrank://auth-callback`; the staging Auth redirect allowlist was updated and verified in the Supabase dashboard. Password changes require an authenticated recovery session.
- The native leaderboard now requests authoritative entries from `LeaderboardService` instead of presenting only locally calculated demo data. Focused launch scopes expose global, city, and weight class while specific-gym feeds remain deferred.
- Onboarding and lift submission now use the authenticated Supabase gym directory and memberships. A lift cannot be submitted against an unjoined placeholder gym.
- Profile bodyweight now round-trips through the owner-only `profile_private_details.bodyweight_lb` field. Migration `202607200001_profile_bodyweight.sql` was applied to staging and remains forward-only/idempotent for later migration-ledger promotion.
- Lift submission only displays success after the server accepts the record. Video upload failure leaves the attempt self-reported and presents the failure instead of falsely labeling it video-backed. Signed playback remains the authoritative viewing path.
- Debug simulator build passed. The complete native unit suite passed after focused-launch notification-routing expectations were aligned with deferred Community and Messages destinations.
- Native UI automation remains blocked before assertions by local Xcode infrastructure: both parallel and single-simulator runs report `DebuggerVersionStore.StoreError` / `no debugger version`. This is not counted as a passing UI gate.
- The focused-launch web tests pass. The broader legacy web suite currently has 89 passing and 6 failing tests, primarily lazy-route loading/timeouts around demo-only exercise-library routes; it is not a production-connected replacement for the native client.
- Local database/RLS rerun is unavailable in the current shell because PostgreSQL, Docker, and Supabase CLI runtimes are absent. The staging migration applied successfully, but the SQL security suite must still run in CI or an isolated PostgreSQL environment.

### Remaining connection and external gates

- Configure Sign in with Apple, APNs credentials/entitlements, and signed distribution after Apple Developer enrollment. These cannot be completed using only the free Apple account.
- Run the two-unrelated-account staging rehearsal with real credentials: signup/recovery, onboarding, workout sync, lift plus video playback, ranking, reporting/review, blocking, and account deletion.
- Complete legal, accessibility, media-rights, privacy disclosure, support/moderation workflow, App Store metadata, physical-device, TestFlight, and signed archive gates.

## Production Supabase provisioning — July 20, 2026

- Created the distinct free-tier `Lift Rivals Production` project in `thenewchosenone's Org`: project ID `ikjgbsrlriqiusuvezco`, URL `https://ikjgbsrlriqiusuvezco.supabase.co`, region `us-east-1` (North Virginia). The database password was rotated after provisioning and successfully reconnected; it and the notification delivery secret are stored in macOS Keychain and are not present in the repository.
- Applied the exact 13-file forward-only migration chain through `202607200001`; the remote migration ledger matches every local version. No staging accounts, workouts, lifts, or media were copied.
- Ran 166 transactional pgTAP/RLS assertions against production with zero failures. Re-ran the gym membership race through two independent hosted connections; exactly one competing third-gym join succeeded and cleanup removed all fixtures.
- Verified zero Auth users, profiles, lifts, and completed workouts; all public tables have RLS enabled; the `lift-videos` Storage bucket exists and is private.
- Configured `liftrank://auth-callback`. Deployed `delete-account` and `send-notifications`; both reject unauthenticated requests with HTTP 401. `NOTIFICATION_DELIVERY_SECRET` is configured, while APNs secrets remain intentionally absent.
- Release now uses the production URL and dedicated `mobile` publishable key; Debug remains on staging. Independent Debug and Release simulator builds passed, and their compiled Info.plists resolve to the correct environments.
- Production is provisioned but remains prelaunch. Two-account application rehearsal, physical-device validation, Apple services, legal/accessibility/media review, and signed/TestFlight gates remain open.
- Custom SMTP is not configured. Supabase's built-in mailer is restricted to organization-team addresses and two messages per hour, so public email signup/recovery must remain a release blocker until a production SMTP provider is connected and tested.
