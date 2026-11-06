# Lift Rivals release readiness

> Current decision: **NO-GO for public release**. See “Full release audit — November 2, 2026” at the end of this document. Earlier build/test/deployment records are historical evidence, not approval of the current working tree.

## Active publish plan

- Primary source for execution: `./scripts/release-gates.sh`  
- Weekly dry-run evidence bundle: `release-evidence/<RUN_ID>/release-evidence.md`
- Route and production hardening check list: `docs/release-publish-runbook.md`
- New command for route/auth smoke checks: `pnpm test:release-routes`

This document records evidence for the 11-phase public-launch plan. A phase is complete only when its automated gates pass and any external verification is explicitly recorded.

## Submitted archive baseline - July 29, 2026

- The preserved local archive was created July 24 at 11:53 PM ET for `Lift Rivals 1.0.0`; its bundled build number is `2`.
- Xcode Organizer records successful validation and upload to App Store Connect, with upload metadata for historical builds `3` and `4`. The local submission candidate recorded at that time was version `1.0`, build `29`; this is historical. The later TestFlight upload baseline is build `49` below.
- The archived Release app resolves the production Supabase project `ikjgbsrlriqiusuvezco` and contains only its public publishable client key.
- The archived app bundle is approximately 11 MB and includes three demo leaderboard GIFs. Current source removes those resources from future Release bundles.
- The archive's arm64 dSYM UUID is `C9327D2A-E3B1-330B-9624-7AE1F607781E`; the archived executable SHA-256 is `707fd1580c6f0af372098473c14da8387640e406e7ab40f385299c967dc23349`.
- The latest committed revision before archive creation was `3f1ad6a95b1917bdac83fba7ae3c272d435048f9` (`Alpha Appstore launch version`). Because the archive does not embed a Git revision and the historical working-tree state is unavailable, treat this as the likely source baseline rather than a cryptographically proven match.
- Release evidence now records the exact Git revision and clean/dirty source state so future archives can be reproduced without this ambiguity.

## Phase 1 baseline — July 18, 2026

- Working branch: `codex/ios-app`; existing uncommitted product and Supabase work was preserved.
- `git diff --check`: passed.
- iOS unit tests: 122 passed.
- iOS UI tests: 8 passed.
- Web application tests: 92 passed.
- Gym-source parser tests: 10 passed.
- Local Supabase SQL security tests: blocked because PostgreSQL/Supabase CLI and Docker are not installed on this machine. Do not substitute tests against the linked shared project.

## Open external gates

- Validate the existing production Supabase project's configuration separately from staging.
- Install an isolated PostgreSQL test runtime or run the SQL suite in CI.
- Complete two-account staging smoke tests and physical-device testing.
- Apple Developer membership is required only for production Apple capabilities, TestFlight, signing, and submission.

## Focused v1 launch profile — July 19, 2026

- Production now resolves an explicit focused feature profile: Home, Leaderboards, Track, and Me.
- Athlete discovery lives in Leaderboards search; reporting and blocking remain available from athlete profiles.
- Community, forums, direct messages, gym feeds, polls, saves/watches, and broad social navigation are removed from the production app surfaces. Historical backend migrations are not evidence that these deferred surfaces ship in focused v1.
- Completed-workout sharing uses dedicated Supabase tables/RPCs and RLS. The migration is `202607190001_focused_launch.sql`; it must pass its pgTAP test before staging promotion.
- Verification evidence: Debug simulator build passed; the complete iOS unit suite passed 174 tests with zero failures. The app launched successfully to the production account screen.

## Implemented phases

1. **Baseline:** unit, UI, web, parser, and unsigned Release evidence recorded above.
2. **Environment isolation:** Debug targets staging; Release refuses to start until a distinct production URL and public key are configured.
3. **Accounts and legal:** email and nonce-protected Apple authentication paths, account deletion, four-stage onboarding, field audiences, immutable legal acceptance, and privacy-first lifecycle analytics are implemented. Apple account-linking needs physical-account validation.
4. **Workout sync and programs:** active sessions remain local; versioned plans, immutable completed snapshots, offline retries, conflict copies, and cables/free-weight templates are implemented.
5. **Competitive authority:** the seven canonical movements, true-one-rep eligibility, per-hand dumbbell rules, private uploads, server evidence state, review thresholds, moderation actions, and immutable audits are implemented in forward-only migrations.
6. **Rankings and profiles:** verified-first rankings, comparison modes and filters, expandable top-three rows, visible personal placement, public best-lift records, and clickable PR details are implemented.
7. **Focused safety:** lift reporting, athlete blocking, and moderation service boundaries remain available. The July 19 focused-launch note is historical: the current source enables Forum in `FeatureAvailability.focusedProduction` and adds it to the main tab navigation. The other deferred social surfaces still require separate scope review.
8. **Notifications:** in-app notifications, event-generated notification records, per-install APNs token registration/revocation, and a credential-isolated APNs Edge Function are implemented. Live pushes remain gated on Apple membership, entitlements, credentials, and scheduling the sender.
9. **Design and exercise details:** floating navigation, vertical program previews, volume summaries, semantic system/light/dark surfaces, Reduce Motion media behavior, anatomy fallback, exercise history/records/charts, and five substitutes are implemented. Original/licensed media still requires a rights review before release.
10. **Security and release tooling:** RPC-to-migration coverage was audited, the local database harness now executes every pgTAP file, and production remains fail-closed rather than falling back to mocks.

## Phase 11 release gates still open

- Perform a two-unrelated-account staging rehearsal for signup, media playback, ranking, reporting, blocking, and account deletion.
- Validate the existing production Supabase project's configuration separately from staging.
- Complete legal review, accessibility review, App Store privacy answers and metadata, support workflow, and licensed/original media review.
- After joining the Apple Developer Program, add production Sign in with Apple and APNs capabilities, exercise account linking/deletion on physical devices, run TestFlight, and perform the final signed archive validation.

## Phase 11 local verification — July 18, 2026

- Latest unsigned Release simulator build: passed for arm64 and x86_64.
- Latest `git diff --check` and backend harness shell syntax: passed.
- `./scripts/release-gates.sh` enforces a `publish_readiness.services_static_preflight` step before web/iOS/backend gates. It checks source/configuration wiring only; it does not prove live APNs or SMTP readiness.
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

## Focused-launch stabilization verification — July 25, 2026

- The focused native app compiles and launches with Home, Leaderboards, Track, and Me. The complete serial iOS unit target passed 230 tests with zero failures, and the complete serial UI target passed 23 tests with zero failures on an iPhone simulator.
- The unsigned Release simulator build passed for arm64 and x86_64 from the stabilized current source.
- Product-consistency batches were completed for recorded workout/PR weights, normalized kilogram presentation, preferred-unit bodyweight editing, leaderboard identity and location privacy, deferred gym leaderboard scopes, and failed video-upload state.
- Failed evidence uploads now remain self-reported, clear temporary media references, and invalidate late progress callbacks. The focused regression test compiles in the unit-test target.
- Focused UI runtime coverage passed for signed-out/create-account routing, five-step onboarding through profile persistence and legal acceptance, profile editing, workout logging and completion, PR submission, leaderboard/profile navigation, media presentation, service-backed lift reporting, athlete blocking, and confirmed account deletion back to sign-in.
- UI-only launch fixtures are explicit DEBUG arguments. Production continues to start with no seeded athletes, gyms, lifts, media, or deferred social data.
- Web unit/component tests passed: 95 of 95. Gym-source parser tests passed: 10 of 10. The production web build passed.
- Production release-route smoke passed on desktop and mobile: 6 of 6. Demo-mode release-route smoke rebuilt the demo bundle and passed on desktop and mobile: 6 of 6. Deferred Community and Messages routes resolve through focused Home and then to Login when unauthenticated in production.
- `check_publish_readiness_services.sh` and `check_launch_metadata.sh` passed their local source/configuration checks. The services check still warns that production APNs secrets, notification-delivery runtime evidence, and production SMTP evidence are unavailable locally.

### Explicit remaining release blockers

- Connect and load-test production SMTP for signup and recovery.
- Complete the two-unrelated-account staging rehearsal for signup/onboarding, profile edit, workout sync/logging/detail, PR plus signed media playback, ranking, reporting, blocking, and account deletion.
- Complete physical-device testing, including camera/photo selection, video upload/playback, keyboard behavior, background/foreground recovery, and account linking/deletion.
- Verify Apple Developer capabilities and distribution signing, Sign in with Apple account linking, APNs credentials and live delivery, and TestFlight installation.
- Complete legal, App Store privacy disclosure, accessibility, support/moderation workflow, and original/licensed media-rights reviews.

## App Store resubmission preparation — October 17, 2026

- Updated the App Store handoff to candidate 1.0 (30) in `docs/app-store-launch-metadata.md`. The Terms page that currently renders is `https://liftrivals.com/terms/`; `/terms-of-use/` returns 404.
- The current production crash in training-progress volume calculation was traced to duplicate exercise catalog IDs and fixed by retaining the first matching catalog entry. The regression test and full iPhone simulator unit suite passed: 408 tests, zero failures.
- Selected review-flow UI checks passed adaptive plans, demo account deletion, sign-in validation, and fresh onboarding. Two existing UI expectations failed: the ranking fixture did not contain its expected athlete, and the profile layout test expects strength sections absent from the current view. Those failures remain unresolved.
- Created and exported the signed App Store archive and IPA for version 1.0, build 30. Archive signing includes the production APNs and Sign in with Apple entitlements, and uses the production Supabase configuration. No service-role credential or email placeholder was found in the archived executable. Archive: `/Users/robertjeanty/Library/Developer/Xcode/Archives/2026-10-17/LiftRivals-1.0-30.xcarchive`; IPA: `/private/tmp/liftrivals-export-30/LiftRank.ipa`.
- Xcode Organizer confirmed “LiftRank 1.0 (30) uploaded.” App Store Connect finished processing it and now lists build 30 as **Ready to Submit** in the existing “Lift Rivals Testing” group.
- Replaced and saved the rejected version's App Review notes: removed the stale Build 4 claim, added build 30 setup/testing steps, current contact name, supported device/OS details, backend/service list, account deletion path, region statement, and current legal/support URLs. Sign-in remains required and the existing demo credential fields are populated; they still need an exact-build login check.
- The isolated PostgreSQL/pgTAP release gate could not run because this Mac has no PostgreSQL `initdb`; no remote migration was attempted.
- Still required before Update Review: install build 30 through TestFlight; perform a clean-install and sign-in/Sign in with Apple walkthrough on the connected iPhone (Apple authentication may require Robert to complete the Face ID/system prompt); verify the exact demo credentials, workout tracking, rankings/social, reporting/blocking, and account deletion; test iPad compatibility on an iPad; record and attach a video matching build 30; confirm current screenshots and store metadata; cover the oldest supported iOS runtime; run isolated SQL security tests; resolve the two UI gate failures and complete the remaining review-flow checks. Do not select Update Review until these gates are complete.

## Release assessment — October 26, 2026

