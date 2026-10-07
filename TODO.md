# Lift Rivals product TODO

## Feature-first execution board

This is the single prioritized queue. The detailed sections below are evidence and acceptance checklists, not a second queue. Keep implementation ahead of release verification, and move work from one phase to the next only after its user-facing behavior is complete.

Status: `[>]` active slice, `[ ]` queued, `[x]` complete. A parent remains open while any required behavior or acceptance evidence is missing.

### Phase 0 — data safety and foundations

- [x] **Backdated workouts:** calendar entry supports prior dates for freestyle and planned sessions while preserving source-session identity.
- [x] **Sync and bodyweight authority:** local/syncing/attention states are visible, retries are available, and the latest logged bodyweight is the shared source for profile and Home displays.
- [ ] **Release blockers:** finish owner/viewer privacy verification and the complete regression gate before distribution.

### Phase 1 — core training experience (active)

- [x] **Tracker workflow:** planned, active, missed, skipped, shortened, rest, and backfilled sessions are resolved and covered by focused simulator regressions.
- [x] **Progress analytics:** empty, one-point, offline, and stale-data states retain actionable structure and are covered by focused regression/build evidence; calendar boundaries and lifter-focused analytics remain useful for powerlifters and bodybuilders.
- [>] **Exercise identity and icon audit:** finish the visual catalog review and replace weak/shared fallbacks consistently in picker, tracker, plan, profile, leaderboard, and submission surfaces.
- [ ] **Home command center:** compact program consistency and weekly goal presentation; task-oriented alerts for missed sessions, plateaus, recovery, unusual volume, sync, and milestones without duplicating Progress.

### Phase 2 — identity and privacy

- [ ] **Personal/Public Profile:** keep private training history separate from the shareable athlete card, with explicit empty/partial/populated states and source labels.
- [ ] **Settings:** complete privacy precedence, history/source behavior, legal/support entry points, and persistence/error feedback for every user-facing control.

### Phase 3 — competition and community

- [ ] **Leaderboards:** finalize verified versus self-reported semantics, 100-row pagination, location coverage, filters, ranking states, lift detail, and unverified removal after video attachment.
- [ ] **Forum:** finalize the neutral hub and All/For You/Following feeds, nested replies, voting, reports, moderator-only tools, notifications, abuse safeguards, and authenticated acceptance paths.

### Phase 4 — retention and polish

- [ ] **Gamification:** retain workout-finish celebrations and weekly goals, then add owner-controlled badges, balanced challenges, rewards, and public/private presentation without incentivizing unsafe volume.
- [ ] **Training catalog completeness:** add missing machine/exercise variants (including dumbbell bench press and iso-lateral movements) and preserve consistent identity across all surfaces.

### Phase 5 — verification and distribution (last)

- [ ] Run empty/one-point/offline/stale/populated-account checks, owner/viewer/moderator acceptance, simulator and physical-device checks, and release notes.
- [ ] Verify the actual candidate build contains the completed feature queue, then distribute through Xcode/Transporter/TestFlight.

### Execution rule

Work only on the current `[>]` slice in this execution board. A `[>]` marker in a detailed reference section means that evidence is still incomplete; it does not create a second concurrent workstream. When the active board item is complete, promote the next item in order and record build/test evidence under its reference section. Do not mark a parent complete merely because its source code compiles; the behavior must be visible in the intended user flow.

## Implementation ledger by phase

These sections retain the detailed acceptance criteria and implementation notes. Their original order is not the work order; follow the feature-first queue above. Release and verification gates are intentionally last.

### Phase 0 reference — Safety, data, and release blockers

