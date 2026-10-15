# App-wide layout and clutter audit

Date: October 15, 2026

## Scope and evidence

This reviews the current uncommitted iOS app for clutter, repetition, action hierarchy, navigation, presentation consistency, and accessibility risks. It is not a backend/security audit, a medical-content review, or a review of the separate website. It supersedes the earlier conversational lists where the source gives a more precise picture.

**V** means observed in the running demo simulator, with the associated source inspected. **C** means confirmed in source, but the affected state was not exercised in this walkthrough. Recommendations are design judgments, not measured usability results.

Simulator: iPhone 17 Pro, iOS 26.5, dark appearance, default text size. Twenty-five screens/states were visually inspected: Home; notification empty state; streak sheet; leaderboard; leaderboard filters; Forum feed; discussion with replies; Me; Settings; Edit Profile; photo manager; Personal Profile; gym directory; gym details; request gym; Tracker Today; Plans; existing-program preview; exercise library; exercise About; exercise-history empty state; Strength progress; Submit Lift; Awards; new bodyweight draft. The expanded program catalog was also inspected through accessibility state.

Every routed screen family was included in the source review below. The comparison selector was additionally checked through its accessibility state while restoring the original filter. **This does not establish that every screen/state passed a runtime check.** Smaller phones, landscape, light appearance, maximum Dynamic Type, keyboard layouts, VoiceOver gestures, real authentication, network failures, populated notifications, uploads, and moderator actions remain runtime verification work. A simulator accessibility-tree inspection is not a substitute for a VoiceOver session.

No app code was changed for this audit. No account was created, policy accepted, lift/workout saved, media uploaded, report sent, or moderation decision made. Existing edits and demo history were preserved. Visiting a gym invoked the existing global leaderboard-filter mutation described in F07. This was verified by returning to Leaderboards (gym scope, one active filter), then restored through Compare with → Global (zero active filters). Simulator was left on Home.

## Screen coverage

