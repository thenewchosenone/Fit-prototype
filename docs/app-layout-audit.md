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
| F30 | Forum keeps All/For You/Following visible, moves community and sort into one staged Filters sheet, and labels post types for faster scanning. Community browsing stays in the navigation bar. | Feed changes, filter Done/Reset/dismiss behavior, directory access, selected-community membership and post-type labels at default and accessibility text sizes. |
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

### Exercise tracking layout and keyboard — October 15, 2026

Scope: the Track exercise page, using disposable demo data in the iOS 26.5 simulator. Production workout records and account preferences were not changed.

- Collapsed set rows now keep inputs, completion, and one options button on a single row at normal text sizes. Removed the empty options footer; recorded RPE remains visible. Input, completion, options, and RPE controls have at least 44-point touch targets.
- Replaced the duplicated “Last” first-set metric with explicit View history and Exercise details actions. Both reuse the existing Library detail page; history opens its History tab. Manual simulator navigation confirmed both destinations and the technique instructions.
- Previous-set comparisons now display in the active workout's unit. The underlying recorded weights are unchanged. The abbreviated PREV heading stays on one line, while its accessibility label spells out “Previous workout.”
- Removed the fixed 300-millisecond Next delay. Switching within a set focuses immediately; moving to another set scrolls its lazy list row into view before assigning focus on the next main-queue turn. This corrects the off-screen-row failure exposed at the largest accessibility text size.
- Added an icon-only keyboard dismissal action, with the accessibility label “Hide keyboard,” alongside Next/Done. It clears SwiftUI focus and uses the same native first-responder dismissal as onboarding. Queued focus/scroll callbacks check that their original focus is still current. Hiding the keyboard preserves the entered values.
- At accessibility sizes, exercise actions stack vertically. Utility controls and previous-set comparison text have bounded visual text scaling so they fit; editable fields retain their accessibility layout and large text.
- Regression coverage in the existing UI test file checks real on-screen keyboard visibility, three consecutive hide/reopen cycles without losing reps, decimal weights, every Next transition across three sets, final Done dismissal, and preferred-unit comparison labels in dark, light, and the largest accessibility text size.
- All three final keyboard cases passed with zero failures (nine hide/reopen cycles total) on iPhone 17e / iOS 26.5: `/tmp/liftrivals-keyboard-dismissal-fixed.xcresult`; log: `/tmp/liftrivals-keyboard-dismissal-fixed.log`. Earlier runs exposed the large-text row-loading and dismissal failures described above; those earlier failed runs are not treated as passing verification.
- A separate completed-workout regression passed, covering set completion, set RPE, workout effort, review, saving, and dismissal: `/tmp/liftrivals-exercise-final-verified.xcresult`.

These checks cover this exercise page and its keyboard flow, not the outstanding full-app or physical-phone launch gates above.

### Strength screen visual audit — October 15, 2026

Scope: Track → Progress → Strength, using disposable simulator demo data. Production account data and recorded weights remain unchanged.

- The recent-strength summary leads with the overall trend. Suggested next steps remains inside that card; muscle details, training coverage, and methodology expand on demand. Muscle summaries omit zero counts. Nested disclosure groups no longer apply an outer accessibility identifier to their child controls.
- Exercise selection uses a full-width text label and a text-first picker. Metric labels use readable system text; metrics, rep records, and bodyweight controls adapt at accessibility sizes. Strength totals use compact vertical cards; their descriptions and supplemental lift names wrap instead of truncating.
- Estimated-maximum chart values now convert from canonical kilograms into the preferred display unit, matching the summary and weight chart. Selected workout performances also use the preferred unit. Bodyweight chart bounds convert into the same unit as their plotted readings.
- Screenshot review caught overlapping chart axes at the largest text size. Charts now use fewer date/value ticks, bounded axis text, edge padding, and a taller accessibility plot. Full exercise values and chart accessibility remain available. An explicit native chart tap gesture selects a performance; the default selection gesture had not responded to the advertised tap interaction.
- Strength sections share an eager native stack inside the existing Progress container to prevent estimated lazy heights leaving a blank gap before Bodyweight. Expanded suggested guidance requests its full content height. Bodyweight actions have 44-point minimum targets.
- Focused UI coverage captures summary, expanded guidance through its plan action, strength records, exercise metrics, picker, both charts, selected performance, rep records, and bodyweight in dark, light, and the largest accessibility text size. It checks selected-performance pounds labels, opens the selected workout and returns, checks the gap between exercise records and Bodyweight, opens and cancels bodyweight entry, and returns to the summary. Existing lift-to-chart, muscle-workload, and repeated-category regressions are retained.