- [x] Verify workout sync states: local, syncing, synced, and needs attention; surface the state on Home and retain failed uploads for retry.
  - [x] Local-only Home and Progress states now include the pending workout count, making unsynced data visible instead of generic; build/install/launch verified at `/tmp/LiftRivals-sync-copy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Verify profile bodyweight and bodyweight-history records stay synchronized after save, reload, and sign-in; authenticated saves update both the history record and profile summary.
  - [x] Centralized latest-entry selection by target date so profile display and authenticated reconciliation cannot disagree when history arrives out of order; the focused XCTest passed with zero failures and the test-target build passes.
  - [x] Authenticated reconciliation now updates the in-memory current profile as well as the local cache, so a newly logged bodyweight (for example, 211 lb replacing 220 lb) is reflected immediately instead of waiting for another reload.
  - [x] Edit Profile now initializes its bodyweight field from the latest logged bodyweight entry, preventing a stale profile summary from resurfacing after a newer measurement is recorded; simulator build/install/launch verified at `/private/tmp/LiftRivals-bodyweight-edit-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Home’s compact bodyweight metric now resolves the latest logged entry through the same profile-data authority, preventing a stale profile summary (for example, 220 lb after a 211 lb log) from being shown; build verified at `/tmp/LiftRivals-home-bodyweight-current/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Prevent onboarding from reappearing for an already-complete account; authenticated routing and legal acceptance checks preserve the completed state.
- [x] Verify backdated planned workouts preserve their original program date and completion state.
- [ ] Test profile/privacy behavior with separate owner and viewer accounts. Public-profile routes now use a non-owner viewer identity when preparing visible lifts, preventing an owner preview from bypassing public visibility filtering; simulator build/install/launch passed. Separate-account backend verification remains.
  - [x] Unit coverage verifies owner versus viewer lift visibility and privacy mapping: public videos are visible to visitors, private videos remain owner-only, non-video lifts are excluded from the public video surface, and private bodyweight, city, and gym settings map to hidden profile fields.
  - [x] Profile-wide private audience is now retained in the local profile cache and blocks visitor lift reads before per-lift filtering; focused owner/visitor regression passed at `/tmp/LiftRivals-private-profile-tests-3/Logs/Test/Test-LiftRank-2026.10.05_04-29-15--0400.xcresult`. Separate-account backend verification remains open.
- [ ] Run demo, offline, empty-state, populated-account, and fresh-sign-in regression tests before distribution.
  - [x] Backend foundation suite passes after the current roadmap changes, including account isolation, sync retry/failure states, profile persistence, and production-owned history safeguards.
  - [x] Full `BackendFoundationTests` passed again after adding country to the shared profile model; no P0 regression failures.
  - [x] `BackendFoundationTests` passed on the iPhone 17 simulator, covering account isolation, bodyweight/unit persistence, profile/privacy mapping, legal/session handling, forum notification routing, and workout sync; result bundle: `/private/tmp/LiftRivals-backend-regression.xcresult`.
  - [x] Re-ran the full `BackendFoundationTests` class after the latest icon and routing changes; all cases passed on the iPhone 17 simulator from `/private/tmp/LiftRivals-backend-current/`.
  - [x] `RankingCalculatorTests` passed on the iPhone 17 simulator, including calendar range/boundary checks, leaderboard/filter behavior, icon mappings, sync, workout summaries, and backdated-plan coverage; result bundle: `/private/tmp/LiftRivals-roadmap-regression.xcresult`.
  - [x] Re-ran `RankingCalculatorTests` and `BackendFoundationTests` after the latest Progress, Home, Settings, leaderboard, and icon changes; the focused simulator run passed with no test failures; result bundle: `/private/tmp/LiftRivals-roadmap-tests/Logs/Test/Test-LiftRank-2026.10.04_22-40-27--0400.xcresult`.
  - [x] Re-ran the focused `RankingCalculatorTests` and `BackendFoundationTests` after the latest consistency, bodyweight, Home weekly-goal, and profile-toolbar changes; the iPhone 17 simulator run passed with no failures, including one-year-back/two-years-forward calendar coverage; result bundle: `/tmp/LiftRivals-roadmap-current-tests-2.xcresult`.
  - [x] Verified planned Skipped/Rest outcomes are included in the workout-plan sync payload; `testWorkoutSyncStoreUploadsPlannedSessionOutcomeChanges` passed on iPhone 17 with result bundle `/tmp/LiftRivals-plan-sync-test.xcresult`.
  - [x] Full `BackendFoundationTests` passed after the planned-session sync change, including account switching, privacy mapping, workout history, plan conflicts, and sync retry behavior; result bundle: `/tmp/LiftRivals-backend-outcome-tests.xcresult`.
  - [x] Re-ran both focused suites after the forum, leaderboard, and profile-surface slices; the current simulator regression passed with no failures; result bundle: `/tmp/LiftRivals-roadmap-current-tests/Logs/Test/Test-LiftRank-2026.10.04_23-17-14--0400.xcresult`.
  - [x] Current roadmap smoke build succeeds after the latest tracked changes; simulator artifact: `/private/tmp/LiftRivals-roadmap-smoke-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Re-ran `RankingCalculatorTests` and `BackendFoundationTests` after the Progress sync-state refinement; both suites passed on the iPhone 17 simulator. Result bundle: `/private/tmp/LiftRivals-progress-stale-tests.xcresult`.
  - [x] Re-ran `RankingCalculatorTests` and `BackendFoundationTests` against the current checkout after the Settings privacy slice; test build and execution succeeded on the iPhone 17 simulator. Result bundle: `/private/tmp/LiftRivals-roadmap-current-tests-3.xcresult`.
  - [x] Full `RankingCalculatorTests` passed after adding persisted Skipped and Rest Day outcomes; result bundle: `/tmp/LiftRivals-ranking-outcome-tests.xcresult`.
  - [x] Re-ran all 235 `RankingCalculatorTests` after the icon fallback corrections; zero failures on iPhone 17, result bundle: `/tmp/LiftRivals-ranking-after-icon-fix/Logs/Test/Test-LiftRank-2026.10.05_04-06-14--0400.xcresult`.
  - [x] Privacy-cache and public-profile state changes compile in the current app build and were installed/launched on iPhone 17 from `/tmp/LiftRivals-private-profile-build-2/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Full current `RankingCalculatorTests` and `BackendFoundationTests` regression passed on iPhone 17: 334 tests, 0 failures; result bundle: `/tmp/LiftRivals-roadmap-current-regression/Logs/Test/Test-LiftRank-2026.10.05_04-53-18--0400.xcresult`.
  - [x] Re-ran both suites after the Settings privacy handoff change: 334 tests, 0 failures; result bundle: `/tmp/LiftRivals-roadmap-post-settings-regression/Logs/Test/Test-LiftRank-2026.10.05_05-04-34--0400.xcresult`.
  - [x] Re-ran both suites after unifying Home and Tracker schedule resolution: 334 tests, 0 failures; result bundle: `/tmp/LiftRivals-shared-schedule-tests/Logs/Test/Test-LiftRank-2026.10.05_05-39-12--0400.xcresult`.
  - [x] Re-ran the Home scroll and Personal/Public Profile UI regressions after aligning stale assertions with the current surfaces: 4 tests, 0 failures; result bundles: `/tmp/LiftRivals-full-test-gate/Logs/Test/Test-LiftRank-2026.10.05_06-32-50--0400.xcresult` and `/tmp/LiftRivals-full-test-gate/Logs/Test/Test-LiftRank-2026.10.05_06-36-01--0400.xcresult`.
  - [x] Re-ran `BackendFoundationTests` and `RankingCalculatorTests` against the current checkout on iPhone 17; test session succeeded with no failures at `/tmp/LiftRivals-roadmap-regression-20261005.xcresult`.
  - [x] Verified the athlete-blocking UI workflow including its explicit destructive confirmation dialog; 1 test, 0 failures at `/tmp/LiftRivals-full-test-gate/Logs/Test/Test-LiftRank-2026.10.05_06-39-39--0400.xcresult`.
  - [x] Verified the substitute-exercise workflow through the real library search field, recommendations, and exercise details; 1 test, 0 failures at `/tmp/LiftRivals-full-test-gate/Logs/Test/Test-LiftRank-2026.10.05_06-44-55--0400.xcresult`.
  - [ ] A full target run was started at `/tmp/LiftRivals-full-test-gate.log`; several existing UI tests failed around Home scroll performance and Me/Profile navigation, then the run stalled waiting for `me.gyms` and was stopped. The complete UI gate remains open and is not represented as passing.

### Phase 1 reference — Core training experience

- [x] Correct the active program week and next-session context everywhere on Home and Tracker.
  - [x] Program-week calculation is covered at the plan start, day six, and day seven boundaries; the focused simulator test passes.
  - [x] Home now resolves today's scheduled session through the same date-based plan schedule as missed-workout recovery, including the program start date and week offset, instead of matching only the weekday name; build/install/launch verified at `/tmp/LiftRivals-schedule-context-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Tracker Today, Missed, and Next session state now uses the same shared date-based schedule helpers as Home, eliminating duplicate week/date calculations; build/install/launch verified at `/tmp/LiftRivals-shared-schedule-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Finish the Today/Plans/Active Workout workflow, including skipped, shortened, missed, and backfilled outcomes.
  - [x] Backdated freestyle and planned workouts preserve the selected calendar date, real elapsed duration, source plan session, and completed sets; focused simulator tests pass.
  - [x] Skip/Rest confirmation copy now matches the persisted outcomes: Skip records an incomplete planned workout, while Rest Day records intentional recovery; neither is presented as completed history. Simulator build verified at `/tmp/LiftRivals-tracker-copy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Persisted Skip and Rest outcomes now count as resolved planned sessions for Home/Tracker schedule resolution, so they no longer resurface as missed; the organized-slice app build succeeds at `/tmp/LiftRivals-organized-slice-build/Build/Products/Debug-iphonesimulator/LiftRank.app`. The focused regression was compiled but its simulator launch was blocked by the CoreSimulator test service and remains to be rerun.
  - [x] Calendar backfill now prioritizes unresolved planned sessions scheduled for the selected date, removes those same sessions from the fallback substitution list, and retains the remaining full-plan choices; final simulator build verified at `/tmp/LiftRivals-backfill-picker-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Regression coverage verifies the backfill picker excludes a persisted skipped session while retaining the unresolved session for its own selected date; focused test passed on iPhone 17 at `/tmp/LiftRivals-backfill-tests/Logs/Test/Test-LiftRank-2026.10.05_19-14-30--0400.xcresult`.
- [>] Complete the full exercise identity and icon audit across every picker and display surface.
  - [x] The shared catalog renderer now gives calf raises an equipment-aware movement cue and uses a strength-training movement figure for fly/rear-delt families instead of the generic open-arms placeholder; the simulator build/install/launch passed at `/private/tmp/LiftRivals-icon-family-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] The deterministic exercise-library regression now covers search, catalog-row selection, and About/History/Records/Charts detail navigation; 1 test, 0 failures at `/tmp/LiftRivals-full-test-gate/Logs/Test/Test-LiftRank-2026.10.05_06-47-10--0400.xcresult`.
  - [x] Focused icon coverage passes for all built-in catalog renderers, canonical ranking mappings, custom-exercise fallback behavior, and cable movement families: 4 tests, 0 failures at `/tmp/LiftRivals-full-test-gate/Logs/Test/Test-LiftRank-2026.10.05_06-49-18--0400.xcresult`.
  - [x] Home recent submitted PRs now resolve known exercise IDs through the shared catalog renderer instead of a separate name-based symbol switch; the simulator build succeeds at `/tmp/LiftRivals-home-icon-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Home scroll performance remains green after the shared icon change: 1 test, 0 failures at `/tmp/LiftRivals-home-icon-build/Logs/Test/Test-LiftRank-2026.10.05_06-53-23--0400.xcresult`.
  - [x] Rebuilt the current checkout after the shared renderer changes and installed/launched it on iPhone 17 simulator `2BC3FC16-C814-4855-BC9C-EC81458870B6`; artifact: `/tmp/LiftRivals-icon-audit-current/Build/Products/Debug-iphonesimulator/LiftRank.app`. The remaining icon work is visual catalog review, not a stale build.
  - [x] Re-ran full built-in renderer and canonical ranking-icon coverage after that build; 2 focused tests passed on iPhone 17 at `/tmp/LiftRivals-icon-audit-tests/Logs/Test/Test-LiftRank-2026.10.05_17-38-53--0400.xcresult`.
  - [x] Leaderboard rows now use the same name-based catalog renderer when a lift lacks a canonical catalog ID, removing the last generic strength-figure fallback on that surface; rebuilt and launched successfully at `/tmp/LiftRivals-icon-audit-current/Build/Products/Debug-iphonesimulator/LiftRank.app` (launch PID `55102`).
  - [x] Refined the shared catalog artwork for lateral raises, flies/rear-delts, and curls so those families no longer rely on the weak open-arms/traditional-figure presentation; build/install/launch verified at `/tmp/LiftRivals-icon-audit-next/Build/Products/Debug-iphonesimulator/LiftRank.app` (launch PID `62172`).
  - [x] Aligned name-only Home and profile-summary fallbacks with the shared movement cues, including lateral/front raises, flies/rear-delts, and curls; build/install/launch verified at `/tmp/LiftRivals-icon-audit-consistent/Build/Products/Debug-iphonesimulator/LiftRank.app` (launch PID `62878`).
  - [x] Gave hip thrust and glute bridge catalog entries a distinct core/bridge movement figure instead of the shared generic functional figure; incremental build/install/launch verified at `/tmp/LiftRivals-icon-audit-consistent/Build/Products/Debug-iphonesimulator/LiftRank.app` (launch PID `63222`).
  - [x] Distinguished shrug equipment, wrist-curl rotation, and hip-abduction/lateral-walk movement cues in the shared renderer; incremental build/install/launch verified at `/tmp/LiftRivals-icon-audit-consistent/Build/Products/Debug-iphonesimulator/LiftRank.app` (launch PID `63549`).
  - [x] Replaced remaining generic open-arms artwork for face pulls, band pull-aparts, wrist curls, and shoulder rotations with movement/equipment cues in the shared renderer; build verified at `/tmp/LiftRivals-icon-family-followup/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Aligned `PopularExerciseCatalog` stored fallback symbols with the shared movement cues for face pulls, rotations, shrugs, wrist curls, pull-aparts, lateral raises, and flies/rear delts; build verified at `/tmp/LiftRivals-icon-stored-fallbacks/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Finish the Progress analytics refinement: overview, strength, muscle, consistency, recovery, plateaus, and bodyweight trends.
  - [x] Program-consistency status summaries now render as compact, color-coded chips with movement-specific accessibility labels instead of a dense inline text block; simulator build verified at `/tmp/LiftRivals-progress-consistency-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Make Home a task-oriented training command center instead of a stack of duplicate metric cards.
  - [x] Home now distinguishes a missed planned session from a rest day and shows its original scheduled date and Log missed workout affordance; simulator build/install passed.
  - [x] Home quick actions now adapt the workout action label and icon for a missed planned session, keeping Progress as the direct analytics action.
  - [x] The optional weekly training-day goal now uses a compact action row when unset and a tighter progress card when active, reducing duplicate card height without removing goal controls.
  - [x] Fixed the unusual-volume alert percentage interpolation so Home displays the calculated comparison instead of literal source text; build/install/launch verified at `/tmp/LiftRivals-home-alert-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.

### Phase 2 reference — Privacy and identity surfaces

- [ ] Separate Personal Profile from Public Profile behavior and layout.
- [x] Profile headers now explicitly label the owner surface as a “Private training dashboard” and visitor/preview surfaces as a “Public athlete card”; simulator build verified at `/tmp/LiftRivals-profile-surface-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Add a “View as public” preview from the owner profile and Settings.
  - [x] Added a View as public action to the owner profile toolbar; it opens the same public-profile rendering used for visitor views. Simulator build/install passed.