**Decision: not ready for publication.** This assessment covers the dirty working tree at revision `b9f0a095d6af59f7ef3c636ab4f24b71412373c1`, not a proven source match for an uploaded build. Existing uncommitted changes were preserved. The current project is version 1.0, build 49, targets iPhone, and has an iOS 17.0 deployment target. The release checklist records Organizer reporting build 48 uploaded on October 25; its processing and review status were not verified.

1. **Blocked — App Review:** On October 26, App Store Connect showed iOS 1.0 as Rejected with unresolved issues. The App Store version selects build 5, but its saved review notes describe build 30; the optional review attachment area showed no attachment. The TestFlight list showed build 48 as Ready to Submit, in the internal Lift Rivals Testing group (two testers), with one install and no crash count displayed. This does not establish external beta approval or seven stable days. Confirm the latest upload records before any later upload and choose a build number greater than every uploaded build.

   The August 16 App Review message requests a physical-device recording on the latest OS showing the core flow, including registration, login, deletion, user-generated content reporting/blocking, and permission prompts where applicable. It also requests tested device/OS models, app purpose and audience, setup and account access, external services, regional differences, and applicable authorization for regulated services or protected material. The earlier August 5 review of build 3 reported unresponsive Sign In/Create Account controls, an Apple sign-in error, unclear Apple sign-in button presentation, and a nonfunctional support URL. Reproduce or verify each issue against the final candidate on the relevant physical devices, including iPad compatibility mode. The August 16 submitted item shows build 5; neither historical review establishes the behavior of build 48 or the current working tree.

   On October 26, the exact support URL saved in App Store Connect (`https://liftrivals.com/support`) redirected to `/support/` and rendered contact and account-deletion information in the in-app browser. This verifies the page loaded at that time, not that support email delivery or response procedures were tested. The release owner reported an iPhone available, but no iPad currently available.

   The privacy URL in the saved review notes and handoff (`https://liftrivals.com/privacy-notice/`) displayed a page-not-found screen. App Store Connect's separate Privacy Policy URL (`https://liftrivals.com/privacy`) loaded a shorter public-record privacy overview; it is not the full notice currently bundled in the app and present in `website/privacy/index.html`. The published terms page also differed from the full in-app terms. Resolve the public legal content and links, with legal review, before resubmission; no website or App Store settings were changed during this check. The App Privacy page listed nine matching categories, but its displayed purposes for User ID, Fitness, and Product Interaction differ from `PrivacyInfo.xcprivacy`; compare both with actual production behavior and reconcile them.
2. **Verified locally, with limits — preparation:** Locked Swift packages resolved without updates. The scheme, Apple Sign in/APNs entitlement wiring, callback configuration, and metadata placeholder checks passed. The service check warned that server-side APNs, notification delivery, and production SMTP evidence was unavailable; shell variables being absent does not prove server configuration is absent. The metadata check establishes only that placeholders are absent and the avatar migration and test files exist, not that store metadata or deployed migrations are correct. Plist syntax and `git diff --check` passed.

   An unsigned generic iOS Release build succeeded and its bundle identifies as 1.0 (49). A narrow bundle scan found no private-key PEM marker, `service_role` identifier, staging project identifier, demo-named files, or GIF files. This is not a comprehensive secret, URL, or demo-entry-point audit, nor signing or archive validation.
3. **Incomplete — automated gates:** Run the full unified release gate on the final source revision. The partial preflight deliberately skipped web, iOS, and backend gates. The oldest-iOS unit and UI gates need an explicitly selected iOS 17 simulator; only iOS 26.5 was installed during this assessment. The previous October 17 UI failures described above remain unresolved until rerun. The release owner previously directed that long automated tests be skipped; no current full-suite pass is claimed.

   October 26 targeted iPhone 17/iOS 26.5 UI run: `testLeaderboardFiltersAndOpensAnotherAthleteProfile` passed. `testMeHubSectionOrderAndCompactHeaderActions` failed when tapping `me.trainingDetails`: the accessibility tree exposed both Submit lift and the submitted-strength breakdown under that identifier. The subsequent assertions refer to strength sections that no longer appear under their old identifiers; this test and related profile coverage need reconciliation with the current design. Result: `work/release-readiness-20261026/targeted-ui.xcresult`.

   A subsequent update to that test verified the current strength-total sheet and awards/submissions ordering, and passed in `profile-ui-retest.xcresult`. The adjacent awards/public-profile test also passed after selecting the current entry point and scrolling it clear of the floating tab bar. The strength-history-through-awards test still failed on a later run before reaching the awards control, so profile navigation is not yet a complete pass. These are local test-source changes made after build 49 was archived; the uploaded app was not changed.

   The strength-history-through-awards test subsequently passed after waiting for the profile screen and dismissing the history sheet correctly (`accent-and-profile-check.xcresult`). This is focused coverage only, not a full UI-suite pass.
4. **Blocked — isolated SQL security:** The local harness could not start because `/Library/PostgreSQL/15/bin/initdb` was missing. Supply an isolated compatible PostgreSQL runtime and pgTAP dependencies, then run the harness with two clean resets or use suitable isolated CI. Do not run migrations on production as a substitute.
5. **External/manual — staging and devices:** Rehearse two unrelated accounts on staging, including account lifecycle, legal acceptance, workout/plan and profile sync across reinstall, avatar, lift/video and rankings, report/block, and deletion. Verify readable failures, no demo data for real accounts, camera/media, background recovery, and Sign in with Apple on small and large physical iPhones. Validate iPad compatibility mode if supported in review. Record the candidate and results.
6. **External/manual — production services and compliance:** Verify production SMTP signup/recovery and throughput, APNs delivery and notification state, deployed migration/storage policies, privacy disclosures against actual behavior, live legal/support URLs, fitness disclaimer, accessibility, media rights, support and moderation/incident procedures. Confirm reviewer account access against the exact candidate; reconcile review notes, screenshots, privacy answers, age rating, export compliance, and any Apple feedback. The build-30 review handoff is historical.
7. **External/manual — promotion:** On the final source and candidate, complete unsigned bundle inspection, signing and archive validation, TestFlight installation, seven stable external TestFlight days and at least 99.5% crash-free sessions as required by the checklist. Archive, upload, review submission and publication require separate authorized manual actions; none were performed during this assessment.

The gate script returns `INCOMPLETE` with exit 2 if required groups, dependencies, or individual XCTest cases are skipped. It retains each XCTest result bundle, refuses to reuse a nonempty evidence directory, and fails if command output cannot be logged. Its unsigned build is labeled accurately; these automated checks do not replace manual or server-side verification.

### Build 49 TestFlight preparation

At the release owner's request, Xcode Organizer validated and uploaded version 1.0 (49) at 10:22 p.m. Eastern on October 26. The archive and source-state evidence are in `work/release-readiness-20261026/`. The production-signed archive and exported IPA passed local signature verification; the archive contains production APNs and Sign in with Apple entitlements, targets the production backend, and identifies as build 49. The command-line upload attempt failed with an App Store Connect credentials error; the subsequent Xcode Organizer upload succeeded. App Store Connect subsequently listed build 49 as **Ready to Submit** in the existing internal Lift Rivals Testing group. Installation and external beta approval were not verified. No App Review submission was made. The remaining release gates still apply; the profile test follow-up is recorded above.

After build 49 was uploaded, the owner requested eight selectable accent colors and confirmed no specific palette was required. Local source now contains an on-device accent selection in Settings: lime, orange, red, pink, purple, blue, teal and green. Focused palette/contrast and UI persistence/redraw tests, including all eight picker choices, passed on the iOS 26.5 simulator; an unsigned Release build also passed. Build 49 predates this change; a later build is needed to test it through TestFlight. No later upload has been authorized.

On October 27, at the owner's request, the latest local source was built in unsigned Release configuration for the iPhone 17 simulator and installed without deleting the existing simulator app data. Its bundled configuration reports the production backend, and the sign-in screen appeared. This simulator build includes the post-upload accent changes and is not the same binary as TestFlight build 49. Production sign-in and Apple authentication were not verified by showing the screen.

The owner reported “session expired” after email sign-in in that simulator. Simulator `securityd` attributed `errSecMissingEntitlement` (-34018) to the unsigned app process: it lacked an application identifier or keychain access groups. Supabase's session storage depends on keychain; this establishes a simulator signing problem but does not establish the status of production iPhone sign-in. A locally re-signed simulator copy failed to launch. A separate copy under `work/release-readiness-20261026/simulator-session-workaround/` was built with a simulator-only, memory-backed auth session and installed without deleting app data; it points to production but is not the actual device release. Session state is lost when that process closes. The owner must retry sign-in to verify the workaround. No credentials were inspected or captured.

On October 27, the owner retried email sign-in in the memory-backed simulator build and reported success. The simulator displayed the signed-in Home screen. This verifies that the workaround permits this sign-in path; it does not verify session restoration after relaunch, Apple sign-in, or sign-in on the production-signed TestFlight app.

## October 28 local release follow-up

- The complete iOS unit target passed on iOS 26.5 Simulator: 415 tests, zero failures. The unsigned Release compile and the web unit, E2E, demo, performance, build, and route-smoke gates passed in the current evidence bundle.
- Eight focused iOS UI flows covering workout open, sign-up validation, awards, bodyweight check-in, exercise library, first progress open, Home scroll, and progress controls passed across targeted simulator runs. The broad UI suite remains incomplete; the earlier run was stopped before all cases finished, and current-account tests still require the documented signed-account setup.
- The October 28, 2026 live check recorded HTTP 200 for `https://liftrivals.com/privacy/` and `/terms/`, with short summaries rendered by a `static-site.js` file absent from this checkout. The repository evidence now confirms that `.github/workflows/deploy-pages.yml` builds and deploys the React demo's `dist` directory; it does not include `website/privacy/index.html` or `website/terms/index.html`. Historical deployment notes record a separate allowlisted site checkout for `liftrivals.com`, but current DNS/hosting ownership and live content were not verified in this follow-up. A local parity audit found the static Terms page differs from the native current document in its introduction and sections 5 and 14; obtain owner/legal approval before syncing the text. Locate the production site's source and deployment manifest before preparing a local correction. Keep App Store metadata blocked until the actual owner publishes and verifies the full pages.
- Local service preflight passes static Apple Sign in with Apple/APNs wiring checks and warns that production APNs secrets, notification delivery secret, and SMTP credentials need provider-side verification. The local pgTAP gate cannot run because PostgreSQL 15 binaries are not installed. No remote database or website changes were made.
- Current source enables the Forum feature in `Services/AppServiceContainer.swift` and presents its tab from `Views/MainTabView.swift`; the July focused-launch statements describing forums as deferred are historical.
- Shell syntax and `git diff --check` pass. Remaining release work includes the full signed UI/device matrix, local backend security tests, legal page publication and verification, provider-side notification/email checks, and the remaining manual App Store/TestFlight gates.

### Web legal route follow-up

- Replaced the web app's demo-only `/terms` text with the current 14-section in-app Terms. The production build passed; web unit tests passed (95/95), production route smoke passed (6/6), and demo build/E2E passed (12/12) after updating its Terms assertion.
- The broader web E2E suite passed (21/21), and the performance gate passed on desktop and mobile (2/2). The 1.8 MB gym catalog is lazy-loaded; it is not part of the normal initial entry payload, so it is retained as required data rather than treated as dead code.
- This is a local source correction only. The live domain still needs an owner-controlled deployment and verification against the reviewed legal copy; no website publication occurred.