This pass adds no implementation files, abstractions, or dependencies. It retains the concrete exercise-view boundaries introduced for the previous Strength stack failure.

Verification:

- The three final end-to-end display cases passed with zero failures on iPhone 17 Pro / iOS 26.5, covering dark, light, and the largest accessibility text size, including chart tap → selected performance in pounds → saved workout → Done, picker dismissal, bodyweight entry cancellation, and return to the summary. Result: `/tmp/liftrivals-strength-tap-and-layout-verified.xcresult`; log: `/tmp/liftrivals-strength-tap-and-layout-verified.log`. Exported screenshots were visually reviewed.
- The smaller iPhone 17e run passed all three layout variants, repeated category switching, and lift-to-chart selection: `/tmp/liftrivals-strength-layout-final.xcresult`. Its muscle-workload case failed before reaching Progress because the initial Track tap did not register while the other simulator was being refreshed. That case was updated to wait for the Progress control and passed on iPhone 17 Pro: `/tmp/liftrivals-strength-preview-verified.xcresult`. The same preview bundle's initial chart-tap case failed, exposing the missing tap gesture corrected and verified in the final three-case run above; neither earlier bundle is treated as an entirely passing suite.
- Earlier screenshots exposed clipped expanded guidance, oversized chart labels, and the blank gap before Bodyweight; those were corrected before the final run. The expanded guidance now reaches its plan action, axis labels are legible without overlap, and exercise records sit directly above Bodyweight.
- After testing, the updated demo was relaunched at normal text size in dark appearance. Native preview navigation was blocked because the Mac was locked; the user can open Track → Progress → Strength after unlocking. No production account data, backend settings, migrations, or releases were changed. Physical-phone and broader launch verification remain outside this simulator pass.

### Strength follow-up and build 28 — October 15, 2026

- The Strength exercise card now leads with the selected exercise, current estimated 1RM, change since the first eligible training day, and logged-day count. Its calculation notes are behind “About this trend”; records and recent sessions are collapsed by default.
- Removed the Bodyweight chart and logging controls from Strength. Home and Edit Profile remain entry points; saved readings and relative-strength calculations remain intact. The bodyweight UI regression now follows create/edit/delete through Home and checks Strength's relative total and the absence of a Bodyweight section.
- The focused dark-mode Strength layout audit passed on iPhone 17e / iOS 26.5. The bodyweight regression was interrupted after CoreSimulatorService died; the accessibility-size rerun was also blocked by that simulator service failure. Logs: `/tmp/liftrivals-build28-strength-followup-retry.log` and `/tmp/liftrivals-build28-strength-followup-final.log`.
- Release service readiness and launch-metadata preflights passed with external APNs/SMTP verification still outstanding. The unsigned Release build and signed archive succeeded as version 1.0 (28): `/tmp/liftrivals-build28-release-build.log`, `/tmp/liftrivals-build28-archive.log`.
- Xcode Organizer Distribute App → App Store Connect completed successfully for version 1.0 (28). Organizer shows “Uploaded to Apple” and build number 28; TestFlight processing may still be pending. The initial command-line export stopped with `App Store Connect Credentials Error`, then the signed archive was added to Organizer and uploaded through its UI. The full release checklist, physical-device verification, and the interrupted UI checks remain incomplete.

### Leaderboard deep audit — October 15, 2026

Scope: the installed iPhone 17 Pro / iOS 26.5 demo at normal text size, plus source review of leaderboard views, search, filters, score formatting, the competition store, profile mapping, service requests, and checked-in ranking SQL. The populated Total and Absolute screens, filter sheet, search and empty search were visually inspected. These observations describe the installed app, before the source corrections below. Production records were not edited. No new app build, archive, upload, or migration was prepared or run.

Source corrections awaiting a later build:

| Finding | Correction |
| --- | --- |
| The Move header is visible when all movement values are absent; mixed rows place scores in different columns. | Hide the entire movement column when no loaded result has movement. Otherwise reserve its width for every row and show a dash for unavailable movement. |
| Filters consumes excess width, while Exercise floats in the center. | Let scope/exercise controls fill their row, keep Filters compact, and stack controls at accessibility text sizes. |
| All-exercise scores omit the exercise being ranked; total breakdowns and supporting text truncate. | Show the exercise for all-exercise lift rankings, simplify total breakdown text, allow two supporting lines, and keep numeric scores aligned. Repeated gym names are omitted in gym-scoped rankings. |
| Accessibility rows drop the username, gym and supporting lift context; YOU uses fixed 8-point text. | Restore supporting context in the stacked row and combined accessibility label, and use system caption text for YOU. |
| A checkmark seal implies verification and relies on legacy verification state. | Use a video symbol based on resolved evidence status; retain the explicit evidence label for accessibility. |
| Search changes the displayed personal rank to Unranked and can show results from an older query. | Derive personal rank from the selected leaderboard before local search; clear search when jumping to the personal row; discard canceled search responses. |
| Local search matches hidden gym and city fields. | Exclude hidden fields from local matching. Server search/privacy behavior was not exercised against a production account. |
| A custom city is labeled My state; country-only scopes can look Global; absent country values can select My country. | Show the actual selected location, require nonempty selected scope values, count country filters, and omit personal scope options whose required profile data is missing. |
| The All lifters shortcut silently resets ranking, evidence, and other filters. | Make the shortcut explicitly Global and clear location only. Full Reset remains available. |
| Filter result counts can briefly describe the previous query; the long sheet initially opens at half height. | Show Updating results / Results unavailable as appropriate and open Filters at the large detent. |
| Filter chips have small targets and can exceed the viewport at large text; weight classes show kg only. | Use 44-point targets, selected accessibility traits, constrained wrapping, an accessibility single-column quick-filter grid, and existing preferred-unit class formatting. Standard kg class names remain in parentheses for pound users. |
| Search lacks interactive keyboard dismissal and results lack pull-to-refresh. | Use the existing native scroll dismissal and async leaderboard refresh. Search-clear and explanation controls have 44-point targets. |
| Leaderboard exercise selection still uses category illustrations. | Use exercise names with equipment/muscle subtitles, matching the Library's text layout. |
| Total explanation does not disclose partial totals. | Explain that one or two eligible powerlifting lifts can produce a partial total and identify S/B/D. |

Open production issues, in priority order. These are established from checked-in source; remote deployment state and production reproductions were not verified in this pass:

| Priority | Finding and consequence | Existing owner / next action |
| --- | --- | --- |
| High | The service fetches at most 200 rows. Load more pages only through that loaded subset; counts are not population totals, and an athlete outside it cannot be found or jumped to. The UI now says Not listed rather than asserting Unranked. | `Services/SupabaseServices+Leaderboard.swift`, `Features/Leaderboard/LeaderboardsViewSections.swift`: provide server pagination, total count and authoritative personal placement; distinguish rank search from global athlete search. |
| High | `CompetitionStore.leaderboardEntries` replaces returned ranks with client competition ranks. Checked-in SQL uses dense ranks. Ties such as 1, 1, 2 become 1, 1, 3, and filtering a capped subset can produce misleading placements and movement. | `Features/Competition/CompetitionStore.swift`: settle the rank contract and preserve server authority; verify ties and filtered populations end to end. |
| High | My city sets `cityID`, but `SupabaseProfileMapper.leaderboard` always maps returned profiles with `cityID: nil`; client filtering rejects them despite the server's city-name match. | `Data/Supabase/SupabaseProfileMapper.swift`, `Features/Competition/CompetitionStore.swift`: reconcile canonical location IDs and server-filtered results. |
| High | All returned public leaderboard profiles are mapped to Beginner. Experience is filtered afterward on the client, so non-Beginner filters can empty the feed and Beginner can include everyone. | `Data/Supabase/SupabaseProfileMapper.swift`, `Services/SupabaseServices+Leaderboard.swift`: obtain authoritative experience or remove the unsupported filter. |
| High | Rep selectors offer 3/5/8/10/custom, while both the calculator and checked-in ranking SQL admit actual one-rep maxes only. The service request does not send a rep filter; selecting other reps can only remove returned singles. | `Features/Leaderboard/LeaderboardsLogic.swift`, `LeaderboardRowAndFilters.swift`, `Utilities/RankingCalculator.swift`: align the exposed choices with launch eligibility before offering rep-specific rankings. |
| High | Server This week / This month mean rolling seven days / one month; client post-filtering uses calendar week / month. The server can select a representative lift that the client then removes, omitting an athlete with a different qualifying calendar-period lift. | `Features/Competition/CompetitionStore.swift`, `supabase/migrations/20260731150000_canonical_verified_rankings.sql`: agree on interval semantics and filter before scoring. Any SQL correction needs a forward migration and runtime security tests. |
| Medium | Loading performs one awaited public-profile request per result. A long leaderboard can require 200 serial calls; any one failure fails the feed. | `Services/SupabaseServices+Leaderboard.swift`: return or batch the public profile data through the existing service boundary. |
| Medium | Remote total results always use `powerliftingBreakdown: nil`; the useful S/B/D explanation is only populated by local/demo calculation. | `Services/SupabaseServices+Leaderboard.swift`: return authoritative lift contributions and distinguish a partial total. Do not manufacture a breakdown from the single representative lift. |
| Medium | At accessibility sizes all five ranking modes become a vertical list before the filters and results. Normal text hides later modes in horizontal scrolling. | `Components/LeaderboardComponents.swift`: evaluate a compact, clearly labeled ranking picker when the next runnable preview is available. |