- [ ] Clarify privacy precedence and verify every visibility setting with persistence tests.
  - [x] Settings now explains that Private profile hides the public page and that field-level controls apply when the profile is public; simulator build/install passed.
  - [x] Settings now exposes the existing gym-audience control alongside the other profile visibility settings and persists it through the shared privacy save path; simulator build passed at `/private/tmp/LiftRivals-settings-privacy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Settings now explains that field-level privacy controls hide public presentation without deleting training records; build/install verification passed at `/private/tmp/LiftRivals-settings-copy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Settings now explicitly explains that achievements and unlocked badges remain private on public profiles; build verified at `/private/tmp/LiftRivals-settings-privacy-copy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Settings now exposes the existing Division and Friend list audience controls and persists them through the same profile privacy save path; simulator build/install/launch verified at `/private/tmp/LiftRivals-settings-audience-build-3/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Focused owner-profile mapping and edited-profile persistence tests pass on iPhone 17, including private gym visibility: `/tmp/LiftRivals-settings-privacy-tests/Logs/Test/Test-LiftRank-2026.10.04_22-05-52--0400.xcresult`.
  - [x] The profile persistence regression now also asserts Division and Friend list audiences; app and test targets compile in `/private/tmp/LiftRivals-privacy-build-for-testing` (the isolated test invocation returned no discovered tests and is not counted as a passing runtime result).
  - [x] Profile persistence now also asserts the profile-wide Private audience survives remote mapping; focused test passed at `/tmp/LiftRivals-profile-persistence-tests/Logs/Test/Test-LiftRank-2026.10.05_04-37-53--0400.xcresult`.
  - [x] Settings now carries the staged profile-wide audience onto the local `UserProfile` before saving, so demo/local privacy changes take effect immediately; build/install/launch verified at `/tmp/LiftRivals-settings-audience-current-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Complete the Settings save, error, destructive-action, and legal-document flows. Settings persists changes through the shared profile save path, keeps failed saves retryable, confirms account deletion and demo reset, exposes legal/support documents, and retains unit, appearance, notification, and sign-out actions.

### Phase 3 reference — Social and competitive features

- [ ] Complete leaderboard pagination, evidence semantics, filters, rank behavior, and lift detail.
  - [x] Render leaderboard results in 100-entry pages with an explicit Load next 100 action; reset the window when the search or ranking request changes.
  - [x] Regression coverage now verifies that the self-reported evidence filter removes video-backed lifts from the local leaderboard after switching from All lifts; result: `/tmp/LiftRivals-leaderboard-evidence-tests/Logs/Test/Test-LiftRank-2026.10.04_22-09-42--0400.xcresult`.
- [ ] Complete forum persistence, nested replies, voting, notifications, moderation, and role enforcement.
  - [x] Comment vote scores now load from persisted signed votes and update immediately for upvote, downvote, and removal; nested replies retain their parent IDs and the focused simulator regression passes. Build: `/private/tmp/LiftRivals-forum-vote-build/Build/Products/Debug-iphonesimulator/LiftRank.app`; tests: `/tmp/LiftRivals-forum-vote-tests/Logs/Test/Test-LiftRank-2026.10.04_22-51-00--0400.xcresult`.
  - [x] Forum hub exposes distinct All, For You, and Following feeds; Following reflects joined communities and For You adds pinned recommendations to joined content. Corrected semantics build: `/private/tmp/LiftRivals-forum-semantics-build/Build/Products/Debug-iphonesimulator/LiftRank.app`; backend regression evidence: `/tmp/LiftRivals-forum-following-tests/Logs/Test/Test-LiftRank-2026.10.04_22-57-32--0400.xcresult`.
  - [x] Following’s empty state now describes the actual joined-community behavior instead of implying that users follow individual discussions; verified in the simulator build at `/private/tmp/LiftRivals-forum-copy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Discussion threads now expose a native Share action that shares the title and body; build/install/launch verified at `/tmp/LiftRivals-forum-share-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Complete public-profile and leaderboard acceptance tests with owner, viewer, and moderator accounts.

### Phase 5 reference — Verification and distribution

- [ ] Build and install the candidate on the simulator and a physical test device.
  - [x] Current candidate was installed and launched on the configured iPhone 17 simulator as `com.liftrank.app` (CFBundleVersion 12) from `/private/tmp/LiftRivals-calendar-range-build/Build/Products/Debug-iphonesimulator/LiftRank.app`; the simulator build completed successfully after the calendar-range regression test was added.
  - [x] The latest combined forum-notification and icon-audit source also built successfully and was installed/launched on the iPhone 17 simulator from `/private/tmp/LiftRivals-latest-roadmap-build/Build/Products/Debug-iphonesimulator/LiftRank.app`; this remains an unsigned simulator artifact.
  - [x] Current roadmap candidate builds successfully after the latest icon-family and ranking-coverage changes at `/private/tmp/LiftRivals-roadmap-candidate-final/Build/Products/Debug-iphonesimulator/LiftRank.app`; this is an unsigned simulator artifact and is not a TestFlight verification.
  - [x] Latest public-profile candidate artifact reports marketing version `1.0` and build `12` in its embedded Info.plist; it remains unsigned and simulator-only.
  - [x] A fresh Release simulator verification completed at `/tmp/LiftRivals-release-verify-20261005/Build/Products/Release-iphonesimulator/LiftRank.app` with `** BUILD SUCCEEDED **`; the embedded artifact reports marketing version `1.0` and build `12`.
  - [x] That Release artifact was installed and launched successfully as `com.liftrank.app` on iPhone 17 simulator `2BC3FC16-C814-4855-BC9C-EC81458870B6` (launch PID `30518`).
  - [x] Current Release archive was rebuilt as marketing version `1.0`, build `13`, and uploaded through Xcode's Distribute App workflow; Organizer reports `Uploaded to Apple` at 7:50 AM on October 5, 2026. TestFlight processing and in-app verification remain pending.
- [ ] Record the source revision and build number in the release notes.
  - [x] Simulator verification recorded source revision `fcf2349a2d190b6dab25ae8044d24bb4527c7ae9`, marketing version `1.0`, and build `12`; the working tree remains dirty, so this is not yet a reproducible signed release record.
- [ ] Verify the actual TestFlight build contains the audited changes before upload.
  - [x] Local launch-metadata and services preflight checks pass for the source; APNs credentials, SMTP evidence, physical-device validation, and signed TestFlight verification remain external gates.

## Cross-cutting reference notes (not a separate execution queue)

- [>] Finish and visually verify the full exercise icon replacement pass. Reopened: earlier named replacements left generic/misleading icons across the catalog and separate ranking/submission mappings. See [full icon audit](docs/exercise-icon-audit.md).
  - [x] Unresolved exercises with weak stored symbols now use a neutral strength fallback instead of generic dumbbells/arrows; focused renderer coverage was added while movement-specific mappings remain unchanged.
  - [x] Full built-in icon rendering plus the unresolved weak-symbol fallback test passed at `/tmp/LiftRivals-icon-fallback-tests/Logs/Test/Test-LiftRank-2026.10.05_04-50-45--0400.xcresult`; the test artifact was installed/launched on iPhone 17.
  - [x] Expanded the shared catalog renderer with distinct squat, hinge/deadlift, lunge, curl, triceps, push-up/dip, and existing press/pull/leg movement families; the full 337-item renderer coverage test passed at `/tmp/LiftRivals-icon-families-2-tests/Logs/Test/Test-LiftRank-2026.10.04_07-16-01--0400.xcresult`. Visual contact-sheet review and separate leaderboard/submission mappings remain open.
  - [x] Routed canonical exercise icons through the shared renderer in leaderboard rows and the selected Submit a Lift exercise action; simulator build passed at `/private/tmp/LiftRivals-icon-surfaces-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Leaderboard and Submit a Lift option sheets now resolve catalog icons by canonical ranking ID or catalog ID, preventing stale generic symbols when an exercise lacks a ranking alias; build/install/launch verified at `/private/tmp/LiftRivals-icon-identity-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Added name-based movement handling for custom/unresolved pull-ups, core movements, and related fallbacks without changing stored custom exercise records; full built-in icon rendering still passes at `/private/tmp/LiftRivals-icon-custom-tests/Logs/Test/Test-LiftRank-2026.10.04_07-21-53--0400.xcresult`.
  - [x] Added focused custom-icon coverage for pull-up, squat, deadlift, and plank names; both custom and full built-in rendering tests passed at `/private/tmp/LiftRivals-icon-custom-coverage/Logs/Test/Test-LiftRank-2026.10.04_07-24-58--0400.xcresult`.
  - [x] Added distinct upright-row, rotation/anti-rotation, and hip-isolation/kickback renderers; canonical, custom, and full-catalog icon tests passed at `/private/tmp/LiftRivals-icon-final/Logs/Test/Test-LiftRank-2026.10.04_07-48-26--0400.xcresult`.
  - [x] Added canonical ranking icon coverage while preserving Sumo Deadlift’s intentional shared `deadlift` ranking ID; focused mapping and PR tests passed at `/private/tmp/LiftRivals-ranking-fix/Logs/Test/Test-LiftRank-2026.10.04_07-41-57--0400.xcresult`.
  - [x] Full `RankingCalculatorTests` regression class passed after the mapping correction, covering calendar ranges, leaderboard behavior, icon rendering, workout summaries, sync, and progress; result bundle: `/private/tmp/LiftRivals-ranking-final/Logs/Test/Test-LiftRank-2026.10.04_07-42-13--0400.xcresult`.
  - [x] Added movement-specific rendering for incline presses (including iso-lateral incline press) and farmer’s carries instead of falling through to generic catalog symbols; simulator build/install/launch verified at `/private/tmp/LiftRivals-icon-followup-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Focused custom icon rendering test now covers iso-lateral incline press and farmer’s carry; test passed on iPhone 17 in `/private/tmp/LiftRivals-icon-followup-tests.xcresult`.