### iOS UI suite follow-up

- The broad UI target was stopped after 38 minutes in a strength-layout audit that was still repeating its bounded scroll search. Its result bundle reports 52 passed, 25 failed, and 1 skipped; the remaining cases did not complete. Real reviewer-account and video-submission cases were excluded from that simulator run.
- Corrected the no-gym UI case to use the existing demo fixture, aligned the gym-row/Home assertions with current UI, and ensured Me Hub action frames include the 44-point minimum target. The focused rerun passed all 3 selected cases: no-gym picker, Me Hub bottom action, and light-appearance screen audit.
- Reconciled the owner-profile tests with the current header, Public preview sheet, privacy action, and submitted-total presentation. Six focused cases now pass across reruns: empty public profile, owner preview controls, preferred-unit score, repeated preview navigation, preview back performance, and primary-tab responsiveness.
- Fixed stale UI selectors/fixtures for the collapsed leaderboard Division filter, program-preview template and supported progression method, report-reason picker, exercise picker rows, current 1M chart heading, Lift video Done button, and custom onboarding logo. The Division filter test passed separately; program-preview and report-submission cases passed together.
- On October 28, the two remaining focused strength UI cases passed on iPhone 17 / iOS 26.5: selecting the exact source exercise from the searchable picker, and opening the Chest breakdown's bench trend while keeping taps clear of the floating tab bar. Evidence: `/tmp/LiftRank-UI-remaining-final-20261028-191902.xcresult` (picker pass; earlier chart assertions were still stale) and `/tmp/LiftRank-UI-strength-precise-20261028-192535.xcresult` (chart pass after scrolling disclosure targets fully into the content area and selecting 1M explicitly). These are focused passes and do not supersede the incomplete broad UI suite.
- Static analyzer passed. A read-only reconciliation of the historical broad UI result found 15 of its 24 assertion/action failures had focused passing evidence at the time. The historical nine-case list was `testLeaderboardControlsStayInsideViewportAtAccessibilitySize`, `testOnboardingSavesProfileAndAdvancesToLegalAcceptance`, `testProfileLiftVideoOpenPerformance`, `testProfilePhotoLibraryOpensAtAccessibilitySize`, `testProgressStrengthCompareAtGymOpensGymLeaderboard`, `testScreenAuditNavigation`, `testScreenAuditNavigationAtAccessibilitySize`, `testStrengthLayoutAudit`, and `testStrengthLayoutAuditAtAccessibilitySize`. The broad run also had one canceled case, one credential-skipped production reviewer test, and 12 cases it did not reach; eight account-dependent cases were excluded. These are historical counts, not a complete current-suite result.

### October 28 unified release-gate run

- With the workspace Node/pnpm runtime on `PATH`, the final unified gate passed web unit tests, full web E2E, demo E2E/build, desktop/mobile performance, production build, and production route smoke. It also passed the iOS 26.5 unit target (415 tests) and unsigned iOS Release build after the dead-code cleanup.
- The machine-readable result is `release-evidence/codex-release-final-20261028/summary.txt`. It remains a failed/incomplete release run: App Store metadata still records blocked Privacy and Terms URLs; App Store Connect's recorded privacy purposes still need reconciliation against production analytics and `PrivacyInfo.xcprivacy`; PostgreSQL 15 `initdb` is unavailable for the isolated pgTAP suite; no oldest iOS 17 simulator was selected; and the oldest/latest full UI gates were skipped because signed simulator/account readiness was not established. Service checks pass static wiring but still require provider-side APNs and SMTP evidence.
- The gate report captures Git revision and status, not dirty or untracked source bytes. Before final candidate verification, preserve an immutable source snapshot and associate its fingerprint with the built artifact, build settings, backend, entitlements and simulator/device results.

### October 29 focused UI and privacy evidence