| Screen family | Coverage in this pass | State-specific notes |
| --- | --- | --- |
| App entry, restoring account, unavailable local database | C | Root branches and recovery copy inspected; database failure not induced. |
| Sign in, create account, email confirmation | C | Validation, progress, configuration-required and demo branches inspected; no credentials submitted. |
| Password-reset request and verified recovery | C | Reset sheet, message ownership, requirements and locked dismissal inspected. |
| Onboarding | C | Welcome, goals/focus, profile/location/gym/privacy, optional starting lifts, comparison and final save branches inspected. |
| Policy acceptance, legal documents, About/support | C | Expansion, acknowledgments, disabled acceptance, error display and document presentation inspected. No acceptance action performed. |
| Home | V | Alerts, training overview, awards overview, quick actions, PR links, weekly-goal entry; active/sync-error variants C. |
| Notifications | V/C | Empty sheet V; populated/read/unread rows and notification routes C. |
| Streak and weekly goal | V/C | Streak sheet V; configurable weekly-goal component and fixed streak rule C. |
| Leaderboards | V/C | Populated total leaderboard V; other ranking modes, loading/error/empty/search/pagination C. |
| Leaderboard filters/selectors | V/C | Main sheet V; location search, exact reps, weight classes and option-sheet rendering C. |
| Submit lift | V/C | Default form and disabled-submit guidance V; selectors, plate calculator, video review/upload and result states C. |
| PR and submitted-lift details | C | Evidence, timestamps, history-to-submission entry points, total breakdown and video-unavailable handling. |
| Me | V/C | Default hub V; expanded training statistics and submitted-lift grid C. |
| Personal/public/other-athlete profile | V/C | Personal default V; public preview, hidden/restricted/blocked data, section jumps, timeline/submissions and history filters C. |
| Awards | V/C | Initial sheet V; expanded collections, closest awards, tier sharing and PR sections C. |
| Edit Profile and photos | V/C | Profile form and empty photo manager V; location editors, selected-media preview/crop/remove and failure states C. |
| Gyms | V/C | Directory, populated primary-gym detail and blank request form V; membership limit, join/leave, loading/error/no-results C. |
| Tracker Today | V/C | Scheduled workout, plateau prompt, program browsing/freestyle choices V; active/conflicting/rest/missed/finished/no-plan states C. |
| Plans and session management | V/C | Saved plans, phase/week header and session-card layout V; queue, notes, week/day editing/deletion and creation forms C. |
| Program catalog, preview and setup | V/C | Expanded catalog accessibility state and existing-program preview V; new-cycle setup, schedule variants and progression editor C. |
| Active workout | C | Session overview, pause/minimize, reorder, substitution, add exercise, finish/incomplete/skip/discard branches. No workout was started to create audit data. |
| Exercise/set tracking | C | Targets, previous sets, rest timer, completion, weight/reps/duration, RPE, warm-up and validation. |
| Workout review and saved summary | C | Save versus public sharing, effort/notes, comparisons, highlights, achievement/tier previews and saved result. |
| Completed workout and edit | C | Metrics, set rows, focused-set navigation, repeat/save-routine/edit/delete and linked-submission notice. |
| Exercise library and filters | V/C | Browsing and representative catalog rows V; no-results, equipment/body-area/muscle filters and custom exercise forms C. |
| Exercise detail | V/C | About/anatomy/technique and history-empty V; populated history, records, charts/data table and substitutes C. |
| Exercise selection/configuration | C | Planned-workout picker, active-workout picker, custom creation, selection counts, long-press details and substitutions. |
| Progress: Strength | V/C | Recent summary/muscle rows V; drill-down chart, records, attention and bodyweight history C in this pass. Prior checks are not counted as new runtime coverage. |
| Progress: Muscle | C | Period/filter controls, primary/secondary work, comparisons, details, charts and no-history/unavailable branches. |
| Progress: Consistency and training health | C | Weekly overview/goal/program, recency, calendar/history, strain/injury conditional sections. |
| Bodyweight entry | V/C | New draft V; existing entry save/delete and unit conversion C. |
| Settings | V/C | Initial form/privacy V; lower sections, automatic PR sharing, notifications, account deletion and demo reset C. |
| Forum | V/C | Populated All feed and discussion/replies V; directory, composer, search/sorts, following, owner actions, watch, reports and error/empty/locked branches C. |
| Reports and blocking | C | Lift/profile report forms, reasons, optional details, submit/error/success and block/remove confirmations. No reports sent or athletes blocked. |
| Moderator review | C | Routed view, card layout, placeholder media, shared form state, decisions and empty queue. Live access/permissions not exercised. |
| Shared navigation/design components | V/C | Five-tab navigation, sheet dismissal patterns, fixed fonts, cards, field labels, empty states and button patterns. |

## Priority 1: misleading or obstructed tasks

| ID | Evidence | Finding and smallest useful change | Source |
| --- | --- | --- | --- |
| F01 | V | **Discussion actions break into fragments at default text size.** Reply, Vote, Collapse replies and Report compete in one horizontal row; deeper indentation leaves still less room. Keep Reply/voting visible and move secondary actions into a menu or a wrapping/stacked arrangement. | `LiftRankApp/Views/MainTabView.swift:1237` |
| F02 | V | **Submit Lift splits “Date” into “Dat” and “e”.** The bodyweight/date horizontal arrangement is chosen even though the label is compressed. Stack these fields before labels wrap, or reserve a readable label width. | `LiftRankApp/Views/SubmitLiftView.swift:283` |
| F03 | V | **The medium-height streak sheet clips the header.** Its fixed-size flame, large count and spaced VStack exceed the available height; the CONSISTENCY eyebrow is outside the visible sheet content. Use scrollable content and a toolbar close action, with a large detent if needed. | `LiftRankApp/Features/Home/HomeOverlays.swift:422`; `LiftRankApp/Features/Home/HomeFeatureComponents.swift:930` |
| F04 | C | **Password-reset errors can be hidden behind the reset sheet.** The sheet writes validation/service messages to `accountMessage`, but renders no error message of its own. Present the error beside the reset input and preserve it until corrected. | `LiftRankApp/Views/MainTabView.swift:3089` |
| F05 | V | **The same user has conflicting “Rival tier” labels.** Me shows Intermediate; Personal Profile shows Beginner because its label uses `displayedExperienceLevel`, which is a different concept. Rename that field Experience or use the actual tier consistently. Do not merge the underlying concepts merely to make the numbers match. | `LiftRankApp/Features/Profile/ProfileLogic.swift:178`; `LiftRankApp/Views/MainTabView.swift:1574` |
| F06 | V/C | **Home's alert promises several actions but is one button to generic Progress.** “Log missed workout,” “Open plateau details,” recovery and volume text all share one destination; the selected Progress category is not tailored to the signal. Give each visible signal a matching destination or show one clearly labeled summary link. | `LiftRankApp/Features/Home/HomeFeatureComponents.swift:131` |
| F07 | V/C | **Opening gym details silently changes the main leaderboard's scope.** Loading the preview overwrites global gym and location filters. Load the preview with an explicit local query; reserve global filter changes for an explicit “View gym rankings” action. | `LiftRankApp/Features/Profile/ProfileContentViews.swift:1327` |
| F08 | C | **Moderator cards expose decisions next to a placeholder video.** The view renders “Video playback preview” instead of a player, shares note/reason state across cards, and displays only the first 12 entries without pagination. Before using this surface for real review, provide actual evidence playback and per-item form state, or make its demo-only status explicit. This pass did not establish that a production user can reach it. | `LiftRankApp/Views/ModeratorReviewView.swift:4` |