- [x] Review the tracker screen for first-time-user clarity after the icon pass: no-plan guidance, program browsing, and accessible plan controls are now explicit.
- [x] Clarify the tracker home header: “Workout Plan” should explain or guide users when no program has been selected.
- [x] Audit every workout plan against its title and intended training style: exercise selection, rep ranges, RIR guidance, percentage work, progression, and powerlifting specificity.
- [x] Fix the workout calendar to support navigating to any prior/future month, preserve empty months, and align every day to the real calendar grid; verify October 2026 includes October 1–31 correctly.
  - [x] Regression coverage now verifies September 1–5 remain present and month projections remain correct one year back and two years forward; the test target builds successfully.
  - [x] Re-ran `testWorkoutHistoryCalendarRetainsLeadingDatesAcrossMonthsAndRange` on the iPhone 17 simulator; September 1–5 and the one-year-back/two-years-forward month checks passed in `/tmp/LiftRivals-calendar-current/Logs/Test/Test-LiftRank-2026.10.05_01-17-30--0400.xcresult`.
  - [x] Re-ran the calendar boundary regression against the current checkout; the September leading dates and one-year-back/two-years-forward month projections passed on iPhone 17 in `/tmp/LiftRivals-calendar-current/Logs/Test/Test-LiftRank-2026.10.05_18-36-27--0400.xcresult`.
  - [x] Calendar grid identity is now keyed to the normalized month so switching months redraws leading and trailing cells instead of reusing stale positions; simulator build verified at `/private/tmp/LiftRivals-roadmap-current-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Audit bodyweight entry validation and copy: clarify why actual bodyweight is marked optional, or make it required when saving a bodyweight entry.
- [x] Verify “Find Your Gym” in both demo and production: demo behavior is covered by the mock directory and location-filter regression; the production catalog currently has 991 active gyms, including 10 in Miami, so an empty state indicates loading/error state rather than missing catalog data.
- [x] Condense the Submit a Lift flow: required lift, context, and video controls remain visible while estimated-max and plate-loading details are grouped behind one collapsed “More details” section.
- [x] Audit the Privacy Notice, Terms of Use, and Fitness Disclaimer against the production feature set: current in-app copies cover the implemented data/features and pass the coverage test. Legal sign-off remains an external release gate.
- [x] Enable forum browsing in the simulator/demo build without requiring production account services; verify read-only forum access in the next build.
- [x] Expand the awards catalog from roughly 100–105 to about 200: audit existing awards, remove overlap, and add balanced milestones for consistency, strength, volume, technique, exploration, and community engagement.
- [x] Fix RPE chip contrast in the workout tracker, especially RPE 7: the number must remain readable in both selected and unselected states and meet accessible contrast expectations.
- [x] Remove the ambiguous “Best set” card from workout summary; a bare weight × reps result lacks exercise context and unclear scoring criteria.
- [x] Restore workout-completion celebrations for meaningful milestones, including new PRs, volume PRs, and other unlocked achievements.

### Phase 1.1 detail — Tracker improvements for strength and hypertrophy

- [x] Make program completion count finished planned workouts from completed history as well as in-progress set logs; keep session and week completion in sync after finishing, editing, deleting, or backdating a workout. Completion now maps saved sets back to their source prescriptions and refreshes when workout history changes.
- [x] Define and label training metrics consistently: working sets, volume load (weight × reps), estimated 1RM, adherence, and training frequency.
  - [x] Show weekly non-warmup working sets grouped by normalized primary muscle, with a drill-down to a recent contributing workout.
  - [x] Label volume load explicitly as weight × reps from completed working sets, and exclude time-tracked sets from Home weekly volume.
  - [x] Normalize volume load categories through each exercise’s resolved primary-muscle profile so body-part aliases do not fragment the summary; recovery and working-set summaries already use canonical muscle regions.
  - [x] Document and label estimated 1RM, adherence, and training-frequency calculations consistently across views: Epley estimates use completed working sets up to 10 reps, adherence is labeled as exercise/session coverage, and frequency reports active weeks out of four.
- [x] Make Today clearly show the next planned workout, an in-progress workout, a rest day, a missed session, or a completed program, with the appropriate next action.
- [x] Clarify plan selection and overview: current week, sessions complete, next session, progression method, and the difference between changing a plan and editing it; provide a useful action when a program ends. The tracker now labels the active plan, separates plan selection from plan editing, routes rest-day and next-session context to the correct week, and offers “Choose another program” when the active program is complete.
  - [x] Label the plan list as the place to choose the active plan, separately from editing the selected plan’s weeks and workouts.
  - [x] In Plan Overview, count only workouts that contain exercises and offer a direct next action: start the next workout, review an unfinished week, or add a week after program completion.
- [x] Show the prescribed set count, rep range, target RIR, training-max percentage, and target load in the in-workout exercise header; convert target load to the active workout unit.
- [x] Label previous performance and make set completion, warmups, RPE, rest, add-set, and substitution controls clear. Set rows expose previous/no-previous values, explicit warmup/working labels, RPE controls, completion state, and set options; the exercise detail view labels rest, Add another set, and substitutions.
  - [x] Label the per-set prior-performance action as “Prev” and expose its workout values accessibly, including a clear no-history state.
  - [x] Show the historical load unit and convert copied previous values into the current workout's unit.
- [x] Keep progress feedback during a workout clear about working sets completed and remaining, and distinguish a full, shortened, or skipped session when finishing. The active workout shows exercise/set progress and remaining working sets, the finish flow labels a shortened save, and planned sessions expose a confirmed Skip action that does not create completion history.
  - [x] Show planned-session completion versus a shortened session and report logged working sets against the original session prescription count on the finish screen.
  - [x] Planned workouts now expose an explicit Skip action with confirmation copy; skipping discards the active draft without creating a completed-workout record or counting the session as completed. The focused planned-workout lifecycle test passed with zero failures and the simulator build passes.
- [x] Add a Strength view for key lift bests, estimated 1RM trends, three-lift totals, and bodyweight-relative strength, with estimates linked to the logged sets they use.
  - [x] Summarize squat, bench, and deadlift estimated 1RMs; show a total only when all three exist and a relative total when bodyweight is known.
  - [x] Preserve the source workout through daily exercise-trend aggregation and let a selected weight or estimated-1RM chart point open that workout.
- [x] Add a Muscle view for weekly working sets by muscle, training frequency, and four-week comparisons; keep volume load as a separate metric from set count.
  - [x] Compare four calendar weeks of primary-muscle working-set counts, show training frequency, and drill down to a workout that contributed sets.
- [x] Add a Consistency view for planned versus completed sessions and sets, missed or backdated sessions, and calendar history.
  - [x] Add a Progress summary for selected-week planned workouts completed and prescribed exercises logged, with a program-browsing empty state.
  - [x] Label the percentage as exercise coverage (planned prescriptions with a completed non-warmup set), separate from fully completed workout count.
  - [x] Show planned working-set coverage separately and describe workout counts as sessions with every prescribed exercise logged.
  - [x] Replaced the dense consistency metric row with compact Sessions, Exercises, and Sets tiles while preserving the same completion and RIR data; simulator build/install passed.
  - [x] Empty Recovery context now offers the same direct “Start a workout” action as the other no-data analytics states; simulator build succeeded at `/tmp/LiftRivals-progress-recovery-action/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] The recovery-action candidate was installed and launched on iPhone 17 simulator `2BC3FC16-C814-4855-BC9C-EC81458870B6` (launch PID `58030`).
  - [x] Exercise-progress empty state now offers “Log this exercise” and routes to Today; rebuilt, installed, and launched on iPhone 17 (launch PID `58758`) from `/tmp/LiftRivals-progress-empty-actions/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Show rep-range progression and, when a plan prescribes RIR, compare target RIR with logged effort.
  - [x] Compare completed reps against each workout's historical numeric rep-range prescription; show sets in range and best in-range load, excluding duration targets.
  - [x] Make each rep-range progression entry open its source workout and logged sets.
  - [x] Compare target RIR with estimated RIR from completed-set RPE, using historical workout prescription snapshots when available.
- [x] Make charts and calendar entries open the workout and relevant sets; explain when a metric has too little history to display a useful trend.
  - [x] Calendar workout entries open the saved workout detail.
  - [x] Exercise weight and estimated-1RM trend selections offer the source workout.
  - [x] Verify chart selections scroll the exact logged set into view in the source workout detail with a simulator UI test.
  - [x] Show a current estimated 1RM instead of a zero-change comparison with one workout, and explain that another session is needed for a trend; the simulator UI test verifies this single-workout state.
- [x] Reorganize Progress around Strength, Muscle, and Consistency while keeping the calendar usable for browsing history and empty months; the calendar remains in the default Consistency view.
- [x] Re-verified the Tracker → Progress navigation and Strength, Muscle, and Consistency analytics sections after the latest Home/icon changes: 1 UI test, 0 failures at `/tmp/LiftRivals-home-icon-build/Logs/Test/Test-LiftRank-2026.10.05_06-55-33--0400.xcresult`.
- [x] Keep workout completion concise and focused on meaningful PRs, program progress, and milestones; put detailed trends and history in Progress.
  - [x] The saved-workout screen shows at most three prioritized highlights, keeps the full achievement catalog collapsed, and leaves detailed trends/history in Progress; `testWorkoutCompletionHighlightsLeadWithProgramMilestone` passed at `/tmp/LiftRivals-workout-finish-test/Logs/Test/Test-LiftRank-2026.10.05_02-59-05--0400.xcresult`.

### Phase 1.2 detail — Progress and analytics refinement

- [x] Use shared semantic design tokens for Progress action text and recovery indicators instead of hard-coded black/orange colors; build verified at `/private/tmp/LiftRivals-progress-tokens-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.

- [x] Add a compact Progress overview with training status, strength trend, volume trend, and recovery flags.
  - [x] The overview uses a compact weekly metric row with working sets, volume, four-week baseline comparison, and recovery flags; placeholder interpolation was corrected and verified in a successful simulator build.
- [x] Add 4-week, 8-week, 12-week, 6-month, and 1-year ranges for relevant charts.
  - [x] Bodyweight history now exposes all five ranges and filters the trend/table to the selected window; simulator build passed at `/private/tmp/LiftRivals-progress-range-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] `testProgressTimeRangesCoverAllSupportedHorizons` passed on the iPhone 17 simulator; result bundle: `/tmp/LiftRivals-progress-range-tests/Logs/Test/Test-LiftRank-2026.10.04_06-46-44--0400.xcresult`.
- [x] Expand Strength beyond exact squat/bench/deadlift IDs with selected powerlifting and bodybuilding lifts. Strength supplements the competition-lift cards with the athlete’s highest tracked estimated-1RM exercises without changing the three-lift total.
  - [x] Strength now supplements the competition-lift cards with up to three highest estimated-1RM weight-and-rep exercises from the athlete’s tracked history, without changing the three-lift total.
- [x] Separate actual best sets, rep PRs, estimated 1RM, volume PRs, and source workout/set details. Exercise Progress presents those records separately and links the source workout/set for selected performances.
  - [x] Exercise Progress now shows separate best-set volume and best-session volume records alongside rep PRs, estimated 1RM, and source-set details; build verified at `/private/tmp/LiftRivals-pr-volume-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Add muscle target ranges with Below target, In range, and Above target states; keep working sets separate from volume load.
  - [x] The four-week muscle table now labels the current week with an 8–20 working-set target band (Below target, In range, Above target) while retaining separate volume-load analytics; build verified at `/private/tmp/LiftRivals-muscle-target-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Add rolling volume averages and comparisons against the lifter’s own baseline.
  - [x] Progress overview now compares the current weekly volume with the average of the prior four weekly summaries and explains the insufficient-history state.
- [x] Make Consistency show planned, completed, missed, shortened, skipped, rest, and backfilled sessions.
  - [x] The selected-week summary now distinguishes completed, shortened, in-progress, missed, upcoming, skipped, and rest planned sessions with date-aware status counts; build verified at `/private/tmp/LiftRivals-outcome-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Completed planned sessions now show as Backfilled when their saved workout date differs from the scheduled source session date; simulator build/install/launch verified at `/private/tmp/LiftRivals-progress-backfilled-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Persisted planned workouts with completed sets but incomplete prescriptions now show as Shortened; truly active partial sessions remain In progress.
  - [x] Skip and Rest Day choices now persist on the planned session and survive snapshot restore; `testPlannedSessionOutcomesPersistForSkippedAndRestDays` passed on iPhone 17 with result bundle `/tmp/LiftRivals-outcome-tests.xcresult`.
  - [x] Replaced the tall status grid with a compact, accessible status summary so Program Consistency keeps the same planned/completed context without dominating the Progress screen; build/install/launch verified at `/tmp/LiftRivals-consistency-compact-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Surface recovery and plateau insights as actionable cards linked to the contributing workouts; recovery rows open the latest contributing workout and tracker plateau cards open recent sets with programming guidance.
  - [x] Progress now includes a compact recovery context list with recent working-set counts, elapsed time since training, and a link to each muscle's contributing workout; build verified at `/private/tmp/LiftRivals-recovery-insights-build/Build/Products/Debug-iphonesimulator/LiftRank.app`. Plateau alert behavior remains covered by the existing actionable card.
- [x] Add bodyweight moving averages, rate of change, and relationship to relative strength.
  - [x] Progress bodyweight chart now shows logged values plus a dated three-entry moving-average line and legend; simulator build passes.
  - [x] A one-entry bodyweight history now keeps the chart visible but explains that another check-in is needed before a trend can be compared; verified in `/private/tmp/LiftRivals-progress-single-point-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Keep charts actionable: selected points show exact date, recorded unit, reps, volume, and a direct link to the contributing workout and set.
  - [x] Exercise strength and weight charts now show a selected-performance detail card with exact date, recorded weight, reps, volume, and a direct workout/set path; build verified at `/private/tmp/LiftRivals-chart-detail-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Verify empty, one-point, insufficient-history, offline, and stale-data states for every analytics section.
  - [x] Refined the Program consistency card into a compact progress ring with retained session, exercise, set, status, and RIR details; build/install/launch verified at `/tmp/LiftRivals-progress-consistency-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Muscle-volume empty state now offers a direct “Start a workout” action instead of ending with passive copy; build/install/launch verified at `/tmp/LiftRivals-progress-empty-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Empty Strength analytics now use a compact actionable state instead of three all-zero lift cards; the same simulator artifact was rebuilt, installed, and launched after the change.
  - [x] Weekly Progress no longer labels a zero-workout week as a negative baseline change; it now explains that a workout is needed for a meaningful comparison. Build/install/launch reverified at `/tmp/LiftRivals-progress-empty-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Progress now surfaces local, syncing, and needs-attention workout-history states with an inline retry action, so analytics do not appear authoritative while history is unsynced; simulator build verified at `/private/tmp/LiftRivals-progress-sync-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Progress and Home now distinguish stale history from merely local or failed sync, with an explicit refresh action and copy that warns when analytics may be out of date; build verified at `/private/tmp/LiftRivals-progress-stale-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Weekly volume’s zero-data state now has an actionable “Start a workout” path into Today; rebuilt successfully at `/tmp/LiftRivals-progress-empty-action/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Empty Recovery context now offers “Start a workout,” and an exercise with no history offers “Log this exercise”; the combined candidate built, installed, and launched at `/tmp/LiftRivals-progress-empty-actions/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Empty Progress analytics retain a seven-day weekly axis and four weekly muscle rows with zero metrics instead of collapsing the layout; focused simulator test passed at `/tmp/LiftRivals-progress-empty-tests/Logs/Test/Test-LiftRank-2026.10.05_19-17-24--0400.xcresult`.

### Phase 1.3 detail — Home command center refinement

- [x] Make the primary Home card answer “What should I do next?” for scheduled, active, rest, missed, backfilled, completed, and finished-program states. The card routes active sessions to Resume, completed or finished programs to Progress, missed sessions to Log missed workout, scheduled sessions to Today, and rest/no-plan states to Plans.
  - [x] The primary card now routes active sessions to Resume, completed-today and finished programs to Progress, missed sessions to Log missed workout, and rest days to Programs; build verified at `/private/tmp/LiftRivals-home-state-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] The primary training card now routes scheduled and missed sessions to Today, while a true rest/no-session state opens Plans to choose the next program.