- On iPhone 17 Pro / iOS 26.5, focused reruns passed `testStrengthLayoutAudit`, `testStrengthLayoutAuditAtAccessibilitySize`, `testLeaderboardScopeCanSelectPrimaryGym`, `testOnboardingSavesProfileAndAdvancesToLegalAcceptance`, `testProfileLiftVideoOpenPerformance`, and the standard-size `testScreenAuditNavigation`. The old Progress gym-shortcut test had no corresponding app action; its coverage was replaced with the current Leaderboards → Compare with → primary gym scope flow. This does not verify the removed shortcut.
- A web cleanup audit removed three unreferenced pure helpers from `src/demo.ts` and `src/programTemplates.ts` (nine physical lines, seven code lines); exact-symbol searches found no callers. Demo environment validation, public routes, the template catalog, and its type import remain. After removal, `tsc -b` passed, as did 95 web unit tests and 30 gym-source parser tests. No tests, abstractions, or dependencies were added.
- The release-gate runner now rejects reused evidence folders, preserves both command and log-capture exit codes, enforces bounded timeouts, and inspects XCTest result bundles so inner skips become `INCOMPLETE`. Its service row is explicitly a static preflight. Stubbed runner checks confirmed an XCTest skip is recorded as incomplete and a failing `tee` cannot produce a pass; `bash -n` and the static service preflight pass. The metadata gate correctly remains failed by the legal-page blocker, including when `rg` is unavailable.
- Follow-up iPhone 17 Pro / iOS 26.5 reruns pass the leaderboard and XXL screen navigation audits after correcting stale test traversal/expectations. The previously unverified light-appearance strength layout audit also passes (1 test, 0 failures, 0 skips; `release-evidence/codex-release-final-20261029/ios.ui.strength_layout_light.log`). The screen audit covers Home bodyweight entry, recent PR detail, Track sections and Progress categories, forum filters, and profile routes. The accessibility-size photo-picker test now explicitly skips when the simulator exposes no selectable library image. A fresh iPhone 17 Pro simulator was seeded with an existing sample image, but its native picker still exposed no selectable item; verify image selection and cropping on a populated physical device. The full signed-account UI gates remain skipped by the release script.
- Focused logs and full unified gate report: `release-evidence/codex-release-final-20261029/`.
- The privacy metadata now records code-level analytics event names and payload fields, and distinguishes their manifest purposes. The October 26 App Store Connect record lists App Functionality for User ID, Fitness, and Product Interaction; the source manifest also lists Analytics for User ID and Fitness, while Product Interaction is Analytics-only. This is a historical comparison, not proof of today's App Store answers or production use. Owner review must approve the disclosure mapping and confirm actual use, retention/access/export, and provider logs before changing the manifest or App Store answers. The preserved build 49 archive from October 26 has a matching historical privacy manifest, but it is not the final candidate and its source snapshot was dirty; verify the final candidate archive afterward.
- The October 29 unified run passes the web gates, latest-iOS unit suite (415 tests), and unsigned Release build. It remains incomplete: App Store metadata fails while Privacy/Terms pages are blocked, isolated pgTAP fails because this machine lacks `/Library/PostgreSQL/15/bin/initdb`, oldest-iOS gates are skipped because no iOS 17 runtime is installed, and both full UI gates are skipped because signed-account readiness was not established. Service checks pass static wiring but APNs runtime secrets, notification delivery evidence, SMTP configuration, and production validation remain outstanding.
- Follow-up review of the accessibility UI failures found stale test assumptions: the leaderboard audit tapped before revealing controls and expected a nonexistent `leaderboard.filter.exercise` identifier; the Home audit required an optional `home.lastWorkout` card; its oversized PR card was required to fit wholly above the tab bar despite XCTest successfully scrolling it to tap; and the profile audit searched for the header-level Public Preview action by scrolling down. After correcting those assumptions, both the leaderboard and XXL screen navigation audits pass. The Photos picker still exposes no selectable image in this simulator, so the focused test skips and physical-device selection/cropping remains unverified.
- A read-only external-service audit confirmed that APNs source/Edge Function wiring exists but no production receipt was evidenced. `push_sent_at` can also be set for intentionally skipped notification kinds, so it is not universal proof of APNs delivery. SMTP readiness checks inspect local environment variable presence only; they do not connect to a provider. The July SMTP setup notes are historical. Next evidence should come from the owner verifying current production provider configuration, then an explicitly authorized controlled signup/recovery and physical-device push round trip. Do not use secrets in shell output or treat local reminders/debug runs as delivery proof.
- The backend audit found no current production migration-ledger comparison; local migrations extend through `202610130002`, while earlier production notes stop at `202607200001`. This does not prove production is missing later migrations. The safe next action is an owner-authorized read-only ledger/function/bucket-policy inventory, followed by staging account-isolation and media round trips. The local SQL harness remains blocked by the missing PostgreSQL 15 runtime; it must run on a suitable isolated local/CI host before relying on current pgTAP coverage.
- The focused photo-picker rerun is an explicit skip, not a selection-flow pass: on the seeded iOS 26.5 simulator the native picker returned no accessible selectable item. The test attempts selection/cropping when a selectable item is available and skips when none is exposed. A real-device photo selection, crop, save, and reopen check remains required.
- The current unsigned Release artifact audit found three UI-test launch hooks in the executable. Those hooks are now compiled only in Debug: workout-snapshot test persistence behavior, startup workout sync, and auto-opening a focused completed set. The targeted Debug fixture test `testExerciseTrendCanFocusExactSourceSetInWorkoutDetail` passes (1 test, 0 failures/skips); the rebuilt Release executable contains none of those three hook strings. A broader review found no other normal Release demo/mock entry point; the remaining `XCTestConfigurationFilePath` check only suppresses push registration in an XCTest launch. Production workout persistence and exercise/catalog data were retained. Bundle scan results, executable and Info.plist fingerprints, public Supabase configuration, URL-host review, and scan limitations are in `release-evidence/codex-release-refactor-final-20261029/ios.unsigned_release_bundle_audit.log`. This is an unsigned simulator artifact, not a signed-device candidate.
- A fresh complete gate run is in `release-evidence/codex-release-refactor-final-20261029/`: 10 pass, 2 fail, 3 skip. Web unit, standard/demo E2E, performance, build, route smoke, latest-iOS unit (415 tests), and unsigned Release build pass. The metadata preflight still fails on an unresolved launch-metadata blocker; pgTAP cannot start because PostgreSQL 15 `initdb` is absent; oldest-iOS unit/UI and full signed-account UI gates remain skipped. The focused-set UI test is supplementary and does not convert those full-suite skips to passes.
- The checklist's explicit iPhone 17 `build-for-testing` command passed; output is in `release-evidence/codex-release-refactor-final-20261029/ios.build_for_testing.log`.
- The October 29 live-site check confirmed the Support URL serves current contact and account-deletion instructions, so that URL checkbox is now complete. Privacy and Terms now render short client-side overviews (2,283 and 2,366 visible characters respectively), not the app's current 10- and 14-section legal documents. Both still require owner/legal approval, source/deployment identification, full approved publication, and rendered verification; see `release-evidence/codex-release-refactor-final-20261029/website-legal-live-audit.log`.
- A source review of all nine code-readiness rows found no additional clear implementation defect: profile-photo upload/cache, persisted workout-deletion IDs, bodyweight check-in RPC, account-scoped awards/PRs, field mapping, and Release missing-config handling are present. End-to-end rows remain open where staging, account restoration, server state, or candidate artifact evidence is required. A current tracked/untracked source and unsigned-bundle scan found no actual credential beyond the public Supabase client config and synthetic/mock test fixtures; scan scope and limitations are recorded in `release-evidence/codex-release-refactor-final-20261029/source-credential-scan.log`. The checklist credential row is checked for this checkout; repeat the scan on the final signed candidate.
- After the October 29 gate run, PostgreSQL 15.19 was built under `/tmp` with the real `pgcrypto`, `dblink`, and pgTAP dependencies. The unmodified backend harness reaches the migration chain and fails at `202609260001_staging_location_search.sql:61`: its `ON CONFLICT (country_code, region_code, ascii_name)` target does not match the older `location_cities` unique constraint. I corrected test-only defects in `202607240001_canonical_locations.test.sql` (derive the seeded region ID and count Miami rather than all prefix matches) and `202610040002_forum_integrity_and_bans.test.sql` (type empty argument arrays and inspect `pg_proc.proconfig`); `202610130002_forum_owner_edits_and_deletes.test.sql` now uses valid top-level update checks and stored function configuration checks. With only the migration seed insert made schema-tolerant in a temporary `/tmp` copy, the full backend harness passes two clean resets, every pgTAP assertion, and the concurrent gym-membership test. The unmodified migration-chain failure remains. Logs are `postgres-pgtap.log` and `postgres-pgtap-diagnostic-v8.log` under `release-evidence/codex-release-refactor-final-20261029/`. The tracked migration was not changed because its deployment status is unknown; confirm the remote ledger before changing an existing migration.
- A new unified run with the correct workspace Node path is recorded in `release-evidence/codex-release-continuation-fixedpath-20261029/`: 10 pass, 2 fail, 3 skip. Web unit, full web E2E (21), demo E2E, performance, production build, route smoke, latest-iOS unit (415), and unsigned Release build pass. The two failures are App Store metadata's unresolved legal-page blocker and the local migration conflict at `202609260001_staging_location_search.sql:61`. Oldest-iOS checks remain skipped because iOS 17 is unavailable, and full signed-account UI gates remain skipped because device/account readiness was not established. The local PostgreSQL runtime is now available; the backend failure is a migration conflict, not a missing binary.
- A current leaderboard audit found the client was replacing server ranks after filtering and rejecting canonical-city results because public profile cards do not contain `cityID`. Remote results now preserve server rank, and that redundant city-ID check is removed. The focused regression and latest-iOS unit suite (415 tests) pass; logs are `ios.unit.remote_city_rank_authority.log` and `ios.unit.after_remote_rank_fix.log` in the unified gate evidence folder. Remaining leaderboard gaps are in `docs/app-layout-audit.md`.
- The full unified release gate was rerun after the leaderboard correction in `release-evidence/codex-release-current-20261029/`: 10 pass, 2 fail, 3 skip. The corrected source passes web unit/E2E/demo/performance/build/route-smoke gates, 415 iOS unit tests, and the unsigned Release build. The remaining failures are legal metadata and the location-seed `ON CONFLICT` mismatch; iOS 17 and signed-account UI checks remain skipped for unavailable runtime/account setup.
- A follow-up leaderboard correction stops client-side re-filtering remote entries by fields already governed by the RPC, while retaining the returned lift evidence check. Production rep-count and experience filters are hidden because the RPC does not support them; demo controls remain. The focused regression and full latest-iOS unit target (415 tests, 0 failures) pass on iOS 26.5 (`release-evidence/codex-release-continuation-filter-authority-20261029.xcresult` and `release-evidence/codex-release-continuation-fixedpath-20261029/ios.unit.after_remote_filter_authority.log`). The mapper still defaults the internal public-profile model to Beginner, but public detail suppresses that value when years of experience are absent. Visible time-range wording still needs a product decision; see `docs/app-layout-audit.md`.
- The same source passes an unsigned Release simulator build (`release-evidence/codex-release-continuation-fixedpath-20261029/ios.release.after_remote_filter_authority.log`). This is a compile check, not a signed candidate or simulator sign-in check. `git diff --check` passes.
- The latest documented unified gate is recorded in `release-evidence/codex-release-after-remote-filter-authority-20261029/`: 10 pass, 2 fail, 3 skip. Current web suites, all 415 iOS unit tests, and unsigned Release build pass. Legal metadata remains unresolved. The gate's default backend step could not locate PostgreSQL; rerunning it with the local install path reached the migration chain and confirmed the `202609260001_staging_location_search.sql:61` `ON CONFLICT` constraint mismatch (`backend-pgtap-local-runtime.log`). iOS 17 and signed-account UI checks remain skipped for unavailable runtime/account setup.
- Runtime inventory confirms only iOS 26.5 is installed. `xcodebuild -downloadPlatform iOS -buildVersion 17.0` and `17.7` both reported unavailable from this Xcode download catalog; the oldest-iOS gate remains skipped pending an installable iOS 17 simulator runtime.
- The iOS build warning for capturing `AVAssetImageGenerator` in a sendable cancellation handler was removed by using AVFoundation's async `image(at:)` API. The existing demo profile-video UI performance test passed (1 test; three measured opens), the focused Debug build has no such warning, an unsigned Release build passed, and the current Release static analyzer completed without diagnostics. Evidence: `ios.ui.profile_video_thumbnail.xcresult`, `ios.release.after_thumbnail_cleanup.log`, and `ios.static-analyze.after_thumbnail_cleanup.log` in `release-evidence/codex-release-after-remote-filter-authority-20261029/`. Apple recommends this async API for Swift clients: [AVAssetImageGenerator.image(at:)](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image%28at%3A%29).
- Read-only diagnosis of the backend migration failure: `202607240001_canonical_locations.sql` creates `location_cities` with a four-column unique constraint including `geoname_id`; `202609260001_staging_location_search.sql` uses `CREATE TABLE IF NOT EXISTS`, then seeds using a three-column conflict target. On the canonical schema, PostgreSQL cannot infer that target. A safe repair must also preserve canonical alias search, which the staging migration's replacement `search_cities` omits. Check every environment's migration ledger and actual schema/data before choosing a repair; do not rewrite the September migration if it was applied anywhere. The audit was local only; no remote database was queried or changed.
- Read-only dead-code audit covered app/web source references, assets, npm dependencies, Swift package products, target membership, and Release test/mock entry points. It found no high-confidence source files, declarations, assets, or direct dependencies safe to remove. The two direct iOS packages (Supabase and MuscleMap) have current uses; TypeScript `noUnusedLocals`/`noUnusedParameters` checks pass. No code was changed for this audit.
- Supplemental iPad compatibility-mode UI checks on iPad (A16), iOS 26.5, both failed before release validation: the navigation audit failed its frame/hittability assertions, and the accent persistence test could not activate the Profile settings control after tapping the Profile tab. The screenshot shows the iPhone-targeted interface rendered in the iPad's 375-by-667 compatibility window, while XCTest's recorded frames/taps disagree with the visible layout. These results do not establish whether physical iPad taps fail; physical-device compatibility review remains open. Result bundles are `ios.ui.ipad_compat.xcresult` and `ios.ui.ipad_accent_compat.xcresult` in `release-evidence/codex-release-ipad-compat-20261029/`.
- Removed the unused private `liftSymbol` helper from `MainTabView.swift` and consolidated three identical workout-snapshot catalog fallbacks as `WorkoutExerciseSnapshot.fallbackCatalogExercise`. Also removed two test compiler warnings by asserting the expected nil submission and using a `Void` gate continuation. The full iOS unit target passes on iPhone 17 Pro / iOS 26.5 (415 tests, 0 failures, 0 skips); Release static analysis also succeeds without diagnostics. The only remaining build notice is Xcode's benign AppIntents metadata-extraction warning. Evidence is in `release-evidence/codex-release-swift-cleanup-20261029/ios.unit.swift_cleanup_final.xcresult`, `.log`, and `ios.static_analyze.swift_cleanup.log`.
- The unified release gate after that cleanup is recorded in `release-evidence/codex-release-verified-swift-cleanup-20261029/`: 10 pass, 2 fail, 3 skip. The six web gates, latest-iOS unit suite (415 tests), and unsigned Release build pass. App Store metadata fails on incomplete public legal pages; the local PostgreSQL harness reaches the known `202609260001_staging_location_search.sql:61` unique-conflict mismatch. Oldest-iOS tests remain skipped until iOS 17 installs, and signed-account UI gates remain skipped because their documented setup was not established. A preceding attempt at `codex-release-after-swift-cleanup-20261029/` lacked Node on `PATH` and the required `LIFTRANK_POSTGRES_ROOT`; its web/backend failures are environment setup errors, superseded by the verified rerun.
- After installing the iOS 17.0 simulator runtime, the full release gate was rerun with the verified Node/PostgreSQL paths in `release-evidence/codex-release-ios17-20261029/`: 11 pass, 2 fail, 2 skip. All six web gates passed; iOS unit tests passed on iPhone 15 Pro / iOS 17.0 (415/415) and iPhone 17 Pro Max / iOS 26.5 (415/415), and the unsigned Release build passed. App Store metadata remains blocked by incomplete public legal pages, and the backend suite reproduces the `202609260001_staging_location_search.sql:61` conflict mismatch. Signed-account UI checks remain skipped because their documented setup is not established. This closes the prior oldest-runtime test gap; it does not resolve migration, legal-page, signing, or device-validation blockers.
- Built a locally signed Release archive and exported an App Store Connect IPA from an immutable source snapshot as build 50. Both archive and export succeeded; `codesign --verify --deep --strict` passed on the archived and exported apps. The artifact reports bundle `com.liftrank.app`, version 1.0, build 50, iOS 17.0 minimum, production Supabase URL, production APNs, and Sign in with Apple. Snapshot, archive, IPA, SHA-256 fingerprints, and validation details are under `/tmp/liftrivals-release-candidate-build50-20261029/`; no upload or device installation occurred. Confirm the latest App Store Connect build and review this dirty source snapshot before promotion. This does not clear the legal-page or migration blocker, or signed-account/device testing.
- A broad latest-runtime UI run on iPhone 17 Pro Max / iOS 26.5 collected 89 cases: 76 passed, 12 failed, and one skipped. Nine production-account tests were explicitly excluded because signed-account setup was unavailable; the in-suite skip was the profile-photo picker check because the simulator had no selectable photo. Failures include the Settings dismissal test's stale navigation-bar selector, Me hub and calendar accessibility-query/runtime mismatches, plus leaderboard scope, signup validation, lift submission, tracker navigation/plans, weekly goal, unauthenticated routing, and workout-history filtering assertions. Full output and result bundle are `release-evidence/codex-release-ui-mocked-20261029/ios.ui.mocked.latest.log` and `ios.ui.mocked.latest.xcresult`. This broad suite is not a release pass; triage and focused reruns remain necessary.
- Corrected the Settings dismissal test's navigation-bar selector to match the actual `Settings` screen, then reran it alone. It still fails: tapping Done does not make the test's Settings navigation bar disappear, and the next measurement iteration cannot tap the underlying settings control. A second focused run tried calling the SwiftUI dismiss action directly, with the same outcome; that unverified app change was reverted. Results are `ios.ui.settings_done.focused.xcresult` and `ios.ui.settings_done.dismiss_fix.xcresult` under `release-evidence/codex-release-ui-mocked-20261029/`. The Settings flow still needs diagnosis.
- Follow-up focused UI checks resolved two failures from the broad run. The weekly-goal menu had been hidden inside a combined accessibility element; changing that card to contain its children keeps its Menu independently operable, and the focused Home-to-Progress consistency test now passes. The test also compares the displayed completed-day count instead of assuming a clean zero-history simulator. The lift-submission test now enters the required weight and repetitions before waiting for Submit; its result-flow test passes. Results are `ios.ui.weekly_goal.accessibility_fix.xcresult` and `ios.ui.submit_lift.focused.xcresult` under `release-evidence/codex-release-ui-mocked-20261029/`. The broader suite has not been rerun after these changes.
- After the goal-card change, the iOS unit target passes all 415 tests with no skips. The current source also passes an unsigned Release simulator build and Release static analysis; Xcode emits only its AppIntents metadata-extraction notice. Logs and result bundle are `ios.unit.latest.xcresult`, `ios.release.latest.log`, and `ios.static-analyze.latest.log` under `release-evidence/codex-release-ui-mocked-20261029/`. This is a simulator compile check, not a signed device candidate.
- A focused Me hub rerun confirms the profile tab remains `not selected` after the test taps it; a center-coordinate tap produced the same result, and the final accessibility hierarchy still showed Home selected. The new test asserts selection and targets the scroll view containing the Me header, but this test remains failed at `ios.ui.me_hub.coordinate.xcresult`. The prior broad run had reported an XCTest automation-type mismatch, so this needs a device/simulator-level interaction diagnosis before classifying it as a release product defect.
- The focused tracker-plans screen test now passes after aligning navigation and segmented-control queries with the current UI and using a short unique note marker. It verifies program-library entry, overview and notes navigation, note editing, saving, and display in the plan detail; the separate plan-open performance check also passed. Results are `ios.ui.tracker_plans.final_focused.xcresult` and `ios.ui.tracker_plans.focused.xcresult` in `release-evidence/codex-release-ui-mocked-20261029/`. The broad UI suite has not been rerun.
- The next broad mocked UI rerun collected 89 cases: 82 passed, six failed, and one simulator-only photo-picker case skipped. The failures were traced to stale UI-test assumptions or synchronization, not established product defects: adaptive-plan selection reused a picker query across a view update; signup-validation assertions used a narrow accessibility role and tapped while the keyboard obscured the form; the progress category name is a button label with content shown after selection; the logo is a labeled SwiftUI shape; and the workout-history tests assumed static text inside calendar buttons and a profile-section scroll view where the current UI renders a menu. The focused adaptive-plan and signup tests now pass (`ios.ui.adaptive_program_schedule.focused.xcresult`, `ios.ui.authentication_validation.keyboard_dismiss.xcresult`). Progress, unauthenticated-routing, and calendar checks passed in the subsequent focused run log `ios.ui.targeted_after_query_fix.log`; that run was interrupted before Xcode finalized its result bundle when the user cleared the goal. The workout-history filters focused result passed in `ios.ui.workout_history.focused.xcresult`; the later calendar accessibility assertion was corrected and passed in the interrupted run. A complete broad rerun is still needed to confirm the full suite together. Full prior-run results are `ios.ui.mocked.rerun.xcresult` and `.log` in the same evidence folder.
- The complete broad mocked UI rerun then finished with 89 cases: 86 passed, two failed, and the simulator photo-picker case skipped (`ios.ui.mocked.final_after_focused.xcresult`). All six failures from the previous run now pass. The active-workout custom-exercise flow passes in isolation (`ios.ui.active_workout_isolated.xcresult`). The performance flow reproduces in isolation: it opens the workout in two measured iterations, then the workout cover disappears and the Home resume card is not hittable; a separate focused rerun also intermittently loses the workout screen before its Finish control appears (`ios.ui.active_workout_performance_fixed.xcresult`). This is not merely a stale label assumption. The active-workout presentation path needs a product-level investigation before it can be called release-ready. No app-source change was made without identifying the dismissal cause.
- Follow-up isolated UI evidence confirmed Home's view-local full-screen cover could fail to remain presented after tapping Resume. Workout presentation now uses the existing `AppRouter.cover` path, hosted by `MainTabView`, for Home, Track, and workout-conflict actions. The performance test now checks the unique `Minimize workout` control rather than the workout name, which is also visible on the Home card. Focused results pass: Home resume and empty-workout completion (2/2, `ios.ui.active_workout_home_functional.xcresult`), Track custom exercise creation plus the 3-iteration workout-open performance test (`ios.ui.active_workout_router_cover_verified.xcresult`, with the latter intermittently failed in an earlier run), and an isolated repeat of the performance test (`ios.ui.active_workout_performance_router_final.xcresult`, 3/3 measurements, 2.90 s average). The latest full broad UI run remains 86/89 before this presentation fix; rerun the broad mocked suite after the current targeted changes to establish the updated aggregate result.
- Superseding October 29 check: the router-cover experiment was reverted after broad testing exposed regressions, so the current source again uses Home and Track view-local workout covers. A full iPhone 17 Pro Max / iOS 26.5 mocked run completed 89 cases: 84 passed, four failed, and the simulator photo-picker case was skipped; XCTest recorded seven failed assertions across those four cases. The workout-open performance and custom-exercise cases passed, but `testActiveWorkoutSetRestoresAfterAppRestart` still fails because tapping Resume leaves the app on Home. `testAccentColorPersistsAcrossRelaunch`, `testAdaptiveProgramScheduleChangesItsPreview`, and `testProfileShowsVerifiedScoreInPreferredWeightUnit` also fail while trying to leave Home; the accessibility hierarchy still reports Home selected, so treat these as a shared tab-navigation interaction needing diagnosis rather than assuming their downstream screen assertions are valid. Result: `release-evidence/codex-release-ui-mocked-20261029/ios.ui.mocked.final_local_cover.xcresult` and `.log`. The only retained test change from this investigation is the unique `Minimize workout` assertion in `testActiveWorkoutOpenPerformance`; no app-source presentation change is retained. Do not repeat the full suite until a targeted fix is ready.
- Isolated the workout-restoration failure once on the same simulator and source state: `testActiveWorkoutSetRestoresAfterAppRestart` passed (1/1; `ios.ui.active_workout_restore_repro.xcresult` and `.log`). The broad-only failure is therefore intermittent or state/order dependent; no presentation change is justified from the current evidence. Other tab flows in that same broad run passed (standard/accessibility/light screen audits, tracker active-workout entry, and tracker plans library), so the three Home-stuck failures also need targeted reproduction before changing navigation or weakening their assertions.
- Focused the three broad-run tab/profile failures together on the same iPhone 17 Pro Max / iOS 26.5 simulator: accent persistence, adaptive-plan schedule preview, and preferred-unit profile score all passed (3/3; `ios.ui.navigation_failures_repro.xcresult` and `.log`). Together with the isolated workout-restoration pass, this does not reproduce a deterministic failure in any of the four cases. No app or test assertion was changed from the broad result; retain the 84/4/1 broad aggregate as a flaky/inconclusive UI gate and investigate suite-order or simulator automation state before spending another full-suite run.