Verification: Swift frontend syntax parsing passed for all five touched implementation files and `git diff --check` passed. Parsing does not type-check SwiftUI or validate runtime layout. Existing leaderboard UI tests were reviewed but not run because they require compiling an app, and the user requested no new build. Dark/light/accessibility screenshots of the corrected source, live loading/error/retry, ties, over-200 pagination, account switching, search cancellation, and production filter accuracy remain explicit verification gates. Build number remains 28. This pass adds no files, types, abstractions, or dependencies.

### Live screen audit follow-up — October 17, 2026

Scope: read-only visual walkthrough of the app currently installed on the mirrored iPhone, in dark appearance at its current text size. Visited Home, Rankings, leaderboard Filters, Track Today, Plans, Library, Progress, Forum, Me, the expanded Submitted lift records section, and Settings. No form was submitted, record changed, workout started, or preference changed. CoreSimulatorService was unavailable in this session, so this walkthrough used the connected iPhone mirror; the installed build/version could not be confirmed.

| Screen/state | Observation | Follow-up |
| --- | --- | --- |
| Me with Submitted lift records expanded | Header reads `0 PRs`; the expanded Top submitted lifts shows Bench 265 lb, Squat 315 lb, Deadlift 545 lb, and Total Strength 1125 lb. The values can have different definitions, but the short header label does not explain why submitted records are excluded. | Clarify the counter's scope in its label (for example, verified or training-session PRs if that matches the statistic), or align it with the records shown. Recheck after data refresh/account confirmation. |
| Rankings → Total | Video-backed is selected and the empty state says no ranked lifters because only video-backed lifts rank. The message explains the state; self-reported and all-lifts options are visible alongside it. | No new issue established in this state. |
| Rankings → Filters | Large filter sheet shows `0 matching lifters`, quick scope choices, exercise choices, and expandable Division/Location. | No new issue established at the visible top of the sheet; lower filters and alternate sizes remain unreviewed. |
| Track → Today | No plan state offers Browse Workout Programs and Start freestyle workout. The helper copy explains the difference. | No new issue established in this state. |
| Track → Plans | `Plans couldn’t sync · Retry` appears above `No saved plans yet` and a Create plan action. The network failure means the empty result may be incomplete, so the screen should be rechecked after a successful refresh before treating this as a confirmed empty-state defect. | Verify that a sync failure cannot imply there are no saved plans; use a distinct unavailable/loading message when remote plans have not loaded. |
| Track → Library | Search and filter are at the top, with a 549-exercise count and alphabetical browsing. | No new issue established in this state. |
| Track → Progress | A `Refreshing workout history` banner appeared above the metric tabs; current empty workout counts were observed while refresh was active. | Recheck after refresh settles and inspect the other metric tabs and lower content. |
| Forum | The All feed resolved to `0 discussions` and a clear `No discussions yet` empty state. | No new issue established in this state. |
| Settings | Focused section links, Done, account, units, and appearance were visible in one sheet. | Lower settings sections and edit/save/error behavior remain uncovered in this run. |

