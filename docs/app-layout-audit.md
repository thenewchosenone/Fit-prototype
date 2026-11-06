# App-wide layout and clutter audit

Date: October 15, 2026

## Requested follow-ups — November 6, 2026

Implementation requested November 6. The user selected Feed with discussions and Friends together. Production notification changes require a separate approval before application; local validation passed (three focused unit tests, one UI test covering Feed and the Home carousel, and two clean SQL resets).

- [x] Home: replace the stacked suggested-lifter rows and separate discovery card with a horizontal “Closest Rivals” carousel. Favor lifters in a similar age range with comparable lifts, including slightly higher and lower results. Explain the match on each card.
- [x] Forum: make friend activity a visible feed option alongside All, Recommended, and My Communities instead of requiring the people icon. Working label: “Friends”; “My People” is another option, with the final label still open.
- [x] Friend feed: show useful shared lift/workout details directly in the cards so users can scan activity without opening every item. Keep deeper details available on tap and respect existing sharing permissions. Decide which additional workout details should be shareable before implementation; current activity covers workout starts and top lifts.
- [x] Feed structure and naming: evaluate renaming Forum to Feed as it combines discussions and training activity, versus separating those experiences. This is an open design decision, not an approved rename.
- [x] Sharing clarity: review where completed workouts and shared PRs appear, and make the destination clear to users. Currently, shared PRs appear on profiles and eligible rankings; optional friend activity covers workout starts and top lifts; shared workout stats expose counts and the latest date, not full workout details. Check how recent lifts should appear in the proposed Friends feed.
- [ ] Gym leaderboard alerts: implemented, SQL-tested, and deployed to production as migration `20261106225236` on November 6; signed-device delivery remains pending. Scope: an opt-in notification when another lifter's eligible video-backed/verified PR actually passes the user in their gym, for the same lift and ranking comparison group. Show the lift and relevant gap, link to the comparison, and group repeated changes. Establish the required evidence/review status before implementation; a video attachment alone must not be labeled verified.
- [ ] Friend notifications: request screen and routing implemented; SQL privacy/permission tests pass. Production application and signed-device delivery remain pending. Verify existing request and acceptance events, inbox behavior, destination routing, and signed-device push delivery. Check the current friends model before considering followers or follower requests; a separate follower system was discussed, not approved.
- [x] Notification timing and noise: focus social/ranking pushes on events that happen while the user is away from the app. Show immediate results such as reaching the top three after submitting a lift on the result screen, without a redundant push. Review foreground behavior, opt-in controls, and duplicate suppression. Delayed review/ranking changes may warrant separate handling.
- [ ] Existing notification audit: local source, routing, and SQL checks completed; physical-device and production-delivery checks remain. Check rest-complete, workout-day, missed-workout, lift-review, friend, forum-reply, and message notifications. Distinguish implemented inbox/local behavior from verified remote delivery and deliberately disabled push categories; use `docs/notification-release-plan.md` for existing delivery gates.

Optional idea discussed, not selected for implementation: alerts for a chosen rival's new PR. Revisit only after the core gym-overtake and friend-request experience is settled.

## Scope and evidence

This reviews the current uncommitted iOS app for clutter, repetition, action hierarchy, navigation, presentation consistency, and accessibility risks. It is not a backend/security audit, a medical-content review, or a review of the separate website. It supersedes the earlier conversational lists where the source gives a more precise picture.

### Current source ownership — October 28, 2026

Historical findings below retain the file and line references observed during each audit. Subsequent extraction moved Forum UI to `LiftRankApp/Features/Community/ForumViews.swift`, Me Hub UI to `LiftRankApp/Features/Profile/MeHubViews.swift`, and authentication screens to `LiftRankApp/App/Session/AuthenticationViews.swift`. `LiftRankApp/Views/MainTabView.swift` now owns root navigation only; old line references into extracted screens are not current locations.

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
| High | The leaderboard RPC response is capped at 200 ranked entries, so Load more cannot reveal later ranks and the personal-rank jump is absent when the current athlete is outside that slice. Separate profile search can find up to 50 matching cards, but it returns no leaderboard rank and is not a substitute for rank search or a population count. | `Services/SupabaseServices+Leaderboard.swift`, `Features/Leaderboard/LeaderboardsViewSections.swift`: provide server pagination, total count and authoritative personal placement; connect athlete search to a ranked result only when the server can return that rank. |
| Low | Leaderboard public-profile mapping fills unavailable experience with Beginner. Public detail currently suppresses its training-details section when years of experience are missing, and production filtering is hidden, so this fallback is not currently presented as user data. | `Data/Supabase/SupabaseProfileMapper.swift`, `Services/SupabaseServices+Leaderboard.swift`: expose experience only after adding it to the authoritative public-profile response. |
| Resolved for production | Rep selectors offered 3/5/8/10/custom although ranking SQL admits actual one-rep maxes only and the service request has no rep filter. The controls and experience selector are now demo-only; production does not advertise unsupported rep rankings. | Revisit only if the server contract is extended to rank/filter rep-specific performances. |
| Medium | Server This week / This month mean rolling seven days / one month, while the visible labels can be read as calendar periods. Remote results now trust the server's selected lifts instead of applying a conflicting client calendar filter, but the interval wording still needs to match the product definition. | `supabase/migrations/20260731150000_canonical_verified_rankings.sql`, leaderboard time-range labels: agree on interval semantics. Any SQL correction needs a forward migration and runtime security tests. |
| Medium | Loading performs one awaited public-profile request per result. A long leaderboard can require 200 serial calls; any one failure fails the feed. | `Services/SupabaseServices+Leaderboard.swift`: return or batch the public profile data through the existing service boundary. |
| Medium | Remote total results always use `powerliftingBreakdown: nil`; the useful S/B/D explanation is only populated by local/demo calculation. | `Services/SupabaseServices+Leaderboard.swift`: return authoritative lift contributions and distinguish a partial total. Do not manufacture a breakdown from the single representative lift. |
| Medium | At accessibility sizes all five ranking modes become a vertical list before the filters and results. Normal text hides later modes in horizontal scrolling. | `Components/LeaderboardComponents.swift`: evaluate a compact, clearly labeled ranking picker when the next runnable preview is available. |

Verification: Swift frontend syntax parsing passed for all five touched implementation files and `git diff --check` passed. Parsing does not type-check SwiftUI or validate runtime layout. Existing leaderboard UI tests were reviewed but not run because they require compiling an app, and the user requested no new build. Dark/light/accessibility screenshots of the corrected source, live loading/error/retry, ties, over-200 pagination, account switching, search cancellation, and production filter accuracy remain explicit verification gates. Build number remains 28. This pass adds no files, types, abstractions, or dependencies.

October 29 follow-up: the remote leaderboard preserves server-assigned ranks and no longer compares canonical `cityID` against public profile cards that intentionally omit that ID. Remote results now rely on the RPC for its supported filters; the only client-side remote filter is the returned lift's evidence level. Production no longer exposes rep-count or experience filters that the RPC cannot honor; demo mode retains them. The focused regression `testRemoteLeaderboardPreservesServerResultsRanksAndRefreshKeyTracksFilters` passes on iOS 26.5. The placeholder experience model value, 200-ranked-entry cap, time-range wording, and other open findings above remain unresolved; the profile detail currently avoids displaying the placeholder. The existing demo profile-video UI performance case also passes after replacing the callback/continuation thumbnail path with AVFoundation's async generator API; an unsigned Release build passed with no `AVAssetImageGenerator` sendability warning.

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

**Supersession note — October 28, 2026:** `OnboardingView.gymsMatchingLocation` is present again in the current source, and the full iOS unit target passed 415 tests on iOS 26.5. The compilation limitation above is retained as historical evidence and is no longer a current blocker.

Further onboarding review (October 18): the welcome and sign-in screens now use the existing Lift Rivals logo instead of system dumbbell/lock artwork. `BrandLogo.imageset` exposes the existing app-icon artwork as an ordinary in-app image asset. Policy acceptance is presented over the live onboarding screen, with Back returning to the same setup values; initialization runs once so dismissing that cover does not reset the draft. Accounts returning directly to outstanding policies have an explicit “Back to sign in” action. Policy acceptance remains required for entry.

Verification of that follow-up: iPhone 17 Debug UI checks passed for the four-choice count and single-goal selection, branded welcome/sign-in images, optional profile details, years-training changes, and the policy Back round trip. The round trip verifies username, decimal bodyweight, and city survive, then verifies Continue opens policies again. Results: `/tmp/liftrivals-onboarding-four-goals-back.xcresult` and `/tmp/liftrivals-onboarding-four-goals-final.xcresult`. No policy was accepted. The existing full-suite unit-test compilation limitation above remains outside this change.

Terms Back-button consistency follow-up: the policy screen now uses onboarding’s 42-point circular chevron and the same top/horizontal spacing, pinned above the scrolling policy content. Its accessible destination label and `legal.back` identifier remain intact. The existing iPhone 17 onboarding/policy Back round-trip test passed in `/tmp/liftrivals-terms-back-style.xcresult`; no new files, abstractions, or dependencies were required.


### October 31 follow-up: workout tracking and feature workflows

- Set entry now presents weight before reps in standard and accessibility layouts; keyboard Next follows the same order.
- Strength goals use numeric-only drafts with a separate unit, positive-value validation, a dedicated editor, visible save failures, and pending-state protection. Add goal leads from a searchable lift picker into the editor. Recent logged lifts appear first and existing targets are marked. Goal cards allow two-line names and show equipment.
- Strength targets synchronize through the account profile service using the authenticated user's private Auth metadata (`strength_goal_targets_kg`, canonical kilograms). Device preferences remain a local cache. Existing cached targets upload only when no account targets exist; failed saves retain the draft. No SQL schema or security policy changes are required.
- Plan creation prevents swipe dismissal of changed drafts and asks before discarding through Cancel.
- Today's plateau alerts now use the same recent-history/recovery-week exclusions as progress attention insights.
- Weekly training goals use a determinate ring and display actual training days, including days beyond the goal.
- Plans distinguish full completion from a cycle whose sessions were all recorded with shortened/skipped outcomes. Today offers cycle review and selection of another program.
- Prescription substitutions reuse the searchable exercise picker, prioritizing matching body parts with different equipment. Muscle progress leads with the selected week's logged workload before the recent-work estimate.

Verification: Debug simulator app and test targets compile. Five focused unit checks passed on iPhone 17 / iOS 26.5, covering weight-first keyboard navigation, bodyweight navigation, and plateau eligibility (including old history and recovery sessions). Cross-device account synchronization still requires a signed-account end-to-end check; no real-account credentials or remote schema changes were used for this follow-up.

Simulator follow-up: confirmed numeric target drafts, visible zero-target validation, disabled invalid Update, cancellation without changing the stored goal, plan discard confirmation and preserved draft content, the ended-cycle status in Plans and Today, and an actual weekly count of four days against a three-day goal. The final goal-sheet presentation correction builds with no issues.

Final check: Add goal shows recent lifts first, marks existing goals, and opens target entry immediately after selecting a lift. The final build succeeded with no issues at 4:20 PM; the simulator remains on Strength progress.


### October 31: implementation backlog, phase 1

- Active exercise tracking exposes existing form cues and progression-method guidance in collapsed disclosures. Existing resolved prescription notes explain the source of suggested loads. Targets remain editable training guidance, separate from competition results.
- Weight-first entry and previous-workout copying remain available. A Copy last set action copies values from an earlier completed working set in the current exercise without marking the receiving set complete.
- Optional effort-based rest is off by default and persists through the existing workout preferences. RPE 9–10 adds 30 seconds to prescribed rest; RPE 1–6 removes up to 15 seconds, with a 30-second floor unless prescribed rest is shorter. Missing/invalid effort and warm-up effort keep prescribed rest. These are transparent timer rules, not learned or medical recommendations.
- Rest countdowns explain adjustments, support adding 30 seconds, and retain Skip. Existing auto-rest controls still govern whether a timer starts.
- Scope remains the approved backlog: no Apple Health, AI, nutrition, avatar leveling, or side-by-side photo comparisons.

Verification: GPT-6 Luna completed the Debug iPhone 17 simulator build and seven focused unit checks, covering rest thresholds, legacy preference decoding, adaptive progression, automatic completion, active workout progress, and weight-first keyboard navigation. No remote database changes or new dependencies were required.


### October 31: phase 3 progress and history

- Consistency's weekly card now includes distinct training days and training minutes, alongside existing workout/set/volume stats and the weekly training-day goal card.
- Recaps & export opens a separate sheet, preserving the compact Progress overview. Month/year selectors and previous/next controls browse personal training recaps; the current period is explicitly partial.
- Recaps count saved workouts with completed working sets, distinct local training dates, completed working sets, duration, and weighted-rep volume. Warm-ups/incomplete sets are excluded from recap totals. Weekly and recap volume share snapshot/catalog tracking-type resolution and unit conversion; calendar periods use a start-inclusive/end-exclusive boundary.
- Native Save CSV to Files exports saved history, including warm-up/incomplete statuses, workout/set identifiers, UTC dates, recorded weight/unit and kilograms, separate reps/timed seconds, and effort. Text cells are quoted and formula-leading content is neutralized. The save flow shows errors, and export is disabled without history.
- Recaps are personal logs, separate from verified competition. Their counting disclosure notes that other-device history appears after sync. There are no account schema or remote migration changes.

Phase 3 verification: GPT-6 Luna ran focused recap, CSV, weekly training-day, empty analytics, and timed-work volume checks. A regression involving older custom timed exercise snapshots was caught and corrected by sharing snapshot-first/catalog-fallback volume resolution. The corrected recap, CSV, and timed-work tests passed. Native Files export delivery still needs an on-device save check.

## October 31: app-wide UX/UI audit after phases 1–3

Scope: screen-family source review plus live iPhone 17/iOS 26.5 demo inspection of Home, Rankings, Forum, Me, Consistency accessibility content, and Training recaps. Source review covers supporting routes, forms, workout flows, settings, and onboarding listed below. This is not an exhaustive device-state certification: Light/System appearance, accessibility text sizes, VoiceOver navigation, keyboard obstruction, live-account permissions, offline errors, and every nested sheet still require runtime checks. Recommendations below are not implemented by this audit. No application code changed.

### Prioritized findings

| ID | Priority / evidence | Finding and consequence | Recommended change / acceptance |
| --- | --- | --- | --- |
| A1 | High / source | Forum composer Cancel directly dismisses; completed-workout editor Cancel directly dismisses; Submit Lift Close directly dismisses. These forms lack the changed-draft protection already used by CreateWorkoutPlanView. Work entered into long forms can be lost accidentally. | Apply changed-draft detection to these forms first, then profile/plan-note editors. Cancel asks Discard or Keep editing; interactive dismissal cannot silently discard changes. Unchanged forms close immediately. Preserve edits on failures and prevent dismissal while saving/publishing. |
| A2 | High / source | PrescriptionTrackView now stacks targets, cues, progression explanation, a global rest preference, metrics, history, and details before the set list. WorkoutSetLogRow adds Copy last set and repeats effort explanation when adaptive effort controls are enabled. | Keep exercise + target + current set at the top. Move persistent rest settings into workout options. Present one effort explanation per exercise; show copy as a compact contextual action. The first editable set should appear without scrolling on a standard phone with default text. Preserve weight-first keyboard order and accessible actions. |
| A3 | High / source | Settings mixes draft values saved by Done with AppStorage notification changes and immediate training-preference updates. Its swipe-dismiss protection only applies while saving. Edit Profile explicitly saves photos independently from the form. | Make save semantics consistent or explicitly label immediate sections. Use Save changes for draft settings, protect changed drafts on dismissal, and show a saved state after success. A user can tell which changes are already applied before closing. |
| A4 | Medium / live + source | Home has a truncated greeting at normal text size and several large competing cards; Resume is gold while ordinary actions use the chosen accent. Awards consume substantial space before recent training. | Shorten/remove greeting decoration; give Resume/Start the dominant action and use the selected accent. Collapse awards into a compact secondary row. Retain full accessible labels and readable names. |
| A5 | Medium / live | Rankings' horizontal metric row cuts off Relative total and hides further choices. All time is a small summary rather than an obvious control. The page title says Leaderboards while the tab says Rankings. | Use a compact metric menu plus clearly labeled scope/time controls, and one consistent screen name. Keep evidence filters visible. Add the approved podium only when it retains verification context and does not push the list excessively down. |
| A6 | Medium / live + source | Color emphasis is spread across selected accent, gold, orange, green, and blue. The current pink accent is a saved user choice, not evidence that the default lime identity is missing. | Preserve theme choice. Reserve accent for primary actions/selection, neutral text for numbers, and semantic colors for meaningful status. Retain status labels/icons. Use lime in default brand presentation; do not overwrite user preferences. |
| A7 | Medium / live + source | Consistency repeats weekly stats across the overview, goal, streak, month count, heatmap, and history. Recap volume displays 153671.5 lb × reps without grouping; weekly minutes display 223 min. | One compact weekly summary with goal progress, workouts, and time; put secondary counts behind Details. Format large volume with separators and restrained precision; use 3h 43m for long durations. Preserve exact export values. |
| A8 | Medium / live | Recap's disabled Next arrow still looks much like the active Previous arrow. Export presents a long technical paragraph within the recap screen. | Give disabled arrows a visibly muted style. Shorten export summary; move column/timezone details under What is included. Show an explicit export success state and keep retryable errors. |
| A9 | Medium / live + source | Me gives a large submitted-strength card prominence above training destinations; tier, workout PRs, personal logs, and submitted totals coexist. Current Self-reported labels are useful and must remain. | Group competition submissions separately from personal training. Keep edit/public-preview controls clear. Make the primary training/history destination visible earlier. Do not describe video-backed lifts as verified. |
| A10 | Medium / live | Forum uses accent on avatars, type badges, selected feed, and icons, while repeated Discussion labels and long previews make each row tall. | Use neutral avatars/type metadata, shorten previews, retain one prominent title and compact vote/reply row. Keep Pinned distinct without a second large colored badge. |
| A11 | Medium / source | FloatingTabBar caps Dynamic Type at xxxLarge and uses small single-line labels. Several screens also have fixed-width controls and horizontally scrolling categories. | Add an accessibility-size navigation presentation rather than silently capping labels. Verify all tabs remain reachable and labeled with VoiceOver. Check smaller phones and large text before claiming accessibility compliance. |
| A12 | Design recommendation / source; refined by R3 below | Library exercise detail splits About/History/Records/Charts while Strength Progress has parallel chart/record destinations. Multiple entry points alone are not a defect. | Retain useful entry points; make metric definitions and included workouts explicit. See the repeat audit's concrete scope mismatch before considering navigation consolidation. |

### Screen-family coverage and next improvements

“Source” means an implementation review, not a live walkthrough of every state. Rows without a confirmed defect are design recommendations or verification targets.

| Screen family | Review basis | Recommended UX/UI work |
| --- | --- | --- |
| Welcome, sign-in, guest, password recovery/update | Source | Keep one primary authentication action; group guest/demo as secondary choices. Verify keyboard return, inline errors, password-manager behavior, and busy states on a real account. Do not change authentication logic based on visual review. |
| Onboarding, location pickers, policy acceptance | Source | Preserve the existing step indicator and draft-preserving Back flow. Reduce optional profile detail density; keep skip/optional status explicit. Verify long location names and large text. |
| Home and streak | Live Home; source overlays | A4/A7. Keep Resume/Start dominant. Explain streak rule once in its detail screen; a missed goal should not read as an app error. |
| Notifications | Source, HomeOverlays | Existing event icons, action routes, unread dot, and unread background are useful. Consider date grouping if the inbox grows. Verify event destination and permission-denied states on device; local reminders and inbox events are distinct. |
| Today and missed-workout suggestions | Source | Prioritize active/due workout, then one next action. Keep optional moves within their stated scope. Move prolonged plateau explanation behind Review; avoid competing primary CTAs. |
| Plans, plan details, weeks, queue, session menus | Source | Show Calendar schedule or Queue mode clearly beside the next workout. Keep viewed week separate from current week. Promote Move workout out of an obscure menu when relevant; preserve skipped/shortened/completed distinctions. |
| Program catalog, template detail, setup, creation | Source | Present training days, duration, equipment, and progression as a short overview before detailed setup. Use the existing review stage; extend draft protection consistently to notes/setup editors. |
| Library, custom exercise, add-exercise and substitute pickers | Source | Retain search, active-filter count, and empty-state reset actions. Keep selected count + Add action visible in multi-select pickers. Use matching labels for body part, muscle, and equipment filters. |
| Exercise detail: About, History, Records, Charts | Source; About and Charts also live in repeat audit | A12/R3. Preserve the concise About instructions and existing Show data table disclosure. Verify the table with VoiceOver and keep metric/time selection consistent. |
| Active workout, exercise logger, rest banner, incomplete finish prompt | Source | A2. Keep pause/resume, rest Skip/+30, and Finish distinct. Verify large-text rest banner wrapping and keyboard reachability. Do not make a destructive discard look like ordinary navigation. |
| Review workout and saved-workout celebration | Source | Lead review with save readiness and errors, then optional effort/notes/public PR selection. After save, show one strongest highlight and a compact achievements disclosure. Keep explicit public-sharing consent. |
| Completed workout detail and editing | Source | A1. Keep workout date, set totals, and edit action easy to find; preserve the existing warning that deleting a log does not remove public submissions. |
| Progress: Consistency | Live accessibility + source | A7. Reduce duplicated weekly information and give history its own clear destination. Keep explanations collapsible. |
| Progress: Strength and goal editor | Source + earlier live checks | Preserve compact accent rings and numeric target editor. Show exercise selector, primary metric and trend first; make goals a compact supporting strip. Preserve target validation and save errors. |
| Progress: Muscle and muscle drilldown | Source | Lead with logged sets and period. Keep estimated training signals collapsed, explain indirect work separately, and retain text labels rather than color-only meaning. |
| Progress: Body and bodyweight entry | Source | Keep Log bodyweight the primary action and clearly label measurement date/unit. Verify editing a historical entry does not look like logging today's weight. |
| Monthly/yearly recaps and export | Live + source | A8. Add compact period comparison only after choosing a defensible comparison for partial periods. Verify Files cancel, success, failure, and export accessibility. |
| Rankings, filters, athlete results | Live + source | A5. Consistent ranking terminology, visible scope/time/evidence, and explicit empty-result reset. Keep submitted/video-backed/verified meaning intact. |
| Submit lift, video selection/review, upload, result | Source | A1. Keep actual versus estimated and evidence status adjacent to the result. Collapse plate-loading assistance until requested. Preserve upload retry and entered values. |
| Me, public profile, lift videos, submission management | Live Me + source | A9. Maintain public preview and field privacy explanations. Verify unavailable/private content does not look like a network failure. |
| Edit profile, photo manager/crop | Source | A3. Make photo's independent save explicit and avoid ambiguous Done/Save behavior. Verify crop controls and removal confirmation at large text. |
| Awards, tiers, existing share preview | Source | Favor closest milestones + recent earned awards over a long locked catalog. Keep share preview a single-result composition; customizable workout shares remain future backlog. |
| Gyms, gym detail, gym request | Source | Keep Joined/Primary states explicit. Put membership-limit explanation at the attempted action. Show request outcome and preserve entered request data on failure. |
| Forum feed, communities, filters, thread, composer/edit | Live feed + source | A10/A1. Clear contextual compose action, concise rows, preserved drafts, and specific locked/read-only state copy. |
| Reports and moderation | Source | Keep reason selection + submit compact with explicit success. Retain demo-only labeling on moderator screen; do not suggest a live moderation workflow exists here. |
| Settings: units, training, account, privacy, notifications, appearance, legal/demo | Source | A3/A6. Move rescheduling suggestions under Training rather than Notifications, because they affect Today UI. Keep notification controls for delivery preferences. Preserve Light/Dark/System. |

### Implementation order and acceptance gate

1. Prevent lost work and clarify save behavior (A1/A3).
2. Simplify active logging and primary Home/Today actions (A2/A4).
3. Unify color, spacing, number formatting, navigation naming, and disabled states (A5–A10).
4. Complete accessibility and state validation (A11/A12 and screen-family targets).

Use existing design tokens and owners. Do not add a second component system or redesign every card independently. Validate changes with the user's selected implementation model and GPT-6 Luna for tests/compilation. Test Light/Dark/System, largest accessibility sizes, a smaller phone, keyboard open, no history, long names, sync failure, and save failure. These checks remain pending for this audit; the current demo screenshots alone cannot establish them.

### October 31 repeat audit: live workflows and corrected priorities

This pass rechecked the installed phase-3 demo on iPhone 17 / iOS 26.5 at normal text size, in Dark appearance with the existing Pink accent. Live evidence and current-source evidence are distinguished below; the app was not rebuilt for this audit. Only navigation and disclosure controls were used. The existing empty freestyle draft was opened and minimized without changing its exercises, sets, or timer controls. No preferences, account data, submissions, or posts were changed.

The highest priorities are predictable save/dismiss behavior and consistent metric meaning. Visual simplification should follow those fixes. Findings R1–R9 refine the earlier audit; they are not implementation completion claims.

| ID | Priority / evidence | Reproduction or source evidence | Recommended change and acceptance |
| --- | --- | --- | --- |
| R1 | High / source-confirmed; network scenario not exercised | Forum New discussion starts an unstructured publish task while Cancel still directly dismisses (`Features/Community/ForumViews.swift:603–628`). Submit Lift likewise keeps Close available while `submitLift()` awaits submission (`Views/SubmitLiftView.swift:148,801–826`). Dismissing the screen does not explicitly cancel the request, so it may finish after its progress/result UI disappears. Before submission, these forms and completed-workout editing also lack changed-draft protection. | Protect edited drafts. During submission, either keep the progress/result visible and prevent ambiguous dismissal, or explicitly support background completion with a persistent outcome. Do not label dismissal as cancellation if a server operation can still complete. Verify with delayed success and failure; no lost result, accidental duplicate submission, or silently discarded draft. |
| R2 | High / source; Settings root and Training inspected live | Units, training focus, and privacy are drafts saved through Done. Appearance/reminders use AppStorage and training switches call immediate setters, including automatic PR sharing (`Views/SettingsView.swift:27–34,190–205,318–328,362–401`). Swiping away protects only an active save, leaving different controls with different persistence behavior. | Establish one clear save contract. Explicitly label any settings that apply immediately, protect unsaved drafts, and use Save changes for deferred edits. Verify change → back → dismiss → reopen for each persistence category. Do not make privacy or sharing behavior depend on an unexplained distinction. |
| R3 | Medium / live + source | Library → Back Squat → Charts → Est. 1RM → 3M showed **Latest 109.8 lb**, Aug 8–Oct 24, 12 workouts. Progress → Strength → Back Squat → 3M showed **Latest estimated 1RM 119.7 lb**, Aug 8–Oct 17, 9 logged training days. Progress deliberately excludes known recovery workouts (`Features/Training/Progress/TrainingProgressView.swift:1330–1334,1904`); Library charts include them (`Features/Training/Library/ExerciseLibraryDetailView.swift:417–420`). Workout counts and training-day counts also have different meanings. | Put the inclusion rule next to the metric: e.g. Latest working-day estimate with Recovery weeks excluded, versus Latest logged estimate with All workouts. Alternatively provide a consistent recovery filter. Preserve intentional calculations; do not treat this as a proven arithmetic defect. With the same exercise, period, and scope, both screens should explain any remaining difference. |
| R4 | Medium / live + source | Today displays Resume active workout alongside Start freestyle workout; Start triggers a conflict flow when a draft exists (`Features/TrainingTracker/TrainingTrackerView+Sections.swift:472–479,945–954`). Opening the existing empty draft shows **0/0 exercises, 0/0 sets**, yet a large filled Finish workout button dominates the secondary Add first exercise action (`Features/Training/ActiveWorkout/WorkoutSessionRunView.swift:387,488–530`). | Make Add exercise the primary action until the workout has loggable content, and explain finish eligibility. While a workout exists, prioritize Resume and put starting a different workout under an explicit secondary action. Preserve the existing conflict and empty-finish safeguards; this is an action-hierarchy issue, not evidence that an empty workout can be saved. |
| R5 | Medium / live | Consistency shows a weekly summary, a second training-day goal card, then Training pattern with another pair of controls; its chart begins near the bottom of the initial viewport. Strength places goal content and multiple control rows before its chart. Muscle uses both Tracker and Progress navigation rows, then heading, period, summary, filter, column labels, and comparison explanation before the muscle rows. | Give each category one initial focal point: Consistency = weekly goal plus compact totals; Strength = selected lift, estimate and trend; Muscle = selected period and set comparison. Consolidate repeated counts and move secondary explanation under existing disclosures. At normal phone size, the primary chart or useful data rows should appear without a long preamble. Retain explicit units and counting rules. |
| R6 | Medium / live + source | Plans with an active workout disables Add Workout Day and plan-edit actions. The reason appears after the plan detail and program library (`Features/TrainingTracker/TrainingTrackerView+Sections.swift:663–676`), separated from controls above it. The viewed plan also stacks plan status, view tabs, schedule explanation, phase disclosure, and week navigation before sessions. | Place a compact Active workout in progress explanation and Resume action beside the blocked plan controls. Compact the plan header while keeping viewed-week dates and schedule mode clear. A user should understand why an action is unavailable without searching the bottom of the screen. |
| R7 | Medium / live copy + source color mapping | Muscle → Recent training signal says **Lime: below 65**, but the lower-score bar uses the configurable `Color.liftAccentText`; this demo is Pink (`Features/Training/Progress/TrainingProgressMuscleView.swift:106,123`). Higher-score bars use orange. The legend text was observed live; the lower-score mapping is source-confirmed. | Use Higher recent work / Lighter recent work with swatches that match the actual colors, or use a dedicated semantic palette consistently. Preserve numeric scores and the statement that this is not a fatigue/readiness measure. Validate every supported accent rather than forcing the user back to lime. |
| R8 | Low / live + source; demo only | Plans → Review saved workout → Full Body A displays **[demo:program-history-v2]** in Notes. The demo seed stores its identity marker as workout notes (`Data/Demo/DemoProgramRepository.swift:148`), and detail displays those notes directly (`Features/Training/CompletedWorkout/CompletedWorkoutDetailView.swift:117–121`). | Keep seed identification out of visible note text while preserving seed deduplication. Use meaningful sample notes or no visible notes. Check detail, editing, and CSV output; do not remove arbitrary user notes that happen to resemble metadata. No production-data leak was established. |
| R9 | Medium / live | The current-month recap's Next period is disabled in the accessibility tree but looks the same pink as Previous. Volume reads **153671.5 lb × reps**; Consistency reads **39931.0 lb × reps** and **223 min**. Export explanation occupies several lines in the recap's main flow. | Visibly mute the disabled arrow; format volume with locale-aware separators and sensible precision; format long durations consistently with recap's existing hours/minutes. Keep export's primary wording short and move column details into a disclosure. Exact CSV values should remain unchanged. |

Reconfirmed visual findings: Home still truncates GOOD AFTERNOON at normal size and gives awards a large card ahead of recent training (A4); Rankings still clips Relative total and hides later modes in a horizontal row, with time range only in the summary (A5); Me's large submitted-strength card pushes training destinations low on the screen (A9); Forum repeats colored avatar, Discussion badge, and multi-line preview per row (A10). These are hierarchy and discoverability recommendations, not evidence that the underlying data or controls fail.

Corrections and useful existing behavior:

- Multiple exercise-detail entry points alone do not justify a redesign. R3 identifies the actual cross-screen consistency issue.
- Library Charts already has **Show data table**. Keep it; VoiceOver behavior still needs a dedicated check.
- Notifications already have an unread dot, tinted background, and border. A missing unread state is not an established defect.
- Public preview intentionally resolves the current user's saved profile/privacy in `Views/ProfileView.swift:13–24`, matching Settings' saved-settings explanation. Passing a draft-shaped value at the call site is not evidence of a broken preview.
- MainTabView uses a bottom safe-area inset. Screenshots showing content continuing behind the floating tab region do not by themselves prove that the last content is unreachable.
- Body's empty state and dated entry form clearly explain the next step, unit, and profile-weight prefill. Back Squat About presents short instructions and form cues with supplemental detail collapsed. Keep these patterns.
- The saved workout's actual completion date differed from the plan's viewed-week date. This alone does not establish an incorrect workout mapping; planned versus actual dates would need a separate workflow check.

Coverage added in this pass:

| Screen or workflow | Evidence / remaining limit |
| --- | --- |
| Home, Rankings, Forum, Me | Fresh live screenshots and accessibility content; no posts, ranking filters, or account changes submitted. |
| Today → existing empty workout → Add Exercises → cancel → minimize | Live. Draft preserved. Populated exercise logger, keyboard, rest countdown, finish/review/celebration remain source-only in this pass. |
| Plans → completed Full Body A | Live plan chrome, blocked controls, completed-set detail and notes. No rescheduling or editing. |
| Library → Back Squat About and Charts | Live guidance, chart metric/period, latest value, and data-table entry point. No custom exercise created. |
| Progress Consistency, Strength, Muscle, Body | All four categories inspected live, including expanded training-signal copy. Lower signal bar color mapping checked in source. |
| Body → Log bodyweight → cancel | Live unchanged form; date, units, prefill wording inspected. No measurement saved. |
| Recaps & export | Current-month recap inspected live again. Files export, previous/year views, failure and completion feedback not exercised in this repeat pass. |
| Settings root and Training | Live controls and copy; save/dismiss semantics reviewed in source. No preferences changed. |
| Auth/onboarding, privacy permissions, other nested editors, social write flows, moderation, offline/retry states | Prior source coverage retained; not newly certified through live interactions. |

Next implementation batches: (1) R1/R2 save and dismissal consistency; (2) R3/R4/R6 metric wording and next-action clarity; (3) R5/R7/R8/R9 plus A4/A5/A9/A10 visual cleanup. Preserve black/white/lime defaults and optional accents. Keep AI, nutrition tracking, Apple Health, side-by-side photos, and avatar leveling out of scope.

Verification boundary: this repeat audit did not run tests or compile an app because it changes documentation only. Light/System appearance, accessibility text sizes, VoiceOver, keyboard-open layouts, smaller screens, real-account network operations, notification delivery, and physical-phone behavior remain unverified in this pass. The source-confirmed Dynamic Type cap in A11 remains a follow-up; no new accessibility compliance claim is made. Future implementation tests and compilation should use GPT-6 Luna as requested. No new files, abstractions, or dependencies were added.

## Supplementary audits — October 31, 2026

Requested sequence: complete workout journey; data consistency; interruption/offline recovery; accessibility/appearance; first-time usability; gamification; scheduling/notifications; privacy/competition; performance. Each audit is documented before proceeding to the next. These audits do not implement fixes. Current-source tests/compilation are assigned to GPT-6 Luna; runtime tests use an isolated disposable simulator and mock/demo accounts, preserving the user's original simulator and workout draft. A source finding is not a claim that a production failure was reproduced.

### Audit 1 — Complete workout journey

Scope: Today/resume → exercise logger → weight-first keyboard navigation → substitution → incomplete-workout prompt → review/edit → save → completion. Source review also traced previous-value copying, automatic set completion, and rest controls. Four existing focused UI tests ran on the isolated iPhone 17 Pro / iOS 26.5 simulator. Their failures prevented an end-to-end completion pass.

| Finding | Evidence and impact | Recommended acceptance |
| --- | --- | --- |
| W1 · Medium: review claims an account save too early | `WorkoutSummaryView.swift:286` displays Saved to your account while still in the unsaved review branch above Save & finish. The wording also does not distinguish local persistence from remote sync. Source-confirmed; demo tests display the demo-specific alternative. | Before save: explain where the workout will be saved. After save: distinguish saved locally, syncing, and synced when relevant. A failed/pending upload must not appear as confirmed remote storage. |
| W2 · Medium: too much preparation before logging | `PrescriptionTrackView.swift:49–193` places targets, cues, progression, adaptive-rest setting, metrics, history/details, and optional substitutions before the first set. Rest effort explanation repeats per set when enabled. This extends A2/R5. | Keep the first editable set visible on a standard phone; move persistent options and supplemental detail behind existing controls. Preserve form cues without making them a required stop. |
| W3 · Medium: primary action ignores workout readiness | Existing live R4: empty draft highlights Finish; Today offers another Start beside Resume, leading into a conflict prompt. The empty-finish and incomplete-finish guards exist. | Prioritize Add exercise for an empty draft, Resume for an existing workout, and Save only after readiness is clear. Keep incomplete-session review explicit. |
| W4 · Medium: substituted exercise can inherit uncompleted input | `DemoWorkoutRepository.swift:268–274` replaces the exercise snapshot under the same ID when no set is completed; existing uncompleted log values remain. The replacement also keeps target reps (`:657–671`). Entered weight/reps can therefore carry into a different exercise or tracking type without a review step. This repository owns local workout behavior; this is source-confirmed, not a live cross-type reproduction. | On substitution, explicitly review carried values. Clear or remap incompatible fields without silently deleting completed work; verify weighted → timed and partial-input substitutions. |

Useful behavior to preserve: weight appears before reps in both row layouts; the keyboard navigator follows that order. Copy previous/last values converts from the recorded unit into the current set's unit and does not itself mark that set complete. Completed source-exercise sets survive substitution by inserting a new exercise. Finish routes incomplete sessions through review, and review allows editing sets before saving. PR sharing is an explicit review choice, separate from saving the workout.

Runtime result: **4 UI tests executed: 1 passed, 3 failed, 0 skipped** (7 failed assertions/taps across the 3 cases). Weight-first entry through three sets and final keyboard dismissal passed. The reviewed screenshot shows weight before reps, the rest banner, and Copy last set. Completion failed after Finish: the hierarchy still showed the workout instead of the incomplete-review prompt. Empty-workout ending failed after Resume: the hierarchy still showed Home. Substitute navigation failed after Find a substitute: the screenshot remained on exercise detail. These observed transitions need targeted reproduction; their cause is not established as either an app defect or an automation defect. No summary/saved screen was reached in this run. The substitute case tests Library navigation, not active-session replacement.

Build: Debug, staging backend configuration, simulator Sign to Run Locally; all selected tests launch `-uiTestingDemoMode` and perform no real account sign-in. Isolated destination: `53AE7E0C-C243-489E-88CB-0CD1EE3833ED` (Lift Rivals Audit 1). Artifact: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Build/Products/Debug-iphonesimulator/LiftRank.app`. Log: `/tmp/liftrivals-supplementary-audit-1-tests.log`. Result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_17-51-13--0400.xcresult`. Screenshots and failure hierarchies: `/tmp/liftrivals-supplementary-audit-1-attachments/`.

Audit 1 is documented with an **open workflow-validation gate**, not a passing journey. One-handed comfort, real-world logging speed, active replacement after partial entry, and physical-keyboard behavior remain unverified. No app or test code changed.

### Audit 2 — Data consistency

Scope: canonical/display units, completed working-set inclusion, timed exercises, workout versus training-day counts, recovery filtering, PR estimates, and CSV contents. Six existing focused unit cases were checked; cross-screen source tracing supplements those cases.

| Finding | Evidence and impact | Recommended acceptance |
| --- | --- | --- |
| D1 · High: legacy custom timed-set volume differs by surface | `TrainingProgressStore.swift:925–931` resolves a missing snapshot tracking type against the full repository catalog, including custom exercises. `WorkoutProgramDomainModels.swift:430–444` resolves `CompletedWorkout.totalVolume` against bundled MockData only, defaulting unknown types to Weight + Reps. Completed-workout detail (`CompletedWorkoutDetailView.swift:47`) and Home's last-workout card (`HomeFeatureComponents.swift:603–604`) use that property. The existing timed regression fixture has a custom timed set with no snapshot tracking type and retained values 500 lb / 30 seconds: source evaluation adds 15,000 lb × reps to detail but excludes it from weekly/recap volume. This is a source-derived mismatch; no affected user record was modified or live-reproduced. | Resolve legacy tracking type consistently before analytics/presentation. Add a regression comparing detail, Home last workout, weekly totals, recaps, and volume-PR comparisons for the same custom timed history. Preserve valid recorded data; never count seconds as repetitions. |
| D2 · Medium: Latest does not describe the same included history | Live R3 remains: Library's 109.8 lb estimate includes recovery workouts while Progress's 119.7 lb estimate excludes them. Per-workout and per-day counts also differ intentionally. | Show the inclusion rule beside each headline and match filter terminology. Do not change correct estimates just to make labels agree. |
| D3 · Medium: active volume looks like a weight | Audit 1's set-entry screenshot shows 1604 lb for two completed sets; source `PrescriptionTrackView.swift:40` formats completed volume as an integer plus unit, while recaps/detail use lb × reps. | Label volume explicitly and use consistent precision/grouping; weight, target weight, and accumulated volume must remain distinguishable. |
| D4 · Low: CSV and dashboard counting rules need a compact explanation | CSV exports all saved set rows including warm-ups/incomplete sets, repeats workout-level duration per row, uses UTC, and preserves original units. Dashboard totals filter completed working sets and use local calendar dates. These are intentional differences, not an established export defect. | Explain One row per set, group by workout ID for workout totals, and UTC dates in export details. Verify a consumer can reconcile an export to the selected local period without summing repeated workout durations. |

Positive source checks: Home weekly and recap share the same completed-working-set volume helper; half-open date intervals prevent boundary duplication; training days are distinct dates, not workout counts; estimated 1RM is limited to eligible weighted sets; the Heaviest chart computes maximum normalized weight separately from the best estimated-max set. CSV distinguishes repetitions from timed seconds and neutralizes formula-leading text. No new arithmetic defect is established beyond D1's legacy fallback mismatch.

Verification: **6 selected unit tests passed, 0 failed**, using the audit-1 build and isolated destination without recompilation. Covered recap interval boundaries/working sets/canonical volume, CSV escaping/units/durations, weekly timed-set exclusion, recorded-volume conversion, bodyweight-versus-workout storage formatting, and normalized PR selection. Log: `/tmp/liftrivals-supplementary-audit-2-tests.log`. These passes do not cover D1's detail/Home-last-workout property. CSV generation checks do not verify the Files save/cancel interface or a spreadsheet round trip. Historical snapshot types, mixed units, same-day sessions, and period boundaries must remain part of the cross-screen regression set. Audit 2 is documented; no application/test code changed.

### Audit 3 — Interruptions and offline recovery

Scope: local persistence, background flush, relaunch state, elapsed/rest timers, upload retries, overlapping edits, deleted-workout tombstones, and account changes. Runtime coverage uses isolated in-memory service fixtures; no real connection or disk failure was induced.

| Finding | Evidence and impact | Recommended acceptance |
| --- | --- | --- |
| O1 · High: local save/load failures have no visible error path | `Data/Local/WorkoutPersistenceStore.swift:57–95` uses optional `try` for fetch, encoding, decoding, and saving; its save contract returns no outcome. A failed fetch/decode returns the same nil as absent history, and a failed device save cannot reach the caller's UI. Source-confirmed error handling gap, not a reproduced disk failure. | Surface failure through the existing persistence/service boundary; retain the in-memory draft and previous readable snapshot. Distinguish missing history from unreadable storage. A forced save failure must not report success. |
| O2 · High: completion acknowledges before durable save/queue recording | `ActiveWorkoutStore.finish` (`:453–460`) returns after scheduling persistence; the repository debounce waits one second (`DemoRepository.swift:215–225`). Authenticated completion then asynchronously encodes/enqueues upload (`AppState+ActiveWorkout.swift:175–183,214–232`). A process interruption between acknowledgement and persistence/queue recording is an untested durability window. Ordinary background flush helps but is not proof against abrupt termination. | Persist completion and upload intent before acknowledging durable save, or clearly show an in-progress save. Fault-inject termination at these boundaries and verify exactly one restored completion and a retained upload intent. Do not erase app data to recover. |
| O3 · Medium: unreadable remote records can still end in Synced | `WorkoutSyncStore.swift:124` skips undecodable snapshots, then may set `.synced` when the pending queues are empty (`:133–140`). No warning identifies omitted history. | Keep valid local history; report partially unavailable history with a recovery path when any owned remote record cannot decode. Verify valid and invalid records in the same response. |

Useful behavior to preserve: focused set fields flush on leaving the field, disappearing, or resigning active; scene-phase changes flush the repository. Rest state stores an end date/exercise ID and restores by time rather than restarting a countdown. Sync deduplicates upload IDs, retains failed uploads, protects newer queued edits, checks account identity after awaits, and tracks deletions. Home and Progress already explain pending/stale history and offer retry; W1 identifies the summary wording that does not match those states.

Verification: **8 selected unit tests passed, 0 failed**: idempotent upload, retry after failure, newer edits during upload, stale account response rejection, deleted-workout retention, account-change cache clearing, clock rollback, and pause/resume/rest-timer lifecycle. Reused the same isolated simulator/build. Log: `/tmp/liftrivals-supplementary-audit-3-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-00-52--0400.xcresult`. These fixtures do not fault-inject O1–O3. The audit-1 UI failure means process-level workout restoration and full save/relaunch cannot be certified by this pass. Real low-storage, interrupted encoding, background suspension, airplane-mode/reconnect, and device notification behavior remain pending. Audit 3 is documented; no application/test code changed.

### Audit 4 — Accessibility and appearance

Scope: large-text and Light-mode set-entry tests, Dynamic Type handling, control labels, existing color tokens, selected-state meaning, and numeric entry. All eight accent palettes were checked numerically against the specified solid surfaces; this is not a pixel audit of every rendered screen or an accessibility certification.

| Finding | Evidence and impact | Recommended acceptance |
| --- | --- | --- |
| X1 · Medium: navigation text stops scaling before accessibility sizes | `FloatingTabBar.swift:16,44–46` caps Dynamic Type at xxxLarge and uses single-line shrinking labels. The large-content viewer and explicit tab labels are useful but do not provide a reflowing large-text navigation layout. | Verify an accessible navigation layout on a small phone with the largest text setting. Preserve selected-state labels and large-content support. |
| X2 · Medium: completed-set colors need stronger Light-mode contrast | Set numbers and completion symbols use `liftOnAccent` on semantic `liftGreen` (`WorkoutSetLogRow.swift:251–257,315–322`). Computed contrast is **3.44:1 in Light**, **13.06:1 in Dark**. Light is below a conservative 4.5:1 normal-text target; large-text/non-text criteria differ, so this does not establish that every green control fails. | Choose foreground/background pairs appropriate to each use and text size, especially small set numbers; verify rendered controls under increased contrast too. |
| X3 · Medium: repeated fields lack explicit set context | `WorkoutSetLogRow.compactField` supplies automation identifiers but no explicit accessibility label; placeholders are Lb/Kg/Assist, Reps/Sec. Each row repeats those names. Source finding; VoiceOver navigation was not executed. | Announce Set 2 weight, pounds and Set 2 repetitions, with value and completion state as appropriate. Test editing by VoiceOver without depending on visual column headers. |
| X4 · Medium: decimal-comma input is rejected by the parser | `WorkoutSetLogRow.swift:74–76` parses decimal-pad input with `Double(trimmed)`. A disposable Swift check returned nil for `100,5` and 100.5 for `100.5`. This is a parser-level result, not a device-locale reproduction. | Parse locale-appropriate numeric input and validate finite values consistently with display formatting. Check comma-decimal typing/paste and dot-decimal entry without silently changing the weight. |
| X5 · Medium: accent legend and disabled state convey inaccurate cues | R7's hard-coded Lime legend conflicts with optional accents; R9's disabled recap arrow retains active coloring. | Name the meaning, match legend swatches to rendered colors, and visibly distinguish disabled controls. Preserve numbers/icons so color is supplemental. |
| X6 · Medium: shaded Light-mode chips reduce small-text contrast | The black 18% `liftScrim` over the Light card reduces the calculated contrast to **3.77:1** for lime text in previous-value buttons and **3.32:1** for muted text in metric chips. Both use small caption text (`WorkoutSetLogRow.swift:269–278`; `PrescriptionTrackView.swift:421–427`). The completed-row blend yields 4.09:1 for lime text. | Adjust the field/chip surface or foreground to meet the selected 4.5:1 normal-text target. Verify actual composited pairs, not just palette colors on white. |

Color evidence: `/tmp/liftrivals-supplementary-audit-4-contrast.txt`. Across eight accents, text on the checked Light card/raised surfaces ranges from a minimum **4.65:1** (Teal on raised) upward; Dark card text minimum is **7.60:1** (Red). `liftOnAccent` on accent fills ranges **9.85:1–16.74:1**. These results apply to the solid token pairs only, not opacity blends, imagery, disabled text, or every semantic color. The 4.5:1 normal-text reference and its exceptions come from [W3C contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

Verification: **2 UI tests passed, 0 failed**: largest accessibility-size and Light-appearance keyboard flows reached the set fields, entered 100.5, navigated three rows, and dismissed the keyboard. Screenshot review confirms field/keyboard visibility; large-text supplemental content consumes substantial scrolling space. Log: `/tmp/liftrivals-supplementary-audit-4-tests.log`; screenshots: `/tmp/liftrivals-supplementary-audit-4-attachments/`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-02-18--0400.xcresult`. No existing `performAccessibilityAudit()` call was found in the test targets. These passes cannot replace manual VoiceOver, Voice Control, Reduce Motion, System-theme transitions, increased contrast, and small-phone checks. The original simulator's appearance and accent were not changed. Audit 4 is documented; no application/test code changed.

### Audit 5 — First-time-user expert walkthrough

The user explicitly selected **Expert walkthrough now; users later**. This is a cognitive walkthrough of labels, choices, feedback, and likely recovery paths, not a study of independent lifters. No completion times, hesitation rates, or participant success rates are claimed. Evidence combines current source, fresh isolated demo Home screenshot, audit-1/4 screenshots, and the prior live screen walkthrough. The demo contains seeded history and must not be treated as a fresh production account.

| Task / question | Expert finding | Recommended change |
| --- | --- | --- |
| Find where to train after signing in | U1 · Medium: successful email/Apple sign-in explicitly selects tab index 1 (`AuthenticationViews.swift:135,180`), which is Rankings (`AppRouter.swift:4–9`). This emphasizes comparison before the next personal task. Current demo Home's Rest Day card offers Open Programs, while freestyle training is found through Track. | Choose a deliberate landing destination, preferably Home/Today or the interrupted task. On rest/no-plan days keep an obvious optional Start workout route. Treat this as a product decision, not broken routing. |
| Choose a program without knowing a maximum lift | U2 · Medium: percentage-based setup explains training maxes but requires a value; without history it says Enter a conservative value (`WorkoutProgramTemplateDetailView.swift:314–341`). A beginner may not know how to choose one or that another progression method avoids this setup. | Provide an explicit I don't know my max path to an existing suitable setup method, without inventing a weight or giving unsupported training advice. Preserve preview and explanation of how targets are calculated. |
| Set a goal and know what reaching it means | U3 · Medium: Home's weekly training-day goal and Progress's estimated-1RM goal are different tasks; Strength's empty-state copy names 1RM but expects familiarity (`TrainingProgressView.swift:921–940,1634–1663`). They are also different from a workout's prescribed target load. | Name all three clearly: weekly days, estimated one-repetition maximum, and today's suggested load. Add one short plain-language explanation at first use; keep detailed rules expandable. |
| Know whether typing the final set finishes it | U4 · Medium: audit-1/4 final screenshots show three filled rows but only 2/3 completed. Source automatically completes a prior valid set when the next row changes, while final keyboard Done dismisses input (`ActiveWorkoutStore.swift:545–572`; `PrescriptionTrackView.swift:334–347`). The last set still needs its completion control. | Make the remaining-set action explicit after final keyboard Done and explain automatic completion once. Do not mark a set complete merely because fields were prefilled. Keep the 2/3 count and completion controls visible. |
| Find a workout versus publish a lift | U5 · Medium: Submit lift appears on Today and several personal surfaces, while logging and public submission are separate flows. Existing review sharing copy is clearer than the broad entry label. Me's submitted totals dominate its training destinations (A9). | Use destination-specific wording and adjacent context: log a workout privately versus submit a lift to share/compete. Give workout history a plainly named route. Preserve explicit sharing choice and evidence labels. |

Useful behavior: onboarding shows a four-step indicator and Back; profile training/location sections and starting lifts are optional; starting-lift copy says private; Continue as Guest explains adding email later; program setup offers a day-by-day preview; strength-goal failure retains the entry. These patterns reduce uncertainty and should remain.

Live boundary: the isolated demo Home screenshot was inspected at normal text/Dark (`/tmp/liftrivals-supplementary-audit-5-ready.png`). CUA could capture the screen but exposed no app controls and returned `noWindowsAvailable` on the attempted Track tap; new interactive task completion was therefore not verified in this stage. Earlier runtime evidence is explicitly reused rather than presented as a fresh participant run. Real-user follow-up: ask lifters to choose a workout, log three sets, set both goal types, find yesterday's workout, and explain what would be public, recording assistance and errors. Audit 5 is documented; no account data or application/test code changed.

### Audit 6 — Gamification and motivation

Completion gamification exists: the saved view presents PR/program highlights, newly earned badges, one next-achievement progress card, optional all-achievements expansion, and the next session. Strength-tier advances are also highlighted. This review checks consistency and emphasis, not whether rewards improve long-term retention; that requires user observation.

| Finding | Evidence and impact | Recommended acceptance |
| --- | --- | --- |
| G1 · Medium: repetition-award preview excludes eligible non-weighted work | `WorkoutSummaryView.achievementWorkingSets` (`:793–812`) keeps only Weight + Reps, and its result supplies both volume and repetition projections. Saved statistics (`DemoCompetitionRepository.swift:167–170`) count repetitions from every non-duration type, including bodyweight/reps-only/assisted sets. Crossing a repetition milestone with those sets can therefore be absent from the completion badge/progress preview even though saved statistics qualify. Source-confirmed rule mismatch, not a live badge reproduction. | Use each metric's existing eligibility rules for projection and saved statistics. Compare a bodyweight-only session crossing a repetition award with its saved Awards screen; continue excluding timed seconds from repetitions and bodyweight/assistance from weighted volume. |
| G2 · Medium: completion's milestone list is incomplete | Summary projection includes only four award categories and duplicates threshold lists (`WorkoutSummaryView.swift:750–789,849–870`). Repository eligibility additionally includes thresholds such as 15 Workouts, 2,000 Reps, and 1 Training Hours, plus streak/PR/strength awards (`DemoCompetitionRepository.swift:314–324` and surrounding eligibility logic). Such awards can qualify without appearing in the completion's newly-earned list. | Derive new awards from the same eligibility source as persisted unlocks. Check a newly crossed threshold, a streak award, and a first PR; celebrate each once without repeating previously earned badges. |
| G3 · Medium: completion can exceed its intended highlight budget | `orderedCompletionHighlights` caps its result at three, but the save action appends every advanced strength lift afterward (`WorkoutSummaryView.swift:349`), then renders up to three badges and a separate progress card. A strong session can restore the crowded reward stack the compact design was intended to avoid. | Lead with one result; keep a small total preview budget across reward types and put the remaining earned results behind the existing expansion. Preserve all earned awards in history. |
| G4 · Low: personal weekly goal and streak target can disagree | Personal goal supports 1–7 days or off; streaks always require three distinct days (`WorkoutHistoryCalendar.swift:164–182`). Streak detail and Progress's expanded rules correctly explain three days, but Home can say Goal reached at two days while the streak still requests another. This is an intentional rule distinction, not an arithmetic defect. | Explain the fixed streak rule near the configurable goal or explicitly decide whether the streak should follow that goal. Define how goal changes affect history before changing calculation. Avoid pressure to exceed a user's selected schedule. |

Useful behavior: projected rewards are captured in local values before the save action changes active state; ordinary completion still receives a positive saved message; sharing remains optional; earned unlocks retain their original dates and survive later history changes. Streaks count distinct training dates and allow the current week to remain in progress. Keep personal training awards distinct from verified competition status; no avatar leveling is proposed.

Verification: **7 selected unit tests passed, 0 failed**, run by GPT-6 Luna on the isolated simulator with existing products. Covered qualifying-week streak calculation, legacy deadlift identity for strength/awards, program-first highlight ordering, exclusion of previously earned milestones, preservation of unlocked awards, initial production-refresh preservation through mocks, and configurable weekly-goal persistence/off. Log: `/tmp/liftrivals-supplementary-audit-6-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-12-16--0400.xcresult`. These tests do not cover G1/G2's projection differences. The audit-1 completion transition remains an open UI gate, so a rendered post-save celebration is not certified by this source review. Audit 6 is documented; no application/test code changed.

### Audit 7 — Scheduling and notifications

Scope: planned-day reminders, permission/error presentation, rest alerts, optional rescheduling, inbox destinations, and the distinction between local and remote delivery. Source was compared with `docs/notification-release-plan.md`; no device notification was sent and no server sender/configuration was changed.

| Finding | Evidence and impact | Recommended acceptance |
| --- | --- | --- |
| N1 · Medium: push taps do not use the inbox destination routes | The application delegate handles only `local_destination = workout_today` (`LiftRankApp.swift:129–135`). The remote sender includes `destination` in its payload (`supabase/functions/send-notifications/index.ts`), but the delegate does not parse or forward it to `NotificationStore.open`. Rest alerts also have no destination payload. The inbox's typed routing tests do not verify notification-banner taps. | Route a tapped alert to its actual workout/lift/forum destination through the existing router. Retain a pending destination through cold launch/auth restoration; handle unavailable content clearly. Verify on a release-signed device. |
| N2 · Medium: rest scheduling can outlive cancellation | `SystemWorkoutRestNotificationScheduler.schedule` waits for settings/authorization callbacks, while `cancel` only removes requests already pending (`:75–110`). There is no generation check before a delayed callback adds its request. Skip/Finish can cancel first, followed by the older callback re-adding an alert. An older +30s request can also supersede a newer end time. Source-confirmed ordering gap; the timing failure was not reproduced. | Invalidate outstanding schedule work on cancel/replacement. Test delayed permission/settings responses followed by Skip, Finish, and repeated extensions; only the current timer may alert. The workout-day scheduler already uses revision/batch checks that preserve newer work. |
| N3 · Medium: rest-alert availability is invisible | Rest scheduling silently ignores denied permission and does not report add-request errors. Its foreground sound is triggered inside the visible exercise's timer view (`PrescriptionTrackView.swift:514–521`), while the notification delegate also requests foreground sound. Behavior can depend on the visible screen and delivery timing. | Distinguish a running timer from an enabled background alert. Offer a concise permission recovery path and select one foreground sound path. Check exercise-to-overview navigation, denied permission, music playback, Skip, and foreground/background transitions on device. |
| N4 · Medium: accountability configuration is only partially implemented | Settings offers workout-day reminders, a time, and rescheduling suggestions (`SettingsView.swift:148–174`); there is no missed-workout sender or per-event accountability preference. `NotificationStore.isEnabled` currently accepts all destinations. The release plan already marks missed-workout and remote delivery as pending. | Track these as remaining backlog/release work, rather than calling all accountability notifications shipped. Define supported event toggles and opt-in behavior before exposing them. Keep missed reminders bounded to unfinished sessions with an actionable destination. |
| N5 · Low: reminder setting does not explain ineligible plans | Refresh excludes queue-based or inactive plans and only schedules eligible future dated sessions; Settings can still show reminders enabled without a scheduled-count/next-reminder status. Rescheduling suggestions disappear when no safe date remains in the original week. These are intentional constraints, but the UI can look inactive without explanation. | Show the next scheduled reminder or a short reason none are scheduled. Explain the same-week limit when relevant and retain the existing Do this workout today route. After a move, show the resulting date clearly with an easy route back to Plans. |

Useful behavior: local reminders use the selected local time, remove obsolete requests, cap upcoming requests, and refresh after plan/history changes and app activation. Permission denial and workout-day scheduling errors have a Settings recovery path. Suggestions are optional and user-triggered, leave other sessions on their dates, skip occupied dates, and protect recorded/started sessions. Inbox rows retain event context and read state.

Verification: **8 selected unit tests passed, 0 failed**, run by GPT-6 Luna on the isolated simulator. Covered local reminder date/bounds, safe rescheduling, finish calling timer cleanup, notification read-state sync and fetch-failure retention, push token registration/revocation through mocks, exact forum-comment destination, and typed leaderboard routing. Log: `/tmp/liftrivals-supplementary-audit-7-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-13-24--0400.xcresult`. The mock cancellation test does not exercise N2's system callback race. Live APNs delivery, cold-start routing, DST/time-zone travel, sound with music, OS permission recovery, and actual background delivery remain pending. Audit 7 is documented; no app/test/server changes were made.

### Audit 8 — Privacy and competition clarity

The user selected **Use isolated test accounts and mark live checks pending**. This stage uses mock identities and account-switch fixtures only, plus client/schema/test source review. It does not claim that local display filtering proves server privacy. No live accounts were created or signed into, no real user records were inspected, and no remote migrations or SQL were executed.

| Finding | Evidence and impact | Recommended acceptance |
| --- | --- | --- |
| S1 · Medium: Self-reported results are a filtered slice of the all-lift ranks | `SupabaseLeaderboardService` sends `verifiedOnly` but no self-reported-only selector and caps the response at 200 (`SupabaseServices+Leaderboard.swift:89–106`). `CompetitionStore.swift:467–470,908–915` then filters those results by evidence while preserving server ranks. A self-reported entry ranked 201 in the mixed result cannot appear, and visible rank numbers describe the wider result. Source-confirmed pipeline limitation, not a reproduced deployed ranking. | Make the displayed rank universe explicit or support the evidence filter and pagination on the server. Preserve server authority; never fix this by inventing client ranks. Test mixed evidence across the page boundary and podium/list agreement. |
| S2 · Medium: save confirmation does not report the separate sharing outcome | Review says selected PRs are submitted when saving, but submission starts in an asynchronous task after workout completion (`WorkoutSessionRunView.swift:179–184`). Saved content contains rewards but no publication status. Failed uploads retain a queue and expose Retry only in Training settings (`SettingsView.swift:208–212`). | On the saved workout, distinguish private workout saved from PR sharing pending, published, or failed; link directly to retry/review. Keep each selected PR's identity and allow users to confirm what actually became public. |
| S3 · Low: public preview cannot answer friend/gym visibility questions | Settings offers Public/Friends/Gym/Private fields, but Preview public profile uses a non-owner visitor and saved public settings (`ProfileView.swift:14–24`; `ProfileViewSections.swift:170–174`). This is a valid public preview, not an audience simulator. | Explain the preview's public-visitor scope, including that unsaved settings have not taken effect. Verify friend, same-gym, stranger, blocked, and owner cases with isolated authenticated identities before adding broader preview claims. |
| S4 · Medium: friend workout activity/stats remain a separate backlog item | Current public profile sections expose eligible shared lifts; private workout history is restricted to the owner (`ProfileViewSections.swift:123–151`). Privacy settings have field audiences and video visibility but no workout-activity opt-in or workout-stat audience. No corresponding workout-start/PR friend activity preference was found in the inspected client. | Keep the approved friend activity/stats features marked incomplete. Implement explicit event/stat scopes and server-enforced audiences before presenting private workout data to friends. Existing friendship and public-lift views do not establish this feature. |

Useful boundaries: ordinary workouts and their backup snapshots are separate from public lift submissions; the reviewed snapshot policy is owner-scoped (`202607180001_public_launch_foundation.sql:224`). Review says an attached video does not mean a lift has been reviewed; ranking controls use Video-backed and Self-reported labels. Saved workout deletion explicitly says linked public lift submissions remain public. Profile settings explain indirect bodyweight inference through relative-strength values. Account guards reject stale history, notification, submission, playback, and ranking responses; profile mapping uses remote card fields rather than seeded private detail.

Verification: **14 selected unit tests passed, 0 failed, 0 skipped** under GPT-6 Luna (8 BackendFoundationTests, 6 RankingCalculatorTests). Covered audience contract, failed privacy-save retry, notification account isolation, remote profile mapping, workout-history/plan ownership and deletion isolation, competition verification/playback/submission account switches, local self-reported exclusion, server-rank preservation, and stale-account leaderboard response protection. Log: `/tmp/liftrivals-supplementary-audit-8-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-14-29--0400.xcresult`.

**Live privacy release gate remains pending:** using disposable staging identities, verify owner/friend/same-gym/stranger/blocked access to profile fields, raw workout snapshots, submissions, and actual media URLs, including after privacy changes and account deletion. Existing SQL matrix tests were inspected but not executed in this stage; the production-named acceptance file contains mutations despite rollback and was not treated as a read-only check. No security-policy change was made, and no privacy vulnerability is claimed from unexecuted cases. Audit 8 is documented; no app/test/server changes were made.

### Audit 9 — Performance with larger histories

Scope: existing synthetic large-data benchmarks, selected demo UI timings, and source paths that may grow with history or network latency. Debug iPhone 17 Pro / iOS 26.5 simulator results are not physical-phone, Release, battery, memory, or server-load measurements. Fixtures range up to 25,000 rows but are not a complete realistic multi-year account: the 5,000-workout fixture has one exercise/one set per workout, while UI fixtures use ordinary seeded demo data.

| Finding | Evidence and impact | Recommended acceptance |
| --- | --- | --- |
| P1 · Medium: leaderboard hydration serializes profile requests | After fetching ranked IDs and submissions, `SupabaseServices+Leaderboard.swift:111–113` awaits a separate profile-card request for each row, up to the 200-row cap. Results return only after the loop; one failed profile lookup throws the entire call. This is a source-confirmed latency/recovery risk, not measured server latency. | Measure with delayed profile responses and the full page. Prefer a server-provided page with the required authorized card fields or bounded hydration through the existing service. Preserve privacy and server ranks, show loading/partial failure deliberately, and avoid unbounded request fan-out. |
| P2 · Medium: background flush can repeat whole-history encoding | Each mounted set row handles `willResignActive` and calls `onPersistImmediately` (`WorkoutSetLogRow.swift:181–184`), which reaches synchronous `persistWorkoutSnapshot`. Scene-phase handling also flushes. `SwiftDataWorkoutPersistenceStore.saveSnapshot` encodes the entire snapshot on the main actor before comparing it with the last payload (`:65–68`). Duplicate disk writes are avoided, but duplicate encoding is not. | Measure resign-active/foreground latency with rich history and several visible rows. Flush pending field edits, then persist once through the existing owner while retaining O1/O2's durability/error requirements. No restructuring is justified solely by a warm-cache benchmark. |
| P3 · Medium: current benchmarks leave the costly boundaries unmeasured | The snapshot performance block measures task enqueue, with the later verification outside the timer and in-memory SwiftData. Several lookup tests prewarm caches. UI-test mode disables repository persistence unless explicitly overridden (`DemoRepository.swift:47–54`). No baseline is configured in the recorded metrics. | Add release verification for cold projections, changed-history invalidation, disk-backed save completion, peak memory, and foreground scrolling on a supported physical phone. Define budgets before using test success as a speed claim. Keep mock network timings separate from actual backend timings. |

Six unit performance cases passed. Values below are means calculated from the three recorded iteration values; each row describes the entire measured batch, not a single call unless stated.

| Measured batch | Fixture / condition | Mean | Recorded iteration range |
| --- | --- | --- | --- |
| Enqueue one snapshot save | 25,000 set logs; in-memory SwiftData; completion checked afterward | 0.0197 ms | 0.017–0.023 ms |
| 50 weekly-summary reads | 25,000 planned sessions; warmed cache | 0.317 ms | 0.313–0.322 ms |
| 50 previous-comparable lookups | 5,000 workouts; cached missing result | 0.060 ms | 0.060–0.060 ms at logged precision |
| 20 calendar projections | 5,000 simple workouts across 1,825 dates; warmed cache | 0.074 ms | 0.072–0.077 ms |
| 50 leaderboard reads | 5,000 profiles and lifts; repeated local calculation/cache path | 0.193 ms | 0.190–0.198 ms |
| 20 option searches | 5,000 options; two-token query | 168.956 ms (about 8.45 ms/search) | 160.835–179.542 ms |

These results support retaining existing revision-based caches and indexed projections. They do not establish cold-start or disk-save performance. Unit log: `/tmp/liftrivals-supplementary-audit-9-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-16-18--0400.xcresult`.

All **3 selected UI performance tests passed**, also under GPT-6 Luna:

| Measured interaction | Iterations | Mean | Range / interpretation |
| --- | --- | --- | --- |
| App-owned restored-launch interval | 5 | 0.569 s | 0.360–0.647 s; 18.6% relative standard deviation; mock restored account, app signpost rather than total icon-to-interactive latency |
| Home swipe to weekly-goal presence | 3 | 2.119 s | 2.095–2.154 s; includes automation gesture, idle synchronization, and element waits |
| Open Progress category controls | 3 | 1.475 s | 1.470–1.478 s; includes tap and element wait; Strength/Muscle/Consistency assertions also pass outside the measured block |

UI log: `/tmp/liftrivals-supplementary-audit-9-ui-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-16-49--0400.xcresult`. These are interaction-test durations, not frame-rate measurements. No configured baseline was reported. Audit 9 is documented with **9 tests passed, 0 failed**; device profiling and richer disk-backed history remain explicit follow-ups. No app/test code changed.

### Supplementary audit disposition

All nine stages were reviewed and documented in order. Audit 5 is an expert walkthrough; participant observation is deferred as requested. Audit 8 uses isolated mock identities; live authorization checks are deferred as requested. Evidence includes source review, inspected simulator screenshots, and **58 focused test executions: 55 passed, 3 failed, 0 skipped**. All three failures belong to audit 1's workout/navigation cases; later passing performance checks do not close that journey gate. This is not a full-suite or release-readiness pass.

Recommended implementation order:

1. **Save reliability and metric correctness:** O1/O2 local errors/durable completion, D1 legacy timed volume, O3 partially unreadable sync history, and W1 truthful save status.
2. **Workout flow:** reproduce audit 1's failed transitions before choosing a fix; address W4 substitution input and U4 final-set completion clarity alongside W2/W3 action hierarchy.
3. **Accessible, calmer screens:** X1–X6 text/input/contrast issues, U1–U5 first-use labels and destinations, and G3/G4 reward/goal emphasis. Keep optional accents and Light/Dark/System behavior.
4. **Reward and notification correctness:** G1/G2 shared eligibility rules, N1–N3 destination/cancellation/alert feedback, and S2 publication progress/retry at the saved workout.
5. **Remaining feature and release work:** S1 authoritative evidence-filtered rankings; N4/S4 accountability and friend activity/stat scopes; P1–P3 measured performance follow-up; independent-user, live privacy, accessibility-assistive-technology, and physical-device checks.

This audit added findings only to this existing document. No application fixes, test edits, new repository files, abstractions, dependencies, remote migrations, or real-account writes were introduced. Temporary logs/screenshots/result bundles are evidence artifacts outside the source tree. The user's original simulator and draft were preserved.

### Implementation follow-up — October 31, 2026

Historical October 31 checkpoint for the original 38 findings. These rows retain the evidence and verification gaps recorded at that time; later results below and the November 1 “Earlier 38 partials reconciled for this pass” section supersede outdated build/test notes and presentation details.

| Finding | Current change and evidence | Remaining verification |
| --- | --- | --- |
| W1 | Review copy now says the workout will be saved to private history. The saved screen distinguishes on-device, waiting, syncing, attention, and account-synced states; a failed completion save stays on review with an error. Debug build and focused completion-failure test passed. | Inspect each rendered state in the isolated simulator, including a failed upload; verify assistive labels. |
| D1 | `CompletedWorkout.totalVolume(in:catalog:)` now uses the same full exercise catalog for legacy type resolution across weekly/recap, Home last workout, completed detail, plan review, and summary comparisons. Removed the catalog-free completed-workout shortcut. The expanded mixed-unit/custom-timed regression and two related volume tests passed, 3/3. | Confirm rendered Home/detail values with an affected saved fixture; no user record was changed. |
| D2 — partial | Library now labels its Latest chart as including completed working sets from recovery/deload workouts; Progress's exercise trend says it excludes those workouts. Source tracing confirms Library history uses all completed working sets and Progress filters known recovery workouts before calculating the trend. No estimate was changed. | Compile and inspect both headlines with the same recovery fixture; verify period dates, best/Latest labels, and assistive reading order. |
| D3 | Active exercise metric now names volume and formats the value as weight × reps with grouping and up to one decimal. Debug build and existing set-entry keyboard test passed. | Inspect the rendered compact metric at standard and large text sizes. |
| D4 — partial | CSV export copy now explains one row per set, repeated workout duration, grouping by workout ID, and UTC versus local-day totals. | Build and inspect export details at standard and large text; reconcile a saved local-day period against the exported rows. |
| W4 — partial | Substitution now clears unfinished weight/reps/effort after confirmation when partial values exist; completed sets remain intact. Cross-kind substitutions use the replacement's target reps and drop the previous exercise's load/percentage targets. A focused weighted-to-timed regression passed 1/1, including completed-set preservation. | Inspect the confirmation and cancel paths in the isolated simulator; verify the no-completed-set branch with partial input. |
| W2 — partial | Exercise guidance, progression explanation, adaptive-rest setting, metrics, and history/detail actions now sit behind a collapsed “Guidance and options” control; specific substitutions are also collapsed. A focused standard-text UI run found the first editable set row and keyboard; the latest three-case rerun passed the weight-first navigation sequence after focus handling changed. | Inspect actual screenshot positioning and accessibility text sizes; confirm guidance remains easy to find. |
| W3 — partial | Tracker Today hides Start freestyle when an active workout is present. The empty-workout Finish action is visually secondary and says “End empty workout”; incomplete sessions say “Review to finish” before opening the existing explicit review. Home Resume now presents through the app router. Focused empty-workout and direct Resume flows passed; incomplete review passed in the preceding run. | Inspect ready-state wording and repeated cold launches; confirm the Home route remains stable outside test fixtures. |
| X1 — partial | A rendered iPhone 17e screenshot showed that a two-column, three-row bar consumed too much screen height at accessibility XXXL despite passing hit-target checks. The revised accessibility layout is a compact native tab menu that names the current tab and marks it selected; standard text sizes retain the familiar single row. The Dynamic Type cap was removed. | Build and inspect the compact menu on a small phone at largest text; navigate every tab, verify content remains reachable and VoiceOver announces the current destination and menu choices. |
| X2 — partial | Completed set numbers and checkmarks now use a semantic foreground that is white on Light-mode green and dark on Dark-mode green, replacing the low-contrast dark-on-dark-green pair. The current solid-token pairs calculate to 5.77:1 Light and 13.06:1 Dark (WCAG sRGB). | Inspect the rendered controls in Light/Dark and increased contrast on the simulator; opacity/composited surfaces are separate. |
| X3 — partial | Weight, assistance, repetition, and duration entry fields now announce their set number and unit or measure in accessibility labels. The native text field retains its editable value. | Verify VoiceOver order and editing on repeated set rows; check completion state is announced through its separate control. |
| X4 — partial | Set weights now parse strict decimal values using the current locale, reject non-finite/negative input, and format entered/copied weights with the same locale (up to six decimal places). A Foundation probe confirmed the parser basis rejects trailing junk and distinguishes en_US from fr_FR separators. | Focused app-parser tests and a comma-decimal keyboard/paste check under a comma locale remain pending; confirm an invalid value cannot complete a set. |
| X5 — partial | The muscle-signal legend now uses swatches matching the orange and selected accent bars and names the score ranges without hard-coding “Lime.” The unavailable next-recap arrow now uses muted text styling. | Inspect every accent plus Light/Dark and large-text rendering; verify the disabled arrow remains understandable with VoiceOver. |
| X6 — partial | Enabled previous-values buttons and compact metric chips now use an opaque raised-card surface instead of a dark translucent scrim; disabled previous-values buttons use the lighter card surface. Metric text uses the stronger primary text color. Calculated minima: accent-on-raised 4.65:1 Light / 8.37:1 Dark; primary-on-raised 13.00:1 Light / 15.48:1 Dark; muted-on-card 5.03:1 Light / 6.24:1 Dark. | Inspect completed-row chips at standard text size and increased contrast; opacity blends elsewhere are outside this finding. |
| G1/G2 — partial | The saved workout now compares actual repository achievement unlocks before and after the successful save, so its badge preview uses the same eligibility rules as Awards, including non-weighted repetitions and categories omitted by the old projection. The duplicate milestone projection was removed. Next-achievement progress reads saved statistics rather than adding the workout twice. A focused AppState completion regression passed for a bodyweight set crossing 1,000 Reps and 15 Workouts, excluding prior unlocks. | Add streak and first-PR regressions; inspect the saved screen when simulator service is available. |
| G3 — partial | The saved-screen preview now shows at most one workout highlight and one badge when both exist (or two badges without a highlight), plus one next-progress card. Further earned badges remain in the existing achievements expansion/history. | Inspect a multi-PR, multi-award completion in the simulator to confirm the result hierarchy and expansion. |
| G4 — partial | The weekly-goal menu now explains that workout streaks always use three training days per week; changing a personal goal does not change historical streak calculations. | Inspect the menu and compare a two-day goal with the three-day streak message in the simulator. |
| N2 — partial | Rest-alert scheduling now increments a protected revision on replacement/cancel. Delayed notification-settings and permission callbacks check that revision before adding a request; replacement removes the old pending request. | Fault-inject delayed callbacks and concurrent extensions/cancel against a controllable notification center, then verify only the latest timer can alert on a signed device. |
| N1 — partial | APNs taps now decode the existing `destination` payload and route through the inbox's typed destination rules. A pending tap survives cold launch/account restoration within the process; local workout-day and rest-alert taps use the same path. Rest alerts open the active session when it still exists, otherwise Today. New push payloads include `recipient_id`, and the app discards a pending destination if it belongs to another signed-in profile. The default Home selection now happens before sign-in completes so it cannot overwrite a pending route. Uncached profile/gym destinations now resolve through the existing services with an "Opening notification…" indicator before showing an unavailable message; an account switch or newer destination cancels/invalidates the prior lookup. Unsupported or missing destinations show an unavailable message. The sender code has not been deployed. | Compile and test typed payloads, cold launch/auth restoration, cached/uncached destinations, account mismatch and switching during lookup, unavailable targets, and rest-alert fallback; verify live banner taps on a release-signed device after deploying the sender. Check server-side notification availability and the final destination against isolated staging accounts. |
| N3 — partial | The rest scheduler now reports checking, scheduled, quiet, blocked, and add-request failure states. The visible timer names the background-alert state and offers an iOS Settings recovery button when blocked/failed; restoring a live timer or returning from Settings re-schedules its alert. Foreground rest sound is handled by the notification delegate across exercise/overview screens, without also requesting system foreground sound. The visible timer delays cancellation briefly at expiry; if no background alert is scheduled, it uses a local sound fallback. | Compile and fault-test denied permission, add errors, extensions, Skip, and restore. Check foreground/background delivery, music mixing, exact sound count, and tappable destination on a signed device. |
| N4 — partial | Workout-day and missed-workout reminders now have separate, default-off account-scoped preferences; the former no longer reads a device-global opt-in that another account could inherit. Local missed alerts are scheduled for the next day at the chosen time only for currently unfinished, dated active-plan sessions with exercises; both alert types share the 48-request limit and open Today. Changes to completion/plan state refresh and cancel pending requests. Settings shows each event's next eligible alert or why none is available. These are the supported accountability events; remote missed-workout push and any additional event types remain release/backlog decisions. The old device-global workout-day opt-in is intentionally not transferred because its account owner cannot be established. | Compile and test opt-in/off, next-day date/DST, shared cap, completion cancellation, inactive/queue/no-exercise exclusions, and alert tap on a signed device. Verify account switching cannot inherit either opt-in and confirm existing users understand that workout-day alerts must be enabled again. |
| P1 — partial | Leaderboard profile-card hydration now deduplicates ranked user IDs and loads them in batches of eight concurrent requests through the existing profile service. Rows are still assembled in server rank order; a failed card request surfaces the existing results-unavailable error rather than silently producing a partial ranking. No server rank or privacy mapping was changed. | Compile and measure a delayed 200-row page, verify at most eight concurrent card calls, confirm full-page rank/podium agreement and an explicit error on one failed card, then compare with a server-provided authorized page before claiming the latency issue closed. |
| P2 — partial | A set row now requests its immediate background snapshot save only when its draft differs from the last persisted draft. The repository records observed changes and the revision of each successful save; the app-level scene-phase flush skips a snapshot already saved by an edited row, while retrying failed saves. Unchanged rows and repeated inactive/background transitions therefore avoid whole-history encoding. | Run the focused revision/retry test and measure resign-active latency and encoding count with several visible rows and rich disk-backed history. Confirm pending field edits and O1/O2 completion recovery still survive suspension and process restart. |
| P3 — partial | The existing 25,000-set in-memory benchmark is now named for what it measures: background task enqueue. A separate benchmark creates a temporary disk-backed SwiftData store with 80 completed workouts, 320 exercise snapshots, and 2,000 sets; it measures three changed-history synchronous saves and fresh-container reloads and checks the stored history. | Run the benchmark on an available simulator, then establish release budgets and measure physical-phone cold projections, true cold storage reads, peak memory, and foreground scrolling. Fresh containers do not clear the OS page cache; this benchmark alone cannot establish cold-load or production speed. |
| N5 — partial | Notification settings now show the next eligible dated workout reminder, or explain why queue-based/inactive plans and plans without unfinished exercises have none. The rescheduling description names the existing same-week, free-day limit. The preview and scheduler share the same eligibility filter. After a successful suggested move, Today confirms the new date and offers View in Plans; dated Plans cards show the scheduled calendar date. | Compile and inspect settings with dated, queue, inactive, completed, and no-exercise plans; verify notification permission failures still read clearly and inspect the move confirmation and resulting date in Plans. |
| S2 — partial | The saved workout now lists each selected PR by lift and set, reads its actual submission queue state, offers Retry for failed submissions, and links directly to lift submissions for review. Selected candidate identities are captured before completing the workout clears the draft. The workout save status stays separate from ranking submission status. | Compile and inspect the saved state through pending, failed, and submitted transitions; confirm the review destination and that submitted does not imply verified or public. |
| S1 — partial | A forward-only local migration adds a server-ranked Self-reported query that filters public, eligible self-reported lifts before selecting each athlete's best lift and assigning ranks. The iOS service uses it for Self-reported, retains the existing server query for Video-backed/All, and labels the 200-row cap as a top-200 self-reported board. Existing client evidence filtering remains a consistency check; rank authority stays on the server. The migration has not been applied remotely. Isolated PostgreSQL runtime tests passed 15/15 assertions on each of two clean resets, including mixed rank 202 appearing at self-reported rank 1; the iOS client compiled. | Confirm the target staging environment and migration ledger before deployment, then inspect all evidence views at standard/large text and verify podium/list agreement and rank 201+ with isolated staging accounts. No production migration is authorized by this follow-up. |
| S3 — partial | Settings now explains that Public preview shows a public visitor's view based on saved settings, and that friends or gym members may see more. The existing preview already uses a non-owner identity. | Inspect the preview before and after saving privacy changes; live owner/friend/gym/stranger/blocked checks remain pending with isolated staging identities. |
| S4 — partial | Added a default-Private workout-stat audience and separate default-off friend workout-start/top-lift choices to the existing atomic profile save. A server-enforced aggregate query gates workout counts/latest date by profile visibility, field audience, and blocks; a public-profile card labels those values self-reported. New server-owned activity records use authoritative timestamps and return only to accepted, unblocked friends while current profile/event/lift visibility permits. The Forum has a friend activity destination, workout/lift actions publish through the service, and failures surface a Retry banner. Pending activity now enters the existing account-scoped local snapshot before publication and is retried after sign-in, legal acceptance, foreground return, or a disconnected-to-connected network transition; the server deduplicates requests by owner, event type, and source ID. Backdated workout starts do not broadcast. Raw workout snapshots remain owner-only; the forward stat migration adds explicit owner-sync CRUD grants under existing RLS. The client checks sharing readback so an older server cannot silently claim success. Neither migration has been applied remotely. | Compile and inspect the stat card/feed at standard/large text, run focused queue recovery/client tests, and verify actual owner/friend/gym/stranger/blocked behavior with isolated staging accounts after confirmed migration rollout. Check offline retry and network transitions, account switching, privacy revocation, top-lift wording, and live destinations. Keep self-reported activity distinct from verified competition results. |
| U1 — partial | Successful email and Apple sign-in now select Home rather than Rankings. When no session is scheduled, Home's training card says “Start a workout” and opens Track Today, where freestyle remains optional. | Compile and inspect fresh signed-in/no-plan and rest-day routes in isolated fixtures; no real account sign-in has been attempted. |
| U2 — partial | Percentage setup now has an explicit “I don't know my max” action that selects the existing Fixed Sets + Reps method and explains that weight is chosen while logging; no training max is invented. | Compile and inspect a percentage template without history; confirm setup can start and the method/target explanation matches the resulting plan. |
| U3 — partial | Progress's empty Strength goal now explains estimated one-rep max as a calculated personal strength estimate, separate from today's load. Active exercise guidance labels “Today's sets” and “Suggested load”; Home already labels weekly training days. | Inspect first-use Home, Strength, and workout screens together at standard and large text; check the distinction is clear without crowding the logger. |
| U4 — partial | After the final keyboard Next/Done, an unfinished last set now gets a short visible instruction to tap its completion circle; the same line explains that moving on can complete earlier valid sets. It disappears after the final set completes or a new set is added. Prefilled values do not auto-complete the final set. | Compile and verify the final-set prompt, completion, and invalid/empty inputs in the isolated simulator at standard and large text. |
| U5 — partial | Today names the separate ranking action “Submit lift for rankings” and its accessibility hint distinguishes it from private workout logging. Me's Your training section now has a plainly named “Workout history” route before lift submissions. | Compile and inspect Today/Me navigation, privacy wording in submission, and private history destination at standard and large text. |
| O1 | An unreadable on-device snapshot retains its original payload and opens the existing recovery screen. Snapshot encode/fetch/save failures now propagate through the storage boundary; the repository exposes a retryable error, and a failed completion save restores the draft. The storage context is isolated so rollback cannot discard other app edits. Four focused storage/repository/completion tests passed. | Verify recovery and retry UI in the simulator; fault-inject a SwiftData disk-save failure, not only a throwing storage fake. |
| O2 — partial | Completion now records an authenticated upload intent in the same synchronous local snapshot before showing “Workout saved.” If encoding or local persistence fails, it restores the active workout, sets, completed list, deletion/upload queues, and achievement state, then shows an error. A failed-save rollback regression passed. | Kill the isolated app at completion boundaries, relaunch, and verify exactly one completion and its upload intent. Check save latency with rich disk-backed history and a signed staging account before closing this finding. |
| O3 | Owned remote workouts that cannot decode now increment an unavailable count and keep sync in Needs attention. Home and Progress show that count; corrected data clears it on retry. A valid-plus-invalid owned snapshot regression passed. | Verify the rendered status and retry destination with isolated authenticated fixtures. |

Verification: GPT-6 Luna built the Debug simulator app (staging backend, `Sign to Run Locally`) and ran 7 earlier summary/formatting unit tests plus 1 set-entry UI test successfully. After D1 cleanup, 3 focused volume tests passed. The initially attempted mixed no-build test invocation could not load the unit-test bundle; it was replaced by a successful `xcodebuild test` run. Logs: `/tmp/liftrivals-workout-changes-build.log`, `/tmp/liftrivals-workout-changes-unit-tests.log`, `/tmp/liftrivals-d1-final-cleanup-tests.log`; final result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-33-51--0400.xcresult`. No new repository files, abstractions, or dependencies were added. The original simulator and draft remain untouched.

Follow-up verification: GPT-6 Luna built the latest Debug app/test targets and passed 2 focused BackendFoundationTests for O3 partial remote history and O1 unreadable local storage. Log: `/tmp/liftrivals-o3-o1-regressions-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-40-01--0400.xcresult`. No new file, dependency, or remote database change was added. The new `loadError` property on the existing storage protocol is needed to distinguish absent data from unreadable data without resetting the stored payload.

Save-path verification: GPT-6 Luna built the latest Debug app for the isolated simulator (staging backend, `Sign to Run Locally`) and passed 4/4 focused tests covering repository save-error reporting, completion draft rollback, legacy snapshot handling, and unreadable/absent snapshots. Log: `/tmp/liftrivals-o1-write-error-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_18-45-42--0400.xcresult`. The storage protocol's throwing save methods and the repository's reported save result are required so completion can gate its success state on a durable local write. No new source file, dependency, or remote database change was added.

Process-restart verification attempted the existing isolated demo UI test with snapshot persistence enabled. The app built, but Resume stayed on Home, matching audit 1's open navigation failure; the test never reached completion or relaunch. Log: `/tmp/liftrivals-o2-process-restart-tests.log`. This result does not validate or disprove completion durability. No simulator data was erased, and authenticated upload-intent restoration remains pending.

Latest W4/D4 Debug simulator build succeeded under GPT-6 Luna with local signing; `git diff --check` passed. Log: `/tmp/liftrivals-w4-d4-latest-build.log`. No new source file, abstraction, dependency, or remote database change was added for W4/D4.

W4 follow-up: GPT-6 Luna passed `testSubstitutingWeightedExerciseToTimedClearsDraftAndPreservesCompletedSet` (1/1) on the isolated Debug simulator build. Log: `/tmp/liftrivals-w4-substitution-test.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_19-02-16--0400.xcresult`. The rendered confirmation/cancel check is still open.

W2/W3 runtime attempt: the latest source compiled and the app/UI-test runner signed locally, but CoreSimulatorService refused connections before XCTest began. The focused run exited with code 75 and one canceled test, with no workout assertion reached. The isolated simulator was not reset or erased. Log: `/tmp/liftrivals-w3-w2-focused-ui-tests.log`. Rendered first-set visibility and Resume navigation remain open; the W2/W3 code changes are not yet runtime-verified.

Accessibility follow-up: X2/X3/X4/X5/X6 source changes compile in the latest generic Debug simulator app build, signed `Sign to Run Locally`. The X4 locale parser XCTest also compiled in the test bundle but did not run. CoreSimulatorService refused connections, so both focused UI attempts canceled before test bodies; no assertions passed or failed in those invocations. Final app build: `/tmp/liftrivals-w3-w2-x6-final-latest-build.log`; test-bundle build: `/tmp/liftrivals-w3-w2-x4-build-for-testing.log`; canceled-run result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_19-07-47--0400.xcresult`. No simulator data was reset. Color checks used current solid token values and do not substitute for rendered accessibility inspection. No new source file or dependency was introduced; `liftOnGreen` is a reused semantic color token for the two completed-set controls, and `parseWeight` remains within the existing set-row view so the locale behavior can be unit-tested.

Reward follow-up: GPT-6 Luna built the Debug app/test bundle and passed 1/1 focused AppState completion regression covering a bodyweight-repetition threshold, the previously omitted 15-workout threshold, and exclusion of existing unlocks. Log: `/tmp/liftrivals-g1-g3-focused-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_19-19-05--0400.xcresult`. The isolated simulator recovered enough for this unit test; rendered reward UI and other award categories remain unverified. No new source file, dependency, or remote change was added.

N2 compile check: GPT-6 Luna's latest generic Debug `build-for-testing` passed for both simulator architectures and included the rest-scheduler revision guard; log `/tmp/liftrivals-g1-g3-n2-build-for-testing.log`. Delayed-callback behavior and device alerts remain unverified.

Focused workflow follow-up: 5 selected checks executed on the isolated simulator, **3 passed and 2 failed**. The locale parser unit test, direct Home Resume, and incomplete planned-session “Review to finish” path passed. Empty-workout ending failed before reaching the session because the first Resume tap left Home visible. Standard-text set entry showed the first editable row and keyboard, then failed after repeated hide/refocus cycles because Next left the weight field focused instead of repetitions. Log: `/tmp/liftrivals-g1-g3-w2w3-x4-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_19-21-01--0400.xcresult`. To address those observed transitions, Home's workout cover is now attached to the stable HomeView body, and same-row keyboard advancement is deferred until the toolbar tap completes. Both fixes require a focused rerun; neither failure is marked closed. No simulator data was erased.

The first rerun reached “End empty workout” from Home and direct Home Resume passed, but the empty confirmation did not appear and the set-entry case again remained on Home before the keyboard step. Log: `/tmp/liftrivals-two-fixes-ui-tests.log`. This contradicts a simple label-only or keyboard-only explanation. Home Resume now uses the existing root AppRouter cover instead of local Home state; its stability, empty confirmation, and keyboard progression require another focused run. U1–U3 first-use copy/routing changes were made after this UI build and require compilation/rendered checks.

Router follow-up: GPT-6 Luna reran three isolated UI cases after moving Home Resume to the app router and deferring same-row keyboard focus. **3/3 passed**: empty workout End/confirm/return Home, direct Home Resume, and weight-first set entry across rows through final keyboard dismissal. Log: `/tmp/liftrivals-router-fix-ui-tests.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_19-28-51--0400.xcresult`. The success covers those mock/demo paths, not the full signed-in journey or every interrupted launch. No simulator data was erased.

Final-set follow-up: GPT-6 Luna passed the corrected focused set-entry UI test **1/1**, including weight-first keyboard movement, final Done dismissal, and the unfinished-final-set instruction. The test locator was updated to use the current workout exercise button after Home Resume moved to the app router. Log: `/tmp/liftrivals-s2-u4-u5-focused-ui.log`; result: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_19-35-36--0400.xcresult`. This covers the isolated standard-text route; large text, invalid inputs, and real-account flows remain pending. The final S2 copy and N5 reminder edits occurred after that build and require the subsequent app-only compile.

Latest compile: GPT-6 Luna built the Debug simulator app after the S2 copy and N5 reminder edits, including `WorkoutSummaryView.swift`, `SettingsView.swift`, and `AppState+TrainingPlans.swift`; `git diff --check` passed. Log: `/tmp/liftrivals-final-u1-u5-s2-build.log`; artifact: `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Build/Products/Debug-iphonesimulator/LiftRank.app`, signed `Sign to Run Locally`. This is a compile check, not a real-account session check. No new source file, abstraction, dependency, or remote database change was added for S2 or N5; the shared reminder eligibility method prevents the Settings preview from disagreeing with scheduling rules.

S3 copy compile: GPT-6 Luna rebuilt the Debug simulator app with the public-visitor preview explanation; log `/tmp/liftrivals-s3-settings-copy-build.log`. No staging-account privacy checks were made. No new source file, abstraction, dependency, or remote database change was added.

D2 first UI attempt: the Progress exercise-trend navigation case passed and reached its estimated-1RM empty state, but it did not assert the new recovery/deload caption. The Library-detail case failed before Library: after a Track tap, the test waited for a legacy `Library` button while the hierarchy still showed Home. Neither case proves the side-by-side inclusion wording. The focused test is being evaluated separately from the source change; no chart calculation was changed.

X1 small-phone attempt: the two-column floating tab bar compiled and the existing XXXL navigation audit passed its first assertions that all five tabs were visible and inside the iPhone 17e viewport. It later failed while looking for a Home bodyweight quick action after 16 scroll attempts; that action was absent from the failure hierarchy, so downstream navigation/content reachability was not evaluated. Log `/tmp/liftrivals-x1-iphone17e-navigation.log`; result `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_19-45-13--0400.xcresult`. A later focused navigation test passed 5/5 tab destinations and content controls, but its screenshot (`/tmp/liftrivals-x1-d2-attachments/BA402B8B-EE54-4A52-8C6A-9A4D9679DFD5.png`) showed the bar dominated the lower half of the screen. That visual evidence led to the compact menu revision; the passed grid test no longer validates the current layout.

D2 focused follow-up: the Library chart case passed with its recovery/deload inclusion caption visible. The Progress case failed before selecting Bench Press: the exercise picker remained open, and the underlying trend still showed the previously selected exercise. Its caption existed beneath the sheet but was not visually verified. The batch was 2/3 passed (Library and the now-superseded X1 grid navigation case), log `/tmp/liftrivals-x1-d2-final-focused-ui-rerun.log`, result `/Users/robertjeanty/Library/Developer/Xcode/DerivedData/LiftRank-bouyeojmudkzsgcptldnlwqqvpvd/Logs/Test/Test-LiftRank-2026.10.31_19-51-32--0400.xcresult`. No arithmetic or filtering changed.

X1 compact-menu follow-up: GPT-6 Luna compiled the revised app/test sources. The first iPhone 17e XXXL run found all five native menu choices with the expected labels and navigated to Track and Me content. Its `.value` assertions for individual menu choices failed because XCTest returned an empty value; the root menu still announced the current tab. A subsequent run using the selected accessibility trait found the menu choices but did not switch from Home after tapping Track, leaving its content assertions failed. A corrected type-agnostic root-menu locator rebuilt successfully, but CoreSimulator died before XCTest launched, so that last version has no runtime result. Logs: `/tmp/liftrivals-x1-menu-17e.log`, `/tmp/liftrivals-x1-menu-elevated.log`, `/tmp/liftrivals-x1-menu-retry2.log`. Native selected-state and repeatable switching remain unverified. No simulator was erased or reset, and no new source file or dependency was added.

N1 compile follow-up: GPT-6 Luna's incremental generic Debug `build-for-testing` succeeded after the notification routing, rest destination, and sign-in ordering edits. Log `/tmp/liftrivals-n1-tests-build-final.log`; the app and test bundle are in the existing Debug simulator DerivedData. A focused test was added to the existing BackendFoundationTests for recipient/payload decoding and typed NotificationStore routing, and the unknown-kind expectation now checks `.unsupported`; the test bundle compiled but did not run because CoreSimulatorService still refused connections. There is no claim of live push, cold-launch, recipient mismatch, or device routing verification. No new source file, abstraction, dependency, remote migration, sender deployment, or real-account action was made. The AppState routing method and pending delegate value reuse the inbox route semantics and app lifecycle; they are current responsibilities rather than a new service.

N3 compile follow-up: GPT-6 Luna's latest generic Debug `build-for-testing` succeeded with the rest-status scheduler, recovery link, scene-active rescheduling, and foreground-sound changes; log `/tmp/liftrivals-n3-build.log`. CoreSimulatorService still refused connections (`simdiskimaged` unavailable), so the existing rest lifecycle/cleanup tests and all notification delivery checks did not run. No notification was sent. The `WorkoutRestAlertStatus` enum and existing scheduler's `ObservableObject` status are needed to distinguish a running timer from confirmed/blocked/failed background scheduling in the current exercise view; no new file, dependency, or remote change was added.

N4 compile follow-up: GPT-6 Luna's generic Debug `build-for-testing` succeeded after the opt-in local missed-workout changes; log `/tmp/liftrivals-n4-tests-build.log`. It added a focused test in the existing RankingCalculatorTests for day-only/missed-only scheduling, next local day across spring DST, combined date order, 48-request cap, invalid times, and legacy preference decoding. The bundle compiled but CoreSimulatorService still refused connections, so none of those assertions ran and no notification was sent. No new source file, dependency, database migration, or remote sender deployment was added. The shared upcoming-reminders calculation is used by both scheduling and Settings previews to keep them consistent.

N4 account-scope compile: the preference setter now checks the current repository profile before applying opt-in, so a direct setter call after account switching cannot write the previous account's queue state. GPT-6 Luna's incremental Debug app build compiled that final edit for both simulator architectures; log `/tmp/liftrivals-n4-account-guard-build.log`. Runtime account-switch and scheduled-delivery checks remain pending.

P1 compile follow-up: GPT-6 Luna compiled the bounded profile-card hydration service for both simulator architectures with no Swift concurrency errors; logs `/tmp/liftrivals-p1-build.log` and `/tmp/liftrivals-p1-final-build.log`. No remote leaderboard query or delayed 200-row test ran; the current concrete Supabase service has no injectable profile-fetch seam, and a synthetic test of only the batch loop would not verify network or privacy behavior. A card failure still reaches the existing explicit Results unavailable/Retry view. No new file, abstraction, dependency, migration, or remote change was added.

S1 compile follow-up: GPT-6 Luna's generic Debug `build-for-testing` compiled both `LeaderboardsLogic.swift` and `LeaderboardsViewSections.swift` for simulator architectures; log `/tmp/liftrivals-s1-build.log`. CoreSimulatorService still refused connections, so the self-reported note, empty state, podium/list agreement, and rank-201 example were not observed at runtime. No SQL, RLS, server rank, dependency, or remote project changed; the additional computed message is shared by the visible note and empty state.

S1 server-ranking follow-up: GPT-6 Luna ran the full isolated backend harness with the new `202610310002_self_reported_rankings.test.sql`; all 15 focused runtime assertions passed on each of two clean resets, including authenticated-only function execute, fixed `pg_catalog` search path, privacy/moderation/block exclusions, and a self-reported lift ranked 202 in mixed evidence but 1 in its own board. Log `/tmp/liftrivals-s1-selfreported-sql.log`. The harness used a temporary `/tmp` copy of the older location seed migration with a schema-tolerant conflict clause; the tracked already-applied migration was untouched. The generic Debug simulator build compiled the new client RPC choice for both architectures; log `/tmp/liftrivals-s1-selfreported-ios-build.log`. No remote migration, account sign-in, simulator install, or live ranking check occurred. The two new files are necessary for the forward-only server query and its required runtime SQL security tests; no new client abstraction or dependency was added.

P2 initial compile follow-up: GPT-6 Luna's generic Debug simulator build compiled the unchanged-row guard in `WorkoutSetLogRow.swift` for arm64 and x86_64 with `Sign to Run Locally`; log `/tmp/liftrivals-p2-build.log`. `git diff --check` passed. The repository revision gate was added after this build and needs its own compile and focused test. No simulator latency or encoding count has been measured. No new source file, dependency, or remote change was added.

P2 revision-gate follow-up: GPT-6 Luna compiled the final repository/view/app changes and the focused regression test for both simulator architectures; log `/tmp/liftrivals-snapshot-flush-build-final.log`. The test checks repeated unchanged flushes, one save after a preference mutation, and retry after a simulated write failure. It did not execute: the isolated iPhone 17e simulator service hub was unavailable before any case started (`/tmp/liftrivals-snapshot-flush-test.log`), and the stalled runner was stopped without resetting data. `git diff --check` passed. The new repository revision integers and `persistWorkoutSnapshotIfChanged` entry point are needed to skip duplicate encoding while preserving immediate save and retry paths; no new file, dependency, or remote change was added.

P3 benchmark compile follow-up: GPT-6 Luna compiled the renamed enqueue benchmark and new disk-backed save/reload benchmark for arm64 and x86_64; log `/tmp/liftrivals-p3-benchmark-build.log`. `simctl list devices` still reported CoreSimulatorService connection refused, so no benchmark values were collected. The measured save block also includes a small log/workout mutation and an assertion; it is a whole changed-history save path, not a pure encoding microbenchmark. No new file, abstraction, dependency, remote migration, or user account was added.

S4 workout-stat follow-up: GPT-6 Luna ran the isolated backend harness with `202610310004_shared_workout_stats.test.sql`; all 26 runtime assertions passed on each of two clean resets. They cover default Private, owner/friend/gym/stranger/blocked audiences, profile visibility, count/recent/latest aggregates, owner raw snapshot read/update, non-owner raw read/write denial, and atomic valid/invalid privacy saves. The first run exposed a missing authenticated table grant on `completed_workout_snapshots`; the new forward migration now adds the owner-sync CRUD grant under the unchanged owner-only RLS policy, and the final tests pass without a test-only grant. The harness used a `/tmp` copy of the older location seed migration for its known conflict; the tracked migration was untouched. SQL log `/tmp/liftrivals-s4-sql-tests-final.log`. Generic Debug app and test-bundle builds passed in isolated derived data (`/tmp/liftrivals-s4-workout-stats-ios-build-final.log`, `/tmp/liftrivals-s4-workout-stats-test-build.log`); the new legacy privacy decoding regression compiled but did not run because no simulator was launched. No remote migration, account sign-in, or live privacy/UI check occurred. The new migration and SQL test are required for a server-enforced aggregate privacy boundary; `SharedWorkoutStats` and its service method carry that specific result through the existing service architecture. No dependency was added.

S4 friend-activity follow-up: GPT-6 Luna ran `202610310006_friend_training_activity.test.sql` through the isolated backend harness; all 38 runtime assertions passed on each of two clean resets. They cover default-off choices, atomic profile save, authenticated-only RPC access, expected-owner mismatch, idempotent starts, source-owned top-lift eligibility, server timestamps, accepted-friend visibility, stranger/block/privacy revocation, moderation/visibility revocation, and direct-table denial. SQL log `/tmp/liftrivals-s5-friend-activity-tests.log`. The new event migration and SQL test are necessary for server-owned, audience-checked activity; the `FriendTrainingActivity` value and three service operations connect it to the existing profile service. The generic Debug app/test bundle initially compiled (`/tmp/liftrivals-s5-friend-activity-test-build.log`); final auto/selected workout-PR hooks and a profile-unavailable message were added afterward and need the incremental compile. CoreSimulatorService refused connections, so no live feed, delivery/retry, accessibility, or Swift runtime check was run. No remote migration or account action occurred. In-memory publish retry is not process durable and remains an explicit follow-up before treating activity delivery as reliable.

S4 final source compile: GPT-6 Luna's incremental generic Debug `build-for-testing` passed after the workout-PR and Forum destination edits, compiling `AppState+ActiveWorkout.swift` and `ForumViews.swift` for arm64 and x86_64; log `/tmp/liftrivals-s5-final-hook-test-build.log`. `git diff --check` passed. The client bundle was not installed or exercised, and the two forward migrations remain local only.

S4 durable retry follow-up: Pending friend activity is saved in the existing account-scoped workout snapshot before publication and retried after sign-in, legal acceptance, or return to the foreground. A concurrent retry now checks that its item is still queued after the network response before changing queue/error state. GPT-6 Luna's generic Debug `build-for-testing` passed for arm64 and x86_64, including the focused queue recovery tests, and `git diff --check` passed; log `/tmp/liftrivals-s4-queue-guards-test-build.log`. CoreSimulatorService still refused connections, so those tests did not execute. No migration was deployed or simulator data reset. A later source edit added a network-path watcher for disconnected-to-connected retry; that edit has not been compiled or exercised because the user deferred tests.

Implementation pass after test deferral: N5 now confirms a successful move with its calendar date, links to Plans, and shows that date on the dated session card. N4 now keeps both workout-day and missed-workout opt-ins in the existing account-scoped workout preferences; the previous device-global workout-day opt-in is not transferred between accounts. GPT-6 Luna's compilation-only generic Debug `build-for-testing` passed for arm64 and x86_64, including the S4 network watcher and N4/N5 edits; `git diff --check` passed. Log `/tmp/liftrivals-nw-reconnect-test-build.log`; app artifact `/tmp/liftrivals-s4-derived/Build/Products/Debug-iphonesimulator/LiftRank.app`. No XCTest case ran. Simulator inspection, live-account checks, and signed-device delivery remain deferred at the user's request; no remote migration or notification sender was deployed.

N1 destination implementation follow-up: A notification for a profile or gym absent from the local directory now fetches it through the existing service before reporting it unavailable. A newer destination cancels the prior lookup, and account changes prevent stale navigation. GPT-6 Luna's compile-only generic Debug `build-for-testing` succeeded; log `/tmp/liftrivals-n1-destination-lookup-build.log`. `git diff --check` passed. No XCTest or simulator action ran, and the push sender remains undeployed.

N1 loading follow-up: The top safe area now displays "Opening notification…" during an uncached profile/gym lookup. GPT-6 Luna's compile-only generic Debug `build-for-testing` passed for arm64 and x86_64 after a cache-access retry; log `/tmp/liftrivals-n1-loading-indicator-build.log`. `git diff --check` passed. No XCTest, simulator action, or remote sender deployment occurred.

Deferred-test run: At the user's request, GPT-6 Luna attempted the focused iOS runtime checks. CoreSimulatorService still refused `simctl` connections and had no isolated launchctl service job to restart while Simulator.app remained active, so no XCTest case started and no simulator was reset. The latest generic Debug app/test bundle compiled (`/tmp/liftrivals-deferred-ios-build-for-testing.log`); a new existing-file regression for both account-scoped workout reminder opt-ins and legacy preference decoding compiled but did not execute. Local web unit/parser tests passed 125/125 (`/tmp/liftrivals-deferred-fallback-web-tests.log`), demo Playwright flows passed 12/12 (`/tmp/liftrivals-deferred-demo-e2e.log`), and the isolated PostgreSQL security harness passed two clean resets with 26 ranking, 26 stat, and 38 friend-activity assertions per reset, 180 focused assertions total and zero failures (`/tmp/liftrivals-deferred-sql-tests.log`). The SQL harness used a temporary `/tmp` copy of the old location seed with its known conflict made schema-tolerant; no tracked historical migration or remote project changed. N1 uncached async destination resolution, N5 moved-date UI, S4 queue recovery, and other iOS runtime/device checks remain unexecuted. `git diff --check` passed.

Fresh simulator retry: GPT-6 Luna rechecked `xcrun simctl list devices booted` at 21:38:38 on October 31; CoreSimulatorService again returned `Connection invalid` / `Connection refused` and `Unable to locate device set`. Neither the user nor system launchctl domain contained a registered CoreSimulatorService job, while Simulator.app and device Mach services were still active. A service-only restart was unavailable; no Simulator process, device data, or XCTest runner was touched. iOS runtime verification remains pending.

Physical iPhone follow-up: Robert Jeanty’s connected iPhone 17 was available as Xcode destination `00008150-001E456C3EF8401C`; read-only inventory found no existing `com.liftrank.app` install. GPT-6 Luna built a signed Debug staging app and unit/UI test runners with automatic Apple Development provisioning for team `32TGWTQNP8`; artifact `/tmp/liftrivals-iphone-tests-derived/Build/Products/Debug-iphoneos/LiftRank.app`, build log `/tmp/liftrivals-iphone-signed-build-for-testing-team.log`. Debug has no APNs or Sign in with Apple entitlements, so these were demo/mock tests with no real account sign-in. The focused device unit set passed 11/11 (`/tmp/liftrivals-iphone-focused-tests-20261031.xcresult`). An initial full unit run executed 437 with 10 failures (`/tmp/liftrivals-iphone-unit-tests-20261031.xcresult`); these traced to stale or device-incompatible test fixtures, not a verified product regression. Corrections retained valid remote workout decoding, post-commit notification cleanup, eight seeded demo workouts, recent same-week plateau/streak dates, device-writable contact-sheet output, and a combined disk-backed save/reload benchmark. The corrected affected unit cases passed individually. Focused demo UI Resume and empty-end routes passed; the weight-first keyboard flow initially failed only on XCTest's generic keyboard query although the attachment visibly showed the numeric keyboard. The revised app-owned toolbar assertions passed 1/1 on the device (`/tmp/liftrivals-iphone-keyboard-ui-fixed-20261031.xcresult`). No phone data was erased. A final full unit rerun was stopped before XCTest began because Xcode reported the phone locked (`/tmp/liftrivals-iphone-unit-final.log`); unlock is pending. Live staging privacy/account flows and signed notification delivery are separate checks.

After the user unlocked the phone, GPT-6 Luna reran the corrected full unit target against the same signed device test products: **437/437 passed, 0 failures, 0 skips** (`/tmp/liftrivals-iphone-unit-final-unlocked-20261031.xcresult`, `/tmp/liftrivals-iphone-unit-final-unlocked.log`). The earlier focused UI results cover Resume and empty-end, and the corrected weight-first keyboard test separately passed 1/1. The phone run used demo/mock identities and did not exercise real-account privacy, APNs, Sign in with Apple, or every large-text screen. No device data was erased or remote migration deployed.

Device review install: XCTest removed its temporary app install after running. GPT-6 Luna installed the same signed Debug staging artifact separately and launched `com.liftrank.app` with `-uiTestingDemoMode` on the iPhone 17. `devicectl` confirmed installation at `/private/var/containers/Bundle/Application/680779A9-0CFD-44F3-9C25-B2DCEAFCE471/LiftRank.app/`; process inventory confirmed `LiftRank.app/LiftRank` running as PID 38268. Artifact metadata is version 1.0 (build 49), staging backend, Apple Development team `32TGWTQNP8`. A follow-up installed-app inventory query returned empty despite install and running-process confirmation, so the process evidence is used for launch status. Demo launch does not sign in to a real account or validate release entitlements.

Newest source build run: GPT-6 Luna compiled the current checkout as a fresh signed Debug iPhoneOS staging app, installed it over the existing `com.liftrank.app` without uninstalling or erasing data, and launched it with `-uiTestingDemoMode` on the connected iPhone 17. Build succeeded; log `/tmp/liftrivals-phone-latest-build.log`, artifact `/tmp/liftrivals-phone-latest-derived/Build/Products/Debug-iphoneos/LiftRank.app`. Process inventory confirmed the new installation running as PID 38295 from `/private/var/containers/Bundle/Application/D08FE62B-21A0-4F86-9ECA-61B57833AF11/LiftRank.app/LiftRank`. Bundle version remains 1.0 (build 49), with staging backend and Apple Development team `32TGWTQNP8`. Source fingerprint: HEAD `b9f0a095d6af59f7ef3c636ab4f24b71412373c1`, app Swift digest `2a45e8cea8b41d273fd2606931a990bcb9e2d9ecd7f89642bfeedc24c66ba1a8`, tracked diff hash `d2b667587abd3d957fffd8f33ddeaf5d80f29053468b7dd98b271d635f54ff24`. This was a build/install/launch check, not a new XCTest or real-account session check; no remote migration was deployed.

### Physical-phone Progress crash follow-up — October 31, 2026

The user's reported Progress crash was reproduced three times on the connected iPhone 17. The phone reports show `EXC_BAD_ACCESS` at the main-thread stack guard while Swift resolves a large generic view type in `TrainingTrackerView.exerciseProgressSection(options:)` and then the Muscle builder. Reports: `/tmp/liftrivals-crash-222516.ips`, `/tmp/liftrivals-crash-222523.ips`, `/tmp/liftrivals-crash-222827.ips`, and the later narrowed report `/tmp/liftrivals-crash-223305.ips`. This is device crash evidence, not a failed assertion alone.

Three local `AnyView` boundaries now isolate the existing exercise heading, muscle workload row, and muscle attention section in `TrainingProgressView.swift` and `TrainingProgressMuscleView.swift`. They retain the same content and actions while reducing the generic view construction depth. No new file, type, dependency, or service was added. The first two boundaries each exposed the next stack-heavy section; the third fix passed the repeated Progress category test on the physical phone. The full focused physical-phone Progress set then passed **8/8**, with no skips or crashes, including Strength/Muscle/Consistency switches, dark and light Strength charts, accessibility XXXL layout, Muscle filters, source workout navigation, and history calendar (`/tmp/liftrivals-progress-final-focused.log`, `/tmp/liftrivals-progress-final-focused-20261031.xcresult`). Two earlier focused test failures came from taps made before controls had scrolled clear of the floating tab bar; both targeted reruns passed after the existing UI test helpers checked actual frames (`/tmp/liftrivals-progress-targeted-diagnostics.log`). This verifies the tested demo routes on this device; it does not establish live-account or release-build stability.

### Pocket Fit backlog implementation audit — October 31, 2026

The approved Pocket Fit list is separate from the 38 supplementary audit findings. Source inspection and the current physical-phone tests support these statuses; a visible control or a compiled service is not counted as live delivery.

| Approved item | Current evidence and remaining check |
| --- | --- |
| 1. Exercise guidance and form cues | Form cues are in the active exercise's disclosure. Direct in-workout usability still needs a focused UI check. |
| 2. Workout and set logging | Weight-first set entry, prior-set fill, and keyboard flow are implemented. Physical-device set-entry coverage is part of the cross-screen matrix below. |
| 3. Automatic weight progression explanation | Suggested-load and progression guidance exist in the active exercise. Confirm that a first-time lifter can identify why a particular load was suggested. |
| 4. Scheduling and optional rescheduling | Plan sessions can move to another day and the app calculates a suggestion. Preview and move confirmation need separate runtime checks. |
| 5. Compact weekly goals and stats | Home goal and Progress Consistency share the weekly view. Goal persistence and Progress rendering are covered by device UI tests; remaining layout judgment is visual. |
| 6. Custom workout and lift share cards | No customizable workout/lift card flow was found. This remains to build. |
| 7. Monthly and yearly recaps | Both periods and export appear in Progress. Export success/cancel and share presentation remain to check on device. |
| 8. Accountability notifications | Workout-day and missed-workout reminders have separate default-off settings; notification navigation can be exercised in demo. Signed delivery and any additional event types remain unverified. |
| 9. Opt-in friend activity | Client controls, feed, and local server migration/tests exist. The migration is not deployed, so live cross-account behavior remains pending. |
| 10. Friend workout stats with privacy | Aggregate card, audience control, and local SQL security tests exist. Live owner/friend/stranger/blocked checks remain pending after a confirmed staging rollout. |
| 11. Leaderboard filters and podium | Metric/scope/time/evidence controls exist; the proposed top-three podium was not found. Filter navigation is in the device matrix; live rank consistency remains pending. |
| 12. Theme and accent options | Light, Dark, System, and accent options exist. The Progress layout ran in dark and light; accent persistence is in the device matrix. |

Excluded by the approved scope: AI, food/nutrition tracking, avatar leveling, Apple Health, and side-by-side photo comparison. No remote database migration was applied during this audit.

The physical-phone demo screen matrix visited Home, Track Today/Plans/Library/Progress, Rankings, Forum, Me/public/personal profile, Settings, and Notifications. It also exercised set-entry keyboard navigation, schedule preview, the weekly goal, Library opening, leaderboard filters, Me footer reachability, and accent persistence. The initial 11-case batch passed 9; its two failures were stale test assumptions about a selected Plans value and an unset weekly goal in persistent demo data. The corrected Plans and goal cases both passed, as did the rerun of set entry, so all **11 selected screen cases passed after correction**, with no app crash (`/tmp/liftrivals-pocketfit-screen-matrix.log`, `/tmp/liftrivals-pocketfit-screen-matrix-20261031.xcresult`, `/tmp/liftrivals-pocketfit-followup-tests.log`, `/tmp/liftrivals-pocketfit-followup-tests-20261031.xcresult`). The matrix does not verify every branch within those screens, real-account permissions, signed notification delivery, exports, or the undeployed friend-data services.

Follow-up from the user's weight-first logging feedback: `WorkoutSetLogRow.previousSummary` now shows weight before reps, assisted reps, or time, matching the editable field order. The existing Prev button still fills both fields. The focused device test now asserts a weight-first Prev label and passed with the signed Debug staging build. This is a targeted text-order change with no new file, abstraction, or dependency.

A further focused physical-phone unit batch passed **17/17** tests for exercise guidance, adaptive loads and schedule variants, rest timing, automatic set completion, weekly goals, monthly/yearly recap calculations, CSV export formatting, reminder date/opt-in rules, leaderboard filters, notification routing, and account-scoped pending friend activity (`/tmp/liftrivals-pocketfit-feature-unit.log`). These unit results validate local rules and persistence paths; they do not establish the live social features or notification delivery.

After the tests, GPT-6 Luna reinstalled and launched the latest signed Debug staging build 49 in demo mode on the iPhone without erasing its app data. Installation, launch, and matching running-process evidence are `/tmp/liftrivals-final-demo-install.log`, `/tmp/liftrivals-final-demo-launch.log`, and `/tmp/liftrivals-final-demo-processes.log`. `git diff --check` passed. This is the current review build on the phone, not a TestFlight release or a real-account session check.

### Image-inspired color themes — October 31, 2026

Settings → Appearance now offers Classic plus three palettes based on the supplied references: Seal Blue / Navy Blue / Crimson Pink (`#D6F2FC`, `#072D59`, `#FF6E88`); Onyx Black / Electric Indigo / Tropical Mint (`#01010D`, `#6331FB`, `#85F9C0`); and Mandarin Orange / Forest Green / Crest Yellow (`#FD550A`, `#015D47`, `#EDF354`). The first two colors shape the page, card, text, and border palette through readable Light and Dark variants. Selecting a theme chooses its third color as the initial accent; the existing Accent color control can override it independently. Classic remains the default for existing installs. Appearance stays Light, Dark, or System, and the chosen theme and accent persist locally.

GPT-6 Luna's signed Debug staging app/test build passed (`/tmp/liftrivals-theme-build4.log`). The physical iPhone theme UI case passed **1/1**, covering all three selections, accent override, Light/Dark changes, relaunch persistence, and restoration of the prior preferences (`/tmp/liftrivals-theme-ui-verified.log`, `/tmp/liftrivals-theme-ui-verified-20261031.xcresult`). Captured Home screenshots were visually reviewed without clipping or unreadable content. The lowest calculated primary/muted text ratio against a themed page/card was 5.03:1; the lowest accent-text-on-card ratio was 4.97:1. This is a focused Home and Settings check, not a visual pass over every screen. The latest signed Debug staging build 49 was installed and launched in demo mode on the iPhone with the existing app container preserved; no account or remote data changed. The implementation adds `LiftTheme`, `LiftThemePalette`, and `LiftThemeSelection` within the existing design-token file to store and apply the palettes; it adds no file or dependency.

### Blank workout completion review — October 31, 2026

The user's dark-screen report was reproduced on the physical iPhone in the incomplete-workout path. After tapping **Review workout anyway**, a blank, dark sheet covered the still-running app. The failure screenshot and accessibility hierarchy are `/tmp/liftrivals-dark-after-workout-attachments/8DF2AC53-A227-4460-BCA1-3EB81CAEB171.png` and `/tmp/liftrivals-dark-after-workout-attachments/8FE45104-FD27-4658-96D6-FA979BC70A30.txt`. No process crash occurred. This reproduced before saving, so the exact timing of the user's separate post-save observation was not established.

The existing `WorkoutSessionSheet.summary` case now carries its prepared `WorkoutSummary` directly. The app presents the summary only when preparation succeeds, eliminating the optional state that could produce an empty sheet during the dismissal/presentation transition. GPT-6 Luna compiled the signed Debug staging app/test bundle and reran the same physical-device completion flow. The review screen rendered, **Save & finish** showed its saved confirmation, and **Done** returned to Home: **1/1 UI test passed** (`/tmp/liftrivals-workout-dark-fix-build2.log`, `/tmp/liftrivals-workout-dark-final-test.log`, `/tmp/liftrivals-workout-dark-final.xcresult`). The old test's broad Review selector was narrowed to the actual collapsed **Review exercises & sets** disclosure and scrolled into view; that test change did not alter app behavior. No new file, abstraction, dependency, remote write, or data erase was involved.

After XCTest, GPT-6 Luna installed the latest signed Debug staging build 49 over the existing iPhone installation and launched it in demo mode. The app process was running as PID 38946, and the device reported the same data-container identifier as before installation (`/tmp/liftrivals-workout-dark-final-install.log`, `/tmp/liftrivals-workout-dark-final-launch.log`). `git diff --check` passed.

## Workout workflow audit and simplification plan — November 1, 2026

Status: **implementation pass recorded below; verification in progress.** User direction: simplify the app without removing features. Users should understand what a screen shows, what to do next, and what its buttons do through clear controls and layout. Reduce recurring explanations that push useful content below the screen. Start with the entire workout journey and plan selection/change workflow; apply the resulting rules to the rest of the app afterward.

### Evidence and coverage

Source review covered Today, plan browsing, saved-plan selection, template setup, custom/history creation, plan/week/workout editing, scheduling and session order, active-workout conflicts, exercise selection, set entry, previous/copy values, completion, and saved-workout handoff. Current source owners are `TrainingTrackerView+Sections`, `TrainingTrackerForms`, `ProgramPlanDetailView`, `ProgramSessionCard`, `WorkoutProgramTemplateDetailView`, `AppState+TrainingPlans`, `WorkoutSessionRunView`, `PrescriptionTrackView`, `WorkoutSetLogRow`, `WorkoutSessionSheets`, and `WorkoutSummaryView`.

Live inspection used the installed iPhone 17 / iOS 26.5 simulator in Explore demo. It covered Today, Plans, the plan menu during an active workout, the saved-plan selector, program browsing, an existing program's preview/setup options, resuming the existing empty freestyle workout, its options, the exercise picker, and an existing saved workout. No plan was activated, modified, or deleted; no exercise/set was added, and the existing active workout was left intact and minimized. Browsing did reproduce the catalog collapsing after closing a preview.

The active workout prevented live plan-changing operations. Those branches, populated set entry, and completion were reviewed in source, not freshly exercised in this walkthrough. Actual independent-user comprehension, VoiceOver speech, large text, other themes, account sync, and interruptions remain validation work. Historical successful tests are not treated as fresh verification.

### Findings

Evidence: **L** = observed live; **S** = confirmed in source; **U** = user report. Priority 1 covers misleading behavior, lost context, or logged-data risk; priority 2 covers clarity and space. These are separate from the earlier 38-finding backlog.

| ID | Priority / evidence | Finding | Proposed change |
| --- | --- | --- | --- |
| WF-01 | 1 · U/S | Tapping previous values can expose long decimals. The input formatter permits six decimal places; the previous-set label uses the general zero/one-decimal formatter. Copying also converts between recorded units. The user's exact historical value has not been reproduced, so a storage/conversion defect is not yet established. | Trace original entry → saved value/unit → previous lookup → autofill. Agree one appropriate input/display precision policy, retain intentional fractional loads, and prevent rounding from silently rewriting the underlying load. Use the same rule for Prev, Copy last set, restored inputs, and logged results. |
| WF-02 | 1 · L/S | Plan options showed nine rows, eight disabled, during an active workout. The reason appeared below the workout list rather than beside these controls. Progression also remains as a disabled item for unsupported custom plans. | Show applicable actions. Put a compact active-workout status with a Resume action near the plan controls. Hide actions that cannot apply to this plan; explain temporary edit locks once at the relevant destination. Browsing and permitted read-only actions remain available. |
| WF-03 | 1 · L/S | Switching saved plans is inside Manage saved plans beneath the week’s workouts and catalog. Tapping a saved-plan row activates it immediately, even though the entry point sounds like general management. | Put a named Switch plan control by the selected plan. Distinguish browsing a saved plan from choosing it as active, with a clear active marker and explicit selection wording. Preserve inactive plans and their progress; avoid a confirmation for every reversible switch. |
| WF-04 | 1 · L/S | Closing a template preview collapses the program catalog whenever any plan is selected. Comparing several programs requires repeatedly reopening it. The sheet’s unconditional onDismiss causes this. | Restore the same catalog, search, filters, and browsing position when a preview closes. Return to the chosen plan only after an actual activation/save. |
| WF-05 | 2 · L/S | A program whose cycle has ended still offers Resume existing program, while showing the original Week 1 template preview. The current plan, its saved changes, and a new cycle are difficult to distinguish. | Make the destination explicit: View current plan for the active plan, Use plan for an inactive saved plan, and Start new cycle for a fresh copy. Label template previews separately from saved-plan contents and retain access to ended cycles. |
| WF-06 | 2 · L/S | Plan status, scheduling instructions, phase details, date range, week controls, and multiple action menus precede the first workout. The scheduling paragraph repeats information that belongs in configuration. | Lead with plan name, compact current status/schedule, week selection, and the next relevant workout. Move explanation and phase detail into the existing Overview/settings destinations. Keep partial/completed/skipped states explicit through concise labels and counts. |
| WF-07 | 2 · S, supported by L | Plan changes are spread between the top menu, a week menu, workout menus, Overview's session queue, and the saved template's Other setup options. Schedule and progression changes are especially indirect. | Provide Plan settings for schedule and supported progression; keep week actions beside the week and workout actions on the workout. Use one consistent term, Plan, in management controls. Offer the current schedule mode as a setting rather than a long command naming its opposite. |
| WF-08 | 2 · S | The active-workout conflict dialog offers Resume Active Workout and Review active workout, both opening exactly the same screen. | Use one clearly named Resume workout route, retain Cancel and the explicitly destructive discard-and-replace option, and show the active workout's name. This merges duplicate destinations without removing a capability. |
| WF-09 | 2 · L/S | An empty freestyle workout displays zero metrics, a large end-workout action, and Reorder Exercises despite having no exercises. Add exercise exists in three places with inconsistent prominence. | Make Add exercise the dominant empty-state action. Show reordering only when there are at least two exercises. Retain discard/end and pause in the appropriate controls; use the populated layout once exercises exist. |
| WF-10 | 1 · S | Earlier valid sets can complete when focus advances, but the final keyboard Done only dismisses input and triggers a paragraph telling users to tap the completion circle. This makes the last set behave differently at the most important moment. | Make completion a clear action for every set, including an explicit final keyboard action when valid. Preserve manual completion, automatic completion, undo/edit behavior, validation, and one rest-timer trigger. Agree the action wording/behavior before implementation; do not silently mark unfinished sets complete. |
| WF-11 | 2 · S | Guidance and options combines form cues, progression explanations, rest preferences, metrics, history, and exercise details. Form cues require a second disclosure, and History is hidden under a label that does not name it. | Give useful destinations concise, recognizable names such as History and Form. Keep weight → reps → completion as the visual priority. Put optional rest/progression explanation behind the corresponding control, with units, targets, and machine-load basis still visible. |
| WF-12 | 2 · S | Finishing an incomplete workout goes through a separate explanatory sheet, then review with another partial-session explanation, then save confirmation. Review also mixes optional comparison, effort, notes, and PR publication. | Use one clear review decision with a compact remaining-set status and direct routes back to unfinished work or to save a shortened workout. Keep Save & finish prominent; retain notes, comparisons, effort, PR choices, and the saved celebration as secondary sections. Preserve explicit publication choice and the distinction between local save, account sync, and PR submission. |
| WF-13 | 1 · S | Active exercise deletion directly removes its set logs, including completed sets, with no confirmation or undo in this path. The label changes from Remove to Delete but does not state that recorded work is lost. | For an exercise containing entered/logged work, use the existing confirmation pattern with the affected set count, or a reliable undo. Keep removing an untouched exercise quick. This is a protection for a concrete destructive action, not another standing explanation. |

### Proposed screen and action structure

Plans should answer three questions at a glance: which plan is active, which week/workout is being viewed, and what can be done next. The top area should contain the plan selector, a short schedule/status value, and a clearly scoped settings action. The first useful workout card should be visible at normal text size. Overview and Notes retain their existing content. The plan selector provides My plans and access to Browse plans, Create plan, and Import; a user should not scroll past an entire week to switch plans.

| Current control | Proposed wording/location | Behavior retained |
| --- | --- | --- |
| Stop program and return to freestyle | Use freestyle, within plan selection/management | Deactivate the selected plan; keep it saved and available to use again. This does not start a workout or delete history. |
| Train in session order (no fixed weekdays) / Use scheduled weekdays | Schedule in Plan settings, with Weekdays and In order choices | Both scheduling modes, missed-workout handling, and queue reordering. Show the selected mode and its relevant controls. |
| Change Progression | Progression in Plan settings | Existing supported progression methods, training maxes, guidance, and protected recorded sessions. Unsupported plans should not show an unusable editor. |
| Share editable program copy | Share plan | An editable copy; show that fact in the sharing flow where it matters. |
| Rename Plan / Duplicate Plan / Delete Current Plan | Rename / Duplicate / Delete plan in the selected plan's actions | All existing operations, with deletion separated and confirmed. |
| Add Week / Clone Week / Delete Week | Week actions beside the selected week | Preserve editing scope and logged-history protection. |
| Resume Active Workout / Review active workout | Resume workout | One route to the existing active workout and its review/finish controls. |

Use short visible labels plus descriptive accessibility labels. A relevant state, unit, validation error, save status, or deletion/publication consequence stays visible when needed. Put reference explanation behind a named disclosure at its point of use. Do not replace readable text with unexplained icons, shrink fonts/touch targets, or hide every control in a large new settings screen.

### Implementation sequence

1. **Agree the workflow and preservation map.** Capture the current paths and a compact before/after Plans layout. Inventory every existing action and its destination in no-plan, saved/inactive, active/ended, template/custom, weekday/sequence, and active-workout states. Retain create-from-history, import/share, duplication, week/workout edits, phases, progression, substitutions, and notes. Track the pre-existing unfinished-plan-draft item PW-13 separately rather than counting it as a new finding.
2. **Fix concrete behavior first: WF-01, WF-04, WF-08, WF-13.** Reproduce the decimal issue with representative saved data, preserve catalog context, remove the duplicate conflict choice, and protect entered work. Make targeted edits in the existing owners.
3. **Pilot Plans: WF-02, WF-03, WF-05, WF-06, WF-07.** Bring selection/switching forward, expose direct setup access, apply state-specific actions, shorten labels, and reduce header text. Verify every old operation has a reachable destination before broadening the design.
4. **Simplify workout execution: WF-09, WF-10, WF-11, WF-12.** Review start/resume, exercise selection and substitution, weight-first entry, Prev/Copy, set completion, rest, pause/minimize, and full/shortened/empty completion together. Preserve drafts and logged sets through every back/dismiss action. Keep the workout and saved-plan editing scopes explicit.
5. **Apply the accepted rules across the app.** Audit Home, Progress, Library, profile, rankings, and notifications screen by screen for repeated instruction, unclear next actions, and excessive header/card space. Retain the existing Light/Dark/System and theme/accent choices and all feature destinations. This wider pass follows the workout pilot; it is not claimed complete here.
6. **Compile and test with GPT-6 Luna.** Use focused numeric/state tests plus simulator walkthroughs of the changed paths. Check default and large text, narrow phone width, light/dark themes, accessibility labels, and keyboard obstruction. A later independent-user check should ask users to choose/switch a plan and log/save a workout without coaching; expert review alone cannot establish that the app is self-explanatory.

### Acceptance and verification handoff

- Plan selection and switching are reachable without scrolling through workouts. Browsing a preview and pressing Back/Close preserves the catalog context; activation clearly updates the selected plan.
- The default Plans screen prioritizes usable workout content. Necessary state is concise; optional explanation is available on demand. A temporary edit lock offers Resume workout rather than an unexplained list of disabled commands.
- Every existing feature has a documented destination. Verify no-plan, custom plan without template progression, multiple saved plans, ended cycle, active workout, scheduled weekdays, session order, missed/rest/shortened/completed workouts, and sync-error states.
- Verify weight → reps order in fields and Prev. A logged 225 lb copied in pounds remains 225; intentional fractional loads remain usable; kg/lb conversions are correct; comma-decimal locales parse correctly. Check repeated copy/save/reopen and unit changes without accumulating conversion or rounding error. Display precision must not overwrite canonical kilograms merely because a field rendered.
- Start, pause, minimize, resume, substitute, reorder, delete, and finish preserve the appropriate workout/plan/history boundaries. Copy and manual editing still require meaningful completion; the final set and its rest timer behave predictably. Full, shortened, empty, and failed-save paths have distinct outcomes with one clear next action.
- In the current live inspection, the existing active demo workout remained at zero exercises/sets and was left minimized. The account sign-in path was not tested.

GPT-6 Luna attempted six existing demo UI cases in a new disposable simulator named Lift Rivals Workflow Audit (`29314C7C-986C-469F-ADCB-740870B6337D`): active-workout resume, set-entry navigation, Plans/library, adaptive schedule preview, program preview, and workout save/dismiss. The elevated test command was interrupted by CoreSimulatorService failure before any test began: **0 passed, 0 failed, 6 not run**. Log: `/tmp/liftrivals-workflow-audit-tests.log`. The result bundle is incomplete. No fresh runtime pass is claimed; no dedicated existing test covered Prev decimal autofill or the preview-close browsing regression. Add focused regression coverage when implementing those fixes. The new audit simulator is shut down and available for later; the original simulators were not reset.

Luna also ran a standalone Foundation check using the current conversion constant and both formatting patterns. `225 lb → kg → lb` returned `225` in both displays. `100 kg → lb` showed `220.5` in Prev but `220.462262` in the input; `102.25 kg → lb` showed `225.4` versus `225.422663`. This confirms inconsistent precision and explains how long decimals can appear, while leaving the user's exact previous record and any underlying historical conversion issue unverified.

This draft changes only the existing audit document. No application code, new file, abstraction, dependency, database migration, or remote data was added or changed by this audit.

## Me screens audit and simplification plan November 1 2026

Status: **expert audit and draft plan; no implementation in this pass.** This extends the workout audit above to Me and its connected screens. The direction remains: make the app understandable through its layout, labels, and actions while preserving every feature. The main problem in Me is repeated navigation and information: the hub leads into another profile hub, some metric taps lead somewhere other than the displayed record, and explanatory text compensates for inconsistent saving behavior.

There are **20 Me findings, MS-01 through MS-20**. They are separate from the earlier 38-item backlog and the 13 workout findings. Fix access, saving, and destination problems before shortening copy; otherwise the interface would become quieter without becoming clearer.

### Coverage and evidence

Live inspection used the existing iPhone 17 simulator, iOS 26.5, Explore demo, app version 1.0/build 49, Dark appearance, Classic theme, and Pink accent. No preference, profile field, membership, workout, or submission was deliberately changed; no upload, publication, deletion, account operation, or demo reset was performed. Navigation ended back on Me. Some screens refresh cached data and awards when opened.

**L** means live inspection; **S** means source review. Source-only branches are listed explicitly. This is a workflow and presentation audit, not a new crash-test or privacy-enforcement result.

| Screen or workflow | Coverage |
| --- | --- |
| Me hub, identity, submitted strength, workout count, PR count, streak, and destination rows | L/S. Opened the Workout PRs summary; checked metric destinations in source. |
| Public preview: Overview, Lifts, Videos, Strength, and profile details | L/S. Visitor restrictions, blocked profiles, shared-stat audiences, and loading failures reviewed in source; no live second-account check. |
| Personal profile: Overview, Workouts, Lift submissions, PR videos, Strength, and milestone dates | L/S except personal Overview reviewed in source. History displayed 20 of 44 workouts. Personal Strength displayed an awards grid before its chart link. |
| Edit Profile: identity, earned status, body, and location | L/S. Save, username confirmation, validation, and dismissal logic reviewed without modifying fields. |
| Profile photo selection, cropping, removal, and upload states | Empty photo manager inspected live; picker, crop editor, removal confirmation, and failure paths reviewed in source. No photo selected. |
| Dated bodyweight entry; location and primary-gym selectors | Bodyweight form and location picker inspected live. Primary-gym selection and saving reviewed in source. No measurement or selection saved. |
| Awards, Rival Tier, next milestones, earned/locked collections, personal records, and tier sharing | L/S. Share rendering/export reviewed in source without generating or sending a card. |
| Submitted lift and total details; exercise-set history | All reviewed in source. Bench history and its prefilled submission form inspected live. |
| Completed workout detail opened from Me | L/S. Existing workout opened without editing, repeating, or deleting it. Existing workout audit covers its connected training operations. |
| Lift submission: exercise, weight/reps, units, 1RM type, context, evidence, visibility, caption, and plate loading | Form and expanded details inspected live. Selectors, video review/upload, validation, submission result, and failure states reviewed in source; no lift submitted. |
| PR video gallery and playback | Personal and public-preview empty states inspected live. Populated thumbnails, playback, unavailable-video Retry, and moderation branches reviewed in source; demo profile had no video. |
| Gyms: directory, gym detail, request form, membership controls, and rankings link | Directory, primary-gym detail, and request form inspected live. Join/leave/make-primary, full membership, error/retry, and rankings handoff reviewed in source. |
| Settings root, units, Privacy, Training, Notifications, and Account | L/S. Demo Account was blank. Guest upgrade, signed-in deletion, notification scheduling/permission, and save/retry branches reviewed in source. |
| Appearance, Color theme, and Accent color | Existing selections and both choice lists inspected live; change behavior reviewed in source. Other appearances were not applied. |
| About and support, About Lift Rivals, Privacy notice, Terms of use, Fitness disclaimer, and Demo | Opened each local screen. Support URL and demo-reset confirmation reviewed in source; no external support request or reset. |

Live testing of changed drafts, account saves, network failures, uploads, exports, actual VoiceOver speech, large text, other themes, and independent-user comprehension remains part of implementation validation. No compile or automated tests were run for this documentation-only pass.

### Findings and proposed fixes

Priority 1 covers blocked access or lost changes. Priority 2 covers navigation, comprehension, and presentation. Where a finding combines live appearance with a source-only consequence, the distinction is stated.

| ID | Priority / evidence | Finding | Proposed change |
| --- | --- | --- | --- |
| MS-01 | 2 · L/S | The identity block, bio, large submitted-strength card, and three counters consume almost the whole first viewport. Workout history and other frequent destinations sit below it. The strength card has several competing focal points. | Compact identity and bio, keep one headline result, and use smaller supporting lift rows. Bring useful destination rows into the initial viewport without shrinking controls. Retain per-lift evidence and units. Keep full bio/profile details available. |
| MS-02 | 2 · L/S | Metric taps behave differently: Workouts and streak open Progress, Workout PRs opens a count plus a paragraph before another chart link, and the total detail largely repeats the hub. The PR sheet explains why its destination will show different numbers. | Make each tap open the supporting records or a clearly scoped detail. Preserve the lifetime PR-event count separately from current exercise records; use a short scope label and a useful records link instead of an explanation-only stop. Update accessibility hints to describe the actual destination. |
| MS-03 | 2 · L/S | Workout history and Manage lift submissions both open Personal profile, with another section menu and repeated profile controls. Personal Strength begins with a long achievements grid, then offers the real strength destination in Track. Public Strength shows different content under the same name. | Open directly titled Workout history and Lift submissions destinations from Me, reusing current views. Route private Strength to existing Progress and Awards to existing Awards. Preserve public-profile views, personal overview, video access, and milestones through explicit destinations rather than another general profile hub. |
| MS-04 | 1 · L/S | Workout history shows 20 of 44, but renders only the first 20 filtered workouts with no next page, Show more, or full-history link. Date filters only narrow recent history. Older matching records can remain unreachable from this screen. | Reuse the complete history destination or add bounded loading with a clear way to reach every match. Preserve date/type/exercise filters, order, detail actions, and return position. Validate with more than 20 workouts and an older record that shares the same exercise as recent workouts. |
| MS-05 | 2 · L/S | Exercise-search placeholders on workout history and lift submissions are very faint against the dark field and look disabled. Other Me search fields use a clearer filled treatment. | Apply the existing themed field style and explicit accessible labels. Keep the field recognizable when empty, focused, populated, and disabled; verify contrast in supported appearances rather than assigning a new fixed color. |
| MS-06 | 2 · L/S | Edit Profile mixes draft fields with a photo manager and dated bodyweight log that save independently. Standing paragraphs explain that Cancel/Save Profile does not control all the changes made from this screen. Earned status also occupies space between editable fields. | Give profile fields one clear Save boundary. Keep photo management and bodyweight logging as visibly separate actions with their own save completion; consider placing their entry points on the relevant profile/body destination. Move earned-status explanation behind its existing disclosure. Preserve biography, training experience, location, gym, height, and all existing fields. |
| MS-07 | 1 · S | Edit Profile, Submit Lift, and Request Gym dismiss through Cancel/Close without a changed-draft check. Submit Lift also has no guard against interactive dismissal. Entered fields or selected media can be lost without a clear discard decision. | Reuse the existing changed-draft/discard pattern for meaningful edits, while dismissing untouched forms immediately. Cover swipe dismissal as well as buttons. Protect submission while a save/upload is in progress and preserve the draft after a failure. Do not add a confirmation to every ordinary Back action. |
| MS-08 | 2 · L/S | Secondary profile editors repeat context: the bodyweight sheet has an entry title, a Log bodyweight heading, a date summary, and a date picker. The location picker starts in a long mixed-region list without bringing the current choice into view. | Keep the bodyweight value, unit, measurement date, and optional note prominent, with a compact source label when prefilled. Give selectors a clear title, current selection, and search; retain country/region disambiguation and all choices. Reuse the shared picker rather than building another selector system. |
| MS-09 | 1 · S, controls L | Settings stages units, privacy, and default Progress focus until Done, while appearance, theme/accent, reminders, rest, and automatic PR sharing take effect immediately. The sheet only blocks swipe dismissal while saving, so staged changes can disappear while immediate ones remain. | Establish explicit save boundaries. Keep privacy/account changes in a clearly labeled Save flow with dirty-draft protection and retry; keep immediate preferences visibly consistent within their own section. Do not quietly autosave privacy to make the controls appear uniform. Test Back, swipe, Done/Save, interruption, and failed saves. |
| MS-10 | 2 · S, explanation L | Privacy preview uses saved privacy, even when the settings draft differs. A paragraph warns that changes appear only after saving. The settings sheet passes a draft profile, but the owner preview resolves the current saved profile/privacy again. | Prefer a local draft preview that does not publish changes. If that cannot faithfully represent the audience, use an explicit Save & preview action and preserve errors. Clearly identify the Public audience; do not imply this preview proves what friends or gym members see. |
| MS-11 | 2 · L/S | The owner's public-preview Videos empty state offers Submit lift with video, but the personal Videos empty state only explains how to add one. The action is shown in the visitor simulation and absent from the owner's working screen. | Put the submission action on the personal empty state. Keep the preview's content faithful to a visitor, with owner-only preview controls outside that content. Preserve evidence, moderation, hidden-video, and unavailable-video states. |
| MS-12 | 2 · L/S | Settings mixes destination rows with inline Units/Appearance below Sign Out. Account is a destination and a second root section. In demo, the Account destination opens a blank page. | Use a consistent category structure with visible current values for Units and Appearance. Put account actions together and move Sign out below everyday preferences. Omit an inapplicable demo-only Account destination or show an explicit demo state. Retain guest upgrade, account deletion, support, legal pages, and the separate demo reset. |
| MS-13 | 2 · L/S | Training focus sounds like a training-plan choice, but only chooses the initial Progress category. Rest settings show the full effort-adjustment formula even while adaptive rest is off. Automatic PR sharing needs a long paragraph to explain its scope. | Rename the picker Default Progress view. Group rest controls and show adjustment details on demand. Name the publishing control explicitly, such as Auto-share eligible PRs publicly, with concise scope/evidence context and further details available. Keep retries and publication eligibility unchanged. |
| MS-14 | 2 · L/S | Notifications repeatedly explains default-off settings and what the iOS permissions button does. Scheduling rules and rescheduling behavior compete with the actual controls; the useful next-alert status is conditional deeper in the form. | Use separate Reminders and Rescheduling groups. Show time and a concise next-alert or unavailable reason only when relevant, with an actionable plan/settings destination. Use Open iOS Settings for the external action. Retain both independent opt-ins, permission/error states, retry, and the existing requirement that a suggested move is user-selected. |
| MS-15 | 2 · L/S | Awards combines Rival Tier, closest awards, earned awards, sharing, records, and a large remaining collection in one scroll. Demo has 58 earned and 138 remaining. Fixed two-column tiles limit titles/descriptions to two lines with no detail action. A separate milestone-date list lives under Lift submissions and renders non-workout events as disabled buttons. | Lead with current tier and the next useful milestone, then expose earned/remaining collections by state or category. Let users inspect full requirements and earned dates; use one column at larger text sizes. Put the timeline with Awards and use plain rows for non-actions. Preserve every award, tier rule, date, and share capability. |
| MS-16 | 2 · S, destination L | Awards Personal records can display a submitted-lift value, but tapping always opens workout-set history. A submitted record may therefore be absent from the destination, or that history may be empty. | Route a submitted value to its submitted-lift detail; route a workout estimate to its workout evidence. Keep View workout history as a separate action where useful. Do not merge submitted records, estimated training strength, and verified competition results. |
| MS-17 | 2 · L/S | Rival Tier sharing first asks the user to Prepare Rival Tier card, then changes into Share Rival Tier card. The first tap exposes the image-rendering step rather than a user decision. | Use one Share tier card entry, generating the existing card before preview/system sharing and showing progress or an error if needed. Preserve the card and user-controlled destination; do not publish automatically. |
| MS-18 | 2 · L/S | Bench history repeats full exercise/workout/date cards for every set, without a visible set number. Several sets look identical. Raw sets display their recorded unit while estimated 1RM uses the preferred unit: the live screen showed 90 kg × 8 beside 251.3 lb. Submit this set opens a review form, which the introductory paragraph must explain. | Group sets by workout with the date once and identifiable set rows. Present comparable values in a consistent chosen unit, retaining original units in detail and the submission prefill. Label the action Review submission or Use this set. Preserve every set, variant, date, and the new-submission path; never rewrite canonical weight for display. |
| MS-19 | 2 · L/S | Submit Lift shows Actual / Estimated without a visible 1RM label, hides the estimate and plate calculator together under More details, and gives optional video selection a filled action competing with the sticky Submit action. Public visibility is below the first viewport while Submit stays available. | Keep weight → reps and an explicit 1RM label. Show the resulting estimate beside its inputs; give Plate calculator a named entry. Mark optional video clearly and keep attachment distinct from reviewed verification. Place a concise chosen-audience summary by the final action so publication is understood without another paragraph or a mandatory extra screen. Preserve all validation, bodyweight/date/gym/equipment, caption, plate loading, video review, visibility choices, and result feedback. |
| MS-20 | 2 · L/S | Gyms repeats membership-limit prose. A primary gym has a large disabled Primary Gym button; source gives Leave Gym the primary style on a joined secondary gym, while Make Primary is secondary. Top lifters does not name its verified-total metric beside the list. The directory's plus means Request Gym, not immediate addition. | Display Primary as status, prioritize a relevant positive action, and keep Leave in clearly scoped secondary actions. Show the membership count/limit compactly and explain the rule when it blocks joining. Label the request entry and the rankings metric/evidence. Preserve search, requests, joins/leaves, primary selection, limits, member/lift counts, ranking filters, loading, and retry. |

### Source owners for implementation

These existing owners contain the relevant behavior; the plan does not require a new navigation framework or service layer.

| Area | Existing source |
| --- | --- |
| Me hub, metric routing, Awards, tier sharing, award tiles | [MeHubViews.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/Profile/MeHubViews.swift:10) |
| Personal/public section navigation and modal destinations | [ProfileViewSections.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/Profile/ProfileViewSections.swift:78) |
| Owner preview resolves saved profile and privacy | [ProfileView.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Views/ProfileView.swift:14) |
| Profile metrics, submissions, history cap, and milestone timeline | [ProfileLogic.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/Profile/ProfileLogic.swift:646) |
| Profile editor, photo/crop flow, video states, gym directory/detail/request | [ProfileContentViews.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/Profile/ProfileContentViews.swift:292) |
| Submitted/total detail, workout-set list, and submission prefill | [TopLiftCardDetails.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/Profile/TopLiftCardDetails.swift:25) |
| Settings categories, immediate/draft preferences, preview, save/retry, and legal reader | [SettingsView.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Views/SettingsView.swift:23) |
| Submission fields, visibility, video review, calculator, and result | [SubmitLiftView.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Views/SubmitLiftView.swift:45) |
| Shared option picker; dated bodyweight editor | [LeaderboardComponents.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Components/LeaderboardComponents.swift:435), [TrainingTrackerForms.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/TrainingTracker/TrainingTrackerForms.swift) |

### Proposed navigation and feature preservation

Me should be a compact personal overview with direct destinations. Keep the current identity, Rival Tier, submitted records, and private training statistics, but give them less space and clearer sources. Each destination should have the same title as its entry point. Do not solve crowding by moving everything into a single overflow menu.

| Destination | Capabilities that remain available |
| --- | --- |
| Edit profile | All existing identity/training/location/gym fields, field validation, username-change consequences, earned status explanation, photo choose/crop/remove, and dated bodyweight logging. Photo and bodyweight saves remain explicit, separate operations. |
| Public preview | Overview, submitted lifts, videos, strength trends, allowed profile details, and permitted aggregate workout stats. Keep an explicit visitor audience and access to privacy controls. |
| Workout history | Complete private history, existing filters, workout detail, and all existing workout actions. Reuse the complete history experience; preserve a clear route back to Me. |
| Lift submissions | Every attempt, date/exercise filters, evidence and visibility, detail, supported management/deletion, new submissions, and video access. Retain personal submitted-strength overview through the records header/detail. |
| Awards | Rival Tier, estimated lift progress, closest/earned/remaining awards, full requirements, earned dates, milestone timeline, records with correct source links, and tier sharing. |
| Progress | Existing consistency, strength, muscle, and body views and their features. Me shortcuts choose the appropriate scope without creating duplicate charts. |
| Gyms | Directory/search, membership and primary status, request form, gym counts, verified-total preview, and full gym rankings. |
| Settings | Privacy, Training, Notifications, Units, Appearance/theme/accent, applicable account actions, About/support/legal, and demo-only controls. Preserve all Light/Dark/System appearances and every current theme/accent. |

The theme and accent lists already use names, swatches, and selection checkmarks effectively. Keep them and make their position in Settings consistent. A theme currently also chooses its default accent; the selected theme/accent should remain visible together so this relationship is clear. Long legal text belongs in its reader: prefer a large initial sheet for Privacy notice and Terms, retaining the documents and readable text sizes. No legal-content rewrite is part of this plan.

### Implementation order

1. **Correct access and saving:** MS-04, MS-07, MS-09, MS-10, MS-16. Make all history reachable, protect meaningful drafts, clarify save boundaries, make privacy preview honest, and connect records to the correct evidence. Use existing error, confirmation, and routing patterns.
2. **Simplify Me and its destinations:** MS-01, MS-02, MS-03, MS-05, MS-11. Compact the overview, open directly named content, remove explanation-only navigation stops, restore useful owner actions, and fix themed field contrast.
3. **Refine profile editing and preferences:** MS-06, MS-08, MS-12, MS-13, MS-14. Organize controls around the decision being made, with current values and relevant status visible. Put reference formulas and background explanation behind existing disclosures.
4. **Refine awards, records, submissions, and gyms:** MS-15, MS-17, MS-18, MS-19, MS-20. Group repeated content, make full details available, clarify action consequences, and preserve the complete feature map above.
5. **Compile and verify using GPT-6 Luna**, following the user's model preference. Perform focused tests for the changed behavior plus a full Me walkthrough. Do implementation in the user's selected model. Do not treat this audit as authorization to publish content, change account visibility, or deploy backend changes.

### Acceptance checks

- From Me, a user can open older workout history, find an actual submitted record, inspect an award requirement, edit a profile field, preview public information, and find appearance settings without coaching. Destination names match their content. Every capability in the preservation map remains reachable.
- History works with 0, 1, 20, and more than 20 results. Filters, scroll position, and back navigation survive opening a workout. No history is deleted or silently filtered to fit the layout.
- A submitted record opens its submission evidence; an estimated workout record opens the source workout/set. Lifetime PR events, best exercise records, actual/estimated 1RM, and competition verification remain distinct. Missing source data gets an honest empty/error state.
- Profile/settings/submission/request forms preserve meaningful drafts or obtain an explicit discard decision. Verify immediate photo/bodyweight/preference changes separately from staged fields, and test save failure/retry, dismissal during saving, interruptions, and account changes with isolated data.
- Privacy preview states its audience and reflects either the draft without publication or an explicitly saved state. Verify private fields, friends/gym audiences, videos, aggregate stats, and owner-only controls using isolated accounts; these are pending live checks.
- Exercise histories retain set identity and original recorded values while displaying comparable units consistently. Reusing a set preserves weight, reps, exercise, unit, and date. The earlier WF-01 decimal policy also applies here; formatting never rewrites stored kilograms.
- Submission review keeps chosen visibility, optional video, evidence status, and final action understandable. Exercise changes, actual/estimated selection, matched-dumbbell rules, plate loading, validation, video failure/retry, and result dismissal retain their current capabilities.
- Check smallest supported phone width, default and large text, keyboard coverage, VoiceOver order/action labels, Light/Dark/System, and all theme/accent combinations touched by the changes. Award requirements must remain fully readable, and noninteractive statuses must not look like disabled actions.
- Validate empty, populated, loading, offline, failure/retry, guest, demo, and signed-in states without resetting the user's simulator data. Check full/primary/secondary gym membership states without using a real account for destructive operations.
- Follow with an independent-user task walkthrough. An expert audit can identify friction; it cannot establish that every screen is self-explanatory to a new user.

This pass appends only to the existing audit document. No application implementation, new file, abstraction, dependency, migration, or remote change was introduced.

## Forum workflow and media audit — November 1, 2026

### Scope and implementation boundary

The request is to simplify Forum without removing features, matching the Workout and Me audits, and to use a picture and a video for test posts. The user subsequently approved implementing photo/video posting before auditing it. This section distinguishes that implemented capability from the proposed Forum improvements below. It does not authorize applying a migration or changing live account data. The user then redirected the work away from excessive testing and back to finding issues. Further work should prioritize the findings and simplification plan below; the verification cycle for this pass has ended.

Photo/video support now uses the existing post attachment column and Forum service. A discussion can contain one optional photo or video. Photos are prepared as JPEGs with a maximum 2048-pixel edge; videos are prepared as MP4s, up to two minutes. Prepared files are limited to 10 MB for photos and 50 MB for videos. The composer supports choosing, replacing, removing, and previewing an attachment, preserves its selected community when returning from preview, protects a changed draft, and retains text/media after publishing fails. Stable draft IDs prevent a retry from inserting the same post twice. Editing published text preserves the attachment. The first version does not replace a published attachment.

Media appears in feeds and discussions, with a full-screen photo viewer and the existing managed video player. A private storage bucket and post-aware access policies restrict media to viewers allowed to read its discussion; signed playback links last two minutes and can be refreshed. Upload validation checks ownership, post path, object presence, type, size, and attachment count. Published files cannot be overwritten through client upload access. Account deletion includes both published and unfinished Forum uploads. Previously appended DEBUG sample discussions are now restricted to demo mode.

Two bundled fixtures support repeatable, isolated testing: a 1200 × 630 legacy demo card and a silent six-second demo app-launch recording. They appear as **Photo test · Lift Rivals** and **Video test · App recording**. Demo posts created during a session stay local to that session. No test post was published to the live community. The video is an interface recording, not lift evidence.

### Coverage and evidence

`L` means inspected in the running simulator; `S` means verified in source. Initial walkthrough: iPhone 17, iOS 26.5, existing build 49, Explore demo, Dark appearance with the existing Pink accent. The empty active Freestyle workout was preserved. Media-build runtime results are recorded in the verification subsection below.

| Surface or workflow | Coverage |
| --- | --- |
| All, For You, Following, selected community, feed cards | L/S. Following with no joined community inspected; join/filter logic and pagination reviewed in source. |
| Search, no matches, community/sort sheet, Reset | L/S. A no-match query produced a blank feed. Search text was cleared afterward. |
| Community directory, discussion destination, membership controls | L/S. Public demo communities inspected; pending/muted/banned and failure behavior reviewed in source. |
| Populated discussion, comments, sorting, reply/collapse actions | L/S. Legacy read-only demo discussion inspected, including accessibility labels and lower-content reachability. Interactive media posts are covered by the new-build tests. |
| New discussion, media picker/preparation/preview, publish/discard/retry | L/S. Photo and video selected, prepared, published, and reopened in demo. Changed-draft confirmation/keep-editing and preview return checked live; forced publish failure is covered separately below. No live upload. |
| Photo viewer, video player, media loading/failure, text edit/delete | Photo zoom/return and video playback inspected live. Media preparation and edit/delete lifecycle unit tests passed. Unavailable/expired remote media reviewed in source; live API checks pending. Published attachment replacement is outside this implementation. |
| Votes, watch, reports, sharing, notification destinations | S; controls inspected live where available. No real report, notification subscription, or external share was sent. |
| Friend activity and public-profile handoff | L/S. Both workout-start and top-lift cards inspected; a top-lift card opened the friend's general profile. |
| Private/invite-only/gym/blocked/removed media | Isolated runtime SQL tests; live multi-account storage requests remain pending deployment to an explicitly confirmed test environment. |

### Findings and proposed changes

The following **20 findings were the simplification/fix backlog**. The November 1 implementation pass below records changes and outstanding verification; the audit evidence here describes the original state. Priority 1 affects reliable completion or state; priority 2 covers navigation, presentation, and comprehension.

| ID | Priority / evidence | Finding | Proposed change preserving capability |
| --- | --- | --- | --- |
| FS-01 | 2 · L/S | All, For You, and Following do not reveal their different scopes. Following means joined communities; For You adds pinned posts. Friend activity is a separate people icon. | Use explicit feed names such as All and My communities, retaining the recommended/pinned scope through a clearly named choice. Give Communities and Friend activity recognizable destinations; preserve every scope and avoid adding explanatory paragraphs. |
| FS-02 | 2 · L/S | The directory opens with a large instructional card, then repeats category, summary, details, and two large actions for each community. It has no directory search. Joined also acts as immediate Leave, while the selected-community header does not consistently reflect pending/muted/banned states. | Use compact community rows with one useful description, visible membership status, and a clear discussion destination. Keep joining/requesting/leaving as explicit relevant actions. Put extended details in a community detail disclosure and add search when the list warrants it. Retain access rules and membership states. |
| FS-03 | 2 · L/S | The feed hides the active sort behind Filters. The count does not explain which filter is active, and All remains selected even when results are restricted to one community. | Show concise current community and sort values near the results, with direct ways to change/reset them. Preserve the existing filter sheet, all choices, and the selected scope on return from a discussion. |
| FS-04 | 1 · L/S | A no-match search leaves a blank screen because empty-state logic checks the unsearched feed. Search and Top/Most discussed sort only operate on the loaded page(s), initially 50 posts. An older matching or leading post can be absent. | Render a no-results state from the actual result set with Clear search. Implement service-backed search/sort and corresponding pagination, or explicitly label the limited scope until that exists. Preserve community/feed filters and do not imply an exhaustive ranking of all posts. |
| FS-05 | 2 · L/S | Following's empty state tells the user to join a community but offers no action. All's empty copy says “this community” even when none is selected. | Use state-specific wording and a direct Browse communities or New discussion action. Distinguish no memberships, no posts in joined communities, a selected community with no posts, and no search matches. |
| FS-06 | 1 · S | A load, join, or deep-link failure can replace the whole feed with Forum unavailable. Success does not consistently clear the stored message, and the root has neither an explicit Retry nor pull-to-refresh. A missing thread can remain on a spinner. | Keep existing results while showing a local action error; give initial-load and missing-thread states an appropriate Retry/Back action. Clear errors on successful recovery and preserve navigation context. Treat inaccessible/removed content separately from offline failure. |
| FS-07 | 2 · S | New discussion defaults to the first community when opened globally. Posting eligibility is not resolved before submission. The chosen-audience label sits below the form and attachment, away from the top Publish action. | Require an intentional community choice when no context exists, or make the default conspicuous. Keep a compact audience summary beside Publish. Present Join/request access when it is the actual prerequisite; preserve private/gym/invite-only restrictions and server authority. |
| FS-08 | 1 · L/S | A successful publish only dismisses and reloads. The new post may be hidden by sorting, feed scope, or the selected community. The photo-post test returned to an old scroll position with the new post above the viewport. There is no clear confirmation or direct route to it. | Open the created discussion or show a concise Published state with View post. Keep the chosen feed position/filter for returning, and preserve stable-ID retry behavior. Do not insert a duplicate on a slow or lost response. |
| FS-09 | 1 · S | The new composer protects changed drafts, but post/comment edit sheets and the thread reply still dismiss without equivalent protection. Edit/reply length limits are not surfaced; service truncation can silently shorten content. | Apply the existing changed-draft pattern to meaningful edits/replies, preserve drafts after errors, and block dismissal during a save. Show a length limit only near its boundary or on violation; validate before submission instead of silently cutting text. |
| FS-10 | 1 · L/S, state-specific | On the original iPhone 17, both baseline and media-thread screenshots lacked a visible reply footer above the floating tab bar despite an accessibility entry. However, the isolated author edit/delete UI test reached a hittable reply field and typed successfully after editing. Baseline wheel/drag attempts also did not reveal lower comments. | Reproduce the difference between initial thread entry, media return, and edit-sheet return before changing layout. Check the nested bottom safe areas in ForumThreadView and MainTabView, keyboard state, and device size. Keep the reply composer visible above navigation, preserving tabs, scrolling, and exact-comment routing. Do not label commenting universally broken or treat an automation gesture failure alone as an app defect. |
| FS-11 | 1 · S | Post votes update the selected icon without updating the displayed count. Watch begins false on every thread opening instead of loading saved state, so the bell can misrepresent an existing subscription. | Load authoritative vote/watch state, update count and selected state together after success, and retain the prior state on failure. Expose clear Watch/Watching actions and prevent overlapping requests. Keep upvotes, downvotes, unvoting, and unwatching. |
| FS-12 | 2 · L/S | Generic avatars and cached-or-generic author names make different participants hard to recognize. Discussion omits the community name, so context is lost after opening a card. | Resolve public author display information through the existing service/cache and show a compact author/community/date line. Use a deliberate unavailable-author label where appropriate; preserve privacy and blocking rules. Keep profile access explicit if added. |
| FS-13 | 2 · L/S | A video thumbnail inside a feed card shows a play symbol, but the card opens the discussion. Its Play video button then opens a paused viewer whose controls must be revealed before playing. The fixed 220-point preview leaves a portrait clip very narrow with large empty bands. | Make the thumbnail's action honest and consistent: open media directly with a separate discussion target, or use a clear video attachment cue. Use a bounded aspect-aware preview. An explicit Play action should play or present visible playback controls; keep feed autoplay off and full-screen media uncropped. |
| FS-14 | 2 · S | The new attachment flow communicates preparation but not upload progress. Failure recovery has two different video retry actions, and photo zoom does not pan. A published attachment cannot be changed, although text can be edited. | Use one clear progress/retry path that refreshes expired access, keep the draft available, and allow a zoomed photo to be inspected. Explain the attachment edit boundary in Edit only when relevant. Do not remove text editing or pretend replacement succeeded. |
| FS-15 | 2 · S | Share discussion exports only title/body text. Neither the discussion destination nor its photo/video accompanies the share. | Define the share result clearly: preferably a discussion link/preview with access enforced when opened. Offer sharing media only when its audience/ownership permits it. Preserve text sharing as an intentional option; do not expose private attachments through a public URL. |
| FS-16 | 2 · L/S | Several compact controls rely on icons; the main upvote announces only a number, downvote says Down, and the bell says Notifications. Some thread actions have no explicit minimum target; comment action rows can become crowded with large text. | Name the action and current state for accessibility, keep 44-point targets, and adapt rows at large text sizes. Give frequent actions clear visible labels where useful while retaining contextual overflow for editing, reporting, and moderation. Verify actual VoiceOver speech and keyboard focus. |
| FS-17 | 2 · S | Report success is stored in the same error string and red presentation as failures. That message may also appear in an edit sheet. Reports and reply errors are low in the thread, away from the initiating control. | Separate concise success feedback from recoverable errors. Show each result near its action or as an accessible announcement; preserve the draft, selected report target, and retry as applicable. Keep all current report reasons and moderator review. |
| FS-18 | 2 · L/S | Friend activity leads with a standing privacy paragraph. A new-top-lift card shows no lift/result and opens a general profile, so the announced event is not the destination. | Keep event cards concise, with permitted result context and a truthful destination. If a specific lift cannot be opened, label View profile. Put sharing settings/help in an explicit secondary destination, keeping opt-in behavior and private workout details protected. |
| FS-19 | 2 · L/S | Legacy sample threads say the demo is read-only but still expose an editable reply field and a DEBUG local reply path. Feed cards show zero replies while the sample thread has three. New interactive media fixtures make this inconsistency more apparent. | Make demo capabilities consistent: use clearly labeled local interactive posts, or hide unavailable editing controls on read-only samples. Keep demo counts accurate and sample data isolated from signed-in accounts. Never invite a user to type into a dead-end control. |
| FS-20 | 2 · L/S | Feed cards repeat a Discussion badge and similar avatar treatment on every row. Threads repeat comment counts; nested replies have large repeated identity/action blocks, while collapse sits inside an overflow menu. | Give each card one focal point: title or attachment. Retain meaningful Question/Pinned/Locked distinctions, compact ordinary metadata, and use clear grouping between posts. Make reply expansion visible where needed and keep every comment, sort, vote, edit, delete, and report action available. |

### Preservation map and implementation order

| Destination | Capabilities to preserve |
| --- | --- |
| Forum feed | All/recommended/joined-community scopes, community filtering, search, top/new/discussed ordering, pinned/question/locked context, pagination, author/time, media, votes/reply counts, deep links, loading/empty/error states. |
| Communities | Browse, community details, join/request, pending/muted/banned states, leave, selected-community discussions, public/private/gym access. |
| New discussion | Community/audience, title/body, one optional photo or video, preparation/preview/replace/remove, publish, validation, progress/failure/retry, changed-draft discard, duplicate prevention. |
| Discussion | Full text/media, photo viewing and controlled video playback, thread voting, watch/unwatch, sharing, owner edits/deletion, reporting and moderation context. |
| Comments | Best/New order, top-level comments, nested replies, collapse/expand, exact-comment links, votes, owner edits/deletion, reporting, locked-state handling and draft recovery. |
| Friend activity | Opt-in friend events, access rules, refresh/retry/empty state, profile navigation and applicable lift context. |

1. **Reliable completion:** FS-04, FS-06, FS-08, FS-09, FS-10, FS-11. Correct results, recovery, publish completion, drafts, reply reachability, and saved interaction state.
2. **Clear navigation and audience:** FS-01, FS-02, FS-03, FS-05, FS-07, FS-12. Put relevant actions beside current state and replace standing instructions with clear destinations.
3. **Media and discussion refinement:** FS-13 through FS-20. Improve previews, sharing, accessible controls, feedback, event context, sample consistency, and density without dropping functionality.
4. **Validation with GPT-6 Luna:** compile and run focused regression checks, then walk every Forum surface. Follow with an independent-user walkthrough; expert review does not establish new-user comprehension.

Existing owners: [ForumViews.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/Community/ForumViews.swift:44) for screens and workflow; [ForumMedia.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/Community/ForumMedia.swift:1) for attachment preparation/viewing; [ForumStore.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Features/Community/ForumStore.swift:1) and [SupabaseServices+Social.swift](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/LiftRankApp/Services/SupabaseServices+Social.swift:320) for service access. Reuse these owners rather than adding another navigation or media framework.

### Verification and rollout

- The new Forum media SQL suite passed all 62 assertions in each of two clean isolated database runs (124 passes total). It covers bucket configuration, grants, fixed function search paths, upload ownership/path, pending upload retry/cleanup, attachment validation/immutability, and public/private/gym/blocked/removed access. Log: `/tmp/liftrivals-forum-media-sql-tests.log`. The tracked test bootstrap now includes the actual Storage metadata column. The temporary run also required an unrelated legacy location-seed conflict correction; the unmodified full repository reset remains blocked by that pre-existing migration issue. No historical migration was edited.
- Three isolated Node/TypeScript mocked account-deletion scenarios passed: nested/pending/published files, 1001-file pagination and removal batches, owner-prefix isolation, and lookup/removal errors stopping before account deletion. Harness: `/tmp/liftrivals-delete-account-mock-test.mjs`. No remote account was touched.
- Debug simulator build-for-testing passed. Installed artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Debug-iphonesimulator/LiftRank.app`, bundle `com.liftrank.app`, version/build `1.0/49`, staging configuration, ad-hoc simulator signature. The walkthrough used Explore demo services, not a live account. The existing iPhone 17 app data and active Freestyle workout were retained.
- Four focused Swift unit tests passed: bundled media/photo normalization; create/retry/edit/delete and media-file lifecycle; invalid-photo rejection; video normalization and a posted video remaining playable after the prepared source is removed. Result: `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_01-36-58--0400.xcresult`. Cold simulator-clone startup delayed the run; these are actual completed passes, separate from the earlier interrupted runner attempts.
- Live media checks confirmed photo display/full-screen zoom/return, video thumbnail/full-screen playback with elapsed time advancing to the end, and return to the discussion. A photo selected through the system picker was prepared, previewed, published locally, and reopened with the attachment intact. The chosen Powerlifting destination and text survived preview return and cancelling the discard dialog. Publish returned to the old scroll position without visible success feedback, confirming FS-08.
- The video also passed the full system-picker → preparation → local publish → reopen flow. The posted clip played with elapsed time advancing after the composer's prepared source had been cleaned up. No crash occurred during the exercised media flows. This is demo-service behavior; real upload/network failure checks remain part of rollout.
- Three focused UI cases passed across targeted runs: post/comment edit-delete and reply-draft retention; failed-publish text-draft retention; photo/video viewers. Initial attempts failed because taps did not reach the intended screen. The final media case passed after scrolling the full post row clear of the floating tab bar; this does not establish that every partially visible row has a reliable human touch target. Successful viewer log: `/tmp/liftrivals-forum-media-ui-viewer-final2.log`; result: `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_01-09-34--0500.xcresult`. The two other passing cases are recorded in `/tmp/liftrivals-forum-media-ui-tests-final.log`; its result bundle was no longer retained after subsequent runs. No further test expansion is planned for this audit.
- The final Debug artifact was reinstalled on the original iPhone 17, then relaunched **without launch arguments** after removing the temporary UI-testing launch mode. No data reset occurred. Binary SHA-256: `fa18a5785cf563d4f87965fca6bb86c04e49e20ae97832053020f31f9e1ce81c`. Release fixture exclusions were reviewed in project settings; a Release artifact was not built. Final diff whitespace review passed.
- **Live rollout remains pending:** apply [202611010001_forum_media.sql](/Users/robertjeanty/Documents/ChatGPT/Liftrivals/supabase/migrations/202611010001_forum_media.sql:1) only after explicit environment confirmation, and deploy the updated account-deletion function with it. Verify real Storage API uploads, signed URL refresh/expiry, private/community access with isolated accounts, report handling, and account cleanup. Local SQL assertions do not substitute for these API checks.
- Check photo/video selection from the system picker, replacement/removal, preview return, cancellation during preparation, publish success/failure/retry, text editing, deletion, playback end/return, and keeping audio stopped after dismissal. Verify a tall video and landscape image, large text, VoiceOver, smallest supported phone, keyboard, and Light/Dark/System. Mark anything not exercised as pending.

New files for this implementation: `ForumMedia.swift` isolates actual attachment preparation and viewing from the large Forum view; `Resources/DemoMedia/forum-demo-photo.png` and `forum-demo-video.mp4` provide the requested picture/video fixtures; `202611010001_forum_media.sql` defines media access/validation; `202611010002_forum_media.test.sql` verifies those security rules. Attachment/draft value types extend the existing Forum contract. No new dependency or generic manager was added. Release's existing file-exclusion setting now includes both demo assets; Release artifact verification is separate from the Debug checks above. The account-deletion change extends its existing storage cleanup. The listing behavior follows the [Supabase Storage list API](https://supabase.com/docs/reference/javascript/file-buckets-list), including folder entries and pagination.

## 53-finding implementation pass — November 1, 2026

User authorized implementing the Workout, Me, and Forum findings before testing, with GPT-6 Luna responsible for compilation and tests. The following records **source changes, not a claim of 53 independently verified closures**. Completed focused Luna verification is recorded below. Existing uncommitted work and simulator data are preserved; no remote migration, account change, or publication is authorized or performed by this pass.

| Finding | Implementation / acceptance boundary |
| --- | --- |
| WF-01 | Prev, Copy, restored inputs, and workout set presentation share up to two decimal places. Prev can wrap to keep weight and reps visible. Formatting restored/copied values does not replace their underlying precision. Canonical unit conversion is unchanged. |
| WF-02 | Plan overflow shows applicable actions; active workouts get a nearby Resume/edit-lock status. Unsupported progression editors are omitted. |
| WF-03 | Switch plan is above workouts; saved choices say Use plan and retain an active marker. Freestyle keeps saved plans. |
| WF-04 | Removed unconditional preview-dismiss catalog collapse; actual selection/activation returns to the plan. |
| WF-05 | Current/inactive/template choices say View current plan, Use plan, and Start new cycle; previews identify template content. |
| WF-06 | Compact status/schedule header; phase details move to Overview. |
| WF-07 | Plan settings groups Schedule and supported Progression; week/workout operations keep their local scope. |
| WF-08 | One Resume workout conflict destination, named active workout, Cancel and destructive replacement retained. |
| WF-09 | Empty workout uses its Add first exercise action; zero metrics/footer actions and irrelevant reordering are omitted. Discard/pause remain in options. |
| WF-10 | Final keyboard action explicitly says Complete set and asks the focused row to validate and persist its current draft, preserve automatic completion of the preceding valid set, and complete the final set through the existing completion/rest owner. Per-set completion identifiers support checking the actual final row. |
| WF-11 | History and Form & details are directly visible; optional settings are named Rest & progression. |
| WF-12 | Incomplete sessions open the existing review directly, with plan coverage and editable sets; removed obsolete intermediate prompt. Save and PR-publication boundaries remain. |
| WF-13 | Removing an exercise with entered/completed sets requires confirmation with its entered-set count; untouched removal remains immediate. |
| MS-01 | Submitted strength records become an expandable section on the compact Me overview. |
| MS-02 | Workouts opens history with an explicit Done action; lifetime PR-event count links to Strength without an explanatory modal. Hints match destinations. |
| MS-03 | Personal destinations use their content title; repeated athlete header collapses; private Strength has a direct Progress route. Personal sections remain accessible. |
| MS-04 | Removed the 20-result history ceiling and use a lazy list for all filtered matches. |
| MS-05 | History/submission filters use themed filled fields and explicit labels. |
| MS-06 | Separate photo/bodyweight operations have short save-boundary labels; earned status is disclosed. All profile fields remain. |
| MS-07 | Profile, submission, and gym-request forms protect changed drafts; profile/submission dismissal is blocked while saving/preparing media. |
| MS-08 | Bodyweight has one title and measurement date; shared selectors put the current selection first before searching. |
| MS-09 | Staged settings show Save, protect dismissal, retain failures, and separate immediate preferences. |
| MS-10 | Changed privacy uses explicit Save & preview, opening only after a successful save; preview identifies public visitor scope. |
| MS-11 | Video submission CTA belongs to the personal empty state, not visitor preview. |
| MS-12 | Settings uses categories for Units/Appearance; account actions are grouped; inapplicable demo Account is omitted. |
| MS-13 | Default Progress view and Auto-share eligible PRs publicly are explicit; rest formula moves into a disclosure. |
| MS-14 | Reminders and Rescheduling have separate groups, short next-alert/status wording, and Open iOS Settings. |
| MS-15 | Earned/other awards collapse; tiles open full requirements/date, use one column at accessibility sizes, and link a complete milestone timeline with plain non-action rows. |
| MS-16 | Submitted records open submission details; workout estimates open workout evidence. |
| MS-17 | Tier card is prepared as view data changes so the normal action is Share; preparation failure offers retry. |
| MS-18 | Sets group by workout and show set numbers; comparisons use preferred units while recorded values and submission prefill retain originals. |
| MS-19 | Actual/Estimated labels name 1RM, estimate stays by inputs, plate calculator remains named, video selection is secondary, audience is beside Submit. |
| MS-20 | Primary is status; Make primary/Join are positive actions, Leave is secondary, membership count and verified-three-lift metric are explicit. |
| FS-01 | All, Recommended, My communities identify feed scopes; community/friend destinations retained. |
| FS-02 | Searchable compact directory, About disclosure, explicit Leave and membership status; pending/banned changes disabled. |
| FS-03 | Current community and sort are visible with direct sort/clear actions. |
| FS-04 | Empty search uses actual filtered results; search/sort explicitly describe loaded discussions. Load more remains reachable with no matches. Server-wide search is not claimed. |
| FS-05 | Empty feeds offer Browse communities/New discussion/Clear search with scoped wording. |
| FS-06 | Recoverable feed errors preserve results and offer retry/refresh; unavailable threads stop loading and offer retry. |
| FS-07 | Composer requires an intentional community, displays audience at the top, and offers Join before publishing; pending/muted/banned status prevents submission. Server authority retained. |
| FS-08 | Successful publication opens the created discussion after composer dismissal, with an explicit Close that protects reply drafts; stable-ID retry remains. Feed cards use their full padded area as the touch target. |
| FS-09 | Edits have discard/length guards; replies retain account/post-scoped in-session drafts across navigation and reject over-limit text. No silent UI/store truncation. |
| FS-10 | Runtime frame checks reproduced a 78-point reply/tab overlap despite a hittable field. Forum now allocates separate layout space to its navigation stack and tab bar, respects the keyboard, and removes obsolete bottom spacer padding. Final focused tests and screenshots confirm the reply editor remains above the tabs on initial entry, after editing, and with the keyboard open; media viewer return also passed. Broader device/assistive coverage remains pending. |
| FS-11 | Successful votes update count and selection together; watch state loads from the existing owner-scoped watch table; reaction requests serialize. Local demo watches persist in session. |
| FS-12 | Public author lookup supplies names/avatars; unavailable authors are explicit; discussion title retains community context. |
| FS-13 | Feed video uses an attachment cue; explicit viewer Play starts playback. Bounded aspect-aware previews retain uncropped full-screen media. |
| FS-14 | Composer shows upload/publish progress, retry refreshes video access through one path, zoomed photos can pan, Edit explains attachment immutability. Progress is indeterminate, not measured upload percentage. |
| FS-15 | Sharing is explicitly discussion text. Public deep links/media export are not invented for private content. |
| FS-16 | Reaction/watch labels name state, touch targets enlarge, large-text comment controls reflow. VoiceOver speech still needs runtime assessment. |
| FS-17 | Report success has separate neutral feedback; recoverable reply/edit errors retain drafts. |
| FS-18 | Activity has a settings destination and truthful View profile wording; no unsupported lift result is invented. |
| FS-19 | Read-only sample threads no longer accept typing; sample reply counts match their three comments. Interactive local media fixtures remain isolated. |
| FS-20 | Ordinary Discussion badges and repeated thread counts removed; reply expansion is visible beside comments. |

### Earlier 38 partials reconciled for this pass

- **Implementation versus delivery:** N1 sender, S1 self-reported ranking migration, and S4 shared-stat/activity migrations remain undeployed. No environment confirmation was provided; this pass does not deploy them. Forum media rollout is separate and also pending.
- **Completed historical evidence:** the corrected phone unit suite passed 437/437; later focused Progress tests passed 8/8 and completion review/save/return passed 1/1. Earlier simulator failures or “not compiled” notes are historical, not current blanket failures.
- **Superseded presentation:** WF-01 replaces the six-decimal presentation described under X4 without changing locale parsing/canonical values. WF-10 replaces U4's explanatory final-set paragraph with a completion action. WF-11/12 and MS-13/14 replace repeated explanation while preserving W1/O1/O2/S2 save and publication boundaries.
- **Still open acceptance:** real notification delivery/cancellation/sound (N1–N4); isolated live audience/access checks (S1/S3/S4); real disk/process interruption and account upload restoration (O1/O2); rendered error/retry states (O3/S2); assistive-technology/large-text coverage (X1–X6); and measured full-page/large-history release performance budgets (P1–P3). Historical unit passes do not substitute for those checks.
- Focused Luna results are recorded below. Independent-user comprehension remains a later participant task, as previously requested. The separate PW-13 unfinished custom-plan draft item is not counted among these 53.

This pass introduces no new application files, dependencies, service layer, or database migration. Small additions within existing owners carry necessary UI state, shared workout-load formatting, account/post reply drafts, and authoritative watch state. New test results and any corrections belong below.


### Completed Luna verification and final disposition — November 1, 2026

Implementation changes are recorded for all **53 findings: 13 Workout, 20 Me, and 20 Forum**. This is not a claim that every live account, device, appearance, accessibility, failure, or interruption scenario has passed. The seven workflow checks combine several findings; they are not 53 separate acceptance tests.

GPT-6 Luna performed compilation and test execution after the source pass. The final Debug simulator build succeeded, using the staging backend and **Sign to Run Locally**, version 1.0 (49). Installed/tested artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Debug-iphonesimulator/LiftRank.app`. All execution used the disposable **Lift Rivals Workflow Audit** simulator (`29314C7C-986C-469F-ADCB-740870B6337D`, iOS 26.5). The user's original iPhone 17 simulator and its data were preserved. Demo fixtures did not publish to live accounts.

**14 distinct checks passed across the focused runs:**

| Coverage | Passed checks |
| --- | --- |
| 7 unit/regression cases | Compact workout weight formatting; current draft persisted before set completion; repeated finish creates one history entry; failed-save draft restoration; previous-account history response rejection; Forum media retry/edit/delete lifecycle; playable video preparation/upload fixture. |
| 7 UI workflows | Adaptive schedule preview; program-library preview at accessibility text size; Me Awards hierarchy; workout summary/save/dismiss; weight-first set entry and final completion; Forum author edit/delete/reply failure recovery; photo/video viewer and return. |

The initial runs exposed stale expectations for renamed preview/community/sample-video titles and removed intermediary prompts, plus intermittent initial automated tab/Resume taps. Tests now wait for their destination and allow one bounded retry. This does not establish reliable first-touch behavior on real cold launches; that remains part of the older navigation acceptance work.

Two real defects were corrected during this verification:

- The new final-set action initially bypassed automatic completion of the preceding valid set. It now persists the current draft, invokes the existing preceding-set rule, then completes the final set. Per-set assertions verify both set 2 and set 3, and the final screenshot shows **3/3** completed. The same screenshot confirms Prev displays both load and repetitions without the earlier truncation.
- The Forum reply editor overlapped the floating tab bar by **78 points**, despite XCTest reporting it as hittable. Forum now allocates actual layout space to the tab bar rather than relying on nested bottom safe-area insets. Initial-entry, edit-return, and focused-keyboard screenshots show the reply editor above the tabs. The final three affected UI cases passed **3/3 with zero failures**.

Evidence:

- Final build: `/tmp/liftrivals-audit53-fs10-build.log`.
- Final three UI cases: `/tmp/liftrivals-audit53-fs10-rerun.log`; result `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_02-00-41--0500.xcresult`.
- Earlier passing unit/UI cases: `/tmp/liftrivals-audit53-focused-ui.log`, `/tmp/liftrivals-audit53-final-tests.log`, and `/tmp/liftrivals-audit53-final-rerun.log`. These logs also retain superseded failures; use the per-case results and corrections above.
- [Reply editor on entry](/tmp/liftrivals-audit53-final-review-attachments/F5A0419B-28BE-4A74-BAF7-2A7FC70C878F.png), [reply editor with keyboard](/tmp/liftrivals-audit53-final-review-attachments/A26AC867-141F-41D0-A6CA-6D6A1CB4F5DB.png), [completed set rows and Prev](/tmp/liftrivals-audit53-final-review-attachments/0CE77B81-F9EC-45A1-B7FF-09BB6216967A.png).

**Remaining partials:** N1 notification sender rollout; S1 ranking migration; S4 shared-stat/activity migrations; and Forum media rollout require a confirmed environment and explicit deployment authorization. Real notification behavior, isolated live audience/privacy/storage access, disk/process interruptions and authenticated upload restoration, full appearance/contrast/VoiceOver coverage, independent-user comprehension, and release performance budgets remain open. Source implementation and the targeted passes above do not close those acceptance checks. PW-13 custom-plan draft work remains separate from these 53 findings.

No new files, dependencies, database migrations, or standalone architectural layers were introduced in this pass. Existing owners gained small shared formatting/tab-bar presentation helpers and necessary draft/completion/watch state. Final source review retained unrelated work; Luna's whitespace check passed.


### Physical-phone live-account review — November 1, 2026

The subsequent phone review initially installed Debug staging, so the user's production account could not sign in. This was corrected with the latest **Release, production-connected** build 1.0 (49), installed over `com.liftrank.app` on the physical iPhone 17 using the existing Apple Development identity/profile and development APNs entitlement. Apple sign-in remains enabled in this Release artifact. No app uninstall, data reset, project signing change, authentication-code change, or remote deployment was performed. The user then explicitly confirmed **“Signed in successfully.”** Session restoration and notification delivery were not tested in this correction.

Current physical-phone review artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphoneos/LiftRank.app`. Build/install evidence: `/tmp/liftrivals-iphone-production-build.log` and `/tmp/liftrivals-iphone-production-install.json`. Future live-account phone reviews should follow the production-environment instructions added to `docs/release-publish-runbook.md`; the earlier staging phone-install notes are historical. No new project file, abstraction, or dependency was introduced for this correction.

### Public-preview training-data permission error — November 1, 2026

The signed-in physical phone showed **Public preview → Couldn't load training data → You don't have permission to do that.** Read-only inspection of production (`ikjgbsrlriqiusuvezco`) established that authenticated callers have column-level SELECT access to lift fields, but not `bodyweight` or `bodyweight_class`, and no table-wide SELECT grant. The app used wildcard SELECT for lift reads. The playback helper functions have authenticated EXECUTE permission. The owner's public preview skips shared workout statistics, so the separately undeployed shared-stat RPC is not the cause of this error.

The correction uses one explicit field selection in the existing `CompetitiveLiftDTO` for all four lift request paths: recent lifts, paged profile lifts, lifts by ID, and submission return data. Restricted bodyweight fields are omitted; the existing optional decoding handles their absence. Evidence/removal-protection fields remain selected. Attempt details omit bodyweight-dependent rows when that value is unavailable, avoiding misleading zero values. No remote grants, policies, migrations, account data, or privacy settings were changed.

Luna's read-only production probe used the public client key, a dummy user ID, and `limit=0`: wildcard selection returned HTTP 401 / PostgreSQL `42501`; the new explicit projection returned HTTP 200 with zero rows. This confirms column-access compatibility without retrieving user data; it does not establish authenticated row visibility. One focused regression was added to the existing ranking test file to verify decoding without bodyweight while preserving lift values and protected-evidence handling. Both focused XCTest cases passed (the new decoding regression and the existing estimated-1RM/removal mapping case). Evidence: `/tmp/liftrivals-bodyweight-projection-tests.log` and `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_07-19-04--0500.xcresult`.

Luna built and installed the corrected **Release / production** artifact over the existing physical-phone app, then launched it successfully (process 40054). Version 1.0/build 49 uses the existing Apple Development identity/profile, team `32TGWTQNP8`, development APNs, and Apple Sign In entitlement. Artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphoneos/LiftRank.app`; evidence: `/tmp/liftrivals-iphone-production-latest-build.log` and `/tmp/liftrivals-iphone-production-latest-install.json`. No uninstall or data reset occurred, and the targeted whitespace check passed.

After the user initially described the updated screen as still showing an error, direct iPhone Mirroring inspection confirmed the permission banner was gone. Public preview displayed the normal **No public training data** state. The signed-in Me screen retained nine workouts, and Lift submissions displayed four records, each labeled **Private submission**. This explains the empty public preview without changing any sharing settings. The phone was left on the populated personal Lift submissions screen. This confirms the reported owner's preview flow; other accounts' audience rules and undeployed shared-stat features remain separate acceptance work.

No new files, dependencies, or architectural abstractions were introduced. The field-selection constant is shared by four existing requests to keep them consistent.

### Settings duplicate dismissal controls — November 1, 2026

The user's physical-phone screenshot exposed a missed navigation issue: Settings → Appearance displayed **Close**, a centered back arrow, and **Done** together. Close and Done both dismissed an unchanged form, while the back control occupied the page-title position. Earlier settings audit/implementation entries did not establish that this arrangement was correct.

The user selected **remove duplicates; keep navigation at the top**. Settings now has one Done action when unchanged. A category page places Back to Settings on the leading edge, retains its centered page title, and shows Done or Save according to its draft state. Cancel appears only at the Settings root when there are unsaved changes to discard. Back preserves the shared draft; save failures, discard confirmation, and swipe-dismiss protection retain their existing behavior. Theme/accent choices continue to apply immediately.

A source review of related profile, home, submission, and training-sheet controls found other Close/Done occurrences in distinct sheets or alerts rather than the same duplicate Settings toolbar. This is a bounded source review, not a new all-screen visual acceptance claim. The existing Settings navigation UI test was extended to cover the reported Appearance header, theme/accent return paths, and dirty Privacy draft/save navigation.

The first focused run exposed a real false-dirty state: untouched Settings could show Cancel/Save because the previous comparison included privacy-derived profile flags rather than just edited preferences. Change detection and the save entry point now use the same comparison of units, effective saved training focus, and privacy. The existing legacy training-focus lookup is shared inside Settings so loading and comparison agree. Unchanged Done no longer submits incidental profile normalization. The initial failed run is not counted as a successful verification.

Luna's corrected focused Settings flow passed **1/1** on the disposable Workflow Audit simulator. It verified clean-root Done, Appearance Back/title/Done without Close, native Back-only theme/accent subpages, preserved Privacy drafts on Back, and saved Privacy values on reopening. Both Luna and the implementation agent inspected the [Appearance screenshot](/tmp/liftrivals-settings-appearance-review/9C58A029-7153-4547-9852-259C4CFF68AE.png). Test log: `/tmp/liftrivals-settings-appearance-test-rerun.log`; result: `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_07-33-21--0500.xcresult`. Large-text and VoiceOver coverage are not claimed by this standard-text run.

The final **Release / production** phone build succeeded, retaining build 49 and the existing development signing/profile, development APNs, and Apple Sign In entitlement. Luna installed it over the existing `com.liftrank.app` and launched it on the iPhone 17 without uninstalling, resetting data, or attempting sign-in. Artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphoneos/LiftRank.app`. Evidence: `/tmp/liftrivals-settings-final-iphone-release-build.log`, `/tmp/liftrivals-settings-final-iphone-install.json`, and `/tmp/liftrivals-settings-final-iphone-launch.json`. The targeted whitespace check passed. Layout/navigation verification used the isolated simulator; the updated physical-phone Settings screen was not re-inspected because the phone was in use.

No new files, abstractions, or dependencies were added. The change stays within the existing Settings toolbar and its existing UI test.

### Settings automatic saving — November 1, 2026

The user subsequently requested automatic saving. This supersedes the manual Save/Cancel contract described above and the older MS-09 staged-settings recommendation. Units, default Progress focus, and Privacy now save on selection through the existing profile service. Appearance, training switches, and reminders retain their existing immediate behavior. Settings shows Done to dismiss and Back to navigate; it no longer presents a Save action or asks the user to save before public preview.

The existing Settings owner serializes profile saves, briefly disables controls/dismissal while a request is active, and submits any newer selection already queued by a control after success. It does not retry an unconfirmed server value indefinitely. Failed or unconfirmed saves retain the chosen values, show an error and Retry, and require an explicit discard decision before closing with unsaved changes. Public preview waits for confirmed settings. Returning to the already-saved values clears the settings error without another write. Opening an unchanged screen does not save.

The existing Settings UI test now exercises one simulated save failure, retained selection, discard protection, retry, and Training/Privacy/Units persistence after reopening without tapping Save. A one-shot flag in the existing demo profile service supplies that failure; no live settings are changed by the test. Luna's result is recorded below.

The initial autosave run reached the expected failure state and retained the selected focus, then exposed that the native discard confirmation presented only Discard changes in its accessibility hierarchy. The Settings discard prompt now uses a two-action alert so Keep editing remains an explicit, accessible choice. That failed run is not counted as a pass; the same focused flow must pass before the phone is updated.

The next run progressed through failure/retry, Training and Privacy persistence, and a Units change, but a tap did not reopen Units at the final verification step. The Settings category labels now declare their full row as the touch target, including the spacer. The test also waits for the Settings root after returning from Privacy. No tap-retry loop was added to this Units check; the full flow remains pending until it passes.

The final Luna run passed **1/1 with zero failures**, including the error/Retry/discard path and automatic Training, Privacy, and Units persistence after reopening. Result: `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_07-57-17--0500.xcresult`; log: `/tmp/liftrivals-settings-autosave-ui-rowtap.log`. The [Training screenshot](/private/tmp/liftrivals-settings-autosave-success-attachments/AD8C69AE-188A-4BD1-97E5-F2FD9D9139C2.png) shows Back, the centered title, and Done after the automatic save. This is a focused demo check; no live privacy changes or broader acceptance pass is claimed.

Luna completed the signed **Release / production** build, version 1.0/build 49, using the existing Apple Development identity/profile and development APNs/Apple Sign In entitlements. Artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphoneos/LiftRank.app`; build log: `/tmp/liftrivals-settings-autosave-release-generic.log`. The targeted whitespace check passed. Final device discovery reported the iPhone 17 **unavailable**, so this autosave build has **not been installed**; the prior manual-save phone build remains installed. A reconnect/unlock request is pending with the user. No app uninstall, data reset, or live settings mutation occurred.

No new files, service layers, or dependencies were added. Existing manual-save helpers and the failed-request snapshot were removed; automatic saving remains in the existing Settings owner and calls the established profile service.

### Powerlifting preference reverting — November 1, 2026

The user reported that Settings → Training → Default Progress view did not retain Powerlifting. This exposed a separate account-mapping bug beyond the manual-save/autosave UI: `ProfileStore.applyAuthenticatedProfile` copied the returned profile fields but omitted `trainingFocus`. A successful account save or refresh therefore retained the previous local focus. The missing field assignment is now included in the existing authenticated-profile mapping.

A read-only inspection of `public.save_own_profile_mobile(jsonb)` in LiftRank Production (`ikjgbsrlriqiusuvezco`) confirmed that its deployed function already assigns `profile_private_details.training_focus` from `new_training_focus` for the authenticated caller. The client also sends and decodes that field. No server data, permissions, or migrations were changed; this metadata check is not a claim of a live-account save test.

The existing training-focus persistence unit test previously shared one repository between its local store and mock server, which concealed the missing assignment. It now uses separate repositories, checks each focus after saving and after refreshing a stale local value, and verifies that a server-side unset focus clears the local value. The older-cache decoding check remains. Luna owns the focused test and final phone build; results and installation status follow below.

Luna's focused persistence test passed **1/1 with zero failures**. Result: `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_08-33-09--0500.xcresult`; log: `/tmp/liftrivals-training-focus-test.log`. This verifies the authenticated profile-store path with separate local/mock-server state, including Powerlifting, and does not claim a live-phone save.

The final **Release / production** build succeeded and includes both the profile-mapping correction and automatic Settings saving. It retains version 1.0/build 49, the existing Apple Development identity/profile and team `32TGWTQNP8`. Artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphoneos/LiftRank.app`; log: `/tmp/liftrivals-training-focus-release.log`; executable SHA-256: `9de0ff15904a391b724939446d4df24adb9f3758269ad8b8e6c0c5404a889724`. The final device check still reported the iPhone 17 unavailable, so this build is **not installed**. No uninstall, data reset, or live preference mutation occurred.

No new files, abstractions, or dependencies were introduced. The production correction is one assignment in the existing profile owner.

### Training data appearing late on first open — November 1, 2026

The user reported that programs, rewards, and other information take time to populate after a fresh install or update. Source inspection found that the selected program was restored only after a server plan request, even when its data was already cached. The startup sequence also waited for analytics/push registration and profile-photo caching before scheduling another refresh with a fixed two-second delay. Completed workout history was fetched during that refresh only under a debug test flag; a normal first launch could miss the foreground trigger while authentication was still restoring, leaving history-dependent rewards to populate after a later navigation or foreground event.

The existing account owner now selects the cached active program before exposing the authenticated screen. Its post-authentication task immediately starts plan sync, history sync, and production account data refresh together, with no fixed two-second pause. History-derived awards update as history arrives; awards are also refreshed after the initial requests complete. Analytics and push registration run after the training requests, and profile-photo caching no longer delays their start. Accepting required legal documents also starts this same refresh. Returning to the foreground starts plan/history refreshes together and uses the stores' existing passive refresh interval to avoid back-to-back downloads; explicit retry and edit-triggered sync retain their forced behavior.

One focused test covers both an empty local cache and an existing cache. It holds the plan response while verifying that workout history and the First Workout award populate independently, checks that an existing active program is already selected, and confirms selection after the server plan arrives. It reuses the existing gated plan-sync test service. Luna is also checking the existing sign-out-during-profile-restoration regression; no broad suite or live-account data reset is requested. Results and final installation status follow below.

The first run failed the new test because its workout fixture contained no completed working set (correctly ineligible for First Workout) and the gated plan service threw a configuration error for every save. The fixture now contains one completed bench-press set, and that existing test service implements successful plan saves. The sign-out regression passed in this initial run; the overall failed run is not counted as successful startup verification. Log: `/tmp/liftrivals-startup-tests.log`; result: `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_08-46-42--0500.xcresult`.

The corrected Luna run passed **2/2 with zero failures**, covering empty/existing cache restoration and the sign-out guard. Log: `/tmp/liftrivals-startup-focused-rerun.log`; result: `/tmp/liftrivals-startup-focused-rerun.xcresult`. The signed **Release / production** build also passed (`/tmp/liftrivals-startup-release.log`). Artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphoneos/LiftRank.app`; executable SHA-256: `aa33a4208927b2cf0e0d4db4294e5849733564c28696decc3cb345a36cb2b7af`. It retains build 49, the existing Apple Development identity/profile, development APNs, and Apple Sign In entitlement. The final single device check reported the iPhone 17 unavailable, so this build has **not been installed**. Targeted whitespace review passed.

No new files, production abstractions, or dependencies were added. A clean install still requires an initial network download; no live-network timing improvement is claimed from these isolated tests.

### Apple Human Interface Guidelines alignment — November 1, 2026

The user requested alignment with Apple's guidelines while retaining all features and Lift Rivals' identity. This is a targeted implementation and verification pass, not a claim of Apple certification or universal compliance. Current references: [tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars), [sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), and [loading](https://developer.apple.com/design/human-interface-guidelines/loading).

| Area | Change in this pass | Verification boundary |
| --- | --- | --- |
| Primary navigation | Replaced the active custom navigation with native `TabView`. Home, Rankings, Track, Forum, and Me retain their own stacks. Tabs remain available in ordinary Me detail navigation. Public preview pushed from Me uses native Back. Tracker keeps its requested section synchronized when internal actions switch sections. | Focused standard/large-text navigation and tab-return checks assigned to Luna. Full-screen active workouts remain a deliberate modal flow. |
| Settings navigation | About/legal information and Public preview push within the existing Settings stack. Preview's Privacy action returns to the same Privacy screen. One Close action dismisses autosaving Settings; Back moves within it. Failed-save retention, retry, and discard protection remain. | This supersedes the prior Done-label evidence above. Theme/accent children and information pages should have native Back without duplicate dismissal actions. |
| Text and controls | Shared action rows, primary/secondary/compact buttons, headings, empty-state actions, and small text badges use Dynamic Type styles. Metric-card hero values use `ScaledMetric`. Onboarding/legal back controls and training-experience steppers have 44-point targets. Exercise letter navigation uses a native menu with one 44-point target instead of tiny stacked letter buttons. Me no longer reserves the old custom-tab clearance. | Exported share-card typography and decorative symbol sizes remain fixed by design. Largest-text verification is representative, not a complete screen/state audit. |
| Motion | Explicit SwiftUI animations in onboarding, legal expansion, tracker/progress/library/plan cards, profile, rankings, forum scrolling, completed workouts, and set tracking now respect Reduce Motion. Shared button press scaling also respects it. | Native transitions are system-owned. This is source coverage of explicit animations, not a claim of manual Reduce Motion testing on every screen. |
| Initial loading | The existing account owner publishes initial training-refresh state. Empty Plans and Awards show concise progress feedback until their data arrives; existing earned awards remain visible. An empty awards collection with failed history sync shows an error and Retry rather than a zero result. Sign-out clears initial loading state. | Existing gated startup test now also checks the loading-state lifecycle. Initial network download is still required on a clean install. |
| Theme contrast | Retained all accent fills. Darkened several Light accent text tones, Classic secondary text, and selected Navy/Forest dark surfaces. Filled button and badge foregrounds now explicitly contrast with their fill. | Luna's numeric solid-token contrast matrix is recorded below. Opacity, system materials, charts, photos, disabled states, and every rendered combination still require visual/accessibility review. |

No new files, services, abstractions, or dependencies were introduced for this pass. The old custom tab implementation already contains unrelated uncommitted work; it is no longer used by `MainTabView` and is preserved rather than deleting that work.

Remaining acceptance work before describing the app as consistently aligned: full VoiceOver reading/focus/rotor order and announcements; Switch Control and external-keyboard navigation; small-phone and landscape layout coverage; each supported theme in rendered Light/Dark/System and Increase Contrast; and modal/deep-link workflows outside the Settings paths changed here. Existing pending live-account, notification, privacy/storage, and interruption checks in earlier audit sections remain pending. Independent-user comprehension is also unverified. Neither a successful build nor a handful of UI tests closes these items.

Luna's initial build-for-testing succeeded. The initial focused run passed **4 of 5 cases**: startup loading/cache restoration, Forum author editing/deletion and reply keyboard clearance, native tabs at the largest accessibility text size, and Settings automatic-save failure/retry plus preview/About navigation. The Me/Awards tab-return case failed with the app at Me root. That run did not establish whether the Home tap had actually switched tabs, so it does not by itself prove a path-persistence defect. Evidence: `/tmp/liftrivals-hig-focused-tests.log` and `/tmp/liftrivals-hig-focused-tests.xcresult`.

Luna added an explicit assertion that Home became selected before returning to Me. The first diagnostic attempt stopped before XCTest bootstrapped (`/tmp/liftrivals-hig-me-diagnostic-retry.log`); it is not counted as an app crash or successful test. After restarting only the isolated Workflow Audit simulator, the diagnostic passed **1/1**, including Home selection, return to the existing Awards stack, public preview, and Back. No production navigation workaround was introduced. Evidence: `/tmp/liftrivals-hig-me-diagnostic-after-reboot.log` and `/tmp/liftrivals-hig-me-diagnostic-after-reboot.xcresult`. All five targeted cases therefore have passing evidence across the completed runs, not one uninterrupted five-case pass. No simulator erase, uninstall, or live-account sign-in occurred.

The implementation agent visually reviewed the exported [largest-text Me screen](/tmp/liftrivals-hig-all-attachments/B54951C7-4E28-47EE-9C15-03F1D856034C.png), [Training settings](/tmp/liftrivals-hig-all-attachments/13EA52D5-B845-4250-ADB4-4BBB14DEF71B.png), and [Forum reply with keyboard](/tmp/liftrivals-hig-all-attachments/924BD521-1F0D-488C-ACB8-5ECDC2ACD5A7.png). Native tabs remained available at the largest text size, Training had Back/title/Close without Save, and the reply field remained above the keyboard. These screenshots use the test's Classic appearance; they are not visual proof for every theme or screen.

The numeric contrast review covered four palettes in Light/Dark, six solid surfaces, primary/secondary text, eleven accents, and seven semantic status/evidence colors. After the changes, the checked normal-text combinations meet 4.5:1. Primary text minimum is 5.94:1; secondary text 4.57:1; accent text 4.58:1; semantic text minimum 4.53:1 (Silver). Dark button text on the eleven accent fills has a minimum of 7.40:1. Light red badges use white text and Dark red badges use dark text. The final semantic-color changes were made after the workflow UI run and compiled successfully in the final Release and Debug builds; rendered opacity/material combinations remain outside this numeric result. Calculation record: [contrast results](/tmp/liftrivals-hig-contrast.txt).

Luna's final signed **Release / production** build succeeded (`/tmp/liftrivals-hig-final-release.log`). Artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphoneos/LiftRank.app`; bundle `com.liftrank.app`, version 1.0/build 49, production backend `https://ikjgbsrlriqiusuvezco.supabase.co`, existing Apple Development identity/profile and team `32TGWTQNP8`, development APNs and Apple Sign In entitlement. Executable SHA-256: `b107b807676255457cfd9ad74636a7bcc49cbfc48ebb5b6e63c4ecadde5a8dce`. The physical iPhone was unavailable; no installation was attempted.

The final **Debug / staging-configuration** build-for-testing also succeeded (`/tmp/liftrivals-hig-debug-final-build.log`), including the updated native-tab/Settings test locators. It was installed in-place in the isolated Workflow Audit simulator (`29314C7C-986C-469F-ADCB-740870B6337D`) and launched with `-uiTestingDemoMode`, which uses isolated demo services. No real sign-in was attempted. The [final simulator screenshot](/tmp/liftrivals-hig-debug-simulator.png) shows the latest app on demo Home. This simulator artifact is not the production phone artifact. Final whitespace/diff review passed; no unrelated work was reset or removed.


## Apple platform alignment — November 1, 2026

Scope: the seven additional Apple guidance areas requested after the HIG pass.
The existing HIG improvements above remain in place. This is an implementation
and evidence record, not a declaration of App Store approval or complete
accessibility conformance. Preserve all existing workout, social, and media
features. Implementation precedes focused validation by GPT-6 Luna.

| Area | Finding and change in this pass | Remaining acceptance |
| --- | --- | --- |
| App Review / user content | Forum post and reply menus now expose Block author directly, with confirmation and visible failure. Successful blocks hide cached posts/replies immediately even if refreshing the block list fails. Posting rules and support are available in the composer; text and media reports have a clear inappropriate-content reason. Existing ownership, membership, report, and moderator protections remain. | Screening before publication is absent. Owner selected a screening service; Sightengine rollout below is not implemented or activated. Reports/appeals still need an operational owner and response process. Confirm live account deletion, reviewer access, latest backend migrations, age-rating answers, and interruption recovery against the release candidate. |
| Accessibility | Larger-text set entry now stacks labeled weight and reps/duration fields. Previous values no longer cap Dynamic Type. Set options adapt vertically; warm-up and delete targets are at least 44 points. Set numbers and completion controls announce the set and completion state. Screenshot review also found a clipped large-text rest countdown and split +30s/Skip buttons; the banner now uses two rows at accessibility sizes, exposes descriptive action labels, and omits redundant successful-alert copy. Prior native tabs, semantic fonts, contrast tokens, and Reduce Motion changes are retained. | Full VoiceOver focus/rotor/announcement and Voice Control task evaluation, Switch Control/keyboard, small phone/iPad compatibility, and all rendered themes remain open. Do not claim an Accessibility Nutrition Label from selected automation alone. |
| Privacy | Production analytics now requires an explicit account/device opt-in, default off, checked at the production service boundary so competition events cannot bypass it. Settings explains that the data includes account ID and training activity. Removed unused camera/full-photo-library permission declarations; all current media selection uses PhotosPicker. Updated metadata to include forum media. | Optional analytics must still be disclosed. Confirm actual provider logging/retention and reconcile App Store Connect purposes. Public legal-page publication remains blocked. Sightengine needs processor review, updated disclosure, and explicit user permission before any content is sent. |
| Performance / efficiency | Cache the generated rest tone instead of rebuilding it on every alert. Use ambient audio, preserving silent mode/music, and release the audio session after playback. An Initial training sync signpost measures plan/history/competition/inbox restoration separately from first navigation. Existing cached data and parallel startup refresh are preserved. | Measure on a signed production device under cold/warm/poor-network conditions; profile main-thread work, long-session memory, media, and energy. A simulator build or one launch measurement does not establish a battery/performance threshold. |
| UX writing | RPE guidance moves behind What is RPE?; the logging actions remain visible. Home's greeting uses normal casing and wraps instead of truncating spaced uppercase text. Removed redundant immediate-save copy in Notifications and duplicate iOS settings entry. Posting rules are expandable. | Repeat comprehension walks on Plans, logging, Progress, Me, and Forum with independent users; the earlier expert walkthrough is not user research. Retain necessary privacy/evidence/error explanations rather than deleting them to reduce word count. |
| Notifications | Sign-in no longer triggers the push permission prompt. Settings offers Enable notifications, permission status, a system-settings route, and registration-error retry. APNs environment comes from the signing setting, fixing development-signed Release tokens previously labeled production. Non-rest foreground notifications refresh the inbox quietly; foreground rest alerts honor the iOS sound setting. Workout/rest visible bodies omit names; delivered alerts clear with account state. Server payload uses a generic update and notification-ID collapse key. | Server payload changes are local only. Verify entitlement/token/backend alignment and permission-denial recovery on a signed device, delivery under Focus/mute/music, cold routing, account switch, retry behavior, and sound settings. Collapse IDs are not exactly-once delivery. Remote preference expansion remains the previously documented backlog. |
| Product page / marketing | Corrected reviewer directions for account settings, system photo picker, notification permission, and forum actions. Added current privacy/media and accessibility claim gates. Website source describes logging/evidence and keeps verified results distinct from personal records. Terms source now matches existing native wording in the introduction and sections 5 and 14; native legal terms/version were not changed. No Apple badge is fabricated or unverified capability advertised. | Publish only screenshots from the exact release candidate with fictional data; verify the selected build, age rating, public links, privacy purposes, accessibility labels, and legal pages in App Store Connect. No website or App Store metadata was published in this pass. |

### Selected screening direction: Sightengine

The owner chose a service instead of mandatory human approval for every post.
Sightengine is the selected direction because its documented APIs cover text,
visual content, embedded text, and audio under one provider. Hive was also
reviewed, but its recommended synchronous video segments are shorter than the
app's current two-minute upload allowance. This is a fit assessment, not a
measured accuracy comparison. No user content was sent to either provider.

As checked November 1, Sightengine Starter is $29/month with 10,000 operations,
50 MB videos, one concurrent video job, and 1 request/second. **Pro is the
recommended plan for complete video coverage**: $99/month with 40,000 operations,
audio moderation, five concurrent video jobs, and 10 requests/second. Both list
$0.002 per additional operation. Operations are not posts: multiple models and
sampled video frames consume multiple operations. Free does not cover the full
video path. No subscription was purchased. Final budget, rate limits, retention,
processing region, DPA/subprocessors, and account terms need owner confirmation.

Concrete integration required before closing the App Review finding:

1. Configure a provider account and a staging project. Keep provider keys and
   callback verification secrets only in server secrets. Use separate staging
   and production secrets; do not place them in the iOS bundle or send them in
   chat. Approve spending limits before enabling traffic.
2. Submit through the existing Forum service and a server endpoint. Authenticate
   the caller, check membership/ownership, and rate-limit before paying for a
   scan. Accept only owned private storage objects; never fetch a user-supplied
   arbitrary URL. Bind the result to the exact text/media revision and owner.
   Newly submitted and edited content stays unpublished until screened; a
   timeout or provider failure preserves the draft and offers Retry.
3. Screen text and photos, including embedded text. Use asynchronous video
   jobs for the current two-minute/50 MB feature, with visual and audio coverage.
   Sightengine's synchronous video path is limited to 60 seconds, so shortening
   uploads or silently scanning only a thumbnail is not an acceptable shortcut.
   Use short-lived private media URLs and only the content necessary for the
   scan; do not send profile details, account email, or private workout history.
4. Authenticate callbacks, reject test-mode/forged/stale callbacks, and make
   completion idempotent. Require finished results for every configured check;
   an ongoing callback is not approval. Keep service failure distinct from a
   content rejection. Store the verdict and current revision, not unnecessary
   copies of sensitive provider payloads. Limit retained rejected media under
   the approved retention policy and account-deletion workflow.
5. Add a forward-only database guard so direct client writes, edits, old app
   versions, and storage URL access cannot bypass screening. Include cached
   feeds, public/profile media, lift evidence, and forum replies in the exposure
   review; protecting only the composer is insufficient. Run real local SQL
   security tests for owner/non-owner/anonymous/moderator/service roles before
   requesting permission to deploy to a specifically confirmed environment.
6. Use clear draft/checking/published/needs-changes/error states, without losing
   text or media on failure. Calibrate against normal lifting footage, exposed
   torsos/sportswear, training slang, spam, harassment, explicit media, and
   threatening content. Retain human report review and appeals for false
   positives; do not equate a model score with an infallible safety judgment.
7. Before enabling the service, disclose Sightengine and the content shared,
   obtain explicit permission, update/version the relevant legal notice, and
   align App Store privacy answers. The existing AI coaching exclusion remains:
   this service is limited to community safety. No new processor is currently
   active and no data-sharing consent is implied by choosing a vendor here.

Sources: [Sightengine text](https://sightengine.com/docs/text-moderation-introduction),
[video workflow limits](https://sightengine.com/docs/video-moderation-workflows),
[callbacks](https://sightengine.com/docs/receive-video-moderation-callbacks),
[audio](https://sightengine.com/docs/audio-moderation-model),
[pricing](https://sightengine.com/pricing),
[security](https://sightengine.com/security), and
[Hive visual API](https://docs.thehive.ai/docs/visual-moderation-api).

Apple references checked November 1:
[App Review](https://developer.apple.com/app-store/review/guidelines/),
[Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/),
[data use](https://developer.apple.com/app-store/user-privacy-and-data-use/),
[performance](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance/),
[UX writing](https://developer.apple.com/videos/play/wwdc2025/404/),
[notifications](https://developer.apple.com/design/human-interface-guidelines/notifications),
[product page](https://developer.apple.com/app-store/product-page/), and
[marketing](https://developer.apple.com/app-store/marketing/guidelines/).

### Verification for this pass

Luna's initial seven-case run passed all four unit cases (analytics consent and
account isolation; APNs signing-environment mapping; token registration/error
propagation; successful blocking with a failed refresh) and the Forum author
edit/delete and Settings autosave/preview UI cases. The accessibility keyboard
case failed because it expected the second and third native List rows to remain
instantiated simultaneously. Set 2 was absent from the accessibility query,
not present with an incorrect completion label. This requires sequential scroll
assertions rather than weakening the completion expectation.

The implementation agent reviewed the failed screenshot and found a real,
separate issue: the large-text rest countdown was clipped, +30s and Skip broke
across lines, and a long success-status sentence consumed the upper screen.
That banner was corrected before requesting a focused rerun. Initial evidence:
`/tmp/liftrivals-apple-focused-tests.log`, `/tmp/liftrivals-apple-focused.xcresult`,
and `/tmp/liftrivals-apple-attachments/728B80EC-6A59-4C4A-A753-B45378275CB6.png`.
Settings' XCTest dismissal measurement averaged 2.250 seconds over three
iterations; this includes automation waiting and is not a cold-launch or
on-device responsiveness result.

The corrected AX keyboard case passed **1/1** in
`/tmp/liftrivals-apple-ax-rerun.log` after rebuilding the current source. The
check confirms both rest actions are available, skips rest, then scrolls to
verify set 3 and set 2 completion separately. All seven selected cases now have
passing evidence across the completed runs; this was not one uninterrupted
seven-case pass. The implementation agent reviewed the new
[rest banner](/tmp/liftrivals-apple-ax-attachments/77D13AC7-7BA4-4ACC-9058-7B90CEA11F6D.png):
countdown, +30s, and Skip are readable without the prior clipping. Large-text
set entry and the standard Training settings screen were also reviewed. Full
assistive-technology and all-theme evaluation remain open.

Final Debug build-for-testing succeeded:
`/tmp/liftrivals-apple-debug-final-build.log`. The app was installed in place and
launched with demo services on isolated Workflow Audit simulator
`29314C7C-986C-469F-ADCB-740870B6337D` (PID 82535). The implementation agent
reviewed [latest demo Home](/private/tmp/liftrivals-apple-demo-latest.png).
No real account sign-in, simulator data erase, or phone install occurred.

Final Release build succeeded: `/tmp/liftrivals-apple-release-build.log`.
Artifact: `/tmp/liftrivals-catalog-derived/Build/Products/Release-iphoneos/LiftRank.app`,
version 1.0/build 49, production backend
`https://ikjgbsrlriqiusuvezco.supabase.co`, Apple Development signing with team
`32TGWTQNP8` and app ID `32TGWTQNP8.com.liftrank.app`. Built Info.plist APNs
value and signed entitlement are both `development`, correctly mapping this
provisioned Release to sandbox APNs. Apple Sign In entitlement is Default.
Executable SHA-256:
`1b1dc2fc523fce8595f0fb531a42dc2e8c18286f9ac89af05bfa8626055ded5c`.
Strict signature verification initially reported `CSSMERR_TP_NOT_TRUSTED` in
the restricted shell. The identical read-only check with elevated access
passed: valid on disk and satisfies its designated requirement. No keychain
or certificate changes were made. The physical phone was unavailable.

All 14 website/native Terms sections match exactly. The existing metadata gate
correctly remains failed with one aggregate blocker for the documented live
release gaps (`/tmp/liftrivals-apple-metadata-check.log`). Deno is not installed,
so the Edge Function was source-reviewed but not type-checked or deployed.
The optional extra launch-performance measurement was not run. Final diff
whitespace review is clean; unrelated uncommitted work remains intact.

No new files, service abstractions, SQL/RLS/grant/trigger changes, or runtime
dependencies were added. Existing AnalyticsStore/NotificationStore own the small
shared consent/signing helpers. Two private ForumThreadView expression boundaries
were necessary to resolve SwiftUI type-check complexity after adding safety
controls; no new view type or architecture was introduced. No remote migration,
screening-provider activation, website publication, or App Store submission occurred. The before-edit snapshot
for this pass is `/tmp/liftrivals-apple-alignment-baseline`; use it to distinguish
these changes from the much larger existing uncommitted implementation.

## Reddit-inspired forum layout and interactions — November 1, 2026

The user chose **layout and interactions**, and separately confirmed that admin
must remain the final moderation authority. This pass does not change roles,
permissions, moderation policy, or the pending screening-provider decision.

### Interface changes

- Removed the duplicate filter sheet. Community selection now uses the existing
  searchable directory, with an All communities action; sorting is directly in
  the feed. All, Recommended, and My communities remain available. Selecting a
  specific community switches to All so an unjoined community is not silently
  excluded by the previous feed choice.
- Feed posts now separate community navigation, discussion navigation, media,
  voting, comments, and text sharing. Upvote/downvote controls toggle and switch
  votes directly in the feed; failures remain visible. The card updates after
  successful writes without jumping to a new position under the user's finger.
  Refresh retrieves current ranking data. Search and sorting still operate on
  loaded discussions; no global Reddit-style ranking or search is claimed.
- Photos and videos open directly from compact feed previews. Videos do not
  autoplay in the feed. Existing full-screen viewers, posting, editing, deletion,
  draft protection, reporting, and blocking remain available.
- The comments action opens the comment section. Comment headers collapse the
  comment and its descendants; replies use indentation and thread lines, with an
  OP label for the post author. Reply focuses the composer. Locked discussions
  disable replying. A notification's highlighted comment retains priority over
  the comments shortcut, and automatic scrolling happens only on initial entry.
- Feed touch targets are at least 44 points. Controls stack at accessibility
  sizes; selected votes and collapsed threads have explicit accessibility state.
  Existing Lift Rivals themes and accent colors are preserved.

References used for interaction concepts:
[Reddit voting](https://support.reddithelp.com/hc/en-us/articles/7419626610708-What-are-upvotes-and-downvotes),
[feed descriptions](https://support.reddithelp.com/hc/en-us/articles/360043043552-What-s-the-difference-between-r-all-r-popular-news-and-my-home-feed),
and [community settings](https://support.reddithelp.com/hc/en-us/articles/15484546290068-Community-settings/).

### Admin capability gap — open

The admin hierarchy is a product requirement, **not a claim that a complete live
admin workspace already exists**. Source inspection found:

- SQL defines a global Admin check, admin access to forum reports and moderation
  records, and post pin/unpin, lock/unlock, remove/restore operations. The client
  service exposes reports and post moderation, but ForumStore and the forum UI
  do not expose an operational moderation workspace.
- `ModeratorReviewView` explicitly supports demo lift review only and displays
  “Live moderation is unavailable from this screen” outside demo mode.
- No complete in-app workflow was found for assigning/removing community
  moderators, reviewing their decisions, resolving appeals, administering user
  restrictions, or managing communities as a global admin. Those capabilities
  need explicit implementation and runtime permission checks before being marked
  complete. This pass does not verify the live account's assigned role.
- The current `can_moderate_forum_community` helper includes global admin, but
  other visibility rules still restrict blocked/private content. The older
  `moderate_forum_post` routine has its own membership check. These paths require
  a unified authority review before promising universal admin oversight.

Future admin work must keep community moderators scoped to their communities,
reserve role management and final moderation overrides for admin, and record
privileged decisions. This is application-level authority; it does not require
shipping database superuser or service-role credentials in the app. No additional
admin or moderator privileges were granted in this layout pass.

### Scope and verification

The before-edit snapshot is `/tmp/liftrivals-reddit-forum-baseline`.
Implementation uses existing ForumViews, ForumStore, and ForumMedia owners.
No new files or dependencies were needed. One private `ForumVoteControls` view
shares the feed/thread vote presentation, and one ForumStore method shares the
vote-toggle update logic. No database migration or remote deployment occurred.
Luna's initial Debug build-for-testing succeeded, and the four selected cases
passed: vote transitions/invalid-action handling, largest-text navigation and
community selection, photo/video viewing, and author edit/delete with comments
navigation, collapse/expand, and reply-draft protection. Evidence:
`/tmp/liftrivals-reddit-forum-build-final.log`,
`/tmp/liftrivals-reddit-forum-focused.log`, and
`/tmp/liftrivals-reddit-forum-focused.xcresult`.

Visual review of `/tmp/liftrivals-reddit-forum-attachments/` found an additional
large-text directory issue despite passing interaction assertions: a decorative
community icon grew outside its fixed circle and the All communities row wrapped
poorly around its icons. The implementation now omits the decorative community
avatar at accessibility sizes and gives the All communities text more width.
The standard thread and media-return screens were readable, and the reply editor
remained above the native tab bar. The visible “1 comments” label was corrected.
The final Debug test build succeeded, and the focused two-case rerun passed
**2/2**: the media flow now also taps upvote, switches to downvote, removes the
vote, and opens a photo directly from the feed; the largest-text case checks the
corrected community directory. Evidence:
`/tmp/liftrivals-reddit-forum-final-build2.log`,
`/tmp/liftrivals-reddit-forum-final-ui.log`, and
`/tmp/liftrivals-reddit-forum-final-ui.xcresult`.
All four selected cases have passing evidence across these runs. The full test
suite and live moderation checks are outside this pass.

Final screenshot review confirmed that the large-text directory no longer has
the overlapping glyph or split word, and the standard Light-appearance feed
shows the community/sort controls and independent vote/comment/share actions
without clipping. Screenshots:
`/tmp/liftrivals-reddit-forum-final-attachments/BB1FE891-3C54-4A5D-AA93-738DBE24664E.png`
and `/private/tmp/liftrivals-reddit-forum-final-feed.png`.
The latest Debug demo is installed and open at Forum on the isolated Workflow
Audit simulator `29314C7C-986C-469F-ADCB-740870B6337D`. No real account sign-in,
phone install, or live content mutation occurred. Final diff review is clean.

## Forum advertising direction — November 1, 2026

**User direction:** focus ads on the Forum using Reddit-style promoted posts
within the feed. This is the placement plan; AdMob is not integrated or enabled.

- Use AdMob native ads between discussion cards, styled with Lift Rivals' current
  typography, spacing, themes, and accents. Display the supplied advertiser,
  headline, image/video, and call to action as available and required by format.
- Clearly label each ad **Sponsored** and preserve visible AdChoices. A
  “Promoted” label alone is not the attribution specified by AdMob. Ad assets and
  advertiser actions must use the SDK's native presentation/click handling;
  do not turn padding or forum navigation into ad click targets. Do not invent
  votes, comment counts, verification badges, or community membership for ads.
- Proposed initial frequency: first ad after five organic posts, then after
  every ten additional organic posts. This is a starting product recommendation,
  not Reddit's measured frequency or a user-approved numeric requirement.
  Keep placement stable while scrolling, voting, and loading another page.
- Initial scope: Forum discussion feeds only. Keep workout tracking, rest timers,
  completion, Progress, rankings, Me, messages, post composition, and moderation
  screens ad-free. Leave discussion/reply threads and search results ad-free in
  the first version. No launch, full-screen, or rewarded ad placements are planned.
- Request ads when needed for Forum. Failed or unavailable ads should leave a
  continuous feed without blocking posts or leaving empty cards. Support large
  text, VoiceOver, and Light/Dark/System appearance. Video must not introduce
  unexpected sound.
- Integrate with Google's test ads before the final release testing round;
  compilation and checks remain assigned to Luna. Live activation still depends
  on consent/privacy setup, store linkage, app-ads.txt verification, and AdMob
  readiness approval. Current privacy copy says there are no third-party ad
  trackers and must be reconciled with the actual integration before release.
  Preserve the commitment not to use health/fitness information for ad targeting.

This plan adds no SDK, dependency, app code, ad requests, or moderation powers.
Sources: [Reddit native advertising](https://www.business.reddit.com/marketing-glossary/native-advertising),
[AdMob native format requirements](https://support.google.com/admob/answer/6329638),
[iOS native ads](https://developers.google.com/admob/ios/native),
and [AdMob verification](https://support.google.com/admob/answer/14538460).

## Blank tabs after changing themes — November 1, 2026

The user reported a blank Home screen with the tab bar still visible after a
theme change. Home, Rankings, and Track conditionally replaced their content
with an empty background while inactive. Those conditions read
`appState.router.selectedTab`, but the views observed `AppState`, which does not
forward the router's change notifications. A theme refresh could evaluate an
offscreen view into its empty branch without a dependable update when the user
returned to that tab.

`MainTabView`, which observes the router directly, now passes `isActiveTab` to
each affected view. The existing inactive-content guards use that input so tab
selection invalidates the child view. Standalone previews retain their default
active behavior. No view identity resets, theme changes, data resets, new app
files, abstractions, or dependencies were introduced.

Verification by Luna: the Debug simulator build succeeded and two focused UI
checks passed in separate runs. The expanded existing test checks visible,
tappable content on all five tabs after all three added palettes, Light/Dark
changes, accent override, and saved preferences after relaunch. A separate short
regression starts with visible Home content, changes to a different theme from
Me, and confirms Home content remains visible and tappable on return. Exported
screenshots show populated screens, including Seal & Navy Home after the Me
route. No phone or TestFlight build was updated by this fix.
The installed artifact is `/tmp/liftrivals-catalog-derived/Build/Products/Debug-iphonesimulator/LiftRank.app`,
version 1.0 (50), ad hoc simulator signed, staging backend configuration, and
launched with `-uiTestingDemoMode` on Workflow Audit
`29314C7C-986C-469F-ADCB-740870B6337D`. The app was left open on populated Home;
no real-account sign-in was tested.

The previous Home-only check also passed before the fix. An initial Me-origin
attempt stopped at a row-center navigation tap before changing a theme; using
the visible Color theme label opened the destination on the first attempt in
the final check. That initial failure is not evidence of the reported blank
screen; the pre-fix runtime symptom was not reproduced conclusively.

Evidence: `/tmp/liftrivals-theme-blank-fixed.log` and
`/tmp/liftrivals-theme-blank-me-route-final.log`; results under
`/tmp/liftrivals-catalog-derived/Logs/Test/` named
`Test-LiftRank-2026.11.01_17-15-46--0500.xcresult` and
`Test-LiftRank-2026.11.01_17-22-18--0500.xcresult`. Screenshots are in
`/tmp/liftrivals-theme-blank-fixed-attachments/` and
`/tmp/liftrivals-theme-blank-me-route-attachments/`.

## Workout plan conflict copies — November 1, 2026

The user reported many `Winter Volume` / `Winter Volume V2` plans with repeated
`(Conflict copy)` suffixes. Source review found byte-for-byte JSON comparisons,
missing saved payloads for conflict copies, a fresh random copy on every retry,
and an insert handler that treated every failure as a conflict. The account's
first triggering event was not established from the screenshot.

Implemented in the existing sync store, service, and workout models:

- Compare decoded plan content with stable entity ordering. Adopt identical
  cloud content and harmless revision advances without producing a copy; apply
  remote-only changes while preserving genuine competing edits separately.
- Derive a stable recovery-copy ID and graph from owner, source plan, expected
  revision, and content. Repeated requests reuse that copy. Persist its full
  sync baseline and retain conflict metadata on later updates.
- Normalize repeated conflict suffixes to one. Treat that automatic rename
  separately from a user's edit so the rename cannot itself create a conflict.
- Preserve edits made while a save is awaiting a response and queue another
  sync. A stale conflict response cannot replace the newer local draft.
- Handle only unique-key collisions as insert conflicts; ordinary failures
  remain failures. Fetch plans using stable ID pagination, and surface unreadable
  remote plan/history payloads instead of silently omitting them.

Cleanup runs only after a successful, settled plan sync. It compares complete
plan graphs after normalizing copied IDs and the generated suffix, retaining
creation dates, names, notes, exercise order/targets, queues, and progression
settings. It keeps an active plan or original plan when possible and only
deletes identical inactive conflict copies without local or downloaded workout
references. Ambiguous graphs and copies with unique content are retained.
Deletion checks the saved server revision; local edits made during deletion are
kept and reuploaded. Account changes stop cleanup. Unchanged copies already
removed remotely are not uploaded again by another device.

No migrations, RLS changes, new app files, or third-party dependencies were
added. Small comparison/retry methods and a conditional-delete service method
live in the existing owners because sync and cleanup share these behaviors.
The earlier blank-screen/theme fix remains included. Luna compiled the Debug
simulator app and passed seven focused checks: deterministic/semantic copy
comparison, true conflicts stable across repeat sync and reconstruction,
revision-only and remote-only changes, cleanup failure/retry with protected
copies, newer edits during an awaited conflicting save, stale cleanup revisions,
and account changes during cleanup. Results:
`/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_18-16-44--0500.xcresult`;
log: `/tmp/liftrivals-plan-conflict-tests-elevated.log`.
The canonicalization test was then strengthened with complete phases/weeks,
sessions, an exercise target, a queue, and progression settings. It passed again
and distinguishes changed targets, queue order, training max, and creation date:
`/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.01_18-22-40--0500.xcresult`;
log: `/tmp/liftrivals-plan-graph-test.log`.

Luna also built the production Release app with development signing/APNs
overrides for direct phone installation; the build and signature verification
passed. Project distribution defaults and the uploaded build 50 remain
unchanged. The iPhone is unavailable to Xcode, so installation and live account
cleanup are pending reconnection. The production HTTP path has not yet been
verified; these focused checks use isolated repositories and services, not live
account data. Build log: `/tmp/liftrivals-plan-conflict-release-elevated.log`.
The signed app and installation/verification record are frozen in
`work/plan-sync-fix-20261101/`; this is a local development-signed build 1.0 (50),
not a replacement upload to TestFlight.

## Progress visual polish — November 1, 2026

The user paused the pending build 51 upload to improve the professional finish
of Progress. This pass preserves the four categories, training calculations,
history, goals, source-workout navigation, recaps, and export.

Source review found competing controls above the strength chart, small weekly
metrics embedded in prose, inconsistent card surfaces, nested cards in expanded
details, and unrelated colors on chart lines and points. The previous layout
also gave every muscle comparison week similar emphasis and squeezed the
activity period picker beside its heading.

Implemented in the existing Progress views:

- **Consistency:** a prominent workout total, aligned training-day/set/minute
  metrics, compact month/streak context, and a separate Volume & details
  disclosure. The activity range is a menu; heatmap labels wrap and the calendar
  uses the same card treatment.
- **Strength:** the selected exercise and trend come first. Goal actions follow
  the chart, personal targets use linear progress bars, and the strength summary
  has a concise heading. Records and estimates remain available in disclosures.
  With no valid saved exercise selection, Progress now prefers a recently logged
  lift over the alphabetically first catalog item; existing selections remain.
- **Muscle:** the selected week's set total has a clear visual priority; prior
  weeks use neutral bars and the selected week uses the chosen accent. Primary
  and secondary counts stay distinct. Partial-history notices remain visible.
  Repeated row-level change explanations are replaced by compact signed counts;
  comparison dates and complete accessibility descriptions retain their meaning.
- **Body:** the current measurement is prominent, Log is beside the heading,
  and the chart has more room with matching line/point colors and restrained
  grid lines. Weight changes are not presented as good or bad outcomes.
- **Shared treatment:** consistent primary card spacing and corners, a clear
  selected category, and a single horizontally scrollable category row at
  accessibility text sizes. The selected category scrolls into view and labels
  retain their full text size without wrapping. Charts retain labeled axes and
  data-dependent weight ranges.

No new app files or dependencies were introduced. A private summary-metric view
method avoids repeating the same number/label treatment for three metrics, and
a private category-button property shares the controls between fixed and
scrolling layouts.
Luna compiled the Debug simulator build and verified the category controls,
muscle filters/detail/source-workout route, and both Strength metrics with chart
selection, source-workout navigation, and records. Strength passed in Dark,
Light, and Accessibility XXXL. Root reviewed the captured screens. The first
XXXL captures exposed wrapped category names and excessive header height; the
scrolling category row above is the correction, and the XXXL Strength check
passed again with it.

The initial chart checks assumed a previously selected lift; a clean selection
instead opened an unlogged machine. The existing test now explicitly chooses
the seeded Bench Press. The calendar check also needed to target vertical
content rather than the newly introduced horizontal category scroller, and to
continue scrolling while lazy date cells were offscreen. The final calendar-only
rerun passed 1/1 with zero failures: an October 1 completed-workout date was
visible and selectable, and its selected-date detail appeared at Accessibility
XXXL. Result: `Test-LiftRank-2026.11.01_19-42-21--0500.xcresult`; log:
`/tmp/liftrivals-progress-calendar-xxxl-final.log`.

Evidence so far: `Test-LiftRank-2026.11.01_19-11-45--0500.xcresult` (muscle and
category checks), `Test-LiftRank-2026.11.01_19-21-59--0500.xcresult` (category,
Dark, Light, and XXXL Strength), and
`Test-LiftRank-2026.11.01_19-32-47--0500.xcresult` (final XXXL Strength), under
`/tmp/liftrivals-catalog-derived/Logs/Test/`. These bundles retain the preliminary
test failures described above; this is not a claim that each bundle passed.
Review screenshots are saved in `work/progress-polish-20261101/`.

The installed test artifact is Debug 1.0 (51), staging, ad hoc simulator signing,
and demo mode. No real-account sign-in or physical-device check was performed.
Body was captured in its empty state and its Log action was checked; a populated
bodyweight chart has not been visually exercised. These changes are not in the
existing distribution archive and have not been uploaded to TestFlight.

### Progress follow-up and production plan-sync correction — November 1, 2026

This follow-up supersedes the upload status above: build 51 was subsequently
rebuilt with the Progress polish and uploaded through Xcode, as recorded in
`docs/release-readiness.md`. Luna's manual demo simulator checks opened Rankings,
Tracker, and all four Progress categories without a blank screen or crash.
One disposable Body entry saved and displayed; the multi-measurement trend is
still unverified. Seal & Navy persisted after relaunch, and the original
Classic/Lime/System settings were restored. Earlier XCTest attempts remain
failed at tab navigation before reaching the features; manual success does not
replace those recorded outcomes.

Read-only production diagnostics identified the reported Plans failure:
build 51 received HTTP 403 for a queued plan DELETE, with PostgreSQL 42501
“permission denied for table workout_plan_documents.” Plan/history reads were
successful. Authenticated users had SELECT/INSERT/UPDATE but lacked DELETE.
The owner-only ALL policy was enabled and the role could not bypass it.

The forward-only `202611010003_workout_plan_owner_delete.sql` restores only
DELETE for authenticated users under that existing policy. Luna ran eight
runtime ownership/revision security assertions successfully on each of two
local resets (`/tmp/liftrivals-plan-owner-delete-sql.log`). The temporary harness
snapshot used the documented location-seed compatibility workaround; no applied
historical migration was edited. After the owner explicitly approved LiftRank
Production, the correction and its migration-history entry were applied in one
transaction. Read-back confirms DELETE enabled, row security enabled, bypass
disabled, and version recorded. On November 2, 2026 (Eastern), the owner confirmed
the physical-phone Retry result: **“Sync succeeds; error is gone.”** The reported
sync-error check is closed through user confirmation; full plan-content and
multi-device consistency checks are not implied.

The affected account has four Private submissions and no public submissions,
corroborating the current Public preview empty state. Sharing was not changed.
The separate shared-workout-statistics RPC remains undeployed; the owner's
preview skips that RPC. A live simulator session remains unavailable because
the production simulator artifact cannot launch, so no account UI pass is claimed.

New source files are the forward-only correction and its focused SQL security
test, required for migration history and runtime ownership verification.
The deployment script and screenshots are diagnostic/release evidence. No new
app abstraction, dependency, or application-source change was required.

### Workout program filters — November 2, 2026

Replaced three tall, unboxed picker rows with compact menu buttons for category,
included equipment, and days per week. Active choices show their selected values
and accent fill; the result count reports matches out of the full catalog.
Clear all is available whenever search or filters are active, including nonempty
results. Search has a shorter placeholder, a clear action, and an explicit empty
state. Existing matching rules and all filter options are retained.

The library header now reads “Workout programs,” with one disclosure indicator
instead of repeated Browse/Hide wording. Accessibility review exposed the old
header squeezing its title into letter fragments and truncating its subtitle.
The simplified header gives the text room to wrap, with fixed decorative icons.
At accessibility sizes, filter buttons stack vertically and selected labels can
wrap; regular text uses a horizontally scrollable row. Controls retain a minimum
44-point touch height. Large-text controls can require vertical scrolling and
are not claimed to fit simultaneously above the tab bar.

Luna compiled and ran the focused
`testProgramLibraryFiltersSearchAndClearAtAccessibilitySize`: **1 passed, 0
failures** on Workflow Audit. Both regular and Accessibility XXXL flows selected
Powerlifting + Barbell + 3 days/week, narrowed 20 programs to 1, and cleared back
to the full catalog. The regular flow also exercised a no-match search. Earlier
attempts retain tab-transition, test-query/scrolling failures and the fragmented
large-text header; they are not counted as passes. Result:
`/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.02_00-56-55--0500.xcresult`;
log: `/tmp/liftrivals-plan-filters-ui-final3.log`. Targeted diff whitespace checks
passed. Root reviewed the final regular and selected XXXL screenshots.

Artifact: Debug 1.0 (51), staging backend, ad-hoc simulator signing, demo mode;
executable SHA-256 `0e8e4ce75966f5dda0db92e4a564cea001cc6dddafdb8e6dec2b93bdb219590e`.
This local build includes changes after the uploaded build 51. No phone install
or TestFlight upload occurred for this pass. Screenshots are preserved in
`work/plan-filter-polish-20261102/` as `filters.png`, `filters-active.png`, and
`filters-accessibility.png` for visual review.

No new app files, types, or dependencies were added. Two private view helpers
in the existing owner share menu contents between layouts and style the three
filter labels consistently. One focused test was added to the existing UI test
file; the new screenshot files preserve verification evidence.

### Goal setup and retained V2 plan — November 2, 2026

Strength goals now have one management section. The chart's duplicate Set/Edit
strength goal action is removed. The editor uses a native form with the exercise,
latest estimate when available, a target weight and unit, Save/Cancel, and an
existing-goal Remove action. No history is required to set a target. The old 0%
ring and repeated setup instructions were removed. Invalid-input/save feedback
is placed above the target within the same form row. A ScrollViewReader keeps
that row visible after input/error changes; simply moving the message above
the input had still allowed row growth to push it behind the software keyboard.

Saved goals use full-width rows with a prominent target and a current estimate
when one exists; no progress bar is invented for an unlogged lift. The goals
heading and Add goal stack at accessibility sizes. Goal exercise selection is
separate from chart selection, so adding/editing a goal no longer changes the
displayed chart or resets its selected points. One private computed value parses
and validates the target and normalizes it to kilograms; remote save behavior
is retained.

The remaining production “Winter Volume V2 (Conflict copy)” was structurally
distinct, with 12 weeks, 36 sessions and 204 prescriptions, versus Winter Volume's
1 week, 3 sessions and 17 prescriptions. Its document was already marked
is_conflict_copy=false. Automatic duplicate cleanup correctly retained the
different contents. A reversible, account/plan/revision/content-guarded name-only
correction changed the document and encoded plan name to “Winter Volume V2.”
No plan or workout was deleted. The plan ID and all other payload contents were
preserved; revision advanced 56→57. Independent production read-back confirmed
the name and unchanged non-name content fingerprint
`a73f1a2160bac0ea176197393fd608ee`. The existing phone build can pull the new name
on its next plan sync. This was a data correction, not a schema migration.

Luna's two existing canonical-copy/cleanup-retention unit tests passed. The
name-correction SQL was validated on a disposable local PostgreSQL fixture:
only the name changed, revision advanced, the graph fingerprint matched, base64
whitespace was removed, and repeated/stale-revision requests changed no rows.
No duplicate-comparison rules were loosened. The repair script and production
verification screenshot are in `work/goal-setup-review-20261102/`.

The app UI changes are local and postdate the uploaded build 51; they have not
been uploaded or installed on the physical phone. No new app files, services,
types, dependencies, or database policies were added. The new selection state
keeps the two UI workflows independent; the private draft-value property shares
validation across field feedback and Save. The obsolete ring/card code was
deleted. A focused lifecycle case was added to the existing UI test file.

Final verification: Luna's focused XXXL lifecycle case passed **1/1, zero
failures** against the final scroll correction. It covers the single Add goal
entry point and absence of the chart duplicate, an unlogged Cable Crunch target,
zero-value rejection, create/edit/remove, and chart-selection stability. Log:
`/tmp/liftrivals-strength-goals-scroll-fix.log`; result:
`/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.02_02-04-46--0500.xcresult`.
Root and Luna reviewed the final invalid/valid screenshots and confirmed the
full validation message and input are above the visible numeric keyboard.
XCTest did not expose keyboard keys reliably, so the keyboard-clearance finding
is visual evidence, not a passing keyboard-frame assertion. Earlier attempts
retain locator/visibility failures and the actual overlap before correction.
No separate normal-size editor image was captured. Remote goal-save failure
was not simulated: this was a Debug/staging demo run with local goal persistence.

The two conflict-copy unit cases passed in
`Test-LiftRank-2026.11.02_01-18-53--0500.xcresult`. SQL fixture output is preserved
as `work/goal-setup-review-20261102/rename-validation.log`. That folder also holds
the guarded name-correction SQL, production read-back screenshot, and final
goal editor/validation images; these new files document the specific repair
and visual verification rather than add application infrastructure.

Final tested artifact: Debug iOS Simulator 1.0 (51), staging backend, ad-hoc
simulator signing, demo mode; executable SHA-256
`f24d6fe1b68737e5d278ad047cc29115b0a2c1558e14a51a21c92c0676fb0cff`.
Luna's targeted source/test diff checks and the repair SQL whitespace check passed.


## Settings workflow and control audit — November 2, 2026

Scope: every current iOS Settings category, nested destination, picker, switch,
button, confirmation, save path and relevant service/store owner. This is an
audit, not an implementation pass. The October 26 Settings checklist in
`settings-todo.md` is historical: the current source below supersedes its
claims about manual saving, duplicate navigation, blank demo Account, and the
missing authenticated training-focus assignment.

Evidence: current source inspection. Luna attempted a bounded manual check in
the disposable Workflow Audit simulator; CoreSimulatorService became unavailable
(connection invalid/refused), and computer use reported no simulator window.
**No Settings workflows were newly observed at runtime in this pass.** No
preferences, notification permission, account data or remote database objects
were changed. Earlier autosave/navigation tests remain historical evidence,
not a fresh pass. No new automated tests or compilation were necessary for this
read-only audit. Physical-device VoiceOver, notification delivery, guest
upgrade/deletion and production cross-account privacy remain pending.

### Open findings

| ID | Priority | Control / workflow | Current behavior and consequence | Smallest proposed correction |
| --- | --- | --- | --- | --- |
| SET-01 | High | Guest → Account → Sign Out | The first Account action dismisses Settings and immediately signs out without warning or offering Add email. `signOutAccount` clears the session, local workouts/plans, pending uploads and local media. A guest has no reusable credentials unless upgraded, so progress can become inaccessible. | Offer Add email or an explicit destructive confirmation explaining guest access loss; Cancel must retain all state. |
| SET-02 | High | Signed-in Account → Sign Out with unsynced work | The same unconditional cleanup removes pending workout/plan changes and retryable PR media. There is no queue-aware warning or opportunity to finish sync before removing local-only work. A remote backup cannot restore work that was never uploaded. | Check existing pending queues; offer sync/retry, cancellation, or explicit discard before clearing local data. |
| SET-03 | High | Sign Out failure | `signOutAccount` catches an authentication-service error, then still clears identity/session/cache and moves to signed-out. Settings has already dismissed, so the failure loses its original destination. | Resolve sign-out failure deliberately before clearing recoverable local work; keep an actionable error visible and preserve retry. |
| SET-04 | High | Privacy / units / focus save → failed read-back → Close → Discard changes | `saveProfile` writes remotely before reading back. If read-back fails, or training-sharing fields do not round-trip, Settings reports failure and presents “Discard unsaved settings.” That dismissal only drops the local draft; it does not undo a remote write that already succeeded. Especially misleading for visibility changes. | Distinguish not-written from saved-but-unconfirmed; refresh/reconcile committed values. Only offer Discard for an actually unsaved draft, without implying a server rollback. |
| SET-05 | High · rollout gap | Workout stats audience; Share workout starts / new top lifts with friends | These are selectable without a capability/availability check. Existing production evidence in this audit documents the shared-stat RPC and friend-activity rollout as undeployed. The save service explicitly throws if sharing fields do not round-trip. A selectable option can therefore lead to a failed save rather than a usable feature. This pass did not re-query production deployment state. | Confirm the rollout before enabling these controls, or mark them unavailable. Deploy only with separate explicit environment approval and required security checks. |
| SET-06 | Medium | Training → Default Progress view | The selected training focus saves, but `loadTrainingFocus()` gives the device-global `liftrank.progress.category` priority. Once a category was visited, changing this setting can appear to do nothing; another account can also inherit the device's remembered category. | Define default versus last-viewed behavior clearly; apply an explicit changed default and scope remembered selection to its owner. |
| SET-07 | Medium | Guest → Notifications → Enable notifications | Settings offers the action to all non-demo sessions. Release registration requires `accountStatus == .authenticated`, excluding `.guest`; the button can finish without asking permission or showing why. Debug registration intentionally returns early too, so Debug cannot verify this action. | Show the correct guest availability/upgrade action, or intentionally support guest permission separately from account push registration. Keep build limitations out of user-facing successful states. |
| SET-08 | Medium | Reminder switches / time / Retry reminders | “Next … alert” is calculated from eligible sessions, not confirmed scheduled requests or permission. It can still appear beside an enabled switch when scheduling failed or permission is denied. The scheduling error and Retry sit under Rescheduling, away from the reminder controls that failed. | Put permission/scheduling status and Retry beside reminders; distinguish a proposed next time from a successfully scheduled alert. Preserve enabled preference without implying delivery. |
| SET-09 | Medium | Training → Start rest timer after completed sets; Adjust rest to logged effort | The first changes the default captured when a new workout is created, while a running workout uses its own automatic-timer flag. The label implies immediate behavior. Adaptive rest is a separate live preference and remains selectable when automatic timing is off, without explaining that dependency. | Label the first as the default for new workouts; point to the active-workout control when applicable. Make adaptive-rest applicability clear while retaining the preference. |
| SET-10 | Medium | Training → Retry failed PR uploads | The button gives no failed count, progress, per-item reason or outcome. The store already has uploading/failed state and `lastError`, including unavailable history/exercise/media cases. Repeated taps are guarded per uploading candidate, but the screen does not explain what is happening. | Surface existing queue state and result beside Retry; disable/relabel while retrying and retain a useful failure action. |
| SET-11 | Medium | Local workout switches save | Rest/default/adaptive timing, automatic PR sharing and reminder choices persist through the workout snapshot. Persistence failures are stored in `repository.workoutSaveError`. The app root has a global error/Retry banner, but Settings does not include it in its presented form; it can be obscured by the sheet. A switch has no in-context failed-save state. The remaining issue is Settings visibility, not an absent app-wide retry. | Surface the existing local persistence error in Settings with the existing retry path; do not invent a second persistence system. |
| SET-12 | Medium | Appearance → Color theme | Every theme tap also assigns its default accent, including tapping the already-selected theme. A custom accent is silently overwritten by a seemingly redundant selection; theme and accent look independent on the parent screen. | Make selecting the current theme a no-op; make the accent behavior for an actual theme change explicit or preserve the custom accent. |
| SET-13 | Low | Account feedback and context | Account has no current sign-in identity/type summary; Sign Out precedes Add email. All `accountMessage` text, including successful “Check your email…” feedback, renders red and can appear in unrelated Settings categories. A successful profile save need not clear an older account message. | Put identity/upgrade first, destructive actions last; separate success from error and associate feedback with its originating action. |
| SET-14 | Low · accessibility review | Theme / accent choice buttons | Selection is displayed with a checkmark but the buttons do not explicitly expose a selected trait/value. Theme rows set a minimum touch height; accent rows rely on Form sizing. This is a source-level accessibility gap to verify, not a claimed VoiceOver failure. | Expose selected state consistently and verify VoiceOver, switch control and touch targets for both lists at large text. |

Source anchors: `Views/SettingsView.swift` (Account 98–137, Privacy 139–189,
Notifications 191–275, Training 277–316, Appearance 329–401, feedback 414–445,
navigation 459–515, autosave 541–574); `ViewModels/AppViewModels.swift:658`
(sign-out), `:946` (push registration); `Services/SupabaseServices+Accounts.swift:394`
(write/read-back); `Features/TrainingTracker/TrainingTrackerView+State.swift:44`
(default focus precedence); `Features/Training/ActiveWorkout/ActiveWorkoutStore.swift:432`
(timer preferences); `Features/Training/ActiveWorkout/PrescriptionTrackView.swift:634`
(timer usage); `Features/Training/ActiveWorkout/WorkoutPRSubmissionStore.swift:107`
(retry); `Features/Training/Plans/AppState+TrainingPlans.swift:333` and
`Core/Notifications/WorkoutRestNotificationScheduler.swift:218` (reminders);
`Repositories/DemoRepository.swift:223` (local persistence). All source paths
are relative to `LiftRankApp/`.

### Complete control and destination inventory

“Traced” means source behavior was followed into its existing owner; it does
not mean a new runtime acceptance check passed.

| Screen / control | Intended and traced behavior | Result / remaining verification |
| --- | --- | --- |
| Root category rows: Privacy, Training, Notifications, Units, Appearance, About & support, Account | Full row opens its named category; Account omitted in demo, separate Demo destination shown. Units/appearance show current values. | Traced; previous blank demo Account issue removed. Current category order is usable; no missing destination found. |
| Settings back / Close / swipe dismissal | Category back returns to root. Child theme, accent, legal and preview destinations use NavigationStack. Close dismisses; saving disables controls/Close/back, dirty profile drafts block swipe and request discard. | Traced; duplicate Save/Done controls absent. SET-04 covers uncertain remote-save dismissal. New runtime navigation check pending. |
| Units → Pounds or kilograms | Changes profile preference and autosaves through profile owner. | Traced; no new mapping error found. Reopen and persistence were covered historically, not rerun. |
| Account → Sign Out | Signs out and clears local account state. | SET-01/02/03. No destructive action executed. |
| Account → guest Email, Password, Add email | Email keyboard, password content type, 10-character minimum; disabled during account operation; service validates; success tells user to check email and clears password. | Traced. SET-13 context/feedback; real confirmation-link/account recovery flow unverified. |
| Account → Delete Account / Cancel / final Delete Account and Local Data | Opens explicit irreversible warning; Cancel leaves data; final action delegates deletion and closes on signed-out. Apple warning explains authorization removal. | Traced; backend deletion, reauthentication and Apple revocation not exercised. Never tapped final delete. |
| Privacy → Profile visibility, Bodyweight, Age group, Location, Gym, Gender category, Friend list | Audience pickers share the profile autosave path; field audience is constrained by profile audience. | Traced; no client inversion found. Live two-account visibility acceptance remains pending. SET-04 applies. |
| Privacy → Workout stats | Defaults missing value to Private; shares only count/latest date per UI contract. | Traced; SET-05 rollout gap. |
| Privacy → Share workout starts / new top lifts with friends | Optional values default false; opt-in saved with privacy; friend/activity restrictions explained. | Traced; SET-05, cross-account/event delivery pending. |
| Privacy → Show lift videos | Direct positive binding, inverse `hideLiftVideos` mapping in profile update. | Traced; no inverted switch found. Actual signed playback authorization pending. |
| Privacy → How visibility works | Expands supporting context rather than changing visibility. | Traced; appropriate disclosure. |
| Privacy → Preview public profile | Opens public-visitor surface, unavailable until profile changes confirmed; returns within Settings. | Traced; owner preview intentionally excludes owner-only data. It does not verify another friend's audience. |
| Privacy → Share usage analytics | Account-specific, device-local opt-in defaults false; production analytics service checks the consent before inserting. | Traced; correct consent boundary found. Network-level opt-out check not rerun. |
| Privacy → Privacy policy | Opens same current privacy document as About & support. | Traced; document navigation, not a settings save. |
| Notifications → Enable notifications / Notification settings | Requests OS authorization where supported, or opens iOS notification settings; refreshes permission on foreground. Root foreground flow reschedules reminders too. | Traced; SET-07. Deny → iOS enable → return is not a newly verified failure. |
| Notifications → Retry connection | Reattempts push registration using existing service; shown after connection error. | Traced; APNs/device-token/server delivery pending on a signed physical release build. No delivery claim based on permission alone. |
| Notifications → Workout day reminders / Missed workout reminders | Independent stored switches; each reschedules existing eligible unfinished dated sessions. Queue/freestyle has no dated reminders. | Traced; SET-08/11. No real permission prompt or alert scheduled in this pass. |
| Notifications → Reminder time | Shared hour/minute for both reminder types; changes reschedule. | Traced; preference is device-global, unlike account workout toggle values. Clarify device scope if needed; no cross-device sync promised. |
| Notifications → Suggest days for missed workouts | Device-local switch gates rescheduling suggestions; does not itself move workouts or depend on OS permission. | Traced into Plans. Correct independent behavior; placement under Notifications is less discoverable than Plans. |
| Notifications → Retry reminders | Re-runs reminder scheduling, separate from push connection. | Traced; SET-08 placement/status. |
| Training → Default Progress view | Profile training-focus picker, autosaves. | SET-06; remote-to-local focus assignment itself is present and no longer the October 26 missing-assignment defect. |
| Training → Auto-share eligible PRs publicly | Persisted opt-in; completion review reads it, eligible PR submissions use public visibility; video may request verification but is not verification itself. | Traced; label matches public-sharing behavior. SET-11 persistence feedback; real upload acceptance pending. |
| Training → Start rest timer / Adjust rest / Rest adjustments | Default timing and adaptive effort controls; disclosure explains the actual RPE adjustment rule. | Traced; SET-09/11. Disclosure is informational, not an action or extra save. |
| Training → Retry failed PR uploads | Existing submission store retries failed/pending records; per-candidate uploading/submitted guard prevents duplicate submission. | Traced; SET-10; unavailable pending history can be skipped without screen-level explanation. |
| Appearance → System / Light / Dark | Device-local AppStorage immediately controls preferred color scheme. | Traced; no Save needed. Fresh all-theme/light/dark visual verification pending. |
| Appearance → Color theme → each of four theme buttons | Immediate theme palette persistence and default accent assignment; selected checkmark. | SET-12/14. Prior theme blank-screen check is historical and was not rerun. |
| Appearance → Accent color → each of eleven accent buttons | Immediate independent accent persistence; selected checkmark. | Traced; SET-14. All-theme contrast and VoiceOver acceptance pending. |
| About & support → About, Privacy notice, Terms of use, Fitness disclaimer | Read-only document destinations; legal text uses current document definitions. | Traced; no duplicate dismiss/save action found. No acceptance is recorded by merely reading. |
| About & support → Support | External link to `https://liftrivals.com/support/`. | Destination traced; current web availability/content not checked, and no claim made that support is operational. |
| About & support → Version / Build | Read-only installed bundle metadata. | Correct non-interactive rows. |
| Demo → Leave demo | Signs out of isolated demo and returns to auth. | Traced; not executed. |
| Demo → Reset Demo Data / Cancel | Confirmation names demo-only data; reset owner guards demo mode. | Traced; Cancel/reset path not executed, no live reset exposure found. |
| Global saving / Retry / Keep editing / Discard changes | Serializes profile save; retains failed draft; queued control changes are retried after success; no writes for an unchanged draft. | Existing design is largely correct; SET-04/11/13 are remaining gaps. |

Recommended implementation order: protect account exit (SET-01–03), make save
confirmation truthful (SET-04/11), resolve sharing availability (SET-05, with
separate deployment approval), then focus/notification/timer correctness
(SET-06–09), followed by retry, appearance and feedback polish (SET-10/12–14).
Use Luna only for focused verification after fixes; do not add a broad suite
for this audit. No new application files, abstractions or dependencies added.


### Deeper Settings audit — November 2, 2026 follow-up

The second pass followed Settings actions through service results, persistence,
remote writes, queued events, media cleanup and account transitions. It adds
**8 findings (SET-15–22), bringing the documented list to 22**. These are
source-confirmed paths with conditional consequences, not newly reproduced
phone/simulator failures. No tests, app changes, remote requests or account
mutations ran in this follow-up. Previously blocked runtime checks remain
pending; deployment of checked-in server code is not presumed.

| ID | Priority | Workflow and evidence | Consequence / proposed correction |
| --- | --- | --- | --- |
| SET-15 | High | Any profile-backed Settings change sends a broad profile snapshot. `ProfileStore.saveEditedProfile` fetches the latest profile but copies display name, bio, avatar, bodyweight, location, unit/focus and all supplied privacy choices from the caller; only selected fields use the freshly fetched value. `save_own_profile_mobile` has a row lock but no expected revision or changed-field mask. | If another device changes the profile after this device loaded it, switching units or a privacy picker can overwrite unrelated newer fields. A row lock serializes writes without detecting stale input. Save only fields owned by the Settings edit, retaining current server values for unrelated fields; detect competing edits where needed. Verify with two independently loaded drafts, not two edits of one shared object. |
| SET-16 | High | Training → Retry failed PR uploads follows `WorkoutPRSubmissionStore.submit` into `CompetitionStore.submitLift`. If the lift record saves but its video upload fails, CompetitionStore returns a non-nil **self-reported** submission after clearing video references. The PR store treats any non-nil result as fully submitted and removes `localVideoURL` from disk. | A failed video is no longer in the failed queue, so this Settings retry button cannot recover it. Preserve the media and distinguish lift-created from evidence-upload-complete. Retry evidence against the same submission rather than creating a duplicate lift. This is a functional recovery defect beyond SET-10's missing progress feedback. |
| SET-17 | Medium | Privacy → switch friend activity off, then on. `retryFriendActivityShares` and `publishFriendActivity` do not recheck current per-kind opt-in. The checked-in record RPCs reject/no-op when sharing is off, and the feed filters by the *current* switch. Existing activity rows are retained; queued work can also outlive the original switch state. | Turning sharing off does not define whether queued/history events are discarded, hidden temporarily, or eligible to reappear after re-enabling. Old stored events become eligible again when switched on; an offline old workout start can receive a new server occurrence timestamp on a later retry. Define an opt-in boundary/queue policy and suppress stale starts. Server opt-in checks exist: this is **not** evidence that events bypass the off setting. Live rollout still requires SET-05 confirmation. |
| SET-18 | Medium | Privacy → Workout stats → Public → Preview public profile. `refreshProfileData` explicitly excludes `isOwnerPublicPreview` from the shared-stat lookup. The preview can therefore show “No public training data” even when real public workout counts would be available after rollout. | The preview is incomplete for the very privacy control it is beside. Provide a safe public-view statistics preview or explicitly identify which content is not represented. Do not fetch owner history as a substitute for permission-filtered public stats. This is separate from an expected empty preview when all lifts are private. |
| SET-19 | Medium | Account → Delete Account → recent-auth rejection. The checked-in edge function returns 403 “Recent authentication required” after its freshness check. The iOS service maps generic function failures through `SupabaseServiceErrorMapper`; no typed recent-auth deletion state or in-context reauthentication action is wired from Settings. | Repeating Delete can repeat the same failure; the warning that sign-in “may” be required is not a recovery workflow. Recognize this server response, offer the correct credential/Apple reauthentication, and require explicit deletion confirmation again after success. Do not equate a token refresh with user reauthentication. Function deployment and physical-account flow were not exercised. |
| SET-20 | High | Account deletion is multi-step and non-atomic. `delete-account/index.ts` removes video/forum objects before avatar removal and before `admin.auth.admin.deleteUser`. Any later storage/database/auth failure returns an error with no completion state for the app. | “Deletion failed” can leave the account present while some media is already gone. Model deletion as an explicit recoverable operation, make retries idempotent, and communicate partial cleanup truthfully. Do not present a failed operation as if all data were preserved. Review storage/account cleanup ordering and resumption using disposable accounts before production acceptance. |
| SET-21 | Medium · rollout dependent | Account → Sign Out revokes the device before clearing the session, but `NotificationStore.revokeCurrentDevice` uses `try?`. The checked-in registration RPC upserts by `(user_id, device_id)`, so registering the same device for another account does not revoke the old account's row. The sender selects unrevoked rows by recipient account. | If revocation fails, an old account's generic push alerts can remain eligible for the shared phone even after another account signs in. No live cross-account delivery or content disclosure was observed, and sender deployment remains pending. Make revocation outcome/retry explicit and reconcile token ownership on account changes while preserving server authority. |
| SET-22 | Medium | Account → Add email / final Delete → operation pending → Back or Close. Individual account buttons disable, but the Form, category back, Close and interactive-dismiss guard depend on `isSavingSettings`/profile draft state rather than `accountOperationInProgress`. Settings can leave the operation and its feedback behind. Other profile controls can attempt autosave while the shared account-mutation lock is occupied. | The user can dismiss an unfinished account action, miss its result or receive an unrelated save failure from the busy lock. Make the pending account workflow explicit: guard dismissal/navigation or retain an accessible operation result, and prevent conflicting profile mutations. Do not lock unrelated browsing unnecessarily. |

Additional source anchors (paths relative to repository root):

- SET-15: `LiftRankApp/Features/Profile/ProfileStore.swift:137`,
  `LiftRankApp/Services/SupabaseServices+Accounts.swift:394`, and
  `supabase/migrations/202610310005_friend_training_activity.sql:130`.
- SET-16: `LiftRankApp/Features/Competition/CompetitionStore.swift:640`
  (especially the video catch around line 719) and
  `LiftRankApp/Features/Training/ActiveWorkout/WorkoutPRSubmissionStore.swift:169`.
- SET-17: `LiftRankApp/Features/Profile/AppState+Profile.swift:34` and
  `supabase/migrations/202610310005_friend_training_activity.sql:95`.
- SET-18: `LiftRankApp/Features/Profile/ProfileViewSections.swift:331`
  and its empty state around line 141.
- SET-19/20: `supabase/functions/delete-account/index.ts:31`, `:95`,
  `LiftRankApp/Services/SupabaseServices+Compliance.swift:91`,
  `LiftRankApp/Services/SupabaseServiceSupport.swift:64`.
- SET-21: `LiftRankApp/Features/Notifications/NotificationStore.swift:65`,
  `supabase/migrations/202607180007_notification_devices.sql:1`,
  `supabase/functions/send-notifications/index.ts:50`.
- SET-22: `LiftRankApp/Views/SettingsView.swift:437`, `:459`, `:511`,
  and `LiftRankApp/App/Session/SessionStore.swift:192`.

Corrections and useful boundaries from looking deeper:

- **SET-11 narrowed:** local persistence already has a root-level global
  error banner and Retry in `LiftRankApp.swift:92`. The gap is surfacing it
  in Settings while its sheet is presented, not a missing retry everywhere.
- App foreground and account-status changes already reschedule workout
  reminders (`LiftRankApp.swift:115`, `:155`). Do not file a duplicate defect
  claiming returning from iOS notification settings never reschedules.
- Privacy SQL writes are transactional; SET-04 concerns a committed write
  followed by failed confirmation, not partially committed privacy columns.
- Friend-event SQL checks current sharing consent both when recording and
  reading events; SET-17 concerns retained history/queues and off→on semantics,
  not a proven privacy bypass.
- Active workout logging takes its own stored unit. Changing the preferred
  unit does not inherently reinterpret the active workout's recorded numbers.
  No unit-conversion defect was established by this Settings trace.
- Analytics consent is checked by the production analytics service, even
  though the high-level event store itself forwards events. No missing-consent
  finding is warranted from that intermediate call alone.

Prioritize SET-15/16 with the earlier account-exit and save-confirmation work.
Treat destructive deletion and cross-account push behavior as disposable-account
acceptance work after fixes. Luna should run the focused checks later; no broad
suite or new scaffolding is justified by documenting this audit alone. Only
existing audit documents were updated; no new files, abstractions or dependencies.


### Settings control affordances — user observation, November 2, 2026

**SET-23 · Medium: interactive controls do not consistently look interactive.**
The user reports that some buttons do not look pressable or toggleable. The
source supports specific inconsistencies: About/legal and Privacy policy use
text-only Buttons while root destinations and Appearance use chevrons; theme
and accent options show a checkmark only after selection, leaving unselected
choices looking like informational swatches. Privacy and training pickers rely
on automatic platform presentation, while actions such as Retry and Preview
use different text/label treatments. Native Toggles are already used: the
reported switch appearance still needs visual verification across themes and
on/off/disabled states, rather than assuming they are incorrectly implemented.
This is an additional finding, bringing the Settings list to **23**.

Apply a consistent visual vocabulary without adding explanatory text:

- Destinations: full-row tap area, trailing chevron; external Support uses an
  external-link indicator. Keep normal informational rows unadorned.
- On/off preferences: native switches with a visible thumb/track distinction
  in both states. Validate enabled versus saving/disabled in every theme;
  avoid making an enabled Off switch resemble a disabled control.
- Single selections: recognizable picker value/control; theme/accent options
  should show a persistent selection affordance on every row, selected or not,
  with selected accessibility state. Retain native selection behavior.
- Immediate actions: use the existing compact button treatments for Retry,
  Enable notifications and Preview where appropriate, with visible pressed,
  busy and disabled states. Preserve destructive semantics for Sign Out/Delete.
- Keep touch targets at least the existing design-system minimum and support
  large text; do not rely on accent color alone to communicate interactivity.

References: `LiftRankApp/Views/SettingsView.swift:169`, `:188`, `:319`,
`:336`, `:374`; inherited foreground/tint comes from
`LiftRankApp/Core/DesignSystem/LiftSurfaces.swift:38`. Existing button styles
are in `LiftRankApp/Core/DesignSystem/LiftButtonsAndEmptyStates.swift`.
No visual implementation or new runtime verification was performed for this
addition; it extends the ongoing audit. No new files/dependencies/abstractions.


### Settings release preparation — November 2, 2026

Implementation in progress after the request for a polished released-app
Settings experience. Current local changes:

- Destination rows for legal/privacy/demo/preview share a full-width label,
  minimum touch height and trailing chevron. Support identifies an external link.
- Units, privacy audiences, Progress focus and appearance use native selection
  screens. Themes/accents retain visible selection circles on every option,
  selected accessibility traits, and consistent touch areas. Reselecting the
  current theme preserves a custom accent.
- Account shows account type/email, offers guest upgrade before destructive
  actions, and confirms sign-out with local/unsynced-data consequences. Guests
  can choose Add email first. Failed sign-out returns before deleting local data.
- Account operations disable conflicting edits/navigation/dismissal. Email
  confirmation feedback is no longer styled as an error.
- Guest account notifications offer an Account destination rather than an inert
  enable action. Reminder eligibility wording no longer promises a scheduled
  delivery; error/Retry has a dedicated adjacent status section.
- Training names the timer preference as a new-workout default. PR retry uses
  existing counts/errors and an in-flight state. Settings surfaces the existing
  local-storage failure and retry instead of leaving it behind the sheet.
- Changing training focus explicitly changes Progress category. This addresses
  the ignored-setting path, but does not yet scope all remembered categories to
  accounts.
- The failed-save exit no longer claims Discard rolls back a server change;
  Close without retrying explains confirmation is incomplete.

This does **not** close all 23 findings. In particular, capability rollout for
training sharing, partial-save reconciliation, stale broad profile writes,
failed PR video recovery, privacy-preview completeness, friend-event lifecycle,
delete-account reauthentication/partial cleanup and push revocation still need
their respective implementation/acceptance work. No production-readiness claim
or remote deployment is justified by UI polish alone.

The first Luna compile encountered a Swift type-check timeout in the large
Settings body. Notifications, Training and Appearance were extracted into
private view properties in the same file to reduce expression complexity.
One private destination-label helper removes repeated row markup; no new app
files or dependencies were added. Luna's focused build/runtime verification
is pending at this entry; update with actual results before release.


Settings verification update: Luna's corrected focused workflow passed **1/1**
with zero failures, covering native picker navigation, theme/accent Back,
Training failure/retry/reopen, Privacy/Units persistence, public preview return
and About. Result: `/tmp/liftrivals-catalog-derived/Logs/Test/Test-LiftRank-2026.11.02_22-43-19--0500.xcresult`;
log `/tmp/liftrivals-settings-final-workflow-rerun.log`. The earlier failed run
used the obsolete Discard changes test locator; only that existing locator was
updated to the actual confirmation/action.

Root reviewed the exported Appearance/Training screenshots. Subsequent
layout-only changes removed redundant root/Appearance section headings and
grouped Training into Progress, Sharing and Rest timer; upload recovery belongs
to Sharing. Luna compiled that final grouping successfully in
`/tmp/liftrivals-settings-grouping-build.log`. The two existing account-exit
checks passed **2/2** (demo isolation and sign-out during delayed profile load),
result `Test-LiftRank-2026.11.02_22-47-43--0500.xcresult`, log
`/tmp/liftrivals-settings-account-exit.log`. Failed-auth-signout injection was
not covered by those existing fixtures; no new mock infrastructure was added.

Verification used the isolated Debug/staging demo simulator. It does not cover
production account deletion, delivery, sharing rollout, every theme's contrast,
VoiceOver, or the entire accessibility-size matrix. The latest header grouping
was compiled after the passing UI workflow, without repeating that flow for
label/group changes. The broader release gates listed above remain open.
No physical-phone install, archive upload, or remote schema/data change occurred.

## Workout programs and Plans UI follow-up — November 3, 2026

Scope: current program catalog, preview/setup, saved-plan switching, active-plan
navigation, session controls and creation entry. This is an audit, not an
implementation or an automated-test result. V = visually observed in the
existing Workflow Audit iOS 26.5 simulator, light appearance, demo account;
C = confirmed in current source only. The installed app was not rebuilt in this
pass, so source-only findings are explicitly separated. The native accessibility
tree did not expose app content; visual navigation used screenshots. No plan
was activated, created, deleted or edited. No live account or database changed.

Visually inspected: Today with ended cycle, Plans with collapsed and expanded
saved-plan selector, ended-cycle workout cards, program catalog and filters,
and Foundation, Strength & Shape preview/setup. Source review additionally
covered unrecorded-session controls, week navigation, percentage-based setup,
creation from history and plan options. Dark themes, maximum text sizes,
keyboard interaction, VoiceOver and actual persistence are not verified here.

### Findings

| ID | Priority / evidence | Issue and user impact | Proposed improvement | Current source owner |
| --- | --- | --- | --- | --- |
| WP01 | High · V/C | Program Preview presents date, progression choices, explanation and weekday configuration before showing the actual workouts. In the observed preview, no exercise list fits on the initial viewport. Users must configure before evaluating the program. | Put goal, days/week, equipment and an expandable workout preview first. Follow with a clear Configure action; retain scheduling and progression in a focused setup step with defaults. | `WorkoutProgramTemplateDetailView.swift:80`, `:206`, `:365` |
| WP02 | High · V/C | Switch plan expands an inline list above the current plan; Use freestyle remains a separate plain-text action above the title. Even one saved plan repeats its name and pushes the first workout well down the screen. | Place a compact current-plan selector in the header. Open a dedicated saved-plan picker with active state, New and Browse actions; keep workout content stationary. Put freestyle inside that choice flow with explicit meaning. | `TrainingTrackerView+Sections.swift:695` |
| WP03 | High · V/C | A completed/ended selected cycle is labeled Active in the saved-plan list while its detail says Cycle ended. Review saved workout receives the same large lime action treatment as starting training. | Separate selection from lifecycle: Selected plus Cycle ended/Completed status. Give ended cycles a clear next-cycle action and quieter review actions. | `TrainingTrackerView+Sections.swift:747`; `ProgramSessionCard.swift:77` |
| WP04 | High · C | The visible Equipment filter means includes this equipment, not can be performed using only this equipment. A dumbbell result may still require machines or a barbell. The menu title explains inclusion, but the collapsed chip does not. | Label the filter Includes equipment and show required equipment in results/preview. If adding an equipment-available mode later, match the complete requirement set rather than changing the current filter's meaning silently. | `TrainingTrackerView+Sections.swift:842`, `:1035` |
| WP05 | Medium · V/C | Catalog cards emphasize RIR + Rep Range or Fixed Sets + Reps but omit equipment. Saved cards add the lengthy resume or start a new cycle subtitle. These are poor comparison cues for choosing a plan. | Show concise category, level, frequency and equipment; use a small Saved badge. Move progression method into setup/details. Keep full names readable. | `TrainingTrackerView+Sections.swift:955` |
| WP06 | Medium · V/C | There are multiple action layers: global Plan options, Edit weeks, per-workout ellipsis, exercise pencil and superset icons. Their scope is not consistently apparent. The global menu also mixes creation/import with selected-plan changes. | Keep plan management under a labeled plan menu, week actions beside the viewed week, and workout actions inside each workout. Use consistent Edit plan / Week options / Workout options naming. | `TrainingTrackerView+Sections.swift:340`; `ProgramPlanDetailView.swift:48`; `ProgramSessionCard.swift:35` |
| WP07 | Medium · C | Next unrecorded workout only changes the selected week; it does not scroll to or open that workout. The week title is itself a menu without a dropdown indicator. Both controls imply more than they reveal. | Rename the jump View next unfinished week unless it actually focuses the workout. Add a chevron to the week selector and distinguish viewed week from next training week. | `ProgramPlanDetailView.swift:213` |
| WP08 | Medium · C | Each unrecorded workout exposes Add exercise beside Start workout, repeats zero-completed status and scheduled date, then hides exercise details behind Show. Editing competes with training, and adjacent buttons remain horizontal at large text sizes. | Keep Start workout primary; move Add exercise into the workout edit flow. Summarize date, exercise/set count and state in one compact line, with a clear disclosure for exercises. Stack actions when text size requires it. | `ProgramSessionCard.swift:18`, `:88`, `:112` |
| WP09 | Medium · C | The first exercise can display enabled superset options with no menu actions when it is not already in a superset: index > 0 gates the only add action. Pencil and superset buttons use 40-point frames, below the project's 44-point target. | Hide unavailable superset controls or expose an actual partner-selection action; give editing controls at least the existing minimum touch target. Keep long exercise names readable instead of single-line truncation beside two icons. | `ProgramSessionCard.swift:131`, `:159`, `:165`, `:186` |
| WP10 | Medium · V/C | Program setup shows every progression mode plus jargon and explanatory copy. Percentage mode adds fixed-width max fields and repeated source paragraphs; a disabled primary button does not summarize missing requirements at the action. | Show the selected method and a Change control, with short plain-language descriptions in the chooser. Keep training-max provenance available on demand. Identify the missing/invalid field beside it and near the disabled action; adapt max rows to large text. | `WorkoutProgramTemplateDetailView.swift:37`, `:124`, `:259`, `:314` |
| WP11 | Medium · C | New Plan uses a toggle to switch between two creation workflows. The default creates and activates an empty plan, after which the user must add weeks and days. History creation has duration and review, so the experiences are uneven. | Offer Start from scratch and Use past workouts as explicit choices. For scratch, collect at least the first week/workout before activation or allow Save draft. Preserve the existing history duration, duplication and review features. | `TrainingTrackerForms.swift:3`, `:51`, `:83`, `:128` |
| WP12 | Low · V/C | Today shows both Choose another program and Browse Workout Programs for the ended-cycle state. Catalog rows and preview carry repeated headings/metadata, while the plan detail repeats weekday/date and week position. Repetition uses space without helping the next decision. | Keep one catalog entry in the ended-cycle state; condense repeated schedule metadata and headings. Retain explanations in contextual disclosures instead of removing functionality. | `TrainingTrackerView+Sections.swift:462`, `:531`; `ProgramPlanDetailView.swift:213`; `WorkoutProgramTemplateDetailView.swift:180` |

Source paths in the table are under `LiftRankApp/Features/Training/Plans/` for
plan views and `LiftRankApp/Features/TrainingTracker/` for tracker files.

### Improvements already present — preserve them

- Catalog search, category/equipment/frequency filters, selected chip styling,
  result counts, Clear all, and accessibility-size vertical filter layout.
- Native Close on program preview and a persistent bottom primary action.
- Plan menu reduces to Resume workout while training is active (plus sharing
  where available), rather than presenting all disabled plan-edit actions.
- History creation supports duration, duplicate workout assignments, conflict
  feedback and a review step. Older audit claims that these are missing are no
  longer current for that flow.
- Destructive week/workout removal has confirmation and explains that saved
  history remains. Preserve this distinction when simplifying copy.

### Suggested implementation order and acceptance criteria

1. **Plan hierarchy and states (WP02, WP03, WP06, WP07):** the selected plan and
   next useful action are apparent without expanding a list; an ended cycle is
   never represented as ongoing training; each action names its actual scope.
2. **Discovery and preview (WP01, WP04, WP05, WP10, WP12):** a user can compare
   programs and inspect workouts before configuring them, see equipment needs,
   and understand what is blocking activation without reading a wall of text.
3. **Workout editing and creation (WP08, WP09, WP11):** no enabled empty menus,
   clear primary training action, usable large-text controls, and explicit
   draft-versus-activation behavior.

After implementation, keep compilation and automated regression tests in Luna
as requested. Use focused checks for program choice, existing-plan resume,
new-cycle setup, cancellation, week jump, equipment semantics, large text and
active-workout restrictions. This audit did not run those tests and does not
claim measured user-study results or full accessibility compliance.

Only this existing audit document was appended. No new files, app abstractions,
dependencies or application-source changes were introduced.

### Authentication screenshot follow-up — November 3, 2026

User supplied two physical-phone screenshots after the Plans audit. These are
additional authentication findings, not part of WP01–WP12. Source inspected:
`LiftRankApp/App/Session/AuthenticationViews.swift`. No credentials entered and
no Apple authentication attempted.

- **AUTH-UI01 · High · screenshot + source:** the guest action and explanation
  are pinned in a bottom safe-area inset (line 213). With the keyboard visible,
  this panel occupies the area above it while the password input and primary
  sign-in action are outside the visible form area. Move the guest choice into
  the scrolling form, below authentication actions, or collapse it during input.
  Verify email → password → submit on a small phone with the keyboard open.
- **AUTH-UI02 · Medium · screenshot + source:** the large branding block and
  introductory paragraph remain ahead of fields during input. Use a compact
  header and prioritize fields when the keyboard is open; keep descriptive
  onboarding copy brief. This compounds AUTH-UI01 rather than proving that
  scrolling or authentication itself is broken.
- **AUTH-UI03 · Low · screenshot + source:** Create Account still displays the
  sign-in introduction and Forgot password action; the native Apple button is
  always configured with `.signIn`. Make app-owned copy and recovery-action
  visibility fit the selected mode. Evaluate a neutral native Apple Continue
  button for the shared authentication entry without altering Apple's sheet.

The second screenshot shows Apple's authentication sheet over a dimmed app.
That screenshot alone does not establish a sign-in failure, incorrect account
selection or a custom-sheet layout defect. Do not replace or imitate the system
sheet. Native keyboard suggestions are also system UI, not app form content.
These observations extend the audit only; no application changes were made.

### Button intent and action check — November 3, 2026

User requirement: buttons must do what their labels promise. This is a source
trace of the audited authentication and program/plan controls, not a live
account, destructive-action or persistence test.

| Control | Actual action traced | Assessment / required behavior |
| --- | --- | --- |
| Sign In | Validates inputs, calls email/password sign-in and loads the account. | Matches. Keep errors visible and entries intact on failure; live verification remains pending. |
| Create Account | Calls sign-up; either loads the session or shows email-confirmation instructions. | Matches. Do not imply account access is ready before confirmation when required. |
| Continue as Guest | Calls anonymous backend authentication, then loads that account. | Matches access without email; it is not an offline demo. Preserve error feedback if anonymous sign-in fails. |
| Apple sign-in | Starts native Apple authorization, exchanges its token, then loads the account. Cancellation returns without a success claim. | Separate from email submission. No live Apple authorization was attempted in this audit. |
| Show / Hide password | Changes the field's visible/secure representation. | Matches. Preserve current text and verify keyboard/focus in later UI checks. |
| Forgot password? / Send reset link | Opens recovery form; explicit Send action requests the link. | Matches. Opening recovery must not send email by itself. |
| Use plan | Selects and activates the saved plan; does not launch a workout. | Reasonable, but Activate plan would make the side effect clearer. |
| Use freestyle | Clears the selected plan and its active flag; does not launch a workout. | Distinguish Switch to freestyle from Start freestyle workout, which actually starts a session. |
| Duplicate | Copies the selected plan AND immediately selects/activates the copy. | **Additional mismatch WP13, High (C):** either label Duplicate & activate or create an inactive copy with a separate Use plan action. Do not silently switch training plans. Source: `AppState+TrainingPlans.swift:770`. |
| Next unrecorded workout | Selects the containing week only. | WP07: label View next unfinished week or navigate/focus the actual workout. |
| Start new 12-week cycle | Creates/activates a program cycle; it does not launch the first workout. | Prefer Create & activate plan (with 12 weeks in the summary), followed by an explicit Start workout action. |
| Save setup changes | Updates setup; dismisses only when the update returns success. | Matches local operation; remote-sync failure must remain visible rather than implying server confirmation. |
| Delete plan | Opens confirmation; confirmed deletion removes the plan and returns to freestyle while preserving workout history. | Matches the confirmation copy. Do not add deletion to a generic Close/Done action. |
| Cancel / Close in program preview | Dismisses setup without invoking the create/update handler. | No save action. Consider discard confirmation for meaningful setup edits, consistent with custom-plan creation. |

Implementation acceptance: every control must have a clear scope, one predictable
result, visible success/error feedback where needed, and accurate disabled
states. A label change alone is insufficient if the actual destination or saved
state is wrong. Runtime checks belong to Luna after changes; do not use real
account creation, password-reset emails or destructive actions merely to audit
button wiring. This extends the source audit to **13 program/plan findings**
(WP01–WP13), plus the three authentication UI findings.

### Account creation implementation and verification — November 3, 2026

Implemented in the existing `AuthenticationViews.swift` owner:

- Guest entry now scrolls below authentication actions instead of occupying a
  fixed panel above the keyboard. Branding collapses while a field is focused.
- Email Next focuses Password; Password Done dismisses input. Interactive
  keyboard dismissal remains available, and the password visibility control
  has a 44-point minimum target.
- Introduction follows Sign In/Create Account mode; recovery is shown only for
  Sign In. The native Apple button uses Continue for the shared entry flow.
- Confirmation notice no longer suppresses subsequent account errors. Editing
  its recipient clears the stale notice. Confirmation instructions allow the
  callback to continue directly instead of always requiring another sign-in.
- Mode selection is disabled during an account operation.

Source trace: email sign-in/sign-up, native Apple token exchange and anonymous
sign-in all use the common authenticated-profile load and onboarding/legal
routing. Guest mode is backed by an anonymous account, not an offline demo.
The shared Supabase client already specifies `liftrank://auth-callback`; no
signup redirect change was necessary. No backend configuration or schema was
changed. Account-operation guards prevent overlapping mutations.

Luna owns focused local compilation and verification. Pending real-service
acceptance must remain explicit: email delivery and confirmation-link handling
on a signed physical-device build, native Apple first-time/returning/cancelled
flows, guest account creation and later email upgrade, expired links and
provider/network failures. Local stubs and simulator form tests cannot prove
those external services work. No intentional live-account test or reset-email
request was performed. Initial guest UI verification exposed incomplete mock
injection in the DEBUG authentication fixture: changing the container field did
not update SessionStore/ProfileStore services. The fixture now installs the
mock container through the existing shared installer. The initial guest request's
backend cannot be established from the UI result alone; no unknown account was
deleted. Subsequent guest checks use explicit mock services.

No new application files or dependencies were introduced. A private focus enum
and an extracted guest-entry view property in the existing screen support field
navigation and removal of the fixed footer without duplicating UI.

Verification outcome (Luna):

- **PASS:** unsigned Release simulator build, including the native Apple
  Continue button in the non-DEBUG branch. Compile evidence only; not a signed
  sign-in artifact.
- **PASS:** responsive authentication UI validation, including malformed email,
  short password, hittable Next/Done keyboard actions and mode-specific copy.
- **PASS:** mocked signup-confirmation and resend success/error unit regression
  (1/1). This verifies state propagation, not inbox delivery or confirmation
  notice rendering after a live signup.
- **PASS:** guest entry reaches legal acceptance for the corrected mock fixture
  (whose profile is already complete), rather than bypassing the legal gate.
- **PASS:** full onboarding/profile flow through legal acceptance on two
  consecutive isolated runs. The initial run's Get started tap did not advance;
  it was not reproduced in those two runs and its cause is not established. No
  retry loop was added to hide it.
- Final focused UI rerun: 2 tests, 0 failures, 45.377 seconds. The earlier form
  test passed separately; there are three distinct passing UI cases overall.
- **PENDING:** live service acceptance listed above. `.env.staging-auth` is
  absent, so the existing guarded staging integration runner was not executed.

Evidence logs are retained in `work/account-creation-20261103/`. No distribution
or physical-phone installation was performed. No app dependencies were added;
new files in that directory are verification logs only. The DEBUG fixture's
one-line installer correction reuses the existing service wiring.

### Remaining account-screen checks — November 3, 2026

Luna's focused `testEmailConfirmationResendErrorAndSignInErrorRemainVisible`
passed 1/1 using explicit mock authentication on the Workflow Audit simulator.
It exercised valid-form signup to confirmation notice, first-resend failure,
retry success, incorrect sign-in with the notice retained, and editing the email
to clear the stale notice/error. This closes the previously untested runtime
confirmation rendering and resend-interaction checks; it does not prove real
email delivery or provider authorization.

A small DEBUG-only scenario was added to the existing MockAuthenticationService
so those states are reachable without backend requests. The confirmation
container now exposes its children separately, keeping Send again independently
accessible; stable identifiers support the focused test. No new app file,
generic service abstraction or dependency was introduced.

Result bundle:
`/tmp/liftrivals-settings-isolated-derived/Logs/Test/Test-LiftRank-2026.11.03_13-05-00--0500.xcresult`.
Original log: `/tmp/liftrivals-auth-confirmation-ui.log`.

Signed simulator preparation: Luna built Debug for the staging backend and
re-signed a separate copy using the existing development identity and existing
simulator entitlements. Strict signature verification passed; application/team
identifiers and keychain access group were present. The compiled app points to
`dfpvamnucwyafxklnjwt.supabase.co` and contains only the public client key.
Artifact: `/tmp/liftrivals-staging-signed/LiftRank-staging-simulator-signed.app`.
Readiness and fingerprints:
`work/account-creation-20261103/signed-staging-simulator-readiness.txt`.
The artifact was not installed or launched, so session restoration is not yet
verified. Debug does not expose native Apple sign-in; that remains a separate
signed Release/device acceptance check. The guarded live staging runner still
requires owner-only `.env.staging-auth` configuration, and real delivery checks
require a disposable inbox. No server settings were changed in this pass.

## Onboarding process audit — November 3, 2026

Scope: account-to-onboarding routing, welcome, training goal, profile and privacy,
optional starting lifts, legal acceptance/Back, interruption recovery, and the
first Home/Progress experience. This is a UX and behavior audit, not a legal
compliance opinion or a new live-account test. Application code was not changed.

Evidence: current source in `OnboardingView.swift`, `SettingsView.swift` (legal
screen), account/profile stores, and the Home/Progress destinations. Today's
prior Luna tests passed the normal profile/Back/legal flow twice, but those
passes do not cover the edge cases below. Simulator inspection uses an explicit
mock onboarding fixture; no production account or legal acceptance is needed.
**C** identifies source-confirmed behavior; **V** identifies inspected visuals.
Large text/VoiceOver and external account services remain separate verification
unless explicitly recorded below.

### Prioritized findings

| ID | Priority / evidence | Finding and impact | Improvement and acceptance criterion |
| --- | --- | --- | --- |
| ON01 | High · C | **Entered starting lifts can disappear silently.** Bodyweight is optional on Profile, but saving starting lifts requires it. The caller suppresses that error with `try?`, as it does submission/network errors. Empty, malformed and nonpositive lift strings are silently filtered. A user can finish with none of the lifts they entered saved. | Keep account setup available, but validate nonempty lift entries, explain any prerequisite at the lift fields, and show a recoverable partial-save result. Preserve unsaved lift values. Never show an unqualified successful completion for discarded entries. Sources: `OnboardingView.swift:883`; `AppState+Profile.swift:89`. |
| ON02 | Medium · C | **“I’ll add my lifts later” can save the entered lifts.** It calls the same `saveOnboardingProfile()` as the primary button, which includes all positive entries. The action is also hidden while a lift field has keyboard focus. | Make Skip starting lifts explicitly omit those drafts, or use Save entered lifts and a separate clear Skip action. A partially completed lift form must not turn a skip action into a save. Source: `OnboardingView.swift:823`. |
| ON03 | High · C | **Changing units can reinterpret starting lifts.** Enter a number on step 4, go back to Profile and change lb/kg: the lift strings are unchanged, while save uses the new preferred unit. Bodyweight converts; starting lifts do not. | Convert entered values at the unit-change boundary, preserving canonical weight. Verify 225 lb remains approximately 102.1 kg after a Back/unit-change/forward round trip. Sources: `OnboardingView.swift:477`, `:883`, `:995`. |
| ON04 | High · C; product direction clarified | **Onboarding overwrites saved privacy choices and disagrees with server defaults.** On appearance, the original flow reset all five Hide flags to false and reconstructed a partial privacy object when saving, losing existing audiences. “Hide exact age” actually controlled age-band visibility. **Owner decision, November 3: onboarding privacy choices should default to Public.** Public is the intended initial choice, not itself a defect. | Align new-account profile defaults with Public, show explicit audience labels, and preserve existing Private, Friends, or Gym choices when setup resumes. Keep the complete saved privacy object instead of reducing audiences to Hide switches. Sources: `OnboardingView.swift`; `BackendModels.swift`; `ProfileStore.swift`. |
| ON05 | Medium · C | **Interrupted setup has no durable draft.** Step, username, location, goals and lift input are local view state. Recreating the screen starts at step 1 and explicitly clears several fetched values. Sign out is immediately available without a draft warning. Some remote profile writes happen before the overall flow finishes. | Persist a minimal account-scoped onboarding draft, or restore supported saved fields and clearly warn before discarding unsaved edits. A restart should resume coherently and must not reset privacy or mix another account's draft. Sources: `OnboardingView.swift:12`, `:94`, `:178`, `:891`. |
| ON06 | Medium · C | **Username errors arrive on the wrong step.** Profile Continue checks only that the username is nonempty. Format/length and uniqueness are checked during final save from Starting lifts, with no return/focus to Username. Users can do optional setup before learning their only required field is invalid. | Validate supported format on Profile, show concise requirements beside Username, and route server rejection back to that field while retaining all drafts. Keep the server authoritative for availability. Sources: `OnboardingView.swift:913`; `SupabaseServices+Accounts.swift:460`. |
| ON07 | Medium · C/V | **Optional setup dominates the profile step.** “Everything else can wait” is followed by photo, bio, units, bodyweight, height, years training, three location controls and five privacy switches, all expanded. The required field and privacy decision lack a clear hierarchy. The welcome screen also repeats progress benefits in its heading, paragraph and three badges. | Keep Username and a compact privacy summary prominent. Put optional training/location/profile additions behind clear disclosures or offer them after entry. Preserve every capability and keep Continue reachable. Sources: `OnboardingView.swift:208`, `:428`, `:548`. |
| ON08 | Medium · C/V | **The stated finish is not the actual finish.** Step 4 of 4 says Enter Lift Rivals, but new accounts next reach mandatory policies. “Before you compete” is shown to general-fitness and guest users too. Expanded policy text pushes the final action farther down. | Represent the legal review in progress or label the preceding action Review & continue. Use neutral wording such as Before you continue. Keep the acceptance action reachable without bypassing unchecked acknowledgments. Sources: `OnboardingView.swift:166`, `:807`; `SettingsView.swift:780`. |
| ON09 | Medium · C | **Height can look selected without being set.** For an unset value the wheel displays 70 inches, but Done only closes the sheet. Choosing the already-displayed value without moving the wheel leaves Not set. There is no clear-height choice, and the height UI always uses feet/inches regardless of the unit preference. | Distinguish an unset value from a chosen default; make Done commit the displayed selection, or show an explicit Not set wheel row. Support clearing and metric presentation. Source: `OnboardingView.swift:302`. |
| ON10 | Medium · C | **Location setup can silently discard effort or disguise an error.** Country/region without a city are dropped by the final complete-location check. Countries and selectable regions are limited to the bundled launch list. Remote city-search failures fall back to a small local list and can appear as No matching cities. | Either persist supported partial location or say what is required before leaving it. Label unavailable regions clearly; distinguish offline/search failure from no result, with retry or Skip location. Do not imply every valid location is searchable. Sources: `OnboardingView.swift:590`, `:844`, `:1077`; `AppViewModels.swift:779`. |
| ON11 | Medium · C | **“Get stronger” is treated as an unset focus later.** The goal saves `get_stronger` separately while leaving `trainingFocus` nil. Progress uses that nil to show Set training focus, and Settings offers no matching Get stronger choice. The user is asked again after completing the goal step. | Give the selected goal a consistent downstream meaning; retain the deliberate strength choice or derive the prompt from both saved goal/focus state. Verify Progress does not ask this user to repeat setup. Sources: `OnboardingView.swift:39`, `:382`; `TrainingProgressView.swift:28`; `SettingsView.swift:488`. |
| ON12 | Medium · C; large-text risk not newly exercised | **Several controls lack adaptive layouts.** Bodyweight/height are fixed side by side, labeled pickers combine their labels and controls horizontally, and lift rows combine a 52-point badge, two text labels, a fixed 72-point input and unit. This risks crowding at accessibility text sizes. Username and bio rely on placeholders once typed; lift rows combine accessibility children around an editable field. | Reflow to vertical rows at large text sizes, retain visible field labels and expose editable values/actions independently. Verify with the largest supported text sizes, keyboard open and VoiceOver before calling the layout accessible. Sources: `OnboardingView.swift:484`, `:967`, `:995`, `:1036`. |
| ON13 | Medium · C | **The first destination lacks a distinct new-user state.** A new account without a plan reaches Home, where no scheduled workout becomes Rest Day. Start a workout navigates to Tracker Today rather than starting a session. This is a weak handoff after asking about training goals. | Show Choose your first plan and/or Start freestyle for a genuinely empty account, with labels matching whether the next tap opens a chooser or begins a workout. Preserve Rest Day for an actual rest day in an established schedule. Sources: `HomeFeatureComponents.swift:306`, `:376`, `:418`; `LiftRankApp.swift:60`. |

Source filenames above resolve to their existing owners:
`LiftRankApp/Views/OnboardingView.swift`, `LiftRankApp/Views/SettingsView.swift`,
`LiftRankApp/Features/Profile/AppState+Profile.swift`,
`LiftRankApp/Features/Profile/ProfileStore.swift`,
`LiftRankApp/Models/BackendModels.swift`,
`LiftRankApp/Services/SupabaseServices+Accounts.swift`,
`LiftRankApp/ViewModels/AppViewModels.swift`,
`LiftRankApp/Features/Training/Progress/TrainingProgressView.swift`,
`LiftRankApp/Features/Home/HomeFeatureComponents.swift`, and
`LiftRankApp/LiftRankApp.swift`.

### What to preserve

- Four understandable goal cards with selection indicators; Continue requires
  one selection. Default-size goal controls are clear and scannable.
- Username is the only required profile entry; location and starting lifts can
  be omitted. Do not turn optional data into new onboarding blockers.
- Back retains state within the current flow, including returning from legal
  review; the prior Luna test verified username, bodyweight and city retention.
- Starting lifts use private visibility and request no verification. Keep that
  boundary between personal entries and verified competition results.
- Saving feedback, duplicate-submission guards and recoverable profile errors
  already exist. Improve partial-result feedback rather than adding another
  generalized state manager.
- Legal acknowledgments begin unchecked and acceptance is gated. The audit
  does not recommend bypassing consent or automatically accepting documents.

### Recommended implementation order

First fix silent lift loss, unit reinterpretation, privacy initialization and
skip behavior (ON01–ON04). Then fix interruption recovery, field validation and
the goal/focus mismatch (ON05, ON06, ON11). Finally simplify the visible flow,
finish labels and new-user destination, and adapt measurement/location controls
(ON07–ON10, ON12, ON13). Keep features available through progressive disclosure.

This audit documents findings only. No app code, dependencies, server settings
or live account records were changed. Screenshot evidence, where saved, is the only
new file type; this report extends the existing audit document.

### Visual walkthrough result

Luna completed a manual walkthrough of the existing mock simulator: welcome,
goal selection, profile, starting lifts, policy review and Back to starting
lifts. Goal selection and the four lift labels were clear at the inspected
text size. Policy acknowledgments remained off; Back returned to the prior
lift screen. No policies were accepted, no live authentication was used, and
no new build or automated suite was run for this audit.

Saved evidence:
- `work/account-creation-20261103/onboarding-goal-step.png`
- `work/account-creation-20261103/onboarding-profile-default.png`
- `work/account-creation-20261103/onboarding-welcome-after-cua-tap.png` — despite
  its filename, this image shows step 2 (goals), confirming the welcome tap
  advanced. An initially stale tool observation is not an app failure.

The mock fixture seeds demo measurements and biography, so their visible values
are not evidence of defaults for a real new account. Later starting-lift and
legal screens were inspected live but not saved because the screenshot command
failed. Largest text sizes, VoiceOver, force-quit draft recovery, changing units
with populated lifts, partial network failure and first Home on a real empty
account were not exercised in this walkthrough; those findings are source-based
and have explicit follow-up acceptance criteria above.

### ON04 follow-up — Public onboarding defaults

The owner requested Public defaults after reviewing the audit. The local change
aligns profile, age group, bodyweight, location, gym and eligible lift-video
visibility. Onboarding now loads the authoritative privacy object, displays
audience menus, and preserves the whole object on save, including choices not
shown in this step. Existing accounts are not reset to Public. Separate friend
activity opt-ins, workout-stat sharing and starting-lift visibility retain their
existing behavior.

`202611030005_public_onboarding_privacy_defaults.sql` changes defaults only for
new database rows. It is a new forward migration because prior migrations must
remain immutable. It has not been applied to staging or production; backend
rollout requires separate environment approval. No new app abstraction or
dependency was added.

Luna verification:
- Two focused unit tests passed: the new Public defaults and decoding of saved
  restricted choices.
- The local database suite passed both clean resets, including the 15-assertion
  profile compatibility test and its real signup-trigger default check.
  Evidence: `work/account-creation-20261103/privacy-defaults-backend.log`.
- The final-source mock onboarding UI test passed: all five menus showed
  Public; Location changed to Friends and Bodyweight to Private; both choices
  remained after save → legal review → Back to profile. Evidence:
  `work/account-creation-20261103/privacy-defaults-ui-final.xcresult` and
  `privacy-defaults-ui-final.log` in the same directory.
- The first UI attempt stopped on Welcome after tapping Get started, before
  reaching the changed controls. That first-tap issue had also occurred in
  earlier onboarding testing; its cause remains unresolved. The failing bundle
  and attachments are retained as `privacy-defaults-ui.xcresult` and
  `privacy-defaults-ui-attachments/`. The rerun used the final source; no retry
  was added to the test to hide the failed transition.

These checks used isolated local data and mock simulator services. They do not
claim live account verification or backend deployment. ON04's local correction
is verified; production defaults await the forward migration.

## November 5, 2026 — collected app fixes

This pass addresses the user's thirteen-item list and preserves existing work in
this checkout. The user explicitly approved all three prerequisite/settings
migrations for production `ikjgbsrlriqiusuvezco`; they were applied together in one
transaction and recorded in `supabase_migrations.schema_migrations` on November 5.

| Item | Change / status |
| --- | --- |
| Today workout time estimate | Removed the rough duration estimate; exercise and set counts remain. |
| Hidden onboarding details | Retained the already-expanded optional fields and verified the onboarding save flow. |
| Taken username advances onboarding | Verified that the profile save/username claim happens before leaving the profile step. A deterministic unavailable-username test stays on step 2 with the error and draft intact. |
| Themes differ too much between appearances | Themed Settings rows and selection pages, added a shared control tint distinct from text colors, and kept Mandarin & Forest's light surfaces green. Manually reviewed all four themes in light and dark; restored System, Seal & Navy, and Orange. Corrected active-workout and saved-workout icon contrast. |
| Training-day goal | Removed the UI, persisted preference, setters, and demo seed. Older snapshots containing the removed field still decode. |
| Weekly streak | Compact explanation, actual days trained this week, progress toward the existing three-day rule, and explicit current-week grace behavior. |
| Public profile | Owner public preview now loads shared workout counts only when both the profile and workout stats are public. |
| Settings save error | Applied the approved `202610310003_shared_workout_stats.sql`, `202610310005_friend_training_activity.sql`, and `202611030001_settings_compare_and_set.sql` to production. Live units change saved, survived reopening, and was restored to pounds and reopened again without the error. No broad profile-save fallback was added. |
| Progress | Added workouts, distinct training days, working sets, average workout duration, and a prior-30-day comparison. |
| Training recap | Added exercise counts, average duration, sets per workout, period comparisons, and most-trained exercises. Completed periods compare against the full previous period. |
| Oversized Start workout | Compact Start label with a 44-point minimum target; actions stack at accessibility text sizes. |
| Add exercise | Explicit rectangular tap area. During an active workout, the action explains the editing restriction and offers Resume. Adding to a saved plan was checked through its existing menu. |
| Switching plans | Visible active-plan control at the top of Plans, with a saved-plan sheet and a freestyle option. Saved history stays intact. |

Verification:

- Four focused unit checks passed: settings field-scoped snapshots and readback,
  recap counts/averages/units, and decoding older workout preferences.
- Mock simulator UI checks passed for onboarding save, taken-username rejection,
  adding a plan exercise and reading it back, and switching to freestyle and back.
- All ten switches across Privacy, Training, and Notifications were changed,
  reopened, restored, and reopened again successfully in the separate Workflow
  Audit simulator. These are persistence checks with demo data, not live-account
  settings writes.
- The complete local SQL suite passed two clean resets. The settings test now
  has 101 assertions, covering all eight audience fields across all four values
  and all three account sharing/video switches in both states, plus authorization,
  isolation, stale-update, and idempotency checks.
- Production readback confirmed all three migration records and five functions,
  fixed `pg_catalog` search paths, authenticated-only execute grants, RLS, and
  private/off defaults. An anonymous request using the correct `changes` and
  `expected` arguments now returns 401 / 42501 permission denied, rather than a
  missing-function error. No real-account sharing preferences were broadened.
- Theme automation exposed outdated picker selectors, which were updated. Its
  last run stopped at a Rankings-tab input failure before theme changes; it is
  not recorded as a theme pass. After the Mac was unlocked, manual visual checks
  covered all four light/dark themes, the weekly streak, populated Progress and
  October recap, compact plan actions, and the active-workout Add exercise notice.
- Public preview loaded its expected private-data empty state without an error.
  The live account's saved workouts and active Upper Hypertrophy workout remain
  intact. Existing-session restoration was observed after process relaunch.
- The final visual pass found a parent accessibility identifier overriding the
  recap button identifier; the summary identifier now belongs to its heading.
- Logs: `/tmp/liftrivals-issues-checks.log`,
  `/tmp/liftrivals-issues-ui-recheck.log`,
  `/tmp/liftrivals-issues-theme-check.log`, and
  `/tmp/liftrivals-issues-sql-all-settings.log`.

Final Release build succeeded and was installed over the existing app on Lift
Rivals Audit 1 (`53AE7E0C-C243-489E-88CB-0CD1EE3833ED`, iOS 26.5), preserving data.
Version 1.0 (51), bundle `com.liftrank.app`, production backend
`https://ikjgbsrlriqiusuvezco.supabase.co`; launched as PID 19816. The final
accessibility readback confirmed `tracker.progress.recaps` belongs to the recap
button. The simulator is left displaying the updated Progress screen.

- Built artifact: `/tmp/liftrivals-home-release/Build/Products/Release-iphonesimulator/LiftRank.app`.
- Installed artifact: `/Users/robertjeanty/Library/Developer/CoreSimulator/Devices/53AE7E0C-C243-489E-88CB-0CD1EE3833ED/data/Containers/Bundle/Application/E9EFB4E3-0F8C-486D-B50A-EF6673A48193/LiftRank.app`.
- Source Swift SHA-256: `22d4adfe0f041137b3a87e19f791e016ef3882c41c04e5d6bd1d305df069a9ea`.
- Built and installed executable SHA-256: `cd8518b88dc2a10b82b203d74837ba09fad4d12d298129b01bcc138dbdfb068a`.
- Signing: code signing enabled, resulting simulator signature ad-hoc,
  TeamIdentifier absent, entitlements `{}`. Existing-session restoration passed;
  fresh credential entry, physical-device signing, and TestFlight behavior were
  not tested in this pass.
- Evidence and fingerprint method: `/tmp/liftrivals-issues-release-evidence.json`.
  Build log: `/tmp/liftrivals-issues-release-final.log`.
  Production screenshot: `/tmp/liftrivals-production-migrations.jpg`.

No new repository files or dependencies were introduced in this pass. The shared
control color token avoids duplicating readable light/dark control colors across
Settings and the streak view. Final scope review and `git diff --check` passed.

## November 5, 2026 — full planned-workout walkthrough

Audit only; no application code changed. Manually started a new Powerbuilding
Upper / Lower cycle, completed Upper Strength, minimized/resumed midway, saved
privately, and reopened the saved workout through its plan card.

### Environment and coverage

- Workflow Audit simulator `29314C7C-986C-469F-ADCB-740870B6337D`, iOS 26.5,
  light Seal & Navy, blue accent, standard Large text size.
- Latest-source Debug 1.0 (52), unsigned (`CODE_SIGNING_ALLOWED=NO`), launched
  with `-uiTestingDemoMode -uiTestingNoActiveWorkout`. Configured backend is
  staging `dfpvamnucwyafxklnjwt`; runtime used isolated demo services, not live
  account services. This is a UI workflow audit, not TestFlight, sign-in, remote
  sync, or release-performance validation. No real credentials were entered.
- Built/installed source artifact:
  `/tmp/liftrivals-home-release/Build/Products/Debug-iphonesimulator/LiftRank.app`.
  Executable SHA-256:
  `878189850fa055ddb0781c0413c19dc073f443530a8444c4bf882fe3c202f95f`.
  Build log: `/tmp/liftrivals-full-workout-audit-build.log`.
- The real account and its active workout on Audit 1 were untouched.
- Logged bench press 3 × 135 lb × 5, barbell row 3 × 95 lb × 6,
  overhead press 2 × 65 lb × 8, and pulldown 2 × 100 lb × 10, all RPE 7.
  Expected and displayed volume: **6,775 lb × reps** across 10 working sets.
- Checked empty-set validation, manual entry, software keyboard entry, keyboard
  Next, copy-to-empty-sets, rest start/skip, exercise completion, minimize/resume,
  finish review, effort/note entry, save, and readback. Did not exercise warm-ups,
  substitutions, supersets, process-death recovery, or larger text sizes.

### Findings still open

P2 means a workflow/usability correction; P3 means lower-priority polish. All
observations below occurred in this walkthrough. Source references corroborate
the behavior; they do not substitute for testing other builds or devices.

| ID | Priority | Observed problem | Recommended behavior |
| --- | --- | --- | --- |
| WF01 | P2 | Completing set 1 inserts a rest banner, a separate copy-all row, and copy controls in unfinished rows. The set list changes height and shifts substantially just as the user moves to the next set. | Keep rest/status space stable and use a compact copy action without moving the active input. |
| WF02 | P2 | With the software keyboard visible, the fixed “Add another set” bar and keyboard toolbar consume much of the remaining screen. Effort controls are partly obscured. Completing a set leaves the keyboard on that completed set while the new rest/copy UI further crowds it. | Prioritize the current/next set; collapse the extra-set action during entry and deliberately advance focus or dismiss the keyboard on completion. |
| WF03 | P2 | Keyboard “Next” after row set 1's reps moved into set 2 while set 1 remained incomplete, even with weight, reps, and RPE populated. The keyboard completion action is reserved for the final input in the exercise. | Make completing the current set explicit and consistent, such as “Log set,” without silently completing a merely prefilled row. |
| WF04 | P2 | Finishing bench press offered “Exercise complete · Review workout,” which returned to the overview with three exercises left. The persistent large bottom action still promoted adding another set. | Offer “Next: Bent-Over Barbell Row”; reserve finish/review wording for the end and keep adding sets secondary. |
| WF05 | P2 | After 6/10 sets and 2/4 exercises, minimizing showed “0 of 4 exercises completed” and “Start” on that session's plan card, alongside the separate Resume notice. Resuming correctly restored 6/10. | The active session card should show its live progress and Resume. |
| WF06 | P2 | “Review to finish” used near-black text on dark green in this light theme. Blank weight/reps fields also looked greyed out despite being editable. | Use readable foreground/background pairs and a clear enabled input treatment. |
| WF07 | P2 | The prescription said “3 reps in reserve,” but each set asked for an effort number on the RPE 6–10 scale. The relationship was not shown at the point of entry, and the same RPE help row repeated under every set. | Show the corresponding target (RPE 7 / 3 reps left) near the effort control, with one concise explanation per exercise. |
| WF08 | P3 | Completing the final set of the entire workout started another two-minute rest countdown. | Stop automatic rest when all planned work is finished, while allowing an explicit extra set. |
| WF09 | P2 | The finish review initially showed 9m 28s. Reviewing options and entering a note increased the displayed/saved duration to 11m 6s. | Stop the workout clock at Finish; resume it if the user returns to training. Review/admin time should not inflate training duration. |
| WF10 | P2 | Bench history showed 203.93 lb × 8, but the finish screen offered 135 lb × 5 as a PR candidate, labeled “First recorded 5-rep best.” The detector compares only identical rep counts. | Distinguish a first entry at a rep count from an improved performance; define whether heavier sets at more reps establish lower-rep records. |
| WF11 | P2 | Saved workout details correctly showed sets and notes, but omitted the selected “3 / Solid” session effort. The immediate success screen emphasized badges; neither screen explained target attainment, change from the previous session, or the next prescribed load. | Surface the effort the user just entered and a concise training result/next-session recommendation. Show actual sets inline in pre-save review instead of counts followed by another drill-down. |
| WF12 | P2 | A cycle starting Thursday Nov 5 listed Monday Nov 9 and Tuesday Nov 10 above Thursday Nov 5. Today's session was below future sessions. The active-plan title was also repeated and the header consumed enough space that only one session fully fit. | Prioritize today's/next scheduled session and reduce duplicate plan headers, while preserving an understandable template order elsewhere. |
| WF13 | P3 | Active overview showed only “6,775 lb” with no Volume label; saved details showed “6775 lb × reps,” wrapping the unit onto another line. | Use consistent, labeled volume formatting across overview, review, and history. |
| WF14 | P3 | Done briefly exposed a “No active workout / Return to Track” empty screen before returning to Plans automatically. It did not remain stuck. | Dismiss the workout flow without flashing the intermediate empty state. |

Relevant existing owners:

- `PrescriptionTrackView.swift`: conditional rest banner at line 36; completion
  and copy rows at 215–237; focus scrolling and keyboard toolbar at 282–317;
  fixed extra-set action at 319; keyboard navigation at 396–420.
- `WorkoutSetLogRow.swift`: conditional per-row copy action at line 97.
- `ProgramSessionCard.swift`: Start action at line 101 and saved-only status
  calculation at line 251.
- `WorkoutSessionRunView.swift`: empty state at line 136, summary dismissal at
  152, volume presentation at 358, finish button colors at 525.
- `WorkoutSummaryView.swift`: live duration at line 68, save duration at 312,
  rep-record wording at 546. `WorkoutPRDetector.swift` compares exact repetitions
  in `previousBestKilograms`.
- `CompletedWorkoutDetailView.swift`: summary and sets at lines 39–120, notes
  at 125; session effort is absent from this presentation.

### Verified results and evidence

Empty sets were blocked with “Enter reps and weight.” Copying filled weight and
reps without falsely marking sets complete. Minimize/resume retained all six
completed sets. Saving marked the planned session complete. Reopening it showed
all ten expected weights, reps, and RPE values, plus the note. Public PR sharing
remained off. No data-loss or save failure was observed in this demo session.

The demo's “First Lift Logged” badge alongside a 49-workout history was excluded
as a production finding because seeded history/achievement state can differ.
“First planned session complete” referred to the newly created plan.

Ten screenshots are retained in `work/full-workout-audit-20261105/`:
`01-plan.png`, `03-keyboard-first-set.png`,
`04-first-set-complete-shift.png`, `05-exercise-complete.png`,
`06-overview-after-bench.png`, `08-minimized-still-start-zero.png`,
`09-completed-set-keyboard.png`, `10-final-set-starts-rest.png`,
`11-finish-review.png`, and `12-workout-saved.png`.

The simulator is left showing the saved workout details. This pass extends this
existing audit document and adds screenshot evidence only; no application files,
abstractions, dependencies, migrations, or live-account changes were introduced.

## November 6, 2026 — workout corrections and repeated walkthrough

The 14 findings above were addressed in the existing workout screens and stores.
The rest area keeps its space, copy actions live in the set menus, extra sets
scroll with the list, and keyboard entry provides **Log set** for each row.
Completed exercises offer the next unfinished exercise. Active plan cards show
live progress and Resume; dated sessions appear in chronological order.

Finish pauses the workout clock and clears rest; returning to training resumes
it. A separate elapsed-time defect that subtracted an ongoing pause twice was
also corrected. Completing the final planned set does not start another rest.
Rep records now consider heavier historical sets performed for at least as many
reps. Review shows actual sets, and both saved presentations show session effort,
target completion, comparison when a matching session exists, and the next load
resolved by the plan's existing progression rules. Volume and finish contrast
were clarified; Done dismisses the workout flow directly.

The only new shared view is `WorkoutTrainingResultView`, inside the existing
`CompletedWorkoutDetailView.swift`, reused by the success screen and history.
No new application files, packages, migrations, or service abstractions were
introduced. Existing tests were extended; screenshots below are audit evidence.

The user also called out previous-set wrapping and a clipped Home streak pill.
The normal-size previous-set display now keeps weight × reps on one line, with
the unit in the column heading and the full value retained for accessibility.
The streak pill now reserves its natural width so its icon and label fit. The
Home header moves its actions to a second row when the full identity and controls
cannot fit side by side.

### Verification

- Ten focused unit tests passed, covering set persistence/completion, workout
  lifecycle, rest cancellation, paused duration, progression, PR comparisons,
  and keyboard navigation. An additional assertion confirms the recap uses the
  same resolved next load as the plan.
- Three focused UI checks passed: save-and-dismiss, set entry in light appearance,
  and set entry at maximum accessibility text size, including repeated keyboard
  dismissal/refocus. Initial keyboard failures led to focusing individual fields
  without animated scrolling; the final keyboard run passed both tests.
- The full manual repeat completed and saved four exercises / ten working sets:
  bench 3 × 135 lb × 5, row 3 × 95 lb × 6, overhead press 2 × 65 lb × 8,
  and pulldown 2 × 100 lb × 10, all RPE 7. Expected and displayed volume was
  **6,775 lb × reps**. The saved detail retained all values, effort **3/5 Solid**,
  and the note “Repeat audit: all 10 sets completed at RPE 7.”
- Review and save both showed **12m 15s** despite roughly two minutes spent
  reviewing and entering effort/notes. A separate final-build check confirmed
  returning from review resumes the clock.
- Recap target attainment was 3/3, 3/3, 2/2, and 2/2 sets. Next matching loads
  were **137.5, 97.5, 67.5, and 102.5 lb**, using the existing plan progression.

### Finding disposition

All fourteen original findings were corrected and checked in the repeated path:

| ID | Repeat result |
| --- | --- |
| WF01 | First-set row stayed at the same vertical position after completion; rest uses reserved space and copy actions no longer insert rows. |
| WF02 | Software-keyboard entry and completion worked; Log set dismissed the keyboard. Extra-set action scrolls with the list. |
| WF03 | Each row exposes Log set after reps; copying values leaves completion explicit. |
| WF04 | Completed bench offered Next: Bent-Over Barbell Row; final pulldown offered Finish workout. |
| WF05 | Minimized card showed In progress · 2/4 exercises · 6/10 sets and Resume; values survived resuming. |
| WF06 | Finish uses readable white-on-green text; editable fields have visible backgrounds and borders. |
| WF07 | Prescription shows RPE 7 · 3 reps left; one explanation replaces repeated help rows. |
| WF08 | Final workout set left no active rest countdown or rest adjustment controls. |
| WF09 | Review/admin time did not inflate the saved duration; returning to training resumed timing. |
| WF10 | Bench 135 lb × 5 was not offered as a PR over the existing 203.93 lb × 8 performance. |
| WF11 | Actual sets were visible before save; saved results/history showed effort, target attainment, and next matching loads. |
| WF12 | A cycle starting Friday Nov 6 placed Friday before Monday Nov 9, Tuesday Nov 10, and Thursday Nov 12. Duplicate title was removed. |
| WF13 | Overview labeled Volume and grouped 6,775; saved details retained the label and compact value with a separate explanation. |
| WF14 | Done returned directly to Plans; the save-and-dismiss UI test also passed. |

### Follow-up findings from the repeat

Two additional issues were found, fixed, and checked on the next build:

- Moving directly to the next exercise showed idle rest even while the previous
  exercise's countdown was active. The exercise screen now restores the active
  workout timer regardless of which exercise started it. In the focused recheck,
  bench showed 178 seconds and the next row screen showed 167 seconds after the
  transition. Adding 30 seconds kept the timer associated with bench press in
  the overview.
- The success footer skipped an unfinished session scheduled today and instead
  promoted a later date. It now first identifies today's remaining session. The
  focused recheck saved a shortened upper session and displayed **Still scheduled
  today: Lower Hypertrophy**.

Final diff review also retained the existing two-second notification-delivery
grace before clearing an expired scheduled rest alert. Clearing immediately could
cancel a notification at its delivery boundary. This restoration has no layout
change; background notification delivery was not manually revalidated.

### Environment, artifacts, and limits

The repeat used the isolated **Lift Rivals Workflow Audit** simulator
`29314C7C-986C-469F-ADCB-740870B6337D`, iOS 26.5, light Seal & Navy, standard
Large text. Debug **1.0 (52)** was unsigned (`CODE_SIGNING_ALLOWED=NO`), configured
for staging `dfpvamnucwyafxklnjwt` but launched with isolated demo services via
`-uiTestingDemoMode -uiTestingNoActiveWorkout`. No credentials or live writes were
used. The real account and active workout on Audit 1 were untouched.

Installed artifact:
`/tmp/liftrivals-home-release/Build/Products/Debug-iphonesimulator/LiftRank.app`.
The final build succeeded; log: `/tmp/liftrivals-workout-fixes-final-build.log`.
Final `LiftRank.debug.dylib` SHA-256:
`87924250edd60c9ac8799642afbc521d24f7c9a0fd08e821ebe32c4a47307335`.
The final artifact was installed and relaunched; Home is left visible with the
complete flame icon and **12 wk** label. The unsigned Debug executable is a shim,
so the dylib hash identifies the application code.
Unit log: `/tmp/liftrivals-workout-fixes-tests.log`; save/dismiss and progression
assertion: `/tmp/liftrivals-workout-fixes-ui.log`; successful keyboard rerun:
`/tmp/liftrivals-workout-fixes-keyboard-final.log`.

The full ten-set run preceded the two follow-up fixes; those transitions were
checked separately on the subsequent build. No remaining blocker was observed
in this covered path. This does not validate production auth, remote sync,
physical-device performance, a full dark-theme replay, warm-ups, substitutions,
supersets, or process-death recovery. These changes have not been uploaded to
TestFlight.

Twelve screenshots are retained in `work/full-workout-fixes-20261106/`:
`01-home-streak.png`, `02-plan-order.png`, `03-before-sets-prev.png`,
`04-keyboard-log-set.png`, `05-first-set-stable.png`, `06-next-exercise.png`,
`07-live-plan-resume.png`, `08-final-set-no-countdown.png`,
`09-review-start.png`, `10-saved-result.png`, `11-rest-carried-to-next.png`,
and `12-todays-session-recap.png`. These evidence images are the only new files
from this pass; the report extends this existing document.

## Plan management and repeat-workout audit — November 6, 2026

Audit only; no application changes. Manually exercised creating an empty plan,
deleting it, switching to freestyle and back, duplicating a plan, switching
between both plans, repeating a saved workout today, saving a shortened repeat,
duplicating a workout onto another weekday, moving that duplicate, and viewing
both attempts in workout history.

### Findings

| ID | Priority | Observed issue | Recommended behavior |
| --- | --- | --- | --- |
| PM01 | High | After saving a one-exercise repeat, the original Wednesday Full Body B card still says 3/5 exercises completed, but Review saved workout opens the new Friday attempt with one set. | Make the card's status and review target refer to the same attempt; expose dated attempts. |
| PM02 | Medium | While the Friday repeat is active, its progress and Resume action appear on the Wednesday card labeled Scheduled Nov 4, without identifying it as a repeat today. | Show the actual attempt date and an explicit repeat label. |
| PM03 | High | Duplicate to another day offers weekday names without dates. Choosing Saturday on Nov 6 created a session dated Oct 31 in the selected final week. Moving it to Thursday produced Nov 5. Only unused weekdays in that week are offered. | Show exact target dates and allow a future date/week, making the current-week restriction explicit. |
| PM04 | Medium | Creating an empty plan on Friday Nov 6 produced a Monday Nov 2 Freestyle Workout with 0 of 0 exercises completed and an enabled Start button. | Offer a start date and a clear add-workout/exercises setup state instead of a past empty session. |
| PM05 | Medium | Duplicate immediately activates the copied plan at week 1, starting today, without an activation/start-date choice. The view retains its scroll position, leaving the changed active-plan header offscreen. | Label the action Duplicate and activate or separate duplication from activation; reveal the resulting plan context. |
| PM06 | Medium | The switcher lists names and Active/Use plan but no week, schedule dates, or progress, making similar plans hard to distinguish. | Add compact schedule/progress context. |
| PM07 | Medium | Repeat, duplicate, and move are adjacent overflow actions with different consequences; the explanation that saved workouts remain unchanged is visibly truncated. | Make Repeat today discoverable and explain whether actions affect the schedule or create a new logged attempt without truncation. |
| PM08 | Low | Delete confirmation says Delete this plan? without naming the plan. | Include the exact plan name while retaining the existing explanation that history remains and the app returns to freestyle. |

### Working behavior and limits

- The empty test plan was deleted with user approval and disappeared from the
  switcher; the app returned to freestyle as stated.
- Switching back to Full Body Foundation restored its week 12 schedule and
  completion states. The copy started with uncompleted workouts.
- Plan switching and editing were disabled while a workout was active;
  minimizing/resuming retained its entered set.
- The repeat saved on Nov 6. History independently showed Full Body B on Nov 1
  with five sets and Nov 6 with one set: the original was not overwritten.
- This was a deliberately shortened repeat (one deadlift set, 96.5 lb × 5),
  sufficient for attempt/date/history checks, not another full-workout audit.
- Deletion of a populated plan and preservation of its linked history were not
  exercised. Production persistence/sync, auth, import/export, and restart
  recovery were not validated.

Environment: isolated Lift Rivals Workflow Audit simulator
`29314C7C-986C-469F-ADCB-740870B6337D`, iOS 26.5, unsigned Debug 1.0 (52),
staging-configured artifact with demo services (`-uiTestingDemoMode
-uiTestingNoActiveWorkout`). Installed artifact:
`/tmp/liftrivals-home-release/Build/Products/Debug-iphonesimulator/LiftRank.app`.
Real account data and the active workout on Audit 1 were untouched. The isolated
demo retains Full Body Foundation Copy, the shortened repeat, and the workout
duplicate moved to Thursday for inspection; the original plan is active.

### Fixes and repeated checks — November 6, 2026

All eight findings were addressed in the existing plan views and stores:

- PM01: Card counts now come from the same latest saved snapshot that Review
  opens. A dated attempts menu provides access to earlier records.
- PM02: An active repeat displays its actual date and a Repeat label.
- PM03: Calendar-plan copy/move opens an exact-date picker. It supports other
  weeks and the week immediately after the plan; saving there adds that week
  and navigates to it. Occupied dates are rejected without replacing a workout.
  Queue plans retain explicitly labeled unused-weekday actions.
- PM04: Empty-plan creation accepts a start date and removes the placeholder
  session. The first week shows Add Workout Day. Empty workout cards cannot
  start until exercises are added.
- PM05: The action now says Duplicate & activate today. Changing the active
  plan scrolls its identity into view.
- PM06: The switcher includes week, workouts logged, and start date. Empty
  plans say No workout days yet; removed schedule entries do not inflate the
  logged-workout numerator.
- PM07: Repeat today is visible on saved-workout cards, with wrapping helper
  text explaining that it uses the plan's exercises and preserves history.
  Copy/move sheets describe their separate schedule effects.
- PM08: Delete confirmation includes the selected plan's name.

Five focused unit tests passed, including two added tests for empty-plan/date
scheduling and populated-plan deletion retaining complete saved snapshots.
The other tests covered existing reschedule protections, plan lifecycle, and
fresh repeat identity. Log: `/tmp/liftrivals-plan-fixes-tests.log`.

The manual repeat copied Wednesday Full Body B to Saturday Nov 7, creating and
opening week 13, then moved that copy to Friday Nov 6. Empty-plan creation,
explicit duplication/activation, switching back, and the named delete prompt
were checked. A new one-set repeat (96.5 lb × 5) saved on Nov 6; its card showed
1/5 exercises logged and 1 set. All 2 saved attempts listed both Nov 6 and Nov 1,
and selecting Nov 1 opened the original five-set workout. The active repeat
displayed Repeat · Nov 6, 2026 and switching remained disabled.

The final build also corrected singular set wording and the empty-plan switcher
summary. It was installed and launched; the corrected empty summary was checked
again. Build log: `/tmp/liftrivals-plan-fixes-final-build.log`. Plans is left open
on Full Body Foundation. The final demo relaunch reset the in-memory audit
workouts; a new empty Plan fixes review remains for inspection. Environment and
artifact path are unchanged from the audit above. This verifies local demo
behavior, not production auth/sync or physical-device behavior.

No new files, types, abstractions, dependencies, or database migrations were
introduced. Date scheduling and switcher summaries extend the existing owners.

## Navigation controls audit — November 6, 2026

Audit only; no application changes. Reviewed Back, Close, Cancel, Done,
sheet dismissal, and tab return behavior using the same isolated Workflow Audit
demo artifact described above. The simulator is left in Track > Library.

### Findings

- NAV01 — Workout review attachments are not retained on Back (code finding).
  `WorkoutSummaryView` keeps picked videos and their URLs in local `@State`,
  while effort, notes, sharing choice, and selected PR IDs are bindings owned
  by `WorkoutSessionRunView`. Back dismisses the sheet. Reopening creates a
  fresh review without its attachments; preserve them with the review draft.
  This was not reproduced with a real video, and no media was uploaded.
- NAV02 — Draft protection is inconsistent. Bodyweight Cancel was tested with
  an unsaved note: it dismissed immediately, and reopening showed no note.
  Source also shows direct dismissal without a dirty-draft guard in plan notes,
  prescription editing, completed-workout editing, custom-exercise creation,
  and program import. Create-plan, profile editing, and forum drafts already
  have stronger protection. Cancel discarding is expected; the improvement is
  consistent protection for meaningful edits, including sheet gestures.
  Gesture-based loss was not verified. Import's Close can also discard pasted
  input; Cancel better communicates that outcome.
- NAV03 — Progress's Choose exercise sheet puts Cancel at the top right using
  `confirmationAction`. Runtime verified. Move it to the same cancellation
  position as the other pickers/editors. It currently returns correctly and
  leaves the selected exercise unchanged.
- NAV04 — Progress detail uses an extra in-content “< Progress” row, whereas
  Workout history and Library detail use the standard navigation-bar Back.
  Runtime verified both return correctly. The former changes category state
  instead of popping a navigation destination; unify the presentation and
  remove the extra header row. Edge-swipe behavior was not tested.
- NAV05 — Read-only modal dismissal varies in wording and placement: another
  athlete's profile uses Done on the left, recap uses Done on the right, and
  settings uses Close on the right. These are functional but inconsistent.
  Choose a consistent dismissal convention while retaining Back for one-level
  navigation and Cancel/Save for editing. Native Back on the pushed Me public
  preview is appropriate; it should not be changed merely to match a modal.

### Checks that passed and coverage limits

- Rankings profile Done and filters Done returned to Rankings. Filters explain
  that results update as selections change.
- Settings Appearance > Color theme Back returned one level; Close from
  Appearance exited settings, matching its different purpose.
- Training recap exercise changes Back returned to recap; Done returned to
  Progress. Progress picker Cancel and overview return also worked.
- Workout history retained its selected November 5 date after switching to
  Forum and Me and returning to Track. Its Back returned to Progress.
- Forum discussion Back, Me public-preview Back, and Library exercise Back
  returned to their correct parent screens.
- Source reviewed authentication/onboarding, plan editors, active workout,
  workout review, profile, community, settings, and progress exit controls.
  Authentication/recovery and onboarding were not repeated with a real account;
  forum posting is read-only in this demo. Existing real-account sessions and
  the separate simulator's active workout were untouched. This is not a claim
  that every conditional screen or gesture was exercised at runtime.

Guidance: [Apple's modality guidance](https://developer.apple.com/design/human-interface-guidelines/modality)
supports handling potential loss of user-created content on dismissal. Wording
and placement findings above are consistency recommendations, not claims that
every use of Done or Close violates an iOS requirement.

No new files, abstractions, dependencies, or migrations were introduced.

### Navigation consistency changes and checks — November 6, 2026

Applied the agreed convention across existing screens:

- Back remains on the left for navigation. Progress's category return now
  shares the Tracker header, removing its separate row. This remains category
  state navigation; it does not add a native edge-swipe navigation gesture.
- Read-only sheets use a top-right X with the accessible label Close: recap,
  workout details, public profiles presented modally, awards, lift/media details,
  notifications, streaks, plateau/muscle details, legal information, and review
  tools. Settings also uses X while retaining its save-in-progress protections.
  Pushed versions retain native Back. Workout details keeps X after its other
  trailing actions; Notifications places Mark all as read on the left.
- Editing retains Cancel/Save (or the explicit task action). Submit Lift and
  program import now say Cancel. The exercise chooser's Cancel is on the left.
  Immediate-apply filters, plan switching, profile photo changes, and onboarding
  pickers retain Done; completion alerts and keyboard Done are unchanged.
- Bodyweight, completed-workout edits, prescription edits, plan notes, custom
  exercises, import, and program setup now guard meaningful draft changes.
  Cancel offers Discard changes and Keep editing; changed sheets cannot be
  dismissed by a swipe. During testing, confirmation dialogs hid their cancel
  option on this OS, so these new prompts use alerts with both choices visible.
- Workout-review video selections and URLs now belong to the parent review
  draft alongside notes/effort. Back preserves that draft. Back and swipe
  dismissal are disabled while a selected video finishes loading. Saved review
  uses X; unsaved review uses a left back arrow labeled Back to workout.

Verification: final Debug simulator build passed; log
`/tmp/liftrivals-navigation-final-build.log`. Installed and launched the artifact
at `/tmp/liftrivals-home-release/Build/Products/Debug-iphonesimulator/LiftRank.app`
on Workflow Audit (`29314C7C-986C-469F-ADCB-740870B6337D`, iOS 26.5).
It is unsigned Debug 1.0 (52), staging-configured
(`dfpvamnucwyafxklnjwt.supabase.co`), launched with demo services and no active
workout. No real sign-in, production changes, or physical-device installation.

Manual checks verified Progress's compact back header and return destination,
left-side exercise-picker Cancel, recap X dismissal, native Back on pushed
workout/profile details, and Settings X. A completed-workout effort draft
triggered its guard; restoring the original effort allowed Cancel without a
prompt. In the final alert implementation, a temporary bodyweight note triggered
both visible choices; Keep editing preserved the note, and a downward drag did
not dismiss the changed sheet. Removing that temporary text allowed Cancel
without a prompt. No audit measurement or workout edits were saved. Final
Settings presentation was verified after removing confirmation-button emphasis
from its X; that screen is left open in the simulator.

Video retention was reviewed in code and compiled, not tested with a real
attachment/upload. Other conditional screens, all editor save paths, real
account sync, and accessibility font sizes were not exhaustively exercised.
The task diff was reviewed for scope and passed whitespace checks. No new files,
types, abstractions, dependencies, or migrations were introduced.


### Flexible workout scheduling — November 6, 2026

Added Fixed weekdays, In order, and Flexible days to new-plan creation and existing plan settings. Flexible days removes calendar assignments and forced next-workout recommendations, offers the remaining workouts in Today, and preserves access to all plan sessions in Plans. Training weeks remain workout groups; existing plans decode with their previous schedule. The new setting uses the existing plan payload, with no database migration.

Verification: the first focused run passed all four scheduling tests, including completing the third workout first and persistence/backward compatibility. A follow-up queue change exposed a regression in explicit queue membership; the implementation was corrected to append only newly added sessions. That correction compiled, but final test execution and the visual walkthrough remain unverified: a concurrent run occupied Workflow Audit, and a separate Flexible Audit simulator stalled during first-boot iOS data migration. Stopped only this task's waiting runner. Logs: `/tmp/liftrivals-flexible-tests.log`, `/tmp/liftrivals-flexible-final-tests.log`, `/tmp/liftrivals-flexible-isolated-tests.log`. Build: Debug, unsigned, staging configuration, demo-only intended runtime; no real account sign-in tested.

No new source files or dependencies. Added `WorkoutScheduleMode` in the existing domain model to represent the three actual schedule choices.


Flexible scheduling retry verified — November 6, 2026: all four focused tests passed against the updated workspace (`/tmp/liftrivals-flexible-retry-tests.log`). Installed the Debug unsigned demo artifact from `/tmp/liftrivals-home-release/Build/Products/Debug-iphonesimulator/LiftRank.app` on Workflow Audit (`29314C7C-986C-469F-ADCB-740870B6337D`). Created and activated “Flexible Audit” from three saved demo workouts, confirmed Flexible days has no weekday assignments, started the third workout (Full Body C) first, logged all five planned sets, and saved it. Home returned to Choose workout; Today retained the first two workouts in Week 1 and removed the completed third workout from the remaining list. Left that chooser open. This closes the preceding test/visual verification gap for the flexible scheduling flow. Real account sync/sign-in and production deployment were not tested or changed.