### Remaining release handoff — October 29, 2026

| Gate | Owner role | Evidence required to close | Current evidence/status |
| --- | --- | --- | --- |
| Public Privacy and Terms pages; App Store disclosures | Release owner with legal reviewer and website host owner | Identify the production source/deployment path; approve full current legal text; publish it to the exact Privacy/Terms URLs in App Store Connect and review notes; verify rendered pages and reconcile App Privacy purposes with production behavior and `PrivacyInfo.xcprivacy`. | The live pages were short overviews, not the full app notices; saved review notes include a stale privacy-notice URL. Legal/site approval and live verification remain open. |
| Migration ledger and backend security | Backend owner | Read-only inventory of production and staging migration ledgers, relevant constraints, aliases, and data; establish whether `202609260001_staging_location_search.sql` was applied anywhere; choose a forward-safe repair; pass the full clean local PostgreSQL/pgTAP suite and staging account/media round trips. | Local chain fails at the three-column `ON CONFLICT` target against the older four-column unique constraint, and the replacement search function omits canonical alias search. Remote ledger is not current in evidence; no remote query or migration was performed for this audit. |
| APNs, notification delivery, and SMTP | Provider owner with release owner | Redacted provider configuration evidence plus successful production-like APNs delivery and signup/password-recovery email delivery, including configured delivery secret and operational sender/domain. | Static wiring preflight passes; provider-side APNs and delivery evidence is missing. Custom SMTP is not configured in prior evidence. |
| Signed-account rehearsal | iOS QA and account owner | On the exact fresh signed candidate: verify signup, sign-in, Apple sign-in/account linking, recovery, session restore, onboarding/legal acceptance, account-scoped workout/media/ranking/report/block flows, and account deletion; retain redacted logs and build identity. | Build 51 is now signed and audited for the current source; no installation or signed-account rehearsal was recorded. Account/device UI gate remains open. |
| Physical-device and iPad validation | iOS QA/device owner | Record device model and OS; verify photo selection, crop, save/reopen, video upload/playback, background/foreground and keyboard behavior, sign-in/deletion, and required iPad compatibility. | Simulator photo selection was skipped because no item was selectable. Simulator iPad compatibility checks failed with frame/tap disagreement; physical iPhone validation is incomplete and physical iPad availability was not established. |
| Fresh signed candidate | Release engineering owner | After source freeze and release-gate fixes, archive/export the exact app-source snapshot; record source and IPA fingerprints, signing/profile, production backend, entitlements, minimum OS, and install/sign-in results. | Build 51 was archived/exported and audited from the current app-source snapshot. A later adjustment changed only the XCTest accent-persistence navigation/retry; it is not in the IPA. The candidate remains local and uninstalled; legal and migration gates plus physical-device/account validation remain open. |
| Full mocked UI gate | iOS automation owner | Re-run the broad mocked suite after the targeted selector corrections; retain result bundle and classify every failure/skip. | The latest full run executed 89 cases: 83 passed, 5 failed, 1 skipped on iPhone 17 Pro Max / iOS 26.5. Failures were `testActiveWorkoutOpenPerformance`, `testAdaptiveProgramScheduleChangesItsPreview`, and `testCompetitionFixtureShowsCurrentVideoAndLeaderboardPlacement`; extracted snapshots show missed navigation/selection taps. All three now have focused passing evidence after bounded test synchronization changes, but the broad aggregate has not been refreshed and is not a release pass. See the broad and focused result bundles below. |
| Oldest-OS UI automation | iOS automation owner | Run the mocked flows on the supported oldest OS with the XCTest runner starting successfully; retain a result bundle showing the tests actually ran. | Two focused iOS 17.0 attempts executed no cases: one failed to locate the UI-test runner with duplicate architecture destinations; an explicit arm64 retry timed out waiting for the Accessibility-loaded notification. This is an automation/runtime setup failure, not a product-flow result. Evidence: `ios.ui.failure_sequence_ios17.xcresult` and `ios.ui.failure_sequence_ios17_arm64.xcresult` under `release-evidence/codex-release-ui-mocked-20261029/`. |