## Priority 2: clutter, duplication and weak hierarchy

| ID | Evidence | Finding and smallest useful change | Source |
| --- | --- | --- | --- |
| F09 | V | **Home has competing workout entry points.** Alert, training overview, quick action and active-workout variant can repeat the task with different wording. Make one primary workout card adapt to Start/Resume/Missed/Completed. Keep bodyweight as a separate quick action. | `LiftRankApp/Features/Home/HomeFeatureComponents.swift:5`, `:343`, `:590` |
| F10 | V | **Leaderboard results start low on the screen.** Large title, metric strip, ranking tabs, comparison, full-width Filters, explanation and evidence line precede the first lifter. Combine context and compact filters; keep results visible sooner. | `LiftRankApp/Features/Leaderboard/LeaderboardsViewSections.swift:25` |
| F11 | V/C | **The leaderboard filter sheet exposes too many choices together.** Quick filters overlap location/division controls; multiple “All” rows and the demo's overlapping 25–34/25–29/30–34 age options make interpretation harder. Keep common choices first, collapse advanced groups and reconcile age-group options. | `LiftRankApp/Features/Leaderboard/LeaderboardRowAndFilters.swift:129` |
| F12 | V | **Plan controls occupy Library and Progress headers too.** The plan selector adds weight where the user is browsing exercises or analyzing personal history. Keep quick plan controls on Today/Plans, or make them subordinate elsewhere. | `LiftRankApp/Features/TrainingTracker/TrainingTrackerView+Sections.swift:229` |
| F13 | V | **Plans puts management above the scheduled work.** Catalog banner, saved-plan list, phase card and week navigator consume almost the first screen. There are separate header and detail ellipsis menus. Bring the selected week/session list forward; collapse plan switching and phase detail. | `LiftRankApp/Features/TrainingTracker/TrainingTrackerView+Sections.swift:637`; `LiftRankApp/Features/Training/Plans/ProgramPlanDetailView.swift:39` |
| F14 | V | **Existing-program preview repeats context and delays the actual sessions.** Program title, resume/edit/new-cycle explanation, another plan name and six phase lines precede Week 1. Give resume one prominent action; put phase structure and alternate setup behind disclosures. Phase checkmark icons should not resemble completion indicators for uncompleted phases. | `LiftRankApp/Features/Training/Plans/WorkoutProgramTemplateDetailView.swift:73`, `:318` |
| F15 | V/C | **Timed prescriptions receive rep-specific target text.** The Full Body Foundation preview exposes a 30–60-second plank with “3 reps in reserve.” Filter target descriptions by tracking kind, including the live prescription view. This is an information mismatch rather than a request to change the exercise prescription. | `LiftRankApp/Features/Training/Plans/WorkoutProgramTemplateDetailView.swift:486`; `LiftRankApp/Features/Training/ActiveWorkout/PrescriptionTrackView.swift:32` |
| F16 | C | **The planned-workout exercise picker has two identical custom-exercise actions.** Plus appears in the toolbar and bottom bar. Keep one labeled action and reserve the bottom bar for selected exercises. | `LiftRankApp/Features/TrainingTracker/TrainingTrackerLibraryComponents.swift:488`, `:639` |
| F17 | C | **Set logging repeats five RPE buttons on every working set.** The optional effort control remains exposed even with details closed. For long sessions this multiplies controls; use one compact optional effort entry and expand when needed, preserving existing RPE data. | `LiftRankApp/Features/Training/ActiveWorkout/WorkoutSetLogRow.swift:292` |
| F18 | C | **Active workout repeats overall set progress.** It appears in the header metrics and next to Exercises, alongside per-exercise completion. Keep one session count plus individual exercise progress. | `LiftRankApp/Features/Training/ActiveWorkout/WorkoutSessionRunView.swift:59`, `:335` |
| F19 | C | **Completed-workout toolbar has four icon actions plus Done.** Repeat, Save as routine, Edit and Delete compete at the same level; the destructive icon is directly exposed. Keep one frequent action and an explicitly labeled More menu for the rest. | `LiftRankApp/Features/Training/CompletedWorkout/CompletedWorkoutDetailView.swift:143` |
| F20 | C | **Workout review mixes saving with celebration.** Tier/achievement projections, highlights and sharing precede or compete with effort, notes and review. Put review/save first; show most celebrations in the already-existing saved state. Retain explicit control over public PR sharing. | `LiftRankApp/Features/Training/Summary/WorkoutSummaryView.swift:248`, `:422` |
| F21 | V/C | **Me repeats its own statistics and expands into Tracker/Awards content.** Header workouts/PRs/streak repeat in Training stats; weekly volume repeats in Recent performance; tiers repeat on several destinations. Keep Me focused on identity and submitted competition activity, with links to detailed training analysis. Some duplication is already hidden by a disclosure. | `LiftRankApp/Views/MainTabView.swift:1614`, `:1632`, `:2013` |
| F22 | V/C | **Personal Profile is a long sequence of overlapping activity views.** PR videos, workout history, timeline and submissions share a scrolling document; the section chips jump rather than filter, and later chips are offscreen. Keep private workout history in Tracker and give submitted activity one feed with useful filters. | `LiftRankApp/Features/Profile/ProfileViewSections.swift:97` |
| F23 | V | **Awards repeats its count and state before showing useful next progress.** The large 64, “64 earned,” section count and repeated “Unlocked” tile captions add little new information. Use a smaller earned/locked summary and prioritize recent/next milestones. | `LiftRankApp/Views/MainTabView.swift:2223` |
| F24 | V/C | **Awards opened from Home lacks a visible dismissal action.** The same content works as a pushed screen from Me, but its Home sheet supplies no Close/Done button. Add dismissal at the sheet owner. The simulator's accessibility Cancel action did dismiss it, so it is not an inescapable modal. | `LiftRankApp/Features/Home/HomeFeatureComponents.swift:944` |
| F25 | V/C | **Settings is one long form with privacy and technical details mixed into everyday preferences.** Move Privacy, Training and Account into focused pages; keep notification-permission instructions contextual and build/version inside About. Keep meaningful privacy choices, not fewer protections. | `LiftRankApp/Views/SettingsView.swift:42` |
| F26 | V | **A new bodyweight draft shows Delete Entry and a meaningless Entry 1 headline.** Only expose deletion for an existing stored reading; title the draft Log bodyweight and prioritize the measurement/date. | `LiftRankApp/Features/TrainingTracker/TrainingTrackerForms.swift:44` |
| F27 | V | **Exercise About puts a large anatomy card ahead of technique.** Front/back figure, legend and muscle chips consume most of the first screen. Lead with the exercise purpose/technique; keep anatomy compact or expandable. The anatomy itself is useful. | `LiftRankApp/Features/Training/Library/ExerciseLibraryDetailView.swift:68` |
| F28 | V/C | **Catalog entries have indistinguishable names and metadata.** Ab Crunch Machine and Abdominal Crunch Machine appear separately with Machine/Abs and different IDs, without an exposed distinction. Review aliases/equipment distinctions before merging; preserve existing history IDs. This observation does not prove every similar name is the same exercise. | `LiftRankApp/MockData/PopularExerciseCatalog.swift:18`, `:285` |
| F29 | V/C | **All-community post cards lose community identity.** The feed passes `selectedGroup` into every card, so All shows “Community” rather than each post's actual group. Resolve the post's own community for its label. | `LiftRankApp/Views/MainTabView.swift:266`, `:817` |
| F30 | V | **Forum has a tall stack of identity and browsing controls.** Navigation title, introductory header, feed picker/sort and community chips appear before posts; a selected community repeats in multiple places. Shorten the intro and consolidate feed/community navigation. | `LiftRankApp/Views/MainTabView.swift:251`, `:324` |
| F31 | V/C | **Gym preview cards repeat local context and unrelated detail.** Gym/city are repeated inside each row, along with bodyweight, a particular lift, full timestamp and evidence. Use compact ranked-lifter rows. The current preview is already limited to five lifters; it is not an unbounded second leaderboard. | `LiftRankApp/Features/Profile/ProfileContentViews.swift:1248`, `:1309` |
| F32 | C | **Report forms preselect Harassment.** A user can submit a reason they never deliberately chose. Require a reason selection and retain the lift/athlete identity in the form. Keep the optional note secondary. | `LiftRankApp/Features/Community/ReportViews.swift:7`, `:66` |
| F33 | C | **Onboarding's profile step asks for many secondary choices together.** Photo, bio, identity, body details, experience, location/gym and privacy precede entry into the app. Separate required ranking/account details from optional profile completion; preserve an understandable privacy choice. | `LiftRankApp/Views/OnboardingView.swift:566` |