- [x] Replace the hard-coded Week 1 lookup with the active program’s actual current week and next session.
- [x] Show program name, week/day, session, planned sets, progression method, and one direct primary action. Home includes the selected plan, current week, progression method, exercise count, prescribed set count, and date in the next or missed-session context; simulator build/install/launch passed.
- [ ] Reduce duplicate Home cards by keeping detailed volume, muscle, calendar, and exercise trends in Progress.
  - [x] Active weekly training goal is now a compact progress row with a circular completion cue and retained goal menu, reducing vertical card space; build/install/launch verified at `/tmp/LiftRivals-home-goal-compact/Build/Products/Debug-iphonesimulator/LiftRank.app` (PID `60632`).
  - [x] Removed the detailed weekly volume/time/day chart from Home; Home keeps the compact weekly training-day goal while Progress remains the destination for trend detail.
  - [x] Compact Home build succeeded and installed/launched on iPhone 17 at `/private/tmp/LiftRivals-home-compact-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Adapt the strength summary for powerlifters and bodybuilders instead of centering only on the three-lift total.
  - [x] Home quick stats now fall back to the athlete's highest tracked estimated 1RM as Top 1RM when no three-lift total exists; relative total remains unavailable until the competition lifts are present. Simulator build passed at `/private/tmp/LiftRivals-home-bodybuilder-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Add weekly comparisons against last week and the four-week baseline.
  - [x] Home now shows both the prior-week delta and a compact four-week average for workouts and working sets; build verified at `/private/tmp/LiftRivals-home-baseline-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] The baseline window is the immediately preceding four weeks (including last week), with the separate prior-week delta retained.
  - [x] Home weekly activity now includes a compact workouts/working-sets comparison against the prior week without adding another metric card; simulator build passes.
- [ ] Separate workout PRs, submitted PRs, video-backed PRs, self-reported PRs, and private PRs.
  - [x] Home now labels its submitted-PR list explicitly and shows Video-backed submission, Self-reported submission, or Private PR provenance on each row; workout-log PRs remain in Progress history.
  - [x] Provenance-labeled Home build succeeded and installed/launched on iPhone 17 at `/private/tmp/LiftRivals-home-pr-provenance-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Add compact actionable alerts for missed workouts, stalled lifts, unusual volume, recovery, unsynced workouts, and program milestones.
  - [x] Home workout-sync alerts now offer “Sync now” for local pending history and “Retry sync” when uploads need attention; build/install/launch verified at `/private/tmp/LiftRivals-home-sync-action-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Home now surfaces up to two computed plateau alerts with a direct route to Progress details; build/install/launch verified at `/tmp/LiftRivals-home-alert-build-2/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] The compact Home alert now also includes recent recovery context when muscles were trained within 48 hours; build/install/launch verified at `/tmp/LiftRivals-home-alert-build-3/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Home now flags an unusual-volume week when current volume reaches at least 150% of the prior four-week average and routes the review to Progress; simulator build verified at `/tmp/LiftRivals-profile-timeline-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Home now surfaces a compact program-completion milestone alongside other training alerts and routes it to Progress; build/install/launch verified at /tmp/LiftRivals-home-milestone-build/Build/Products/Debug-iphonesimulator/LiftRank.app.
  - [x] Reworked the combined alert panel into a compact signal summary with per-signal next actions (plateau details, recovery, volume, or program progress) and improved accessibility values; build/install/launch verified at `/tmp/LiftRivals-home-alert-organized/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Home now includes a missed-session signal with the planned workout name and scheduled date, alongside the existing plateau, recovery, volume, sync, and milestone actions; build verified at `/tmp/LiftRivals-home-missed-alert/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Re-evaluate quick actions so Add missed workout and View Progress are prioritized over lower-frequency actions such as Gyms. Home exposes Progress and missed-workout recovery directly, while the gym directory remains available through its dedicated flow.
  - [x] Replaced the Home Gyms shortcut with direct Progress access; the gym directory remains available from its dedicated flow.
  - [x] Home’s workout quick action now changes to “Log missed workout” with a recovery icon when a planned session is missed; otherwise it remains “Log workout.” Simulator build passed at `/private/tmp/LiftRivals-home-missed-action-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Test Home with no plan, active plan, rest day, missed workout, backdated workout, active workout, empty account, and program-complete states.
- [x] Keep the Home scroll performance test aligned with the current UI (`Recent submitted PRs` and the weekly training-goal control); the isolated test passes with 0 failures in `/tmp/LiftRivals-full-test-gate/Logs/Test/Test-LiftRank-2026.10.05_06-32-50--0400.xcresult`.
  - [x] Re-ran the Home scroll/performance regression after the program-milestone and sync-alert changes; 1 test passed on the iPhone 17 simulator at `/tmp/LiftRivals-home-milestone-tests/Logs/Test/Test-LiftRank-2026.10.05_17-29-17--0400.xcresult`.
  - [x] Fixed the active-workout/no-scheduled-session state so Home shows Resume workout, uses the play icon, and routes back to Today instead of opening Programs; build/install/launch verified at `/private/tmp/LiftRivals-home-active-resume-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.

### Phase 4.1 detail — Gamification expansion

- [x] Enrich the existing workout-finish celebration after a successful save: highlight earned weight, rep, and volume PRs, program milestones, and awards; lead with the most meaningful result and provide View all achievements. The saved screen orders program milestones before PRs, volume, completion, and awards, and exposes a working View all achievements disclosure.
  - [x] Show a post-save confirmation only after the workout save succeeds, with key workout metrics and the top PR, volume-PR, or achievement highlights.
  - [x] Include planned-session completion as a workout highlight when a planned session is fully logged.
  - [x] Add first-session, halfway, and program-complete context from the saved plan/session graph.
  - [x] Provide a working View all achievements disclosure on the saved screen.
  - [x] Add program-milestone context and order the celebration by significance rather than category; program completion/halfway context now leads, followed by PRs, volume, session completion, and awards. Simulator build passed at `/private/tmp/LiftRivals-gamification-build/Build/Products/Debug-iphonesimulator/LiftRank.app`; `testWorkoutCompletionHighlightsLeadWithProgramMilestone` passed in `/tmp/LiftRivals-gamification-tests/Logs/Test/Test-LiftRank-2026.10.04_06-57-35--0400.xcresult`.
- [x] Add a user-selected weekly training-day goal to Home and Tracker, updated after workouts; count multiple workouts on one day once, respect rest days, and show the next attainable milestone. Goal choice is persisted in the existing local workout-preference snapshot and can be disabled.
- [x] Add program milestones for the first week, halfway point, and completion based on completed scheduled sessions; missed workouts logged later count toward their original date and matching session. Milestone counting ignores empty placeholders and de-duplicates completed planned sessions by source session ID.
  - [x] Milestone counting now ignores empty plan-session placeholders and de-duplicates completed planned sessions by source session ID, so backfilled completions cannot advance a program twice; simulator build passed at `/private/tmp/LiftRivals-milestone-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Add a personal progress timeline with dated milestones linked to workouts, including comeback milestones. Personal Profile now shows workout-count, comeback, and unlocked-achievement events; workout milestones open the saved workout detail, and the timeline is excluded from Public Profile.
  - [x] Simulator app build verified at `/tmp/LiftRivals-profile-timeline-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Add owner-controlled public badge visibility. Achievements remain private until this setting is persisted and exposed in Public Profile.
- [ ] Add optional monthly consistency challenges and earned profile titles/frames without encouraging unnecessary weight or volume increases.
- [ ] Add friend rivalries and gym/community challenges with invitations, individual goals, privacy controls, shared progress, and server validation.
- [ ] Extend the existing workout/achievement system with PostgreSQL-authoritative rewards and an offline cache; associate rewards with source workouts, prevent duplicate awards on retries, and recalculate appropriately after backdated entries, edits, or deletions.
- [ ] Verify ordinary and PR finishes, offline sync, duplicate saves, backdated plan workouts, and account reloads. Deliver the richer finish screen and weekly goals first, verify them in the simulator, and identify the TestFlight build containing them.

### Phase 1.4 detail — Exercise identity and icon audit

- [x] Inventory all 337 built-in training exercises, six ranking choices, shared renderers, custom/prescription fallback paths, and existing icon tests; document source findings in [full icon audit](docs/exercise-icon-audit.md). Runtime visual verification remains pending.
  - [x] Expanded the core catalog pass for cable fly, pec deck, lat pulldown, seated cable row, lateral/rear-delt fly, incline dumbbell curl, and cable crunch; simulator build passes.
- [ ] Unify exercise identity/rendering across Add Exercises, Library, workout/plan/substitute/Progress views, leaderboard pickers, and Submit a Lift; eliminate independent mappings that leave old icons visible.
  - [x] Home recent-lift and Personal Profile lift rows now resolve persisted exercise names through the shared catalog renderer instead of their independent name-to-symbol switches; simulator build verified at `/tmp/LiftRivals-icon-surface-current-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] That artifact was installed and launched successfully on the iPhone 17 simulator (bundle `com.liftrank.app`, launch PID recorded by `simctl`); picker/Profile visual contact-sheet review remains open.
  - [x] Updated the shared core workout library so overhead press, shoulder press, leg press, and leg extension no longer reintroduce the old arrow symbols.
  - [x] Leaderboard and Submit a Lift ranking choices now resolve their icons from the shared training catalog instead of an independent mapping; simulator build passes.
  - [x] Leaderboard result rows now resolve the displayed exercise icon from the same catalog, replacing the generic dumbbell glyph; simulator build passes.
  - [x] Unresolved leaderboard exercises now use a neutral strength-training figure rather than a misleading dumbbell fallback; build/install/launch verified at `/tmp/LiftRivals-leaderboard-fallback-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Home recent-PR rows now use the same neutral movement fallback for unresolved exercise names instead of a generic dumbbell; build/install/launch verified at `/tmp/LiftRivals-home-icon-fallback-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] The shared catalog renderer now provides movement-specific composites for lateral raises, calf raises, leg presses, pulldowns, pullovers, and rows across every surface that uses `ExerciseCatalogIcon`; simulator build/install passed.
  - [x] Added shared movement composites for front raises, face pulls, band pull-aparts, flies, and rear-delt flies; simulator build/install passed.
- [ ] Replace remaining generic figures, equipment-only fallbacks, and arrows across the full inventory; correct core-first matching, pullover spelling, upright-row, and custom/prescription fallback cases.
  - [x] Added dedicated movement renderers for back extensions, horizontal presses, shrugs, wrist curls, hip thrusts/glute bridges, and leg curls/extensions; full-catalog renderer regression passed at `/tmp/LiftRivals-icon-families-test/Logs/Test/Test-LiftRank-2026.10.04_07-06-19--0400.xcresult`.
  - [x] Core movement matching now runs before body-part fallbacks for crunches, planks, twists, Pallof presses, and wood chops; pullover and pull-over IDs share the intended pullover mapping.
  - [x] Unresolved catalog entries now use a neutral functional movement fallback instead of `dumbbell.fill`, so custom/prescription surfaces do not imply unsupported equipment; simulator build verified at `/tmp/LiftRivals-icon-neutral-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Catalog regression confirms no expanded exercise retains the unresolved `dumbbell.fill` fallback; focused iPhone 17 test passed at `/tmp/LiftRivals-icon-neutral-tests/Logs/Test/Test-LiftRank-2026.10.05_19-24-21--0400.xcresult`.