- Current-source signed candidate 51 was archived and exported from an immutable repository snapshot. Archive/export and strict signature verification passed; Release static analysis also succeeded with only Xcode's AppIntents metadata-extraction notice. It identifies as `com.liftrank.app` 1.0 (51), minimum iOS 17.0, and production Supabase; it carries production APNs and Sign in with Apple entitlements, `get-task-allow` is false, the bundled privacy manifest matches the snapshot, and the Release executable scan found no service-role/private-key markers or Debug UI-test fixtures. Source tarball SHA-256 is `324387c19b3de55e5cb46fdc2abcb94957970f62c5bb792e887c324d382f42c8`; IPA SHA-256 is `23a2ab9cae6b35af5f49a28d7c65cfddf05882dd8f97a9d83852b2481259ceff`. Full validation is `/tmp/liftrivals-release-candidate-build51-20261029/validation.txt`. No upload, TestFlight installation, or account sign-in occurred; external release gates remain open.
- A five-case targeted sequence replayed the original failure neighborhood: accent persistence, custom exercise, workout restore, adaptive schedule, and profile score. Four passed; `testAccentColorPersistsAcrossRelaunch` failed while the Profile tab remained unselected and the app stayed on Home. That same accent test passed in the prior three-case focused run. This confirms the navigation/UI gate is intermittent; the XCTest snapshot also reports an automation-type mismatch. It does not establish whether the fault is simulator automation or a product interaction defect, so no assertion was weakened and no app navigation change was made. Evidence: `release-evidence/codex-release-ui-mocked-20261029/ios.ui.failure_sequence_repro.xcresult` and `.log`.
- To remove the unrelated Me-tab dependency from the accent-persistence test, it now opens Settings from Home and retries once if the Settings screen does not appear within two seconds, matching the existing Settings dismissal test's retry pattern. The accent test passed alone and in the five-case sequence after this adjustment. In that sequence, custom exercise then failed because the Track tab tap left Home selected, while workout restoration, adaptive schedule, and profile score passed. The test-only change is in `LiftRankUITests.swift`; app sources are unchanged. Evidence: `ios.ui.accent_persistence_home_retry.xcresult` and `ios.ui.failure_sequence_after_accent_fix.xcresult` in the mocked UI evidence folder.
- Historical candidate 51 comparison: at the time of that audit, the tree differed only in UI tests and this document. That statement is superseded: the current working tree has app-source and Xcode project edits, so candidate 51 validates only its archived snapshot and is not a current-source release candidate. Build and audit a fresh signed candidate after code-level blockers are resolved.
- The iOS 17.0 focused sequence could not initialize XCTest: the first attempt was ambiguous between arm64/x86_64 destinations and failed to launch the runner; the explicit arm64 attempt timed out waiting for Accessibility to load. No app test case ran. Do not count this as an iOS 17 UI result.
- After adding one selected-state retry to the custom-exercise Track entry, the same five-case failure sequence passed 5/5 on iPhone 17 Pro Max / iOS 26.5: accent persistence, custom exercise, workout restore, adaptive schedule, and profile score. Evidence: `ios.ui.failure_sequence_after_navigation_retry.xcresult` and `.log`.
- The refreshed broad mocked run completed on October 29, 2026, on iPhone 17 Pro Max / iOS 26.5: 89 cases executed, 83 passed, 5 failed, and 1 skipped (the signed-in production reviewer case). Failures: `testActiveWorkoutOpenPerformance` had two state assertions and could not find “Minimize workout”; `testAdaptiveProgramScheduleChangesItsPreview` could not tap “Plans”; and `testCompetitionFixtureShowsCurrentVideoAndLeaderboardPlacement` failed its fixture assertion. The accessibility-size strength audit took 133 seconds but passed; the suite completed in 2,808 seconds. This supersedes the earlier 84/4/1 aggregate and remains a failed UI gate. Evidence: `release-evidence/codex-release-ui-mocked-20261029/ios.ui.mocked.after_targeted_retries.xcresult` and `.log`.
- Failure attachment review showed the active-workout and adaptive tests remained on Home after their tab/resume taps, with XCTest reporting the legacy/modern accessibility automation type mismatch. The competition failure snapshot showed the exercise filter still set to Back squat and zero ranked lifters after the test tried to select Bench. The tests now verify/retry those specific state transitions. The focused verification run passed active-workout and competition flows (2/2); adaptive initially exposed a missed selection of “6 days,” then passed alone after verifying/retrying the two schedule selections. Evidence: `ios.ui.failure_verification_after_missed_taps.xcresult` (2/3) and `ios.ui.adaptive_program_schedule.retry_check.xcresult` (1/1) under `release-evidence/codex-release-ui-mocked-20261029/`. App source and signed candidate 51 are unchanged.
- A subsequent broad mocked run after those tap corrections did not finish. Its log contains 71 completed cases (64 passed, 7 failed), then stops as `testSettingsDoneDismissalPerformance` begins; the result bundle was not finalized, so this is not a suite aggregate. Captured failures were accent persistence, authentication validation, the competition fixture, Me Hub awards/public profile, searchable gyms, accessibility-size navigation, and set-entry row movement. The set-entry case passed a focused rerun (1/1) with a finalized result bundle, indicating an intermittent failure. Authentication reruns remain inconclusive: the iOS 26.5 accessibility bridge inconsistently exposes keyboard controls and the final hierarchy showed onboarding where the test expected auth; no app-source change was retained. Evidence: `ios.ui.mocked.after_missed_tap_retries.log`, incomplete `.xcresult`, and `ios.ui.set_entry.followup.xcresult` under `release-evidence/codex-release-ui-mocked-20261029/`.
- Snapshot review showed the competition, gym-directory, and Me Hub failures followed missed Profile-tab or Awards-link transitions. The UI tests now wait for the Profile header, retry the tab/link once if the destination does not appear, and query NavigationLinks without assuming a button type. These three focused flows pass 3/3 on iPhone 17 Pro Max / iOS 26.5; the full mocked suite still needs a fresh run after all remaining corrections. Evidence: `ios.ui.me_navigation_followup.xcresult` in the same folder.


## Build 50 upload — November 1, 2026

At the owner's explicit request, the current workspace was archived as version
**1.0 (50)** and uploaded through **Xcode Organizer → Distribute App → App Store
Connect**. Xcode displayed “App upload complete: LiftRank 1.0 (50) uploaded”;
confirmation was observed at approximately 21:32 UTC (4:32 p.m. Eastern).
The final confirmation window was left open. App Store Connect processing,
TestFlight tester availability, and App Review were not separately completed or
verified by this upload task. Existing public-release gaps remain open.

GPT-6 Luna performed the production archive and artifact checks. The app uses
`com.liftrank.app`, the production Supabase backend, production APNs, Apple Sign
In, and the existing Apple Distribution identity/profile for team `32TGWTQNP8`.
Strict signature verification passed. The only archive warning concerned
App Intents metadata extraction with no AppIntents dependency.

Evidence is preserved in `work/release-build-50-20261101/`: the archive,
source-input snapshot and fingerprint, source revision/status, archive manifest,
signing checks, build log, and upload confirmation. The app executable hash is
`1f3a2a76338e695ba4a0bc9d8e50057046f801aef8f5bac07a8d6ad4ecf163c0`.
The source snapshot hash is
`d2cc7175806ea4d7bfc38517b7c77bbf11de45d035ab9f398559840881929247`.

Only the app build number changed from 49 to 50 for packaging; prior uncommitted
implementation was preserved. No new app files, abstractions, or dependencies
were added. Generated archive/source/evidence files support release traceability.
AdMob remains a documented placement plan, not an integrated SDK. No backend
migration, live-data change, phone installation, or App Review submission occurred.

## Build 51 — earlier archive and failed upload attempt — November 1, 2026

At the owner's request to publish the conflict-copy and theme blank-screen
fixes, the app build number was advanced from 50 to 51. Luna archived the current
workspace with the existing Apple Distribution profile, production backend,
production APNs, and Apple Sign In. Strict signature verification passed. The
focused sync and theme checks are documented in `docs/app-layout-audit.md`.

The archive, source snapshot, signing report, and build log are preserved in
`work/release-build-51-20261101/`. Only packaging version numbers changed in
this upload turn; no new app files, abstractions, or dependencies were added.

**This earlier archive was not uploaded.** Xcode command-line distribution failed at the App Store
Connect account/provider step (`App Store Connect Credentials Error`, unexpected
nil `Actor/relationships/providerId`). The Organizer fallback could not proceed
because the Mac was locked and automatic unlock failed. The owner was asked to
unlock the Mac. That archive predates the subsequent Progress polish and is
retained as historical evidence; it must not be used for the updated release.
See `upload-status.txt` and `xcode-distribution-upload.log` in the evidence folder.

## Build 51 with Progress polish — uploaded — November 1, 2026

After the owner unlocked the Mac, Luna rebuilt the current source as **1.0 (51)**
with the Progress polish, conflict-copy fixes, and theme blank-screen fix. The
fresh archive is `work/release-build-51-progress-20261101/LiftRank-1.0-51.xcarchive`;
the earlier archive was preserved and was not used for this upload.

The Release archive, production backend/APNs, existing Apple Distribution
identity/profile, Apple Sign In, and `get-task-allow=false` were verified. Strict
signature verification passed and the app/dSYM UUIDs match. The focused simulator
checks associated with the changes are recorded in `docs/app-layout-audit.md`;
the full suite and live-account/physical-device checks were not rerun for packaging.

Xcode Organizer → Distribute App → standard App Store Connect distribution
displayed **“App upload complete: LiftRank 1.0 (51) uploaded”** at approximately
9:57 p.m. Eastern on November 1 (02:57 UTC November 2). The confirmation window
was left open. This confirms upload, not completed Apple processing or TestFlight
tester availability. App Review was not submitted; existing public-release gaps
remain open.

Release evidence is in `work/release-build-51-progress-20261101/`, including the
archive, source snapshot/fingerprints, signing summary, build log, and upload
confirmation. Source snapshot SHA-256:
`b7675d877be13a57a43c9af249b3f5402d9fe04011368cb756bb2863525029c4`.
Archived executable SHA-256:
`a5aa880d404e9c19966aaa330cd6121dfa4adb71f8446818e1dbd524494d2ee2`.

No app-source changes, new app files, abstractions, or dependencies were needed
for this upload. The new archive and verification records preserve the exact
release inputs and outcome. No backend deployment or phone installation occurred.

## Build 51 plan-sync server correction — November 1, 2026

After production logs confirmed a denied plan DELETE from build 51, the owner
explicitly approved applying `202611010003_workout_plan_owner_delete.sql` to
LiftRank Production (`ikjgbsrlriqiusuvezco`). The correction grants DELETE to
authenticated users under the existing owner-only policy; it does not change
that policy. It and its migration-history record were committed atomically.
Read-back confirms the privilege and migration record, row security enabled,
and authenticated bypass disabled. No new app binary was needed. Luna's eight
focused SQL security assertions passed on both local resets. On November 2,
2026 (Eastern), the owner confirmed the physical-phone Retry result:
**“Sync succeeds; error is gone.”** This closes the reported sync-error check.
See `docs/app-layout-audit.md` and
`work/progress-polish-20261101/verification.txt` for evidence and limits.