## Priority 3: shared presentation polish

| ID | Evidence | Finding and smallest useful change | Source |
| --- | --- | --- | --- |
| F34 | C/V | **Navigation typography is unusually small and fixed.** The floating tab bar uses a 9-point system font with shrinking, while other screens use heavy large headings. Use scaled, readable navigation labels and test all five tabs at larger text sizes; reduce density rather than overriding the user's text preference. | `LiftRankApp/Core/DesignSystem/FloatingTabBar.swift:45` |
| F35 | C | **Recovery and failure screens have uneven hierarchy.** Password update repeats recovery context in a header, a card and footnote; local-database failure always exposes raw technical details but no direct support action. Keep one explanation and primary action; put technical details behind an optional disclosure. Authentication, report and gym-request forms also vary between persistent labels and placeholder-only labels. | `LiftRankApp/Views/MainTabView.swift:3196`; `LiftRankApp/LiftRankApp.swift:116`; `LiftRankApp/Features/Community/ReportViews.swift:23` |

## Existing improvements and intentional repetition

- The recent Strength answer already comes first, with corrected estimate eligibility, bodyweight source, empty state, chart navigation and recent/all-time labels. Do not reopen those fixed audit items as unresolved calculation bugs.
- Remaining Strength density is a layout task: collapse methodology, replace strings of zero counts with a short status summary, and keep the chart adjacent to the selected lift. Existing day counts and methodology should remain available.
- The weekly training-day goal and the three-day streak are separate rules. Repeated placement may be simplified, but changing a personal goal must not silently redefine a streak. Explain the difference if both remain visible.
- Workout estimates, submitted lifts and eligible ranked lifts are distinct. Reuse navigation and formatting while retaining those labels and evidence distinctions.
- Bodyweight, privacy preview and submission shortcuts can remain in relevant contexts when they open the same editor/destination. Multiple entry points alone are not necessarily clutter.
- Gym ranking preview is already capped at five. Compress its rows rather than adding unnecessary pagination.
- Exercise History's empty state, the photo manager, notification empty state, basic create-plan form, video-review close action and policy-document disclosures are reasonably focused. Do not add cards or extra steps without a concrete need.
- Confirmation before discarding/deleting, explicit public-sharing controls, loading/error states and evidence badges carry useful information. Keep them even when reducing surrounding decoration.