This is a partial live walkthrough, not a completion of every screen and state in the coverage table. The mirrored iPhone showed Home with historical private lift highlights and Me with separate competitive statistics; source confirms Me reads `competitiveStatistics.prCount`, while the submitted top-lift cards read the best-strength-lifts data. That makes the `0 PRs` label a concrete clarity issue even if the values are technically consistent. Network-dependent screens should be revisited after their refresh/error state settles. No code, tests, simulator build, or backend state were changed in this follow-up.

### Expanded live walkthrough — October 17, 2026

Scope: continued the connected iPhone walkthrough through Home notifications/streak/awards, Submit Lift, Edit Profile, public profile, program catalog/preview, Strength and Muscle progress, exercise About/History, Forum filters/composer, Gym directory/detail/request form, and rechecked Plans/Progress after fetches settled. Only read-only destinations and blank forms were opened. No account, workout, lift, post, report, gym membership/request, or profile change was submitted. Rankings still showed Global and zero active filters afterward; app was returned to Home.

New or confirmed findings from this pass:

| Priority | Screen/state | Finding | Smallest useful follow-up |
| --- | --- | --- | --- |
| High | Submit Lift, initial form | The form presents `Conventional deadlift`, `315 lb`, `1 rep`, and today's date as a ready-to-submit lift. Source confirms 315 lb and 1 rep are defaults when no prefill is supplied, rather than a saved lift. The bodyweight is taken from the profile. A user can mistake the default load/reps for their own entry. | Start with weight and reps unset (or label them as example values) and keep Submit disabled until the user enters a performance. Preserve intentional prefilled values when arriving from a specific lift action. |
| Medium | Me header with submitted-lift records | `0 PRs` appears while submitted bench, squat and deadlift records are available below. This statistic is separate from the displayed best-lift records, but its label does not say what it counts. | Clarify the counter's scope or use the same source as the visible submitted records. |
| Medium | Forum → All, All communities, zero results | The empty state says `Start a discussion in this community` even though the feed and filter both say All communities. | Use an all-communities empty message and point to the existing New discussion action. |
| Medium, needs reproduction | Request Gym → Cancel | After tapping Cancel, the view returned into a gym detail (Auburn) rather than remaining on the directory. A nearby directory row may have received the tap during dismissal/animation; repeat with a deliberate touch before assigning this as a product bug. | Check that a sheet dismissal does not pass the same tap to the underlying list. |
| Needs stable network | Plans | `Plans couldn’t sync · Retry` remained visible above `No saved plans yet` after the program catalog loaded. The account may have no saved plan, but the failure leaves remote plan availability uncertain. Retry was not invoked because it starts synchronization against account data. | Distinguish a confirmed empty list from a list unavailable because sync failed; validate with a successful account sync. |

Other states reviewed: Notifications gives a clear caught-up message; Workout streak explains the 3-day weekly rule and shows progress; Awards clearly separates 30 earned from 166 remaining and identifies closest awards; public profile explains that qualifying lifts may be private or unavailable; program setup explains the three progression choices and start date; Strength says more comparable history is needed and separates strength records from workout trend; Muscle explains its no-working-sets state; Exercise About gives numbered instructions and the History tab explains how to create history; Gym directory has search and location labels, Gym detail explains its three-gym limit and verified-lift counts, and Request Gym marks required and optional fields with Submit disabled until required fields are filled. Settings and Edit Profile were inspected only at their opening states.

Implementation follow-up: Submit Lift now starts weight and reps blank unless the user arrives with a prefill; the estimate and plate total wait for an entered weight, and submission stays disabled until positive values are entered. The Me statistic now reads `Workout PRs`; Forum's All empty state refers to discussions across communities and points to `+`; Plans shows an unavailable state after sync failure instead of claiming the account has no saved plans. The Request Gym cancellation behavior still needs a deliberate retest before changing code. These source changes have not been visually or behaviorally verified on device.