## Full release audit — November 2, 2026

**Decision: NO-GO for public App Store release.** A successful compile or
TestFlight upload does not close the known data-recovery, moderation, server
rollout and acceptance gaps below. This audit covers the current local iOS
candidate, its supporting services and public release surfaces. No code fixes,
production changes, uploads, purchases or submissions are authorized by this
audit alone, and none were performed in this audit.

### Candidate and evidence boundary

- App target source: version **1.0 (51)**, iOS **17.0+**, iPhone-only target,
  portrait orientation. Debug targets staging; Release targets production.
- Last recorded uploaded candidate: November 1 build 51 from
  `work/release-build-51-progress-20261101/LiftRank-1.0-51.xcarchive`.
  Current filters, goal editor and Settings changes postdate that artifact.
  The next upload needs a higher unused number, verified in App Store Connect.
- Working tree contains substantial modified/untracked application, tests and
  migrations. Preserve an immutable source snapshot and fingerprint for the
  actual final candidate. Neither a Git HEAD nor an old archive proves this tree.
- Current work is a source/configuration and evidence audit with bounded Luna
  verification. Live App Store Connect settings, remote migration ledgers,
  two-account privacy, signed physical-device workflows and real moderation
  operations were not freshly certified.
- iOS 17.0 and 26.5 runtimes are installed per Luna's fresh inventory. Older notes
  saying only iOS 26.5 is installed are stale. Installed is not tested.

### Prioritized release blockers

| ID | Priority / status | Finding and release impact | Closure evidence |
| --- | --- | --- | --- |
| REL-01 | High · confirmed source mismatch | Local changes retain already-uploaded build number 51; older release-policy metadata still calls 49 current. No signed frozen candidate exists for these latest changes. | Freeze exact source, assign next unused build, record configuration/backend/signature/entitlements, matching dSYM and hashes, validate new archive. |
| REL-02 | High · confirmed defect paths | Settings could submit stale unrelated profile fields; failed PR evidence uploads could lose their retry file. See SET-15/16 in app-layout-audit.md. November 3 local fixes are recorded below: video retry passed focused verification; Settings protection requires its new server endpoint and acceptance before release. | Focused fixes plus independent stale-profile and failed-evidence recovery tests; preserve existing lift IDs and media until upload acceptance. |
| REL-03 | High · confirmed defect paths | Delete-account server cleanup can remove media before later account deletion fails, and the app has no explicit recent-auth recovery flow (SET-19/20). | Disposable-account deletion success, reauthentication, partial-failure/resume and repeated-request evidence, including Apple account handling. |
| REL-04 | High · source + unverified rollout | Client exposes shared workout stats, friend activity, self-reported ranking and Forum media while deployment/acceptance for their corresponding migrations is not established for this candidate. The known shared-stat RPC absence is prior production evidence, not a fresh remote inventory. | Read-back inventory per environment; approve only needed forward migrations separately; security tests and two-account end-to-end checks after deployment. |
| REL-05 | High · confirmed screening gap | Forum is enabled in focusedProduction. Media posting uploads directly then inserts a visible post. No integrated media-screening/approval step exists in that path; the selected screening service remains a plan. A generic client text filter elsewhere is not proof of a protected Forum publishing pipeline. | Enforced filtering/approval before publication, report/block flows, accountable admin moderation, appeals/contact and response operations; photo/video and bypass/security checks. |
| REL-06 | High · unresolved disclosure/release evidence | Public full Privacy/Terms text and App Store privacy-purpose parity remain unverified. Historical rendered policy was only an overview; the current web reader could not fetch Privacy, Terms or Support. Fetch failure does not prove outage. Local launch metadata still marks legal URLs blocked. | Verify rendered full production pages and deployment ownership, reconcile actual collection/optional analytics/processor use with App Store Connect, confirm support reaches a maintained channel. |
| REL-07 | High · missing current security acceptance | The normal repository migration/security suite passed two clean resets on November 3 after the explicitly approved historical seed correction and forward city-search repair. Real two-account staging acceptance remains incomplete; local SQL results do not establish live deployment behavior. | Standard isolated migration/security suite plus account A/B ownership, private media, block/report, role/admin authority and account switching. No live user data needed. |
| REL-08 | High · missing device/auth acceptance | Latest binary lacks signed-device sign-in/restore, email confirmation/recovery, guest upgrade, offline restart/sync, workout completion and Settings acceptance. Unsigned simulator cannot establish keychain/session correctness. | Exact candidate on small/large physical phones; signed staging session round-trip and production TestFlight smoke without erasing user data. |
| REL-09 | Medium · unverified service operations | Static push/SMTP configuration is not proof of delivery. Generic sender changes, scheduling, failed revocation and recipient ownership need rollout/acceptance. Forum/message push is skipped by the checked-in focused sender despite Forum being enabled. | Signed APNs foreground/background/denial/Focus/account-switch tests; real confirmation/recovery delivery; align advertised events with sender behavior. |
| REL-10 | Medium · accessibility/performance evidence | Selected large-text/demo tests exist, but final Settings grouping, all themes, VoiceOver/Voice Control, small-phone/iPad compatibility, memory/energy and production cold-start/offline performance lack full candidate evidence. | A bounded task/device/accessibility matrix, real performance measures, and honest App Store accessibility declarations. |
| REL-11 | Medium · release operations | Exact-candidate reviewer account, review notes/screenshots, age rating, media rights, support/moderation ownership, rollback and crash monitoring sign-off are incomplete. The repo requires seven stable external TestFlight days and 99.5% crash-free sessions; no matching candidate evidence is recorded. | Verified reviewer access and assets, rights inventory, operational owners and rollback rehearsal, dated external-beta reliability report. |

Apple's current review guidance was read during this audit. It requires working
backend access and complete review access, and UGC safeguards including filtering,
reporting, blocking and reachable contact information. These findings are an
engineering readiness assessment, not a prediction of Apple's decision:
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

### Whole-product coverage matrix

| Area | Current evidence | Remaining acceptance |
| --- | --- | --- |
| Launch, authentication, onboarding, legal | Environment isolation and keychain requirements traced; historical real-phone sign-in succeeded. Current compile/test outcomes recorded below. | Exact candidate cold/warm launch, Apple/email/guest, expired session, recovery and reinstall restoration. |
| Home and navigation | Prior demo screen matrix and theme-blank correction exist; current source uses native tabs. | Current smoke result below; production populated/empty/offline states, interruptions and deep links. |
| Workout tracking | Historical start/resume/set-entry/finish/history checks; active workout stores its own unit. | Exact candidate force-quit/restore, offline save/sync, set/weight precision, rest alerts, failure recovery and no duplicate history. |
| Plans and library | Filter polish local; user confirmed production plan Retry succeeds after approved owner-delete grant. Distinct retained plan renamed without deleting content. | Multi-device competing edits, copy reconciliation, pending delete/retry, plan switching/schedules and catalog/source accuracy. |
| Progress, goals, awards | Recent focused goal lifecycle passed; chart/goal selection separated. | Real account history hydration, trend/estimated-1RM correctness, bodyweight changes, award idempotency and populated-screen performance. |
| Rankings and public profiles | Server-authority design retained; owner preview permission issue previously resolved. | Deployed ranking contracts, metric/rep/filter/pagination correctness, blocked/private audiences, shared-stat preview completeness. |
| Forum, posts, photo/video, admin | Source media path and enabled feature reviewed; report/block/admin intent documented. | REL-04/05/07. No real posts, media transfers or moderation actions were made during audit. |
| Me and Settings | Recent 1/1 Settings workflow and 2/2 account-exit tests; final grouping compiled. | Remaining SET findings, failed sign-out injection, current all-theme/accessibility visuals and actual account flows. |
| Local cache, sync and data safety | Canonical storage/service boundaries traced; current unresolved stale-write/media-loss paths called out. | Server/local reconciliation, full migration chain, multi-account isolation, recovery and export/delete semantics. |
| Privacy and security | Manifest declares nine linked categories, no tracking; production analytics has per-account/device consent guard. | App Store parity, server policies/roles, retention/deletion, third-party processing and candidate-bundle inspection. |
| Permissions and notifications | Library media uses PhotosPicker; no direct camera/microphone request found in app source. Do not invent a missing camera purpose-string bug. | Device permission/delivery checks; no live prompt or token mutation during audit. |
| Packaging, web and operations | Build 51 upload historical; checked-in Pages workflow publishes React dist, not proof of the separate legal-site source. AdMob is not integrated. | REL-01/06/11 plus current verification results below. No advertising readiness claim. |

### Verification results

Luna is collecting current static services, metadata, unsigned Release compile,
unit/screen smoke and practical local web/backend evidence in
`work/release-audit-20261102/`. Results must be appended explicitly. Unrun,
blocked and skipped gates are **not passes**. The full release-gates orchestrator
was not represented as successful: signed-account UI, device, production service,
legal and operational prerequisites remain incomplete.

No application source was changed for this audit. Existing readiness documents
are the report owner; generated logs/artifact inventories are necessary evidence,
not new application abstractions or dependencies.


### Current verification outcomes — November 2 audit

- **PASS with warnings:** static services preflight (exit 0). APNs/SMTP
  credentials/delivery warnings remain external gates, not confirmed provider
  failures. Evidence: `work/release-audit-20261102/services-preflight.log`.
- **FAIL / release blocked:** launch metadata check (exit 1), retaining existing
  Privacy Policy/Terms parity blockers. This is a metadata readiness failure,
  not proof that the URLs currently return HTTP errors. Evidence:
  `work/release-audit-20261102/launch-metadata.log`.
- **PASS, compile only:** unsigned Release simulator build, version 1.0 (51),
  production URL `https://ikjgbsrlriqiusuvezco.supabase.co`, production APNs
  Info.plist value. Simulator signature is ad-hoc, not a production distribution
  signature or valid live-auth acceptance artifact. App:
  `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphonesimulator/LiftRank.app`.
  Executable SHA-256:
  `37dd6cc69fd0641dba5936504a4d9f837f23543c45dad754b064a3b3ee98948a`.
  Log: `work/release-audit-20261102/unsigned-release-simulator-build.log`.
  This Release artifact was not installed or used to sign in.
- **INCOMPLETE:** unit-suite attempt initially hit restricted SwiftPM cache
  access. Elevated invocation built the Debug host, briefly lost the simulator
  service, recovered and emitted many passing cases across clone runners.
  It then stopped producing results while CoreSimulatorService remained
  disconnected. No finalized summary was available within the bounded wait;
  termination was requested. Individual streamed passes are not a full-suite
  pass, and an output tail without failures does not establish zero failures.
  No additional UI/web suite was started. This gate remains incomplete.