## Suggested implementation order

1. Fix F01–F07: visible wrapping/clipping, hidden reset errors, misleading labels/links and navigation-state mutation. Establish the intended audience/status of F08 before exposing a live moderation workflow.
2. Simplify high-frequency tasks: Home, Today, Plans, exercise selection and set entry (F09, F12–F20).
3. Consolidate destinations and context: leaderboard filters/results, Me/Profile/Awards, Forum and gym preview (F10–F11, F21–F24, F29–F31).
4. Improve setup/settings/library forms and shared typography (F15, F25–F28, F32–F35).

Each pass should preserve history, canonical exercise IDs, ranking/evidence semantics and user preferences. Validate the changed flow at default text size and a large accessibility size on a smaller phone before widening the visual sweep. Do not remove a feature solely because it has several entry points.

## Runtime verification still required

- Small-phone/landscape/light-mode and maximum-Dynamic-Type walkthroughs, including keyboards and numeric fields.
- VoiceOver focus order, selected-state announcements, grouped labels, chart summaries and modal dismissal.
- Real sign-in/create-account/confirmation/reset success and failure, Apple sign-in in a release configuration, legal-acceptance failure and account-recovery expiry.
- Network/offline/error/empty states for remote lists, pending uploads, blocked/restricted profiles and populated notifications/deep links.
- Active workout through rest, edits, substitutions, incomplete finish, review, save and optional public PR upload using explicitly disposable test data.
- Media selection/crop/playback/failure; report/block confirmations; production moderation only with the correct role and a confirmed test environment.