Smoothness and coverage limits: tab changes and the opened sheets/details completed without a visible frozen state in this pass, but no frame-rate or latency instrument was run, so this does not certify animation smoothness. Forum, Plans, and Progress each showed a transient load/refresh state before settling; Plans retained its sync error. This pass did not exercise onboarding/authentication, keyboard submission, photo/video picker permissions, an active workout, form validation errors, post/report submission, account actions, light appearance, or large accessibility text. Those need a disposable test identity and targeted layout run to cover safely and reproducibly. No code, tests, build, or backend changes were made. `git diff --check` passed for the audit document.

## Onboarding layout follow-up — October 18, 2026

This targeted implementation supersedes F33’s recommendation to hide optional profile details. The profile now keeps username, photo, bio, training details, location, and privacy visible by default; optional fields remain optional. Bodyweight and height share a row, with years training below. Bodyweight uses decimal entry and can be cleared to unset, with unit conversion through the existing profile boundary.

Training choices are reduced to Get stronger, Build muscle, Powerlifting, and General fitness. One selection enables Continue; the overlapping optional training-style section is removed. The city sheet initially lists common cities for the chosen region and offers search for other cities, a searching indicator, retry/empty guidance, and completion later. Searching does not erase an existing city selection. The redundant “You’re ready to track” page is removed: onboarding has four steps, and the optional starting-lifts page saves directly through either its main action or skip action. Sign-in uses less top spacing and keeps guest entry in a bottom safe-area inset while the form scrolls.

Draft recovery, username guidance/availability, first-workout routing, real-account/network-failure verification, iPad, and large accessibility text remain follow-up work. These layout changes do not address session-expiry behavior.

Verification: the Debug iPhone 17/iOS 26.5 app built successfully. Four targeted UI checks passed across the verification runs: guest entry is hittable; years training increments; an empty username blocks advancement while optional profile/location fields can wait and the main final action reaches policy acceptance; and the richer flow selects “Get stronger,” clears and enters decimal bodyweight, selects a common city, searches another city, reopens common choices, and completes through the skip-lifts action. Profile, measurement, city-sheet, and guest-entry screenshots were inspected at default text size. The input test explicitly closes the keyboard before advancing. The first city run exposed a stale query when opening the sheet; observing the query at the onboarding view and keeping the prefilled test’s selection separate from its search query fixed it.

Evidence: `/tmp/liftrivals-onboarding-layout-oct18-ui.xcresult`, `/tmp/liftrivals-onboarding-layout-oct18-retest.xcresult`, and `/tmp/liftrivals-onboarding-layout-oct18-city.xcresult`. Initial failures and their fixes are retained in those bundles; the final city/skip-lifts flow passed without failures. These use the existing mock-account UI-test launch mode, not production accounts. The full `LiftRank` test scheme cannot compile because the pre-existing `RankingCalculatorTests.swift:6987` calls the already-removed `OnboardingView.gymsMatchingLocation`; verification used the existing `LiftRankUITestsOnly` scheme without modifying that unrelated test file.

Further onboarding review (October 18): the welcome and sign-in screens now use the existing Lift Rivals logo instead of system dumbbell/lock artwork. `BrandLogo.imageset` exposes the existing app-icon artwork as an ordinary in-app image asset. Policy acceptance is presented over the live onboarding screen, with Back returning to the same setup values; initialization runs once so dismissing that cover does not reset the draft. Accounts returning directly to outstanding policies have an explicit “Back to sign in” action. Policy acceptance remains required for entry.

Verification of that follow-up: iPhone 17 Debug UI checks passed for the four-choice count and single-goal selection, branded welcome/sign-in images, optional profile details, years-training changes, and the policy Back round trip. The round trip verifies username, decimal bodyweight, and city survive, then verifies Continue opens policies again. Results: `/tmp/liftrivals-onboarding-four-goals-back.xcresult` and `/tmp/liftrivals-onboarding-four-goals-final.xcresult`. No policy was accepted. The existing full-suite unit-test compilation limitation above remains outside this change.

Terms Back-button consistency follow-up: the policy screen now uses onboarding’s 42-point circular chevron and the same top/horizontal spacing, pinned above the scrolling policy content. Its accessible destination label and `legal.back` identifier remain intact. The existing iPhone 17 onboarding/policy Back round-trip test passed in `/tmp/liftrivals-terms-back-style.xcresult`; no new files, abstractions, or dependencies were required.