- **UNRUN:** oldest iOS 17 unit/UI gates, full latest UI suite with signed
  staging accounts, real physical-device matrix and backend/provider acceptance.
  Existing Settings 1/1, exit 2/2 and goal lifecycle evidence remains focused
  historical evidence, not a fresh full-suite pass.
- **INCONCLUSIVE:** web reader fetches of the public Privacy/Terms/Support pages
  were unavailable in this audit. No page outage, content parity or support
  delivery was established by those fetch attempts.

The source audit is complete at the coverage level documented above. Release
validation remains incomplete and the decision stays NO-GO. Close confirmed
data-loss/recovery and moderation defects first, reconcile server capability
rollout, then rerun the standard security and signed-account/device gates on
one frozen candidate. Only after metadata/privacy/operations sign-off should a
new archive be validated and distributed. No automatic production deployment
is part of this order of work.


## Release fixes started — November 3, 2026

REL-02 video-recovery implementation is local and passed focused Luna
verification. The PR queue now retains the already-created submission ID and
local file when the lift saves but evidence upload fails. Retrying a queue item
with a submission ID calls a dedicated evidence retry on the existing
CompetitionStore; it does not submit another lift. Successful evidence upload
updates cached evidence state and removes the local retry file; another failure
retains it. A missing local URL becomes an explicit failure instead of falling
through to new-lift submission. The existing submitter protocol gains one
operation for this real distinct step; no new service/type/file/dependency was
introduced in application code. Existing test doubles were updated and one
test-only sequenced media-upload fixture exercises repeated failure followed
by success without a live upload.

Luna ran `testWorkoutPRVideoRetryKeepsFailedEvidenceAndReusesSubmission`:
**1/1 passed, 0 failures** on November 3. It covers initial upload failure,
another failed retry, successful retry against the same lift ID, local-file
cleanup after success, and missing-video rejection without a duplicate lift.
Log: `work/pr-video-retry-missing-url.log`. Result:
`/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.03_01-39-03--0500.xcresult`.
This focused regression is not a full-suite, physical-device, or live-server
acceptance result. Local snapshot-write failure and interrupted server-response
recovery are not established by this test.

This is the first fix within REL-02, not closure of that entire gate: stale
profile updates remain open and need a field-scoped, concurrency-aware server
write rather than another broad client snapshot. The other release gates remain
open. Build number/frozen archive work belongs after implementation settles;
no production migration, moderation-provider activation or distribution occurred.

### Settings overwrite protection — local implementation, November 3

The authenticated Settings screen now uses a dedicated field-scoped save rather
than `saveEditedProfile`. It records the values shown when Settings opens and
sends only modified preferences with their expected previous values. The new
`save_own_settings` RPC locks the account rows, validates an explicit settings
allowlist, and checks all changed fields before writing any of them. A conflicting
edit is rejected; an identical retry is accepted. Name, biography, avatar,
location, body measurements, gym membership and authority fields are not writable
through this endpoint. Privacy defaults are normalized before computing changes.

The UI retains unsaved edits after a failure and offers **Reload saved settings**
to review current server values. Successful readback updates the controls while
preserving edits queued during the request. Demo mode retains its existing local
save path. There is no fallback to the unsafe broad save when the new RPC is
unavailable.

This implementation requires the new forward-only migration
`supabase/migrations/202611030001_settings_compare_and_set.sql`, including its
existing training-sharing column prerequisites. Do not distribute this client
before the required migrations have been verified and explicitly approved for
the intended environment. No remote database was changed. Luna's local runtime
SQL attempt is **BLOCKED before assertions**: the installed temporary PostgreSQL
distribution is missing `share/postgresql/postgres.bki`, so `initdb` cannot create
the isolated test cluster. Log: `work/settings-cas-local-harness.log`. The new
25-assertion security regression is authored but unrun; no migration/security
pass is claimed and deployment remains blocked. Luna's focused Swift run
recovered after a Simulator service interruption and **passed 2/2, zero failures**:
snapshot normalization/changed-field/explicit-null encoding and ProfileStore
server-readback/account-switch protection. Result:
`/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.03_01-55-37--0500.xcresult`;
log: `work/settings-cas-focused-tests.log`. Final generic Simulator
`build-for-testing` **passed**, including both architectures and the final
baseline-based unsaved-edit check; log:
`work/settings-cas-build-for-testing.log`. This is compilation evidence, not
signed-account or database acceptance. The single demo Settings UI walkthrough
**failed: 1 test, 2 assertions**. The log shows failure waiting for the
**Accent color** navigation bar after returning from Color theme, followed by
a failed attempt to tap that missing bar's button. Log:
`work/settings-cas-demo-ui.log`. Cause remains unresolved; neither a stale test
locator nor a product navigation defect has been established. The finalized
failure hierarchy still shows Appearance with an enabled Accent color row after
the recorded tap, not the expected destination. Evidence:
`work/settings-cas-failure-attachments/27F72958-7DEF-462A-8C38-B0AE625D55A9.txt`;
result: `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.03_02-03-43--0500.xcresult`.
The evidence does not distinguish an ignored tap from a navigation return.
No additional UI
run was made. The broader profile editor
and older clients still use the full-profile endpoint; this is Settings-specific
protection, not a claim of universal concurrent-edit protection.

New application structure: one `ProfileSettingsSnapshot` value type and one
service operation keep preference comparison and persistence out of the view.
No dependency was added. A new forward migration is necessary because applied
migrations must not be edited; a matching SQL security regression file documents
and exercises the new endpoint's permissions and conflict behavior.

### Accent navigation and database test repair — November 3, verified locally

**Accent navigation: PASS. Database suite: PASS.** Luna performed compilation
and verification; these results do not close the remaining release gates or
authorize remote deployment.

Appearance now routes Color theme and Accent color through explicit value-based
destinations registered outside the conditional Form. Both retain native Back
navigation and their existing selection behavior. One private route enum and
two existing-screen view properties replace the embedded link destinations;
no application file or dependency was added.

Luna manually verified Color theme → Back → Accent color, changed Lime to
Orange, reopened the picker to confirm the saved selection, then restored Lime.
The focused automated `testSettingsCloseDismissalPerformance` also **passed**:
1 test, 0 failures, 145.119 seconds. It covers the Accent selection/reopen/restore
regression and the existing Settings workflow. The dedicated Workflow Audit
simulator ran iOS 26.5 with a Debug demo build, isolated derived data and parallel
testing disabled. No real-account sign-in was tested and no simulator data was
erased. Earlier attempts stalled at launch; the final run completed after the
Mac was unlocked and kept awake. Manual evidence:
`/tmp/liftrivals-workflow-audit-accent-restored.png`.
Automated log: `work/settings-navigation-final-20261103.log`.
Result bundle:
`/tmp/liftrivals-settings-isolated-derived/Logs/Test/Test-LiftRank-2026.11.03_07-16-21--0500.xcresult`.

Read-only Supabase dashboard inspection confirmed `202609260001` is recorded
in staging (`dfpvamnucwyafxklnjwt`) and absent from the production ledger
(`ikjgbsrlriqiusuvezco`). The user explicitly approved a narrow historical-source
exception on November 3: **“Approve local historical-file correction.”** The
reviewed seed correction replaces the incompatible three-column conflict target
with an existing-city check and untargeted conflict handling. Its version and
the remaining SQL are unchanged. Approval applies only to repository source,
not to executing migrations remotely. The reviewed patch remains at
`work/location-migration-repair-20261103/historical-seed-fix.patch`.

The new forward migration
`supabase/migrations/202611030003_restore_canonical_city_search.sql` restores
canonical alias-aware city search overwritten by the staging migration,
preserving location IDs and data. This separate forward correction supports
existing deployments; neither staging nor production was modified.

Luna restored PostgreSQL 15.19 with OpenSSL, pgcrypto and dblink at
`/tmp/liftrivals-pg15-repair/install`. The existing test runner now detects
missing bootstrap or extension files before initializing a cluster. After the
approved source correction, the normal repository
`scripts/test_backend_foundation.sh` passed **both clean resets**, including
concurrent gym-membership checks. Each reset passed Settings compare-and-set
25/25 and canonical locations 18/18, including non-prefix alias matching, fixed
search path and caller grants. TAP plans matched, with no failed assertions,
bailouts or plan-count errors. No temporary migration substitution was used.
Evidence: `work/settings-database-final-20261103.log`.

Remote migration rollout and live two-account staging acceptance remain
separate, pending release work. Do not distribute clients that require the new
Settings endpoint before its approved environment rollout.

## Build 52 — uploaded to internal TestFlight — November 5, 2026

At the owner's explicit request to distribute using Xcode, the current workspace
was frozen and archived as **1.0 (52)**. Xcode Organizer recorded successful App
Store Connect validation at **10:06:36 p.m. Eastern**, then successful upload at
**10:08:32 p.m. Eastern**, with no validation or upload warnings. The distribution
screen identified **TestFlight (Internal Testing Only)** and ended with
**“App upload complete: LiftRank 1.0 (52) uploaded.”** Apple processing, tester
availability, and installation were not independently verified. No App Review
submission was performed.

The archive uses `com.liftrank.app`, production Supabase, production APNs, Apple
Sign In, and the existing Apple Distribution identity/profile for team
`32TGWTQNP8`; `get-task-allow` is false. Strict signature verification passed,
app/dSYM UUIDs match, and the privacy manifest matches the frozen source. The
narrow bundle scan found no private-key PEM markers, staging project identifier,
or Debug UI-test launch flags. Dependency versions remained locked. The archive
warning was limited to skipped AppIntents metadata extraction with no framework
dependency. Service static preflight passed with the existing provider-evidence
warnings; this upload does not close full device/account or public-release gates.

The earlier Settings rollout blocker was resolved before this archive: the owner
approved the shared-stats, friend-activity, and Settings compare-and-set migrations
for production. All three were applied together, with private/off sharing defaults;
live settings save/readback and restoration to the original preference succeeded.
The preceding app-fix pass records four focused unit passes, onboarding and plan
UI checks, all ten toggle persistence checks in the separate audit account, manual
light/dark review, and two clean SQL-suite resets (101 Settings assertions each).
The full test/device matrix was not rerun during packaging. Details are in the
November 5 collected-fixes section of `docs/app-layout-audit.md`.

Evidence: `work/release-build-52-20261105/` contains the frozen source tarball and
file manifest, archive, build/preflight logs, signature/configuration audit,
Organizer distribution metadata, and upload confirmation. Organizer's archive is
`/Users/robertjeanty/Library/Developer/Xcode/Archives/2026-11-05/LiftRank-1.0-52.xcarchive`.
The executable matches the preserved archive byte-for-byte.

- Source snapshot SHA-256: `1efa6291103d7bc42777302f948dfc8ff564b821e0b880c25cd6cce5bdfe0dac`.
- Archived executable SHA-256: `7f0a6e74fa70d3289b111bc0020ce76c8effc973dc7b6a04cda312f9449006c7`.
- App/dSYM UUID: `A3CA534E-BD1E-3B43-AAA8-D532C88E0B94`.

Only the app build number changed in this distribution turn. No new app files,
abstractions, or dependencies were added. Generated source/archive/evidence files
preserve the exact release inputs and Xcode's result. Existing uncommitted work
was preserved; no additional backend changes or phone installation occurred.