These are unverified runtime states, not claims that the app failed those cases. No broad test suite was run for this documentation-only audit.

## Implementation handoff — October 15, 2026

The implementation pass has addressed F01–F35 in source. **All entries still require final behavioral and visual sign-off.** The user subsequently requested a test run, build and TestFlight upload; the evidence from those steps is recorded below. The final GPT-5.6 Luna verification pass remains outstanding. This table is a handoff checklist, not evidence that every behavioral or visual check passed.

| Finding | Implementation | Required final verification |
| --- | --- | --- |
| F01 | Comment row keeps Reply/votes visible, moves secondary actions to a menu and reduces nested indentation. | Default/large text; nested replies; vote, collapse, edit/delete/report availability. |
| F02 | Bodyweight and performed date are stacked. | Small phone, long locale date, keyboard, default/large text. |
| F03 | Streak content scrolls and Close stays in the navigation toolbar. | Medium sheet at default/large text; Close accessible while scrolled. |
| F04 | Reset sheet owns and renders validation/service errors. | Invalid email and failed reset remain visible in the sheet; success dismisses it. |
| F05 | Profile header says Experience for the experience level. | Me/Awards tier and Profile experience remain distinct and correctly labeled. |
| F06 | Home alert is a summary link, without misleading per-signal action promises; missed-session handling stays with the workout card. | Summary link reaches Progress; workout card handles missed sessions. |
| F07 | CompetitionStore loads an isolated gym query; only explicit View gym rankings changes global filters. | Capture filters before/after preview, error/retry behavior and explicit navigation. |
| F08 | Review screen is explicitly demo-only, with per-lift notes/reasons and lazy rendering of the full demo queue. | Production shows no decision controls; demo cards do not share form state. |
| F09 | Home uses its workout card/active banner as primary action; bodyweight is a compact separate action. | Scheduled/missed/rest/completed/active variants and their destinations. |
| F10 | Leaderboard uses an inline title, compact rank/count context, one-row scope/filters and visible evidence context. | Results enter view earlier; ranking/evidence state remains clear and correct. |
| F11 | Filter groups collapse with active counts; legacy age ranges are explicitly labeled. | Every filter remains usable, including location search, legacy ranges and Reset. |
| F12 | Plan controls appear only in Today/Plans; Today's single-action ellipsis becomes a direct submission button. | Library/Progress header; accessible Submit a lift action. |
| F13 | Selected plan workouts precede catalog/saved-plan management; phase/saved plans collapse; week options are labeled. | Week controls, plan management and catalog jumps from Today/Plans. |
| F14 | Session preview precedes collapsed phase structure; alternate setup actions collapse; phase completion-like icons removed. | Resume/edit/new-cycle choices; setup state preservation; preview reachability. |
| F15 | Preview, plan cards and live prescriptions suppress reps-in-reserve text for duration tracking. | Plank and weighted-time exercise; normal rep-based RIR still shown. |
| F16 | Custom exercise creation appears once in planned-workout selection; footer is for adding selections. | Custom creation, selection count, add/cancel and disabled empty Add. |
| F17 | RPE expands through Effort & options; an existing recorded RPE remains summarized. | RPE logging/clearing, warm-up controls, persistence and adaptive progression evidence. |
| F18 | Active workout keeps one session-level set count alongside individual exercise progress. | Count updates and reorder mode. |
| F19 | Completed workout keeps Repeat prominent; routine/edit/delete live in More. | All actions and existing destructive confirmation remain reachable. |
| F20 | Review/save and explicit PR sharing stay before save; tier/highlight/achievement celebration appears after save. | Save, effort/notes, public sharing opt-in, post-save tier/highlight/achievement messages. |
| F21 | Me retains submitted records, removes duplicated training/tier analysis and links to Training progress. | Hub destinations, top submitted cards and training-focus category routing. |
| F22 | Profile section controls filter content; Activity hosts submissions; private workout history links to Track. | Personal/public/blocked privacy, Activity/videos/training selection and private-history routing. |
| F23 | Awards uses a compact earned/remaining summary, closest awards first and no repeated Unlocked captions. | Expanded collections, tier sharing and accessibility earned/locked labels. |
| F24 | Home supplies Close for its Awards sheet. | Close dismisses Home sheet; pushed Awards retains normal Back. |
| F25 | Settings uses focused Privacy/Training/Account/Notifications/About pages with a common draft and Done action. | Navigate between sections without losing edits; initial-section routes; save failure/retry; account actions. |
| F26 | Bodyweight draft is titled Log bodyweight; Delete appears only for a stored reading. | New/existing entry, Save/Cancel, units and existing-entry delete confirmation. |
| F27 | Exercise About leads with technique; anatomy is an optional disclosure. | About/history/records/charts and anatomy expansion at larger text sizes. |
| F28 | New search/substitution selections use machine_abdominal_crunch and aliases; machine_ab_crunch remains in the catalog as a labeled legacy record. | Search either name returns one selectable entry; old IDs/history/plans remain resolvable; no data migration. |
| F29 | Post cards resolve their own community instead of using the selected feed community. | All/Following/selected feeds, gym/community-less posts and missing community fallback. |
| F30 | Forum removes the generic intro block and keeps a short selected-community summary/membership action. | Feed/community/sort controls and community membership states. |
| F31 | Gym preview uses compact rank/avatar/name/value rows with explicit leaderboard navigation. | Correct total formatting, privacy, row profile navigation and five-row cap. |
| F32 | Report reason starts unselected; submission requires a choice; identity and optional details remain visible. | Lift/profile reports, disabled initial Submit, errors/success; use disposable test data only. |
| F33 | Optional photo, bio, height, years training and gym move after required onboarding/privacy fields into a disclosure. | Required validation, optional values, location/gym dependencies, privacy, keyboard and final save. |
| F34 | Tab labels use scaled system text, minimum targets and selected traits; accessibility sizes can scroll tabs horizontally. | All five tabs on small/default/large text, VoiceOver order and tab-bar clearance. |
| F35 | Recovery copy is shorter; local database errors have support and optional technical details; account/report/gym forms retain field labels. | Recovery requirements/errors, local failure scrolling, support link and labels after text entry. |