- [ ] Review a labeled full-catalog contact sheet at picker and tile sizes in light/dark mode; verify every affected screen and replace tests that currently expect weak placeholders.
  - [x] Updated icon regression expectations for the calf-raise and overhead-press replacements.
  - [x] Full built-in inventory renderer coverage now exercises all 337+ catalog entries at picker size; `testExerciseCatalogIconsRenderForFullBuiltInInventory` passed on the iPhone 17 simulator in `/tmp/LiftRivals-icon-inventory-tests/Logs/Test/Test-LiftRank-2026.10.04_07-03-34--0400.xcresult`.
  - [x] Re-ran `testExerciseCatalogIconsRenderForFullBuiltInInventory` against the current shared renderer and source surfaces; the iPhone 17 simulator test passed with no failures in `/tmp/LiftRivals-icon-current-tests/Logs/Test/Test-LiftRank-2026.10.05_17-06-49--0400.xcresult`.
  - [x] Replaced the unavailable `figure.hang` SF Symbol used by pull-up and hanging-leg-raise paths with supported climbing/core symbols; the full inventory renderer test passed without symbol warnings in `/tmp/LiftRivals-home-icon-tests/Logs/Test/Test-LiftRank-2026.10.05_04-03-50--0400.xcresult`, and that tested app was installed/launched on iPhone 17.
  - [x] Updated the remaining stored pulldown/pullover and cable-row fallbacks to climbing and rowing movement symbols, and removed the generic traditional-figure fallback for unresolved chest/shoulder/arm entries; the catalog regression passed on iPhone 17 at `/tmp/LiftRivals-stored-icon-tests-2/Logs/Test/Test-LiftRank-2026.10.05_19-59-17--0400.xcresult`.
  - [x] Machine and Smith-machine exercises now use a machine-stack cue instead of a misleading dumbbell overlay; full built-in renderer coverage passed on iPhone 17 at `/tmp/LiftRivals-machine-icon-tests/Logs/Test/Test-LiftRank-2026.10.05_19-27-25--0400.xcresult`.
  - [x] Leg-press variants now distinguish 45-degree/linear, vertical, and horizontal movement direction instead of sharing one right-arrow cue; full built-in renderer coverage passed at `/tmp/LiftRivals-legpress-icon-tests/Logs/Test/Test-LiftRank-2026.10.05_19-30-17--0400.xcresult`.
  - [x] Full built-in icon coverage now renders every catalog entry at picker size in both light and dark color schemes; focused iPhone 17 test passed at `/tmp/LiftRivals-icon-appearance-tests/Logs/Test/Test-LiftRank-2026.10.05_19-34-23--0400.xcresult`.
  - [x] Generated and visually inspected separate labeled full-catalog contact sheets for both appearances at `/tmp/LiftRivals-exercise-icon-contact-sheet-light.png` and `/tmp/LiftRivals-exercise-icon-contact-sheet-dark.png`; the iPhone 17 generation test passed at `/tmp/LiftRivals-icon-contact-tests-2/Logs/Test/Test-LiftRank-2026.10.05_20-06-41--0400.xcresult`.
  - [x] Current Release simulator artifact rebuilt successfully after the contact-sheet/icon changes at `/tmp/LiftRivals-icon-release-current/Build/Products/Release-iphonesimulator/LiftRank.app`; install/launch retry was blocked by a transient CoreSimulatorService connection failure, so runtime release verification remains open.
  - [x] Replaced the focused icon regression's weak stored-symbol assertions with user-facing renderer checks for the named cable, machine, press, row, leg, and bodyweight exercises; the iPhone 17 test passed at `/tmp/LiftRivals-named-icon-audit/Logs/Test/Test-LiftRank-2026.10.05_19-51-18--0400.xcresult`.
- [ ] Record the source revision and actual TestFlight build containing the visually verified icons before marking the icon pass complete.
- [ ] Replace the generic up-arrow on standing and seated calf raises with movement-specific icons; keep calf raises visually distinct from front raises.
  - [x] Calf-raise catalog mappings now use posture-aware movement symbols instead of the generic up-arrow.
  - [x] The shared picker renderer now uses a seated posture for seated calf raises and an upward-to-line heel cue for all calf raises, while front raises retain a separate arm-raise cue; focused icon regression passed at `/tmp/LiftRivals-calf-icon-tests/Logs/Test/Test-LiftRank-2026.10.05_02-54-06--0400.xcresult`.
- [ ] Replace misleading shared icons for wrist curls, shrugs, band pull-aparts, stiff-leg deadlifts, hip thrusts, glute bridges, hip abductions, upright rows, band lat pulldowns, and band overhead triceps extensions; update all exercises sharing those mappings.
  - [x] Expanded catalog symbol resolution now gives wrist curls, shrugs, pull-aparts, stiff-leg deadlifts, and band overhead triceps extensions movement-specific symbols; focused catalog assertions cover those families. The broader visual audit remains open.
  - [x] Corrected the invalid cable-row SF Symbol name and broadened matching to all cable-row IDs; the focused icon test passed at `/tmp/LiftRivals-icon-family-tests/Logs/Test/Test-LiftRank-2026.10.05_03-28-50--0400.xcresult`.
  - [x] Added a movement-specific functional symbol for push-up and dip families in both the shared picker renderer and ranking catalog resolver; the focused icon regression passed at `/tmp/LiftRivals-pushup-icon-tests/Logs/Test/Test-LiftRank-2026.10.05_03-35-25--0400.xcresult`.
  - [x] Updated the independent Home and workout-summary lift-symbol helpers so push-up and dip names no longer fall back to chart/dumbbell glyphs; build/install/launch verified at `/tmp/LiftRivals-icon-surface-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Aligned Profile and Home summary icon helpers with the shared row, pulldown, curl, fly, lunge, calf, leg-press, hip, shrug, and deadlift families so recent-lift summaries no longer use generic fallback symbols; build/install/launch verified at `/tmp/LiftRivals-summary-icon-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Name-only Home/Profile fallback paths now use climbing, standing, and strength-training movement symbols instead of pulldown arrows, open-arm curl/fly placeholders, or shrug arrows; rebuilt and launched on iPhone 17 at `/tmp/LiftRivals-icon-fallback-slice/Build/Products/Debug-iphonesimulator/LiftRank.app` (PID `59569`).
  - [x] Name-only historical lifts now neutralize weak caller-provided fallbacks before rendering when no catalog identity exists; focused iPhone 17 render test passed at `/tmp/LiftRivals-name-icon-tests/Logs/Test/Test-LiftRank-2026.10.05_19-37-38--0400.xcresult`.
  - [x] Split lateral raises from fly icons and route upright rows before the generic row matcher so they no longer inherit misleading movement symbols.
  - [x] Finalized the shared renderer pass for shrugs, wrist curls/extensions, hip thrusts/glute bridges, and hip abduction/lateral-walk movements; simulator build/install/launch verified at `/tmp/LiftRivals-icon-audit-consistent/Build/Products/Debug-iphonesimulator/LiftRank.app` (launch PID `63549`).
- [ ] Distinguish barbell, dumbbell, and band overhead presses where the movement icon otherwise looks identical, then verify the affected families in the exercise library and other screens using catalog icons.
  - [x] Leaderboard and Home lift summaries now render overhead, shoulder, and push presses with a standing movement symbol instead of the generic dumbbell fallback; simulator build verified at `/private/tmp/LiftRivals-overhead-press-icon-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Arnold and military press names now join the same standing-press family in the catalog renderer and expanded symbol resolver, with focused catalog assertions.
  - [x] Removed the stored overhead-press up-arrow fallback so leaderboard and other non-library renderers use a strength-training movement symbol.
  - [x] Focused icon regression now passes against both the popular catalog and shared core library mappings, including shoulder press, leg press, and leg extension entries.
  - [x] Replaced stored arrow placeholders for band face pulls, cable/internal-external rotation, cable front raises, and standing calf raises so raw-symbol surfaces no longer resurrect those weak icons; focused icon assertions were updated.
  - [x] Shared library composites now vary overhead and lateral-raise implement marks by barbell, dumbbell, band, or cable, and calf raises use a distinct movement cue; simulator build succeeds. Visual contact-sheet and TestFlight verification remain open.
  - [x] Stored overhead and shoulder-press symbols now use an upright movement figure instead of the generic circular-arrow glyph across raw-symbol picker and ranking surfaces; focused icon expectations were updated.
  - [x] Neck-machine exercises now use a standing movement icon with directional neck cues instead of the dumbbell fallback; targeted icon regression passed in `/tmp/LiftRivals-neck-icon-test.xcresult`.

### Phase 2.1 detail — Personal and public profile

- [ ] Define Personal Profile as the private training dashboard and Public Profile as the shareable athlete card; do not rely only on `isCurrentUser` conditionals.
  - [x] Owner weight-class and relative-strength displays now prefer the latest logged bodyweight entry; public profiles retain the persisted profile value. Simulator build passes.
  - [x] Profile navigation now labels the owner route “Personal profile” and visitor routes “Public profile” when no username is available, making the private dashboard versus public athlete surface explicit; build/install/launch verified at `/tmp/LiftRivals-profile-surface-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] `ProfileView` now accepts an explicit Personal/Public surface while retaining compatibility with existing callers; public preview routes use the explicit public surface. Build/install/launch verified at `/tmp/LiftRivals-profile-surface-explicit-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] The explicit surface is now authoritative; `isCurrentUser` is derived from it, preventing Personal/Public state divergence. Build/install/launch verified at `/tmp/LiftRivals-profile-surface-authoritative-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Updated the repeated Public Profile UI acceptance test to assert the explicit profile section navigation, and the isolated test passed with 0 failures at `/tmp/LiftRivals-profile-ui-test-2/Logs/Test/Test-LiftRank-2026.10.05_06-13-31--0400.xcresult`.
  - [x] The Me-hub awards/Public Profile entry-point UI test also passes with the updated public-surface assertion; result bundle: `/tmp/LiftRivals-me-hub-ui-test/Logs/Test/Test-LiftRank-2026.10.05_06-21-37--0400.xcresult`.
  - [x] Updated lift-video UI acceptance tests to use the current `profile.prVideos` accessibility surface; the competition-fixture video flow passes with 0 failures at `/tmp/LiftRivals-video-ui-test/Logs/Test/Test-LiftRank-2026.10.05_06-26-19--0400.xcresult`.
- [x] Add a “View as public” preview from Settings; Personal Profile’s existing “View public profile” route now renders the public-facing state.
- [ ] Ensure Training history shows only workouts belonging to the viewed athlete; test own and another athlete's profile so no private or misattributed workouts appear.
- [x] Give blank demo/incomplete profiles a meaningful name or completion prompt instead of an empty name and lone “@”. Owner profiles show “Your profile” plus a Complete profile action; public viewers show “Athlete profile” and “Username unavailable.”
  - [x] Owner profiles retain the Complete profile prompt; public viewers now see neutral Athlete profile and Username unavailable labels.
  - [x] Public profile navigation titles now use Athlete profile when no username exists.
