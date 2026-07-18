# LiftRank release readiness

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

- Run all pgTAP tests from two clean databases once the isolated PostgreSQL runtime is installed.
- Apply the identical migration set to staging and perform a two-unrelated-account moderation/messaging/upload rehearsal.
- Provision production Supabase and validate its configuration separately from staging.
- Complete legal review, accessibility review, App Store privacy answers and metadata, support workflow, and licensed/original media review.
- After joining the Apple Developer Program, add production Sign in with Apple and APNs capabilities, exercise account linking/deletion on physical devices, run TestFlight, and perform the final signed archive validation.

## Phase 11 local verification — July 18, 2026

- Latest unsigned Release simulator build: passed for arm64 and x86_64.
- Latest `git diff --check` and backend harness shell syntax: passed.
- Web Vitest suite: 92 passed; gym-source parser suite: 10 passed.
- Focused account/backend iOS suite: 13 passed before the final notification-decoding regression test was added; the latest Release build compiles that test's production model changes.
- The subsequent complete simulator run reached UI testing, then Xcode's simulator launch workers stopped materializing. The edit-profile UI case was recorded as failed after a 201-second runner failure; an isolated retry and a unit-only retry stalled before test execution with the same Xcode worker state. CoreSimulator was restarted without erasing data, but did not recover in this run. Re-run the complete unit/UI suite after restarting Xcode/macOS; do not treat this infrastructure failure as a passing release gate.