### Final verification instructions

- Use GPT-5.6 Luna for the final build/test/simulator pass. Do not treat this source checklist as a passed test.
- Preserve the existing uncommitted workout-library/strength-progress work and the pre-existing Package.resolved deletion. No migration or remote account operation is part of verification.
- Start with a build, fix compile errors, then run focused existing/new regressions for the changed behavior. Update UI expectations for intentional label/navigation changes instead of weakening assertions.
- Exercise F01–F07 first in Simulator, then the reorganized task flows. Include a smaller phone and a large accessibility text size. Restore the user's default text size afterward.
- Specifically check local gym-query isolation, inline reset errors, nil report reasons, duration/RIR presentation, alias lookup compatibility, draft deletion visibility and target Progress routing.
- Use demo/disposable test data for saves and uploads. Do not submit real reports, accept policies, delete accounts or perform production moderation merely to test layout.
- Record results and any remaining gaps here. The goal remains active until verification and any resulting corrections are complete.

The original layout pass added no implementation files, types or dependencies. The gym-specific store query keeps networking behind the existing service protocol; the Progress routing field opens the intended existing category from another screen. The previously created audit document remains the only new file. The subsequent production crash fix introduces the concrete view boundaries described below.

### Verification evidence and unresolved crash — October 15, 2026