- [ ] Clarify the Overview / PR videos / Training / History / Submissions navigation: make it true section selection or clearly identify it as shortcuts within one scrolling page; avoid confusing duplicate section labels.
  - [x] The profile shortcut is now labeled “PR videos” to match the destination content instead of the ambiguous “Videos”; build verified at `/private/tmp/LiftRivals-profile-label-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Public profiles now omit the private Workout history destination and section; Personal Profile retains the history filters, while public navigation stays limited to shareable sections. Simulator build/install/launch verified at `/private/tmp/LiftRivals-profile-nav-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] The Training shortcut now uses the concise “Training” label while the expanded destination remains “Training profile,” removing the duplicate-looking navigation title; build verified at `/tmp/LiftRivals-profile-nav-current/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Replace the prominent all-zero strength card with a compact empty state and Submit Lift action until qualifying lifts exist; show the full total and breakdown once data exists.
  - [x] Owner and visitor profiles now use a compact “No ranked lifts yet” state; owners get a direct Submit lift action, while populated profiles retain the total and breakdown card.
- [ ] Make the profile header actions self-explanatory, especially Submit Lift and Edit Profile; ensure the Training shortcut opens or reaches its collapsed content.
  - [x] Owner profile toolbar actions now show visible Submit lift and Profile actions labels while retaining their existing behavior and accessibility labels.
- [ ] Add explicit source labels for logged workout PRs, submitted lifts, video-backed lifts, self-reported lifts, and private lifts.
  - [x] Personal training-history rows now identify Program versus Freestyle workouts while public profiles continue to hide workout history.
  - [x] Profile submission rows now explicitly label Private submission, Video-backed submission, or Self-reported submission; simulator build/install/launch verified at `/private/tmp/LiftRivals-profile-source-build-2/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Add Personal Profile filters for workout history, date range, program, and exercise.
  - [x] Personal workout history now supports date windows, Program/Freestyle filtering, exercise search, and a larger result window; public profiles remain history-hidden. Simulator build passed at `/private/tmp/LiftRivals-profile-history-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] `testProfileHistoryDateRangesUseExpectedCutoffs` passed on the iPhone 17 simulator; result bundle: `/tmp/LiftRivals-profile-history-tests/Logs/Test/Test-LiftRank-2026.10.04_06-52-39--0400.xcresult`.
- [x] Make public ranking cells actionable or remove action-like subtitles when no navigation exists.
  - [x] City, state, and age ranking cells now say “No … rank yet” instead of implying a dead leaderboard link.
  - [x] Public profiles no longer inherit the current viewer’s verified-total subtitle; the global rank card states that rank is not shown publicly.
- [x] Label public progress as submitted-lift history and make hidden workout history clearly a privacy choice.
  - [x] Public profiles now use “Submitted-lift progress” and “No submitted-lift history yet,” while owner profiles retain the private training labels.
  - [x] Public-profile achievement rendering now avoids the viewer-local unlock store and presents achievements as private until an owner-controlled audience setting is available; the profile persistence regression passed at `/tmp/LiftRivals-profile-privacy-tests/Logs/Test/Test-LiftRank-2026.10.05_01-22-18--0400.xcresult`.
- [ ] Add public states for private, restricted, blocked, deleted, and no-public-data profiles.
  - [x] Public profile routing now distinguishes blocked athletes, private/no-public training data, and ordinary empty profiles with explicit user-facing states; blocked profiles offer an unblock action.
  - [x] Private public profiles now stop rendering visitor profile content and show an explicit private state; visible-lift refreshes are skipped for private profiles.
  - [x] Profile-wide Friends and Gym audiences now use an explicit access resolver; Gym permits shared primary-gym viewers, while Friends remains restricted until an accepted friendship is available to the local cache.
  - [x] Public/Gym/Friends/Private access regression passed with two focused tests at `/tmp/LiftRivals-profile-audience-tests/Logs/Test/Test-LiftRank-2026.10.05_04-46-01--0400.xcresult`; app build/install/launch verified at `/tmp/LiftRivals-profile-audience-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Blocked public profiles now replace the profile content with an explicit blocked state and reversible Unblock action; the profile build succeeds at `/private/tmp/LiftRivals-profile-blocked-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Blocked public profiles also skip visible-lift refreshes, preventing background data loading after a block; final build verified at `/private/tmp/LiftRivals-blocked-profile-final/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Public profiles with no visible submissions now show an explicit no-public-training-data explanation instead of an ambiguous empty page; build verified at `/private/tmp/LiftRivals-public-empty-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Add report/block confirmation, completion feedback, and recovery from failed actions.
  - [x] Blocking another athlete now requires explicit confirmation; Unblock remains immediate and the blocked profile state is reversible. Build verified at `/private/tmp/LiftRivals-profile-block-confirm-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Lift and athlete reports now show an explicit submitted confirmation before dismissing, while failures remain retryable in place; build verified at `/private/tmp/LiftRivals-report-feedback-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Ensure achievements and profile badges have explicit public/private visibility controls.
  - [x] Public profiles now hide achievement unlocks instead of reading the viewer's local unlock store; build verified at `/private/tmp/LiftRivals-profile-achievement-build/Build/Products/Debug-iphonesimulator/LiftRank.app`. Keep the parent open until an explicit owner-controlled public badge setting is added.
- [ ] Check the profile layout with empty, partially complete, and populated accounts in light and dark mode, including larger text sizes.

### Phase 2.2 detail — Settings and privacy controls

- [x] Organize Settings into Account, Privacy, Training, Notifications, Appearance, Legal, and Developer sections; stable section identities and simulator build evidence are recorded below.
  - [x] Grouped the existing sign-out and delete-account actions under an explicit Account section; simulator build passes.
  - [x] Renamed the workout-preference section to Training and aligned the support link with the documented `/support/` route.
  - [x] Added stable section identities for Account, Privacy, Training, Notifications, Appearance, Legal, and Developer so navigation and deep links can target every Settings group; simulator build passed at `/private/tmp/LiftRivals-settings-sections-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Wire Allow comments and Notification preferences to real saved behavior, or remove the switches until that behavior exists.
  - [x] Removed the non-persisted Allow comments and in-app notification toggles; Settings now exposes only the real iOS notification-permission entry point.
- [x] Keep Settings visible while profile/privacy changes save; show progress, success or a recoverable error instead of dismissing before the result is known.
  - [x] Settings uses an explicit Done save action, keeps the sheet open with a progress indicator while persistence runs, and presents a retryable save error without dismissing on failure; the latest simulator build completed successfully at `/private/tmp/LiftRivals-settings-verification/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Define one save model: immediate-save with confirmation or explicit Save/Cancel; do not mix both without explanation.
  - [x] Profile/privacy edits use the explicit Done save model; training toggles remain intentionally immediate because they are independent workout preferences.
- [ ] Make Private profile override behavior and individual audience controls clear, reversible, and testable.
  - [x] Settings now states that Private profile overrides the individual fields and that turning it off restores their saved settings; field toggles consistently say “from public.”
  - [x] Settings privacy copy build installed and launched on iPhone 17 at `/private/tmp/LiftRivals-settings-privacy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Use consistent privacy labels for profile, bodyweight, age band, location, gym, and lift videos.
  - [x] Settings privacy copy uses one public-visibility vocabulary for profile, bodyweight, age band, location, gym, and approved lift videos.
- [x] Add a public-profile preview that updates when visibility settings change.
  - [x] Settings preview now renders the staged privacy/profile draft, so unsaved visibility toggles are reflected before saving.
- [ ] Explain the difference between public, video-backed, self-reported, and private PR submission settings.
  - [x] Settings now explains that automatic sharing may publish eligible PRs as self-reported or video-backed, while ordinary workout logs and private PRs remain private.
- [x] Confirm Reset Demo Data with a clear list of affected local data and keep it unavailable in production.
  - [x] The confirmation lists the demo profile, workouts, bodyweight history, plans, awards, and other local data, states production accounts are unaffected, and the destructive action is only rendered while `isDemoMode` is true.
- [ ] Verify sign-out, delete-account, legal acceptance, support, appearance, and unit settings after a fresh reload.
  - [x] The Settings save/reload UI regression verifies Done dismissal, privacy-toggle persistence across reopening, and recoverable sheet behavior; 1 test, 0 failures at `/tmp/LiftRivals-home-icon-build/Logs/Test/Test-LiftRank-2026.10.05_06-58-40--0400.xcresult`.
- [x] Fix the About text and support link so they describe the actual available support path; About now names `support@liftrivals.com` and warns users not to send credentials, while Settings links to the live Support page. Build verified at `/private/tmp/LiftRivals-settings-support-copy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] About now describes workout tracking, evidence labels, and directs users to the Settings Support link; Support points to the canonical trailing-slash URL `https://liftrivals.com/support/`.

### Phase 3.1 detail — Leaderboards

- [ ] Show eligible PRs without video on the Self-reported leaderboard when automatic sharing is enabled; attaching video updates the same lift to Video-backed. Keep results to 100 per page with Load more, search, and Jump to my rank.
  - [x] Focused regression confirms verified mode excludes self-reported lifts, All lifts includes both evidence states, and Self-reported isolates the no-video entries; result bundle: `/tmp/LiftRivals-leaderboard-audit-test/Logs/Test/Test-LiftRank-2026.10.05_18-26-12--0400.xcresult`.
  - [x] Automatic PR sharing now has focused coverage for the no-video path: an eligible PR is submitted as self-reported, leaderboard-eligible, and linked to its source workout when sharing is enabled; `testWorkoutPRSubmissionStorePublishesSelfReportedPRWithoutVideoWhenEnabled` passed at `/tmp/LiftRivals-self-reported-test/Logs/Test/Test-LiftRank-2026.10.05_01-38-41--0400.xcresult`.
  - [x] The leaderboard surface renders at most 100 matching entries per page and exposes an accessible “Load next 100” action while additional results remain.
  - [x] Evidence filters now explain their scope above results and in the empty state: Video-backed states that only lifts with attached video are ranked, while Self-reported explains that eligible public lifts without video appear there and move to Video-backed after a video is attached; build/install/launch verified at `/tmp/LiftRivals-leaderboard-evidence/Build/Products/Debug-iphonesimulator/LiftRank.app` (PID `61447`).
  - [x] Added a conditional Jump to my rank action that uses the existing scroll-focus request when the current athlete is loaded.
  - [x] The local/demo verified view now excludes self-reported lifts while the unfiltered view retains them; simulator build passes.
  - [x] Owner-versus-self-reported eligibility coverage now uses separate athletes and passes the focused XCTest; the leaderboard remains one row per athlete.