- The first test build found a non-escaping content builder retained by the new leaderboard disclosure. Its signature was corrected to `@ViewBuilder content: @escaping () -> Content`.
- The next full run passed all 407 unit tests. UI testing recorded 13 failed cases before interruption; the complete suite did not finish. Log: `/tmp/liftrivals-app-layout-tests.log`. Several failures reference the previous layout or labels; current-account cases reached Sign In instead of an authenticated account and do not establish a navigation regression.
- A subsequent Debug simulator build and signed Release device archive succeeded. Build 1.0 (26) was uploaded through Xcode Organizer's Distribute App flow. Upload success is packaging evidence, not a passing UI or crash gate.
- The user reported that opening Strength crashes consistently. The existing `testRecentStrengthLiftOpensItsChart` passed in normal Debug and with only the app target temporarily using `-O` and whole-module compilation. Logs: `/tmp/liftrivals-strength-crash-debug.log` and `/tmp/liftrivals-strength-crash-app-optimized.log`. These checks used demo data on the iOS 26.5 simulator; they do not reproduce or disprove the reported phone crash. Temporary project settings were removed afterward.
- Applying optimization globally to test dependencies crashed the Swift compiler in IssueReporting before the app ran. That attempt provides no app runtime evidence: `/tmp/liftrivals-strength-crash-optimized.log`.
- At diagnosis time, the paired iPhone was unavailable and Computer Use reported the Mac locked. Cached device reports were for build 14; local simulator reports were from October 13 and involved Profile. A current Strength crash report is still required to identify the phone failure.
- Source corrections add the persistent Email accessibility label and update existing UI tests to open profile video sections, expand RPE options, navigate Settings categories, select a report reason, expect closest awards first, and explicitly launch the custom-exercise accessibility case at a large accessibility text size. Build 27 includes these changes; their individual UI cases still require execution in the final verification pass.

### Production Strength crash diagnosis

- The in-app browser provided authenticated App Store Connect access even while native Computer Use was blocked. TestFlight Crash Feedback includes a build-26 report from iPhone 17 / iOS 26.7.1 at 3:00 AM ET on October 15, with the comment “Crashed when I pressed strength.” Report: `AKU4QY5NiMnf39fHQ4YBLGQ`; downloaded crash: `/tmp/liftrivals-production-strength-crashlog.crash`.
- The report records `EXC_BAD_ACCESS / KERN_PROTECTION_FAILURE` in the main thread's stack guard. Swift was resolving nested generic view metadata. The archived build-26 dSYM UUID matches the report exactly: `9FA3FBFD-4B9B-3D37-A6C4-4FDFEDFEED7A`. Symbolication maps app frames to closure #9 in `TrainingTrackerView.exerciseProgressSection(options:)`, then that section and the Progress builder.
- The source correction divides the oversized exercise builder into four private concrete views in the existing file: `StrengthExerciseCharts`, `StrengthSelectedPerformance`, `StrengthExerciseRecords`, and the repeated `ExerciseProgressMetric`. These boundaries reduce the combined runtime type and view-construction stack demand. The existing filtering, calculations, selection bindings, workout actions and UI text are retained. No file or dependency is added.
- All three focused optimized simulator regressions passed: repeated category switching, lift-to-chart selection and muscle-workload routing. Log: `/tmp/liftrivals-strength-stack-fix.log`. Temporary optimization settings were removed. A successful simulator run alone does not establish that the production phone crash is resolved; the corrected device build must still be exercised on the affected phone.
- The newer 3:12 AM build-26 report, `AD1btkR5DfXPTtybLMuWw6A`, independently identifies the same stack guard failure and `exerciseProgressSection` closure. Download: `/tmp/liftrivals-production-strength-latest.crash`.
- Signed Release archive 1.0 (27) succeeded: `/tmp/liftrivals-strength-fix-build27-archive.log`. Xcode Organizer's Distribute App → App Store Connect flow confirmed upload success. The original 35-item audit and final Luna verification remain incomplete; the upload does not establish phone validation.