- [ ] Correct ranking semantics and user rank: avoid a client-side result cap hiding a valid rank, remove fabricated movement values, and define what All exercises ranks.
  - [x] Jump to my rank now expands the 100-row page window to include the current athlete before scrolling; simulator build verified at `/private/tmp/LiftRivals-roadmap-current-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Demo ranking no longer fabricates movement from usernames or a fixed current-user delta; movement stays neutral until a real prior snapshot is available.
  - [x] Unchanged rank movement now renders a neutral dash instead of an upward `+0`; positive and negative movement retain directional styling. Simulator build passes.
  - [x] The All exercises view now explains that Total is the best bench + squat + deadlift, while Relative explains the bodyweight comparison.
- [ ] Apply every filter consistently in demo and production, including location/gym, age, class, evidence, reps, and calendar time ranges; keep selected scope when returning to the page.
  - [x] Scope selection now exposes Global, country, state, city, class, and gym levels; state/country selections populate the same authoritative filter fields used by local and remote results.
  - [x] Remote leaderboard results now apply the same exercise, gym, city, state, country, sex, age, weight-class, evidence, reps, and time-range filters as the local/demo path; country is preserved through profile mapping and the focused remote-filter XCTest passed on the iPhone 17 simulator.
  - [x] Full `RankingCalculatorTests` regression class passed after the remote filter alignment, including leaderboard refresh, privacy, icon, calendar, sync, and workout-summary coverage.
- [ ] Show the qualifying lift's exercise, reps, date, evidence status, and weight basis (including per-hand dumbbell weight), with a direct path to the lift; distinguish loading errors from no results.
  - [x] Leaderboard result rows now show the recorded weight × reps, performed date, and “per hand” when applicable, alongside the exercise and evidence badge.
  - [x] Leaderboard refresh failures now render a distinct retryable “Leaderboard unavailable” state instead of being misclassified as “No ranked lifters”; build/install/launch verified at `/private/tmp/LiftRivals-leaderboard-error-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Simplify duplicate filter controls and improve demo athletes so location, class, evidence, and Most Improved filters can be meaningfully tested.
  - [x] Quick-filter “All lifters” now clears the separate video-only flag as well as the filter object, so its label and result semantics agree; build verified at `/private/tmp/LiftRivals-leaderboard-quick-filter-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.

### Phase 5.1 detail — Verification before production training data

- [ ] Implement and test the profile/history and settings safety fixes, then install a verified new build on the phone; local changes are not present in the current production app or TestFlight build automatically.
- [ ] On that build, complete one small test workout and verify its saved record in the production backend and after a fresh sign-in before relying on it for a full workout; do not reinstall while sync is uncertain.

### Phase 3.2 detail — Forum workflow plan

- [ ] Define the forum information architecture: neutral hub, All / For You / Following feeds, community directory, community detail, rules, and membership states.
  - [x] Added a browseable community directory from the neutral hub with summaries, categories, join/leave state, and a direct View discussions action; All / For You / Following remains the feed navigation.
  - [x] Forum membership loading now retains server status so Restricted requests display Pending instead of being presented as Joined; Pending actions remain disabled until the server changes the membership. Build verified at `/tmp/LiftRivals-profile-timeline-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Inventory every visible forum control and assign an end-to-end action: feed selection, community selection, join/leave, sort, new post, open post, nested reply, vote, share, report, block, and notifications.
  - [x] Forum feed cards now show the server-backed vote and reply totals with the current vote state, while the thread remains the action surface for voting and replies.
- [ ] Complete the post and comment workflow: drafts, validation, loading, success, retry, locked posts, deleted content, empty states, and offline/network errors.
  - [x] Locked discussions now hide the reply composer, show a clear read-only message, and reject reply submission defensively; simulator build passed at `/private/tmp/LiftRivals-forum-locked-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Finish nested discussion behavior: reply targets, indentation, collapse/expand branches, orphan handling, comment counts, and refresh after posting.
  - [x] Added collapse/expand controls for comment branches while preserving nested indentation, reply targets, and exact-comment notification scrolling; simulator build verified at `/private/tmp/LiftRivals-roadmap-current-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Thread comments now have a real Best/New sort menu applied to root comments and nested replies while preserving indentation and collapse state; build/install/launch verified at `/private/tmp/LiftRivals-forum-comment-sort-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Demo forum threads now include a deterministic nested reply, so the simulator exercises reply indentation and branch collapse/expand instead of showing only flat comments; build/install/launch verified at `/tmp/LiftRivals-forum-nested-demo-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Implement one-vote-per-user reactions with visible selected state, undo, server-authoritative counts, and protection against voting on one’s own content; decide whether downvotes affect ranking or are private feedback.
  - [x] Post score loading now sums the server-stored vote values, thread posts/comments expose upvote and downvote actions with undo state, and reopened threads hydrate the current user’s post and comment votes; the simulator build compiles successfully. Production/RLS acceptance coverage remains open.
  - [x] Comment vote labels now interpolate the persisted score instead of displaying the literal placeholder text; build/install/launch verified at `/private/tmp/LiftRivals-forum-vote-label-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Add community and content moderation roles enforced by server permissions: report queues, review states, remove/restore, lock, moderator labeling, appeals, audit history, and no moderation controls for regular users.
  - [x] Audited the current client routing: regular forum hub/thread surfaces have no Moderator Review entry point; role enforcement for any direct route and the server-side report queue remain intentionally open.
- [ ] Add abuse safeguards: rate limits, duplicate-submit protection, blocked-user filtering, report reasons, and clear user-facing moderation outcomes.
  - [x] Post and reply actions now guard against duplicate submissions while a request is in flight and show a progress state; server-side rate limits and blocked-user filtering remain open.
- [ ] Add notifications for replies, mentions, and meaningful reactions with read/unread state and deep links back to the exact post or comment.
  - [x] Forum notification deep links now surface a clear unavailable-access state when the target post cannot be loaded instead of silently dropping the destination; unknown destination decoding also passed `testUnknownNotificationDestinationFallsBackWithoutDroppingTheNotification` at `/tmp/LiftRivals-notification-test/Logs/Test/Test-LiftRank-2026.10.05_03-52-44--0400.xcresult`; build/install/launch verified at `/tmp/LiftRivals-forum-deeplink-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Add forum acceptance tests covering every button, role, feed, nested reply, vote, report, moderation action, and failure state in demo and production configurations.

### Appendix — Findings to fix before a user beta

- [ ] Load membership from the server on launch; make Following reflect joined communities, give For You its own defined behavior, and show Restricted requests as Pending rather than Joined.
  - [x] Load Joined/Muted community memberships from the server so Following survives navigation and relaunch.
  - [x] Keep For You distinct from All: when no joined communities are available, show an explicit empty state instead of silently falling back to every post.
  - [x] For You now has distinct behavior: joined-community posts plus pinned recommendations; Following remains joined-community posts.
- [ ] Replace placeholder Top and Most discussed sorting with real vote and comment metrics; add post pagination and search beyond the first 50 posts.
  - [x] Added offset-aware forum post loading and a guarded “Load more discussions” action after each 50-post page.
  - [x] Post cards now load vote/comment aggregates from Supabase; Top sorts by votes and Most discussed sorts by comments with recency tie-breakers.
  - [x] Jump to my rank now appears only when the current athlete is present in the active filtered/search result set, avoiding a no-op control; simulator build passed at `/private/tmp/LiftRivals-leaderboard-jump-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Leaderboard header rank and lifter count now reflect the active filtered/search result set instead of the unfiltered global list; simulator build passed at `/private/tmp/LiftRivals-leaderboard-metrics-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] All Exercises absolute rankings now label the value as Best and explain that the ranking uses each athlete's best eligible single lift; simulator build passed at `/private/tmp/LiftRivals-leaderboard-all-exercises-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Local/demo leaderboard filtering now applies country and city-ID scope exactly like the remote path; simulator build passed at `/private/tmp/LiftRivals-leaderboard-scope-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Replace hard-coded post/comment counts and decorative vote, share, report, rules, and overflow controls with working actions or remove them; show the actual community and author on each post.
  - [x] Comment vote controls now persist one-vote-per-user state through the existing forum comment-vote table; removed the hard-coded comment vote count.
  - [x] Removed fabricated post vote/comment counts and the non-actionable share affordance from post cards; voting and sharing remain available only where their actions are implemented.
  - [x] Thread vote counts now use the loaded post aggregate instead of a hard-coded value.
  - [x] Replaced the former decorative share icon in the thread header with a native Share action that includes the discussion title and body; build/install/launch verified at `/tmp/LiftRivals-forum-share-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Removed decorative ellipsis controls from post cards and comments; reporting remains available from the thread action menu.
  - [x] Added reporting for individual comments through the existing reason dialog and server report pipeline; simulator build passed at `/private/tmp/LiftRivals-forum-comment-report-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Report confirmation now names the actual reported target instead of showing the literal `(targetType)` placeholder; build/install/launch verified at `/private/tmp/LiftRivals-forum-report-copy-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Removed the non-actionable About and Rules labels from the hub until community-detail and rules views are connected.
  - [x] Forum post cards now use the current user's username or a cached author profile when available, with a safe community-member fallback; build/install/launch verified at `/private/tmp/LiftRivals-forum-author-label-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] Thread headers, nested comments, and the reply-target banner now use the current user’s username or a cached author profile when available, with a safe community-member fallback; build verified at `/private/tmp/LiftRivals-forum-reply-author-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [x] Make demo forum actions clearly read-only or persist their state across navigation, so the simulator does not imply a post, reply, or vote was saved when it was not.
  - [x] Demo join, leave, post, comment, vote, watch, report, and moderation actions now return explicit unavailable errors instead of silent success.
  - [x] Demo join/leave, vote, watch, and report mutations now fail explicitly instead of returning successful no-ops; the simulator cannot imply those actions were saved.
  - [x] Demo threads now show a read-only badge, hide the report menu, disable reply/vote/watch controls, and explain that sign-in is required; build/install/launch verified at `/private/tmp/LiftRivals-forum-demo-readonly-build/Build/Products/Debug-iphonesimulator/LiftRank.app`.
- [ ] Route forum-reply notifications to the exact thread/comment; handle unknown notification destinations without dropping the entire notification list.
  - [x] `forumPost` destinations now open the exact discussion thread, and unknown destination kinds fall back to Home while preserving the notification; focused XCTest coverage passed.
  - [x] Optional comment targets now flow through notification decoding, routing, and the thread view, which scrolls the exact nested reply into view; a forward-only source migration adds `commentID` to future forum-reply payloads, and the app build passed at `/private/tmp/LiftRivals-forum-comment-route/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  - [x] `BackendFoundationTests` passed with exact-post and exact-comment notification routes; result bundle: `/tmp/LiftRivals-forum-comment-tests/Logs/Test/Test-LiftRank-2026.10.04_06-40-26--0400.xcresult`.
- [ ] Add forward-only database corrections and runtime security tests: banned members cannot rejoin/post, removed posts/comments cannot be read, moderators can view their community reports, and reply parents must belong to the same post.
  - [x] Added source-only forward migration `supabase/migrations/202610040002_forum_integrity_and_bans.sql` enforcing same-post reply parents, banned-member write blocking, and moderator/author access to removed content; remote deployment and runtime SQL acceptance remain intentionally open.
  - [x] Added pgtap acceptance coverage in `supabase/tests/202610040002_forum_integrity_and_bans.test.sql` for server-side moderator/visibility helpers, same-post reply triggers, and protected forum read/write policies; run it only against the deployed migration.
  - [x] Hardened the new security-definer forum functions with `pg_catalog, public` search paths and added fixed-search-path assertions to the acceptance test.
- [ ] Verify all forum flows against a real authenticated backend with regular-user and moderator accounts before inviting beta users; confirm the deployed schema separately from source migrations.
