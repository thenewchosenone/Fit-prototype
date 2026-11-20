# Program builder todo

Created October 24, 2026. Based on the [Winter Volume V2 workflow audit](workout-plan-workflow-audit-2026-10-24.md).

## First priority: complete program creation

- [x] Add program duration and start date, with a calendar preview.
- [x] Add a weekly schedule builder: training days, assigned routines, and rest days. Flag duplicate-day conflicts.
- [x] Allow duplicating source workouts during review and saved workouts onto additional days.
- [x] Support applying an edit to this workout, all matching workouts, or future weeks while preserving completed history.
- [x] Add a final review showing duration, workouts per week, total sessions, estimated session lengths, weekly volume, and progression. Make program activation explicit.

Acceptance scenario: build Winter Volume V2 from the latest three freestyle workouts as a 12-week, six-day pull/push/legs split with Sunday off, without manually cloning eleven weeks or reconstructing exercises. Clearly distinguish the viewed week from the next unfinished training week.

## Training structure and progression

- [x] Add progression rules: rep ranges, criteria for load increases, and unit-aware increments. Store canonical loads in kilograms.
- [x] Add training phases with different sets, reps, and effort targets, plus configurable deload weeks.
- [x] Preview weekly working sets by muscle group and highlight missing targets or schedule conflicts.
- [x] Suggest initial loads and reps from recent workout history, showing the source of each suggestion and allowing review before saving.
- [x] Add supersets with exercise grouping and rest between rounds.
- [x] Save exercise substitutions for unavailable equipment.

## Flexibility and reuse

- [x] Support a flexible workout sequence alongside fixed weekdays, including rescheduling after missed days.
- [ ] Save unfinished program drafts and resume editing later. **Open as PW-13**; the implementation is not present in the current source.
- [x] Add program versions so active plans can change without rewriting completed history.
- [x] Allow sharing a program and copying it into an editable personal version.

## Workflow verification

- [x] Verify history import preserves exercise order, completed working-set counts, and supported prescription fields without modifying source workouts. `WorkoutProgramBuilderTests.testHistoryImportBuildsTwelveWeeksAcrossSixWeekdaysWithoutChangingSources` passed.
- [x] Verify six-day scheduling, twelve-week generation, and scoped edits produce the expected sessions without duplicates. `WorkoutProgramBuilderTests.testFutureWeekEditLeavesProtectedHistoryUnchanged` and the 12-week/72-session history import test passed.
- [x] Verify saved programs sync and remain available after relaunch. `WorkoutProgramBuilderTests.testSavedProgramSyncsAndRestoresFromRemotePlanService` passed against the mock remote plan service and shared local persistence.
- [ ] Investigate the unreliable text replacement seen through iPhone Mirroring; establish whether it is an input-tool issue or an app defect before changing app code. Current inspection shows “iPhone in Use” and requests that the iPhone be locked to reconnect, so text replacement could not be tested and no app defect is concluded.

## Freestyle workout audit: observed problems

Observed October 24, 2026, on the iPhone 17 simulator with the Alex Reyes demo profile. Findings only; fixes are not implemented.

- [x] Preserve finish-review drafts when navigating Back: the audit note disappeared after leaving review and reopening it. Check effort and visibility choices for the same issue.
- [x] Make duration consistent between review and saved results: review showed over six minutes, while the saved workout showed 2m 38s. Explain any intentional exclusion of idle time before save.
- [x] Preserve exercise selection order, or make the resulting order explicit: selected curl first, then leg press; the added workout placed leg press first.
- [x] Keep the active rest countdown visible from the workout overview. It was visible on the exercise screen but absent after returning to the overview; this does not establish that the underlying timer stopped.
- [x] Reduce set-entry clutter: every working-set row shows five RPE buttons plus set options. Consider making optional effort controls expandable.
- [x] Increase RPE button touch targets and check spacing for comfortable tapping.
- [x] Standardize typography across the workout header, exercise cards, set rows, and review. Heavy headings and multiple accent treatments compete for attention.
- [x] Make demo mode and workout visibility clearer before saving, so users can tell which account is receiving test data and whether a summary will be public.
- [x] Improve the completion handoff: Today's training returned to a rest-day message after saving, without a visible just-completed workout link in that view.

Verified outcome: saved a synthetic freestyle workout with public visibility after explicit user approval: Leg Press 3 × 10 at 100 lb, Alternating Dumbbell Curl 3 × 12 at 20 lb; six working sets and 3,720 lb displayed volume. The saved entry appeared in training history, the profile workout count increased from 72 to 73, and the active-workout card cleared. Remote publication was not independently verified.

## Progress screen audit: usefulness and presentation

Observed October 24, 2026, in the iPhone 17 simulator using the demo profile. UI walkthrough only: no implementation investigation or application-code changes. Body had no logged weigh-ins, so its populated trend could not be assessed. The recent synthetic workout contributes to the displayed totals.

### Priority problems

- [x] **Clarify the strength chart scale and units.** Back Squat's summary shows starting estimated 1RM 91.9 lb and best 119.7 lb, but the estimated-1RM chart plots around 40–60 without a unit label. The logged-weight chart below plots around 75–100. The estimates therefore appear lower than the logged loads. Reconcile the displayed units/scale before relying on the charts.
- [x] **Explain conflicting strength values and sources.** The top card shows squat 365 lb beneath a description about estimated 1RM from completed working sets, while selected Back Squat history shows best estimated 1RM 119.7 lb. Surface source, date, and whether each value is submitted, logged, or estimated; do not leave users to reconcile these themselves. No conclusion about the underlying calculation was established.
- [x] **Retain progress context across navigation.** Switching to Home and back reset the category to Strength and the selected exercise to Alternating Dumbbell Curl. Preserve the user's section and lift selection where practical.
- [x] **Keep category navigation accessible on long pages.** Consistency/Strength/Muscle/Body controls scroll away while Tracker navigation remains fixed. Important comparisons and alternate sections become harder to reach.

### Card-by-card decisions

| Section / card | What the user should learn | Observed issue / recommended adjustment |
| --- | --- | --- |
| Consistency: weekly overview | How much training was completed this week | Keep, but clearly separate weekly, monthly, lifetime, and streak scopes. “6 recently trained” does not identify what is counted or its period. Explain the streak rule and show progress toward a chosen frequency target rather than only raw counts. |
| Consistency: five-week volume mini chart | Whether workload is rising or falling | The bars lack dates, values, and an explicit volume definition. The 72% decline statement needs context for an unfinished week or recovery phase; the active program separately shows a recovery week. Do not imply every reduction is a problem. |
| Consistency: activity heatmap | Training patterns over time | Keep for longer-term patterns, but add month/weekday labels and numeric color thresholds. The inspected 90-day grid leaves substantial unused horizontal space. Tapping a day did not show a visible value or workout detail. |
| Consistency: program consistency | How closely completed training matches the plan | Keep: this is different from merely training frequently. Explain what the 40% represents alongside 0/3 sessions, 6/15 exercises, and 15/24 sets. Make “3 shortened” lead to the affected sessions, and give target/estimated RIR plain-language context. |
| Consistency: Muscle workload shortcut | Where to inspect muscle-specific training | Useful navigation, not another metric. Keep compact so it does not compete with analytical cards; it currently sits between adherence and the workout calendar. |
| Consistency: workout calendar | Which workouts happened on a particular day | Keep as history navigation: selecting Oct 24 revealed the saved six-set workout. It overlaps with the heatmap's dates, so clearly distinguish “training pattern” from “open a workout,” or combine them as alternate views. “73 completed” above October reads like a monthly count even though the weekly overview labels 73 as all workouts; label its scope. |
| Strength: lift/tier overview and total | Current strength benchmarks | Useful status, but needs source/date labels, tier thresholds, and an explained bar endpoint. Static all-time numbers alone do not show progress. Clarify the bodyweight source for relative total, especially when Body has no logged weigh-ins. |
| Strength: other tracked lifts | Benchmarks outside the three main lifts | The reason these three lifts are featured is unclear. Let users choose relevant lifts or move these into the exercise selector rather than maintaining another prominent snapshot. |
| Strength: exercise progress summary | Change for the selected lift | Keep. Label “Increase” as starting-to-best if that is the intended comparison; the positive best-ever increase does not describe the latest point's decline from the peak. Show the comparison dates and period. The single-workout state usefully shows a best logged set and explains the trend-data requirement. |
| Strength: estimated 1RM and weight trends | Estimated capacity versus actual logged loads | Both can be useful, but the near-identical charts consume substantial space. Consider one chart with an explicit metric selector; label units and distinguish actual loads/reps from estimates. Keep workout drill-down discoverable. |
| Strength: rep-range PRs and set/session volume records | Best performances in different contexts | Useful secondary records, not four separate headline insights. Group into a compact records area with dates and source workouts. Volume records should use explicit weight × reps units. |
| Strength: rep-range progression | Whether prescribed rep targets are being achieved | Keep distinct from PRs, but emphasize a trend or next decision rather than only a list of workouts with sets-in-range counts. Label its period and whether all prescribed sets were completed. |
| Muscle: muscle map | Which muscles received logged work | Keep as an overview. Primary and Secondary legend dots appeared the same bright yellow even though parts of the figure were green. Make the legend match the figure, add non-color distinctions, and allow selecting a muscle for its name/count/source exercises; the inspected map tap showed no detail. It is not a fatigue or recovery view. |
| Muscle: workload and training-emphasis insights | How direct sets/frequency vary by muscle and over time | Keep as the main actionable muscle card. Drill-down successfully shows the source exercises, individual sets, dates, and links to workouts. Separate selected-week counts from comparisons over completed weeks; avoid mixing the periods without a clear heading. Long explanations should support a short takeaway rather than bury the weekly table. |
| Muscle: estimated volume share | How recorded weight × reps is distributed | Lower-priority detail: proportions overlap with workload without directly explaining progress or a plan target. Consider placing this inside workload details. Keep the visible clarification that a smaller share does not imply underdevelopment; prominently identify excluded bodyweight/timed work and the estimate's scope. |
| Body: bodyweight trend | Change in measured bodyweight over time | Keep, but fix the empty state: it says both “Log bodyweight to start” and “Add another weigh-in,” then displays an empty table. Use one clear no-data message and Log action; distinguish no data from one reading and no readings in the selected range. |
| Body: bodyweight entry | Log a dated measurement | The sheet leads with “Week 1,” prepopulates 198 lb, and shows today's date without an obvious date editor. Explain where the prefilled value comes from and make date/measurement the primary context rather than program week. Opened and canceled without saving. |

### Cross-screen improvements

- [x] Give each main card a clear question, date range, data source, and one takeaway; keep raw statistics as supporting detail. Added explicit source/metric notes for consistency and strength, date/source notes for measurements, and direct period labels for trend and record cards.
- [x] Reduce repeated headline totals and nested tiles. Standardized card titles and compact numeric formatting, labeled volume units, and removed the duplicate lifetime workout total from the weekly overview.
- [x] Use aligned periods or clearly label exceptions: this week, prior completed weeks, lifetime bests, and the selected exercise's history currently coexist. Weekly, prior-four-full-weeks, 14-day comparisons, selected trend ranges, and all-time records now identify their periods.
- [ ] Review chart and heatmap accessibility. Heatmap cells announce their date, value, units, and relative intensity. On the latest installed Debug build, the simulator accessibility tree exposes each Progress category as a named selectable button; strength chart points announce date, metric, and units, and selecting a point exposes its workout action. The bodyweight chart has date-and-unit labels in its accessibility representation. Actual VoiceOver speech is still unverified because the Simulator menu has no VoiceOver control and Settings search did not surface one.
- [x] Treat body measurements and progress-photo comparisons as visible feature gaps in this build; neither was available on the inspected Body screen. A muscle-fatigue card was also not visible. Do not claim those experiences were tested. The Body screen now states these gaps and explains that Muscle shows logged training recency rather than directly measuring fatigue, recovery, soreness, or readiness.

Suggested information hierarchy: Consistency = frequency and adherence; Strength = lift changes and records; Muscle = set distribution and training emphasis; Body = changes in actual measurements. Keep the heatmap for patterns, calendar for history, and muscle drill-down for evidence instead of repeating the same totals in each.

## Me and public profile audit

Observed October 24, 2026, in the iPhone 17 simulator with the Alex Reyes demo profile. Reviewed Me, expanded Training details, Awards, personal profile Overview/Timeline, public Overview/PR videos/Training/Submissions, and the profile editor. Findings are from the UI only; no code investigation or profile edits were saved.

### Priority clarity problems

- [x] **Correct the Rival Tier explanation or displayed result.** Awards now explains that Rival Tier uses the lowest tier across squat, bench, and deadlift, matching the calculator. The Me header labels it Rival Tier.
- [x] **Distinguish verified experience from Rival Tier.** Profile and editor labels now read Verified experience, separate from Rival Tier.
- [x] **Explain public/private view boundaries.** The owner's public profile preview now identifies itself and links directly to Privacy settings. Separate-account authorization remains untested.
- [x] **Explain or omit the blank strength score.** Source review found no SCORE field rendered in the current profile UI; removed the unused score formatter. The reported blank field is not present in the current source.

### Me: hierarchy and repetition

- [x] Consolidate duplicate stats: Me now has one compact, actionable workout/PR/streak summary; Rival Tier appears without a repeated badge, and lift submissions are labeled separately from benchmarks.
- [x] Make Workouts, PRs, and Streak actionable or give them clear destinations. Me metrics now open the relevant Progress category; workout PRs and shared lift submissions have distinct labels and destinations.
- [x] Make Training details discoverable and communicate its expanded state. The disclosure is labeled Submitted lift records, explains what it reveals, and exposes its expanded/collapsed state to accessibility.
- [x] Clarify navigation between Training details, Rival tier & awards, and Your lifts and history. The Me hub now distinguishes Lift submissions, Training progress, and Rival tier & awards; personal profile includes a Workouts section.
- [x] Clarify the gym row. Gyms now reports the selected primary gym and joined-gym count separately.
- [x] Give numbers explicit scopes and units. Me labels the lifetime workout count, workout PR count, and current weekly streak; submitted lift counts distinguish submissions from distinct exercises. Weekly volume is not duplicated in the current profile view.

### Awards reached from Me

- [x] Put Rival Tier and next goals before the long unlocked collection. Awards now leads with Rival Tier and closest goals.
- [x] Group/filter incremental awards instead of giving First Workout, 2 Workouts, 3 Workouts, and similar milestones equally prominent tiles. Remaining awards are grouped by type, capped with Show all, and earned awards show their dates.
- [x] Fix visible singular/plural copy, including “1 Programs Started” and “1 Training Hours.” Both display as singular in award cards.
- [x] Consolidate the duplicate next-goal and locked-award entries. The three featured next goals are excluded from the grouped Other awards list, whose locked cards show criteria.

### Public profile: usefulness and presentation

- [x] Compact the repeated identity header or let it collapse. Profile details now collapse under a single disclosure; public profile navigation no longer repeats the username as its title.
- [x] Clarify Back versus Done. An owner preview has one Done action; visitor profiles keep normal Back navigation.
- [x] Keep tab navigation accessible on long histories and make horizontal overflow clear. The personal profile exposes Workouts directly, and profile section buttons have names, selected traits, and a visible horizontal scroll indicator.
- [x] Define Shared lifts versus Exercises. The profile summary labels submission count and distinct exercise count; Me distinguishes workout PRs from lift submissions.
- [x] Reduce duplication between Latest lift, the three-lift Strength summary, and Submissions. Current profile surfaces label benchmark, progress, and dated submission roles separately.
- [x] Explain self-reported versus verified/ranking status consistently. Submission rows explicitly describe attempts and show evidence status; verified experience is labeled separately from Rival Tier.
- [x] Give public training history a manageable browsing experience. Public profiles expose only shared lift submissions, with date and exercise filters and an expand/collapse list; private workout history remains unavailable to visitors.
- [x] Clarify whether public training/submission rows are intentionally read-only. Lift rows are accessible buttons that open submission details; report actions remain separate.
- [x] Improve the PR-video empty state for an owner viewing their preview. Owner previews explain how to add a video and provide a Submit lift with video action when videos are public.
- [x] Replace unexplained Hidden/blank metric slots. Private relative totals and absent lift benchmarks are omitted from public strength cards.

### Personal profile and editor

- [x] Reduce overlap between Personal profile, Me Training details, and Track Progress. Detailed strength analytics now route to Track; profile focuses on submitted lifts, public sharing, and history management.
- [x] Clarify Progress timeline's scope. The dated workout-count timeline is labeled Training milestones.
- [x] Label which profile fields are public in the editor. Bio, location, primary gym, verified experience, and bodyweight each explain their public visibility behavior.
- [x] Preserve clear save boundaries for profile photos and bodyweight. Photo changes are labeled as immediate and separate; the bodyweight action is Log bodyweight and explains its separate dated save and privacy behavior.
- [x] Standardize changed profile controls with existing typography tokens and semantic accessibility labels. Assistive-technology verification remains a follow-up.

What worked: View public profile gives a distinct preview; public submissions visibly label self-reported evidence; public Training showed the synthetic workout summary without its private audit note; public relative total was Hidden while personal relative total was visible; the personal timeline provides milestone dates; Awards' next-goal cards show concrete remaining progress. Follow/rival actions for a different signed-in viewer, populated video playback, remote privacy enforcement, and edit/save validation were not tested.

## UX/UI reaudit — October 25, 2026

Current simulator walkthrough, iPhone 17, dark appearance, demo data. The descriptions preserve the observed gaps; checked entries now have implementation and verification evidence below. The earlier completed checklist entries remain historical implementation notes; the current runtime still shows some of those problems.

Count: **48 issues: 5 Me + 8 public profile + 16 Progress + 19 Tracker**. Each checkbox below counts once, including findings that affect multiple screens. Tracker here covers Today, Plans, Library, and their inspected detail views; Progress is counted separately.

Prior implementation goal completed October 25 at approximately 2:40 a.m. Eastern: **48/48 implemented at that checkpoint; pass 2 subsequently reopened TR-05 and TR-12** (Me 5/5, public profile 8/8, Progress 16/16, Tracker 19/19). Final Debug build succeeded, was installed, and launched on the iPhone 17 simulator. Long automated tests were skipped at the user's request. A one-time 4:45 a.m. Eastern check remains scheduled; if completion is confirmed, it starts a fresh audit of all checklist screens and flows.

#### Fix verification evidence

| Area | Simulator/source evidence |
| --- | --- |
| Me | Distinct preview/manage/benchmark destinations and metric chevrons; shared 12w streak; readable closest-award goals; separate read-only earned status with reachable explanation. Owner verified experience agrees as Beginner in editor and public details. |
| Public profile | Compact owner/visitor header with one visible Done; individually exposed selected section buttons; short submission dates, badges and chevrons; aligned two-column video placeholders; explicit unavailable state with Retry; flat, compact single-performance Strength state and named Leaderboards link. |
| Consistency | Single-line category label; compact weekly summary; readable five-week text rows; 12w streak matches Me and explains carry-over; Log a workout opens the existing entry sheet. |
| Strength | Exercise trend now leads the first viewport; metric selector switches estimated 1RM/logged weight; actual first/latest dates and selected-range explanation; advice distinguishes last three workouts from two 14-day averages without repeated recommendations. |
| Muscle / Body | Four initial signal tiles with 0–100 explanation and text color legend; Glutes opens Oct 18–24 with contributing sets. Body shows one empty message and opens its bodyweight editor. |
| Today / Plans | Labeled Submit lift; active-program context and unfinished-workout route; name/status/date range, visible views, scoped management menu; saved-workout review priority; partial progress shows 15/24 sets and explains full completion; focused searchable/filterable catalog with readable saved status. Preview workload expands into aligned muscle rows; Edit Setup title fits with Cancel/Preview and collapsed scheduling explanations. |
| Library | Alphabet ends above floating navigation; matching 549 counts; selected filter summary; Clear search restores results; singular working-set copy; dated record links open the matching workout; explicit volume units, chart period/current value and readable axis labels. |

Verification limits: unavailable demo video remains unavailable after Retry, so live media playback is unverified. Profile Done is visually/source verified; its toolbar button was omitted by simulator accessibility inspection and coordinate input returned `noWindowsAvailable`; visitor sheet dismissal was exercised through accessibility Cancel. Alphabet positioning is visually verified; AX activation did not confirm its scroll jump. No profile edits, bodyweight entries, plans, exercises or workouts were saved or started during fix verification. Build and diff checks passed; no new files, architectural abstractions or dependencies were added for these fixes. Existing record models gained source-workout IDs and existing stores gained date lookups to support provenance/context.

### Me — 5 issues

- [x] **ME-01 — Simplify overlapping destinations.** Submitted lift records, Lift submissions, and View public profile divide related content between the Me hub and a second Personal profile hub. Make the destination and purpose of each action clear.
- [x] **ME-02 — Make interactive statistics look interactive.** Workouts, Workout PRs, Weekly streak, and expanded lift tiles look like static summaries despite being buttons. Add a consistent visual cue and clear destination.
- [x] **ME-03 — Reconcile verified experience.** The editor showed Beginner while the public profile details showed Intermediate for Alex Reyes. Use consistent values and terminology across these views; do not imply the Rival Tier is the verified-experience level.
- [x] **ME-04 — Improve the closest-awards treatment.** Dim text and icons make the nearest achievable goals look disabled. Keep progress and the remaining requirement readable and visually actionable.
- [x] **ME-05 — Distinguish editable and read-only editor fields.** Verified experience appears in the same form as editable identity fields and uses the accent color. Give earned information a clearly different presentation and an explicit route to its explanation.

### Public profile — 8 issues

- [x] **PP-01 — Use one clear dismissal action per presentation.** The owner preview visibly has both Back and Done. A visitor profile opened from Leaderboards as a sheet with no visible Close or Done control. Match navigation to the presentation.
- [x] **PP-02 — Reduce header overhead.** The preview banner, identity card, collapsed details row, and section navigation consume much of the first screen. Keep useful athlete context and the first meaningful content visible together.
- [x] **PP-03 — Improve section navigation.** Later sections are clipped horizontally, and the inspected accessibility tree exposes a section-navigation group without individual tab controls. Make all sections discoverable and expose each name and selected state.
- [x] **PP-04 — Simplify submission rows.** Full weekday/date/time strings wrap inconsistently beside evidence badges and overflow menus. Prioritize exercise, result, short date, and evidence; move exact timestamps into details and make row interaction clear.
- [x] **PP-05 — Give video cards and playback clear states.** Visitor video tiles showed black areas and uneven caption heights. Opening a demo video showed an unavailable-player symbol without an explanation or retry action. Provide stable placeholders, aligned captions, and readable loading/unavailable states. This demo observation does not establish a production media-service failure.
- [x] **PP-06 — Flatten the Strength card.** Separate rounded containers surround the exercise name, units, one-entry message, and chart. Consolidate these into one coherent hierarchy with fewer borders and less padding.
- [x] **PP-07 — Replace the one-point trend presentation.** A single submitted lift still gets a large chart and repeated best/latest values. Use a compact single-performance state until comparison data exists.
- [x] **PP-08 — Reduce the Rankings placeholder.** A prominent nested card says rankings are not shown here and offers a generic View action. Use a compact, clearly named Leaderboards link so submission progress receives priority.

### Progress — 16 issues

- [x] **PG-01 — Keep category labels readable.** Selected Consistency wraps as “Consisten- / cy” at the inspected size, while the other categories occupy one line. Give selected labels enough width or choose a layout that handles longer names.
- [x] **PG-02 — Compact the weekly summary.** The empty This week card fills most of the first screen with zero metrics, source notes, a streak explanation, and repeated logging guidance. Lead with one takeaway and keep supporting explanations secondary.
- [x] **PG-03 — Enlarge the five-week volume comparison.** Bar values and dates are very small and crowded into a corner of the summary. Provide a legible chart or a compact textual comparison.
- [x] **PG-04 — Add an action to the empty weekly state.** The screen repeatedly asks users to log a workout but has no direct Start/Log workout action in that state.
- [x] **PG-05 — Reconcile the weekly streak across screens.** Me showed a current 12w streak while Consistency showed Week streak 0 for the inspected demo profile. Explain any intentional difference or align the displayed result, especially at the start of a new week.
- [x] **PG-06 — Bring exercise progress closer to the Strength entry point.** Tall disclosure rows, all-time records, and structural-balance content precede the selected exercise trend. Reduce navigation depth and excess vertical spacing around the main progress task.
- [x] **PG-07 — Explain apparently conflicting strength signals.** Dumbbell Hammer Curl appeared Improving (+20.0%) in the breakdown and “may be stalled” in next steps. Identify each comparison window and explain the distinction; the same generic advice is repeated across exercise cards.
- [x] **PG-08 — Consolidate the Strength charts.** Estimated 1RM and logged-weight charts are stacked with near-identical shapes, consuming substantial space. Use a clearly labeled metric selector or a more compact comparison while preserving the distinction between estimates and actual sets.
- [x] **PG-09 — Match trend explanations to the selected period.** The selected exercise view showed last 3M, but About this trend described “this 28-day window.” “Since start” also omits the actual comparison dates. Label the selected range and first/latest eligible dates consistently.
- [x] **PG-10 — Clarify the muscle estimate's meaning.** Muscle leads with “Muscle fatigue estimate” and precise percentages, while Body explicitly says Muscle does not directly measure fatigue or recovery. Name the signal consistently and explain what the percentage represents beside the metric.
- [x] **PG-11 — Reduce the mandatory muscle grid.** Seventeen tiles dominate the first screen and push workload information below it. Lead with a useful summary, then provide an expandable list or focused selection.
- [x] **PG-12 — Preserve context when opening a muscle estimate.** Tapping Glutes 97% opened the current week with no logged work. Open the contributing period for the selected signal or explicitly bridge recent-work estimates to the selected-week workload.
- [x] **PG-13 — Explain muscle colors and thresholds.** Orange and lime bars appear without a visible legend or text explaining their ranges. Add meaning that is available without relying on color.
- [x] **PG-14 — Add Log bodyweight to Body.** The empty state asks for a dated measurement but provides no action to enter one. Keep measurement entry available beside the trend.
- [x] **PG-15 — Use one Body empty-state message.** The same card says both “No bodyweight measurements in this period” and “No measurements in the selected range.” Consolidate the message and distinguish no history from a range without readings.
- [x] **PG-16 — Replace release-status copy in Body.** Other progress tools is a prominent card explaining what is “not available in this build.” Present useful available actions and place feature availability information where it helps users decide what to do.

### Tracker: Today — 2 issues

- [x] **TR-01 — Identify the header's add action.** Today's header uses an unlabeled plus-in-circle for Submit a lift, while the main task is starting/logging a workout. Distinguish lift submission from workout creation before the user taps it.
- [x] **TR-02 — Give rest days useful plan context.** With an existing program, Today leads with Rest day and Browse Workout Programs, followed by freestyle. Show the active program and next scheduled session/date, with browsing treated as a secondary task.

### Tracker: Plans — 9 issues

- [x] **TR-03 — Show the active program name.** The screen starts with the generic Program details and 12 scheduled weeks. Identify the program being viewed and its active/saved status prominently.
- [x] **TR-04 — Reduce the prominence of import.** Import shared program occupies the first full-width action above the existing plan. Prioritize reviewing or continuing the selected program and put import with program-management actions.
- [x] **TR-05 — Clarify the viewed week's time and status.** The workout-list selector shows Week 12 and 12 of 12 without calendar dates or a clear link to the next unfinished session. Distinguish the week being browsed from the next training action.
- [x] **TR-06 — Expose view switching and scope actions accurately.** Week options contains Workouts/Plan Overview, Plan Notes, program sharing, week edits, and Use session queue; a separate Plan options menu also exists. Put view switching visibly on the page and group actions by their actual scope. Explain session queue before changing scheduling behavior.
- [x] **TR-07 — Rework saved-session action hierarchy.** Shortened saved sessions prominently offer Add Exercise and Repeat workout, while Review saved workout looks secondary. Lead with the saved result/status and clarify that plan edits affect prescriptions while Repeat starts a separate attempt.
- [x] **TR-08 — Explain partial completion in the overview.** The overview shows 0% and 0 of 3 workouts completed alongside 15 of 24 planned sets logged. Make partial progress legible and explain how shortened saved sessions contribute to each metric.
- [x] **TR-09 — Improve program-catalog browsing.** Expanding the catalog inserts 20 programs below the active plan, without visible search or goal/equipment/frequency filters in the inspected catalog. The first saved-program card truncates its resume/start status. Give browsing a focused layout and keep saved-state actions readable.
- [x] **TR-10 — Make preview workload information scannable.** Weekly muscle sets appear as a long inline paragraph followed by “No muscle targets are configured” and schedule-conflict guidance. Use a compact readable summary with a useful takeaway and move configuration diagnostics into setup.
- [x] **TR-11 — Make setup mode explicit.** Choosing Edit existing setup changes the primary action to Save setup changes while the navigation title remains Program Preview. Distinguish preview from editing, offer a clear return/cancel path, and keep long scheduling explanations from burying the training-day controls.

### Tracker: Library and exercise details — 8 issues

- [x] **TR-12 — Keep the alphabet index above bottom navigation.** The right-side index extends behind the floating tab bar, obscuring its final letters. Fit the index within the usable viewport and preserve a reliable jump target for every section.
- [x] **TR-13 — Reduce filter-sheet scanning effort.** Equipment, body area, and a long primary-muscle grid use the same flat button treatment; more filters extend below the first viewport. Group or progressively reveal choices, keep selections easy to review, and improve the distinction between enabled unselected controls and disabled controls.
- [x] **TR-14 — Reconcile unfiltered Library counts.** Library showed 549 exercises while the filter sheet initially offered Show 550 Exercises, with no filters applied. Make the visible count and the filter result count describe the same set or explain the difference.
- [x] **TR-15 — Fix the search-only no-results action.** Searching for zzzzzz with no filters applied still presents Clear filters. Tapping it leaves the search and empty state unchanged. Offer Clear search/change query for that state and show filter-reset actions only when relevant.
- [x] **TR-16 — Fix singular set-count copy.** Exercise History displays “1 working sets.” Use the singular form for one set and preserve the plural form for other counts.
- [x] **TR-17 — Give exercise records provenance.** Best estimated 1RM, session volume, set volume, and heaviest weight have no visible dates or source-workout links. Let users understand when and where a record was achieved.
- [x] **TR-18 — Label exercise-detail metrics consistently.** Record volume is shown as lb instead of explicit weight × reps units, and the Est. 1RM chart has numeric ticks without a visible weight-unit label. Distinguish volume load from lifted weight across Records and Charts.
- [x] **TR-19 — Improve the exercise chart's time context.** The chart clips its final date label to “Oc…” and offers no visible date-range selector or headline current/change summary. Keep axis labels readable and state the displayed period and metric takeaway.

Review coverage: Me, expanded lift records, profile editor, Awards, Personal profile submissions and lift details; owner public preview Overview/details/Submissions/PR videos/Strength; visitor Overview/video grid/player; Progress entry states in all four categories, Strength recommendations and exercise charts, Muscle estimate drill-down and four-week context, and Body's empty state with All selected. Tracker coverage includes Today's scheduled-rest-day state, the saved/shortened-session plan list, Phase details, Week options and Plan Overview, the expanded program catalog, an existing program's preview and setup form, Library browsing, filter selection/cancellation, search-only no-results recovery, Back Squat About/History/Records/Charts, and the unsaved custom-exercise form. No profile edits, measurements, exercises, plans, or workouts were saved or started during these reaudit walkthroughs.

Limits: Simulator scroll/drag automation did not move several lower cards. The lower Consistency heatmap/calendar and the full Muscle workload table were not visually reaudited in this pass. Populated Body trends, Today with a pending scheduled session or active workout, workout execution/finish flows, setup save/activation behavior, smaller devices, larger text sizes, light appearance, actual VoiceOver speech, and live account/media behavior remain unverified. Counts above cover confirmed findings from inspected states, not an exhaustive sign-off on every state.


## UX/UI reaudit — October 25, 2026, pass 2

**Implementation and focused verification completed October 25, 2026, at approximately 7:50 a.m. Eastern.** The user requested a repeat audit, then explicitly asked that the scheduled task continue from this point and fix the issues afterward. The earlier 48-item completion entry records the prior implementation pass; this walkthrough found additional gaps and residual acceptance problems. This section is the current work list, not a claim that every state has been audited.

**24 confirmed findings, all implemented: Me 3/3, public profile 5/5, Progress 7/7, Tracker/program builder/Library 9/9.** Count each item below once. The reopened historical TR-05 and TR-12 are represented here and must not be added again to this total. P1 = misleading review information; P2 = usability, navigation, clarity or accessibility problem; P3 = layout/refinement.

### Me — 3

- [x] **R2-ME-01 [P2] — Make the Workout PR count explainable at its destination.** Tapping Me's “49 Workout PRs” opens Strength at the previously selected Dumbbell Hammer Curl trend (41.9 lb); it does not show or explain the 49 earned records. Route to a relevant PR list/summary or give the destination a clear bridge to the count.
- [x] **R2-ME-02 [P2] — Include result values in submitted-lift accessibility labels.** Expanded Me tiles visibly show Bench 245 lb, Squat 365 lb, Deadlift 455 lb, and Total 1065 lb. Their inspected accessibility labels only say “View submitted … lift” / “View total strength breakdown,” omitting those results. Expose exercise, value, unit and source together. Actual VoiceOver speech was not tested.
- [x] **R2-ME-03 [P3] — Reduce overhead in the submission-management destination.** “Manage lift submissions” opens another identity/editing card plus five navigation pills over three rows; the submission list begins near the bottom of the initial viewport. Keep the management task and its results prominent while retaining access to secondary profile content.

### Public profile — 5

- [x] **R2-PP-01 [P2] — Allow choosing the exercise in public Strength.** Alex has three shared exercises and the visitor has four, but Strength shows only Back Squat (365 lb / 435 lb respectively), with no visible or inspected selector to review the other exercises. Offer the available exercises and make the selected exercise clear.
- [x] **R2-PP-02 [P2] — Reconcile Actual versus Estimated 1RM labels.** Alex's 365 lb × 1 submission detail says “Actual 1RM”; the public Strength card describes the same dated performance as “Estimated 1RM.” Preserve the distinction between an actual single and a calculated estimate consistently.
- [x] **R2-PP-03 [P3] — Give the owner's video empty state a readable layout.** “No PR videos yet” places an icon, narrow explanatory text, and a long “Submit lift with video” action side by side. The explanation wraps into many short lines. Put the action below the message or otherwise give the copy enough width.
- [x] **R2-PP-04 [P2] — Explain Relative total beside the result.** The visitor overview shows “Relative total 9.91x” without the formula, bodyweight reference/date, or an explanation of unavailable/private reference data. Explain the ratio and its reference while respecting privacy; this observation does not establish a calculation error.
- [x] **R2-PP-05 [P2] — Expose video-card metadata accessibly.** Visible cards show result values and unavailable previews, but the inspected button names only say “Play [exercise] lift video.” Include weight, reps, and preview state in the accessible description; add a short date so repeated videos of the same exercise can be distinguished before opening them.

### Progress — 7

- [x] **R2-PG-01 [P2] — Finish volume-unit consistency outside Library.** Strength's expanded records show best set volume 264.6 lb and best session volume 793.7 lb; selected chart performance says “264.6 lb volume.” Program creation review likewise shows “Weekly recorded volume: 20618.5 lb.” Use explicit weight × reps units wherever volume load is presented, as Library now does. This is one cross-screen unit issue.
- [x] **R2-PG-02 [P2] — Give Progress records provenance and an accurate disclosure title.** “Records and recent sessions” for Hammer Curl exposes an 8-rep PR and all-time set/session volume values without dates, source-workout links or an actual recent-session list. Bring the dated/source-linked treatment already present in Library here, and make the disclosure name match its contents.
- [x] **R2-PG-03 [P2] — Make dated bodyweight entry and prefill explicit.** Body has no measurement history, yet Log bodyweight opens an enabled Save form prefilled with 198 lb and a static October 25 date. Explain the source of the prefilled weight and provide a clear date control for earlier measurements; avoid making an unchanged profile/default value look like a newly measured reading.
- [x] **R2-PG-04 [P2] — Keep comparison units consistent in drill-downs.** The Glutes contributing-week sheet mixes 89 lb and 117.5 lb rows with 37.5 kg and 20 kg rows despite the profile's lb presentation elsewhere. The new-plan review also mixes kg/lb suggested loads. Present comparable values in the preferred unit, optionally retaining an explicit recorded-unit detail.
- [x] **R2-PG-05 [P3] — Use the heatmap's available width and clarify month placement.** At 30D the heatmap occupies a small cluster at the left of a wide card; even 90D leaves substantial unused width. Month names appear as a separate “Sep · Oct” / “Jul · Aug · Sep · Oct” list rather than aligned positions. Improve readability and date orientation within the available card space.
- [x] **R2-PG-06 [P2] — Identify the Program consistency percentage denominator.** The lower card shows a 40% ring alongside 0/3 sessions, 6/15 exercises and 15/24 sets. It does not state that 40% corresponds to the exercise fraction or explain why this differs from Plans' set-based progress. Label the score/formula and preserve the distinction between adherence metrics.
- [x] **R2-PG-07 [P2] — Make shortened-session status lead to the affected results.** The “3 shortened” badge in Program consistency is exposed as a non-button element; both accessibility activation and a direct tap left the screen unchanged. Provide a named action to inspect those saved workouts, with a clear explanation of their completion status.

### Tracker, program builder and Library — 9

- [x] **R2-TR-01 [P2] — Complete the plateau evidence and drill-down.** Today's “Review recent sets” sheet claims both estimated strength and total working-set volume failed to rise, but displays only three best sets/estimated 1RMs. Show the volume evidence or narrow the claim, and provide source-workout actions so the user can inspect all contributing sets.
- [x] **R2-TR-02 [P2] — Make unfinished-workout routes consistent.** Today opens Week 12 through “Review unfinished workouts.” Browsing the completed Week 11 overview identifies “Review unfinished week: Week 4 · Deload,” and that action opens Week 4. Decide consistently whether shortened saved attempts count as finished, identify the relevant next action, and route to it; do not silently choose a different week depending on entry point.
- [x] **R2-TR-03 [P2] — Label the viewed program week accurately.** After browsing Week 11 (Oct 12–16), Overview says “Current week · Week 11” on Oct 25. Consistency then follows the browsed Week 4 and shows “Week 4 · Week 4 · Deload,” without its calendar range. Use Viewed/Selected week and its dates, reserving Current for an actual current-period calculation. This is the residual historical TR-05 finding.
- [x] **R2-TR-04 [P1] — Reconcile new-plan review totals with the shown prescriptions.** With the default three history sources, review says 25 working sets/week (Full Body C 5, Demo Strength 15, Full Body B 5). The displayed prescriptions sum to 8 + 15 + 7 = 30 sets. Clarify source-completed sets versus newly prescribed sets and ensure the activation summary describes the plan being created. No plan was activated; saved-plan behavior/data corruption is not established.
- [x] **R2-TR-05 [P3] — Fit the creation-review title.** The review toolbar visibly truncates its title to “Review pro…” beside the wide Create & activate action. Use a short title or a layout with adequate room, as the revised Edit Setup screen now does.
- [x] **R2-TR-06 [P2] — Improve catalog-search contrast.** Program catalog's search field has a black fill and very dim placeholder/border in dark appearance, unlike Library's readable search control. Match the established search treatment and verify placeholder/input contrast.
- [x] **R2-TR-07 [P3] — Separate catalog goal and equipment filtering.** “All goals & equipment” is one mutually exclusive category menu containing Bodybuilding, Powerlifting, Cables Only, Free Weights Only and General. It cannot combine a goal with equipment, and has no explicit machine/bodyweight/dumbbell equipment choices despite catalog programs using them. Offer clear independent filters or label this accurately as program categories and provide usable equipment refinement.
- [x] **R2-TR-08 [P2] — Repair distant alphabet jumps.** The index now fits above the tab bar, but tapping Z through its named control and by direct coordinate leaves the list at the beginning. Tapping B correctly jumps to the B header. Keep the positioning fix and make every index destination reliable. This reopens historical TR-12; unlike the prior pass there is a successful nearby-jump control comparison.
- [x] **R2-TR-09 [P2] — Make the exercise chart table complete or explicitly partial.** Back Squat's chart announces 12 workouts and a range beginning Aug 2, but “Show data table” starts Aug 30 and lists eight dates through Oct 18. Provide all plotted entries or identify the limited subset and offer the remaining rows; accessible numeric data should cover the same range as the chart.

### Original audit handoff checkpoint — superseded by the completion evidence below

- Reviewed: Me hub and Workout PR navigation, expanded lift records, editor, Awards; personal submissions and submission detail; owner public Overview/details/Strength/video empty state; visitor Overview/Strength/submissions/video grid/unavailable player; all four Progress entry categories, Strength metrics/selected point/records, Glutes contributing-week sheet, Body entry sheet, 30D/90D heatmap, lower Program consistency; Today plateau sheet and unfinished route; Plans viewed weeks/phase/overview, management menu, history-based creation and final review, saved-plan disclosure, catalog/categories, template preview/Edit Setup; Library B/Z jumps, About/History/Records/Charts/data table, search-only recovery, search-aware filter sheet, and custom-exercise form.
- Continue before fixing: inspect the lower workout calendar and remaining Muscle workload/volume table; complete saved-plan selector coverage; review freestyle/workout execution/finish-review screens when safely reachable without saving synthetic records; inspect other original checklist states that remain unverified. Reuse this evidence and avoid repeating the completed walkthrough wholesale. Confirm the current screen after the interrupted tool call; its attempted return from Rankings to Track may have executed. Rankings was used only to open the visitor profile.
- Audit limits: iPhone 17, dark appearance, demo data. No fresh automated tests or build were run for this audit. Drag/scroll tooling did not reliably move some ScrollViews, although several control activations revealed lower content. Calendar click targeting was unreliable and unexpectedly returned to Rankings; do not treat that as an app navigation defect. Actual VoiceOver speech, light appearance, larger text/smaller devices, live account/media success, populated Body trends, active-workout execution and save/activation outcomes remain unverified. A plan name was entered only for an unsaved creation review, then canceled; no Create & activate, Save Profile, Save bodyweight or Save exercise action was taken.
- The previous fix build remains installed. No application code was changed during pass 2. The scheduled continuation should finish the audit, prioritize these confirmed findings, implement small targeted fixes, build/install the result, manually verify relevant UI where practical, and update evidence/checkboxes only when justified. Preserve all preexisting uncommitted work and skip long automated tests as requested.


### Pass 2 implementation and verification — October 25, approximately 7:50 a.m. Eastern

All **24/24 confirmed pass-2 findings** have targeted implementations and focused simulator/source verification. Historical TR-05 and TR-12 are checked again using the same evidence, without counting them as additional issues. No additional distinct defect was confirmed in the newly reached calendar and Muscle states. This is completion of the confirmed work list, not an exhaustive sign-off on every runtime state.

| IDs | Implementation and evidence |
| --- | --- |
| R2-ME-01–03 | Workout PRs opens a lifetime-count explanation and a route to exercise records; the simulator showed 49 and explained the selected exercise/date scope. Expanded lift AX values include 245/365/455 lb and the 1065 lb total. Submission management uses collapsed Athlete details and a section menu; all three submissions fit the initial screen. |
| R2-PP-01–03 | Public Strength offers the shared exercises. Switching Squat to Bench displayed 245 lb with its date and Actual 1RM. Single-result status uses the same `isActualOneRepMax` field as submission details; multi-result copy refers to each submission's recorded status. The owner's video-empty message and action now stack vertically and were visually readable. |
| R2-PP-04–05 | Visitor overview announces the three-lift-total/bodyweight formula, 164 lb reference and unavailable reference date. This remains within the existing bodyweight visibility condition. Visitor video buttons announce exercise, weight, reps, date and Preview unavailable; short dates also appeared visibly on the cards. Actual playback remains unavailable in demo data. |
| R2-PG-01–02 | Shared volume formatting and Progress record tiles use weight × reps. Hammer Curl showed 264.6 lb × reps / 793.7 lb × reps. Records and source workouts exposes dated PR/volume links; the PR link opened the matching October 14 workout. Workout details and program review also showed explicit volume units. |
| R2-PG-03 | Bodyweight editor explains profile-weight prefill and includes an editable, past-date-capable DatePicker. Selecting October 24 updated both the date control and header; canceled without saving. Future dates were disabled. |
| R2-PG-04 | Muscle contribution rows and plan suggested loads convert canonical kg to the preferred unit. The Glutes sheet showed formerly mixed-unit rows as 82.7 lb / 44.1 lb alongside 89 lb / 117.5 lb. Every inspected creation-review load used lb. |
| R2-PG-05 | Heatmap distributes week columns across the card and places month labels above the relevant columns. Both 30D and 90D filled the available width in screenshots; dated AX values remain available. |
| R2-PG-06–07 | Consistency explicitly describes completed exercises ÷ planned exercises and distinguishes Plans' set fraction. The inspected AX tree exposed the formula beside the 40% result. The named Review 3 shortened sessions action opened the matching viewed Week 12, where saved-workout review buttons were visible. |
| R2-TR-01 | Plateau sheet shows each workout's working-set volume and source action. All three Row examples showed 2116.4 lb × reps; the October 22 source opened the October 22 workout with its sets. |
| R2-TR-02–03 | Today now uses the same fully-completed-session criterion as the overview's unfinished-week route. In the inspected no-future-session state it opened Week 4 · Deload, with August 24–28 dates. Overview said Viewed week and retained its set-completion explanation. Consistency identifies the viewed week once and includes the range. |
| R2-TR-04–05 | ProgramStore owns one shared imported-set-count calculation used by both creation and review. The unsaved default-source review showed 25 sets/week, with days 5 + 15 + 5 and exercise rows summing to those values. It explains completed counts and saved-target fallback. Review title fit beside Create & activate. Canceled without activation; persistence/activation outcome was not tested. |
| R2-TR-06–07 | Catalog search uses semantic field/text/placeholder colors and a subtle border. Final installed build showed readable placeholder and typed Dumbbell, returning 14 matches. Program category and Includes equipment are independent; equipment offered Barbell, Bodyweight, Cable, Dumbbell, Machine and Smith Machine. Selecting Dumbbell returned 14 matches. Includes means a program uses that equipment, not that it requires only that equipment. |
| R2-TR-08–09 | Alphabet IDs belong to the outer lazy section container. Z visibly jumped to Zercher Carry/Squat and Zottman Curl; B also jumped successfully. Chart data table now iterates every plotted entry: all 12 dates August 2–October 18 appeared in AX, including the four formerly omitted dates. |

Additional coverage: expanded lower Muscle workload and volume, including the populated Last week state (33,817 lb × reps), all 10 volume groups and counting explanation. Reached the workout calendar, navigated October → September and selected September 1 and September 30; selected-day workout results changed to the matching saved workouts. Calendar cells expose dates, workout counts and selection. Manage saved plans expanded; the demo has one saved plan, so a multiple-plan selector is not present and was not exercised.

Final verification: Debug `xcodebuild build` succeeded after the final profile-status and search-contrast refinements. Installed and launched `com.liftrank.app` on iPhone 17 / iOS 26.5, device `2BC3FC16-C814-4855-BC9C-EC81458870B6`, process **97550**. The final installed search was manually rechecked. `git diff --check` passed. Long automated tests were skipped as requested. Existing unrelated changes, including existing test-file edits, were preserved.

Verification limits: actual VoiceOver speech, other device sizes/larger text/light appearance, live account privacy enforcement/media success, populated Body trends, multiple saved-plan switching, plan activation/save, and workout execution/finish/save remain unverified. Starting freestyle immediately persists an active-workout snapshot; it was therefore not started merely to audit, honoring the no-synthetic-records constraint. No profile, measurement, plan, custom exercise or workout was saved, no migration was deployed, and nothing was published.

New structures: no new files or dependencies were added by pass 2. Two small helpers live in existing owners: ProgramStore.importedSetCount keeps creation and review counts identical, and the existing Strength records view's recordSource reuses one dated-workout-link rendering across PR and volume records. No new architectural layer was introduced.

Remaining unchecked historical follow-ups are the iPhone Mirroring input-tool investigation and actual VoiceOver speech verification. Neither is counted as an unresolved pass-2 app defect. For future coverage, use existing non-synthetic populated states or obtain a specifically disposable workflow before creating persistent audit records; then exercise the remaining save/activation and alternate presentation states listed above.


## Program workflow Astra pass — October 25, 2026

Goal: find and fix confirmed issues in workout program creation/editing and Plans. Astra handled investigation and implementation; after the user switched models, the current source was built and installed in the iPhone 17 / iOS 26.5 simulator. Do not mark entries verified merely because source edits exist. Preserve earlier uncommitted work. Build 49 is installed and running.

Continuation automation: `continue-program-workflow-after-usage-reset`, one-time October 25 at 12:13 p.m. America/New_York, after the reported 12:11:36 p.m. five-hour usage reset. Continue this chat and checkpoint; do not restart the audit.

Source-confirmed findings: **13 total; PW-01–12 implemented; PW-13 remains open.** Focused simulator behavior has been verified for PW-01, PW-03–06, PW-08–10; PW-02, PW-07, PW-11–13 still need the remaining coverage listed below.

- [x] **PW-01 [P1] — Save the history load shown in review.** Review derives Suggested load from the latest completed weighted set, but ProgramStore.createPlanFromHistory copies snapshot.targetLoadKilograms, which can be nil or different. Use the same canonical kg load for review and creation, with accurate source copy. **Focused simulator verification:** the review's suggested loads matched the created plan's expanded exercise prescriptions on representative history data.
- [ ] **PW-02 [P2] — Keep per-workout review set totals consistent.** Source fix implemented: day headings now use the same importedSetCount as exercise rows and overall totals. Verification is pending.
- [x] **PW-03 [P1] — Make a single saved inactive plan reachable.** Manage saved plans only renders plan buttons when count > 1; after stopping the only program or importing a sole custom plan, no resume action exists. **Focused simulator verification:** stopped and reactivated Full Body Foundation through Manage saved plans; the inactive row was reachable and clearly labeled.
- [x] **PW-04 [P1] — Respect exercise occurrence and superset boundaries in scoped editing.** updatePrescription matches every occurrence of exerciseID, even for This workout, and copies the source superset group onto other sessions' exercises. Edit the selected occurrence and preserve destination grouping. **Focused simulator verification:** edited one of two duplicated workout-day occurrences to 1 RIR; the other occurrence remained at 0 RIR.
- [x] **PW-05 [P2] — Preserve a target of zero RIR.** The prescription editor uses 0 as Not set and offers only 1–5, so saving an existing 0 RIR target silently removes it. **Focused simulator verification:** saved and re-opened a 0 RIR target; it remained displayed as 0 reps in reserve.
- [x] **PW-06 [P1] — Preserve custom prescriptions on schedule-only setup edits.** updateWorkoutProgramSetup always calls changeProgression, rebuilding sets/reps/loads even when only a weekday/date changed. Regenerate only when progression inputs actually change. **Focused simulator verification:** a date-only setup edit retained the customized 0 RIR and superset prescription; restored the original cycle start date (Aug 2, 2026) afterward.
- [ ] **PW-07 [P2] — Preserve substitutions when cloning a week or duplicating a plan.** Source fix implemented: copies retain substitutionExerciseIDs. Verification is pending.
- [x] **PW-08 [P2] — Make blank workout names invalid before Add.** Add Workout Day permits whitespace-only names, dismisses immediately, and has no inline validation. **Verified on iPhone 17 simulator build 49:** entered whitespace only; Add was disabled and the form remained open. Canceled without saving a record.

- [x] **PW-09 [P1] — Protect partially logged sessions consistently.** Setup rescheduling and progression rebuilding could change a session containing logged sets without a completed-workout record; superset actions also allowed recorded sessions. Reuse protected-session IDs for setup/prescription/superset changes and protect logged sessions in progression rebuilding. **Focused simulator verification:** attempting a scoped prescription save on a partially logged workout showed the protection alert and saved no change.
- [x] **PW-10 [P2] — Keep supersets as the selected pair.** Re-pairing an already grouped exercise reused the old group without detaching its former partner, accidentally creating a larger group. Clear former groups and create a fresh pair. **Focused simulator verification:** replaced the pair and confirmed only the selected two exercises shared the new superset; the former partner was detached.
- [ ] **PW-11 [P2] — Allow saved workout duplication and rescheduling.** Source actions are implemented for copying sessions with notes/prescriptions and moving only eligible sessions. Verification of destinations, occupied weekdays, queue order, and history protection is pending.
- [ ] **PW-12 [P2] — Keep creation failures visible and retain entries.** Source feedback and success-gated dismissal are implemented for creation. Verification of failures, retries, active-workout guards, and repeated submissions is pending.
- [ ] **PW-13 [P2] — Preserve unfinished creation drafts.** CreateWorkoutPlanView keeps its name, source assignments, date and duration only in @State; Cancel or swipe-dismiss destroys them. No program-draft persistence or resume owner was found. The original checked draft/resume item is not supported by current source. Still needs a targeted implementation using an existing persistence owner and clear account/device scope.

### Implementation evidence (not final testing)

- PW-01–02: shared ProgramStore.importedLoadKilograms now drives review and creation. Review day totals use the existing importedSetCount just like its exercise rows and total. Latest valid weighted set is normalized to kg; saved target is the fallback.
- PW-03: saved-plan rows render for one or more plans; inactive rows explicitly say tap to activate.
- PW-04–05: scoped editing matches the corresponding occurrence of an exercise in the same-named workout, using raw ordered prescriptions, and preserves destination superset fields. The editor distinguishes nil (-1 picker tag) from 0 RIR.
- PW-06: setup rebuilds progression only when method/max inputs differ and validates before changing the schedule. Untouched training-max text retains its original canonical value, preventing display-rounding from triggering a rebuild.
- PW-07–08: plan/week copies retain substitution IDs. Add Workout Day and Rename Plan reject empty/whitespace names and active-workout changes.
- PW-09–10: shared protected-session selection covers outcomes, completed workouts, logged sets and the active session. Setup and superset operations use it; repository progression rebuilding also excludes logged sessions. Pairing detaches former groups before applying one new group.
- PW-11–12: duplicate/move actions now live in the existing workout options menu, with named accessibility labels and failure feedback. Copies include notes and all raw prescription fields with new IDs; recorded history is not copied. Creation forms retain entries on failure, and history review guards repeated submissions.
- Changes are in the eight existing source owners: ProgramStore, AppState+TrainingPlans, ProgramSessionCard, ProgramPlanDetailView, WorkoutProgramTemplateDetailView, TrainingTrackerForms, TrainingTrackerView+Sections, DemoProgramRepository. Reviewed targeted diffs against the pre-Astra copies. No app files, model types, architectural layers or dependencies added. Small methods in existing owners centralize repeated import/protection rules and implement duplicate/move operations.

### Continuation checkpoint

- The 12:13 p.m. continuation fired during this work and has been handled; the consumed one-time automation `continue-program-workflow-after-usage-reset` was deleted. The goal remains active because PW-13 and remaining audit coverage are unfinished.
- **Implemented: PW-01–12. Remaining confirmed: PW-13. Behavior verified in focused simulator scenarios: PW-01, PW-03–06, PW-08–10 (8 findings).** Do not repeat implementation of PW-01–12. Review the latest files first if any later work occurred.
- Initial runtime coverage: build 48, Explore demo → Track → Plans → Plan options → Create Plan. Confirmed visible creation entry and saved-workout cards. Simulator was left on the unsaved New Plan sheet with an empty name. No workout, plan, measurement or profile record was saved.
- Next: investigate the smallest existing-owner solution for unfinished creation drafts (PW-13), account isolation and honest on-device/sync labeling; add explicit resume/discard behavior and loss prevention. Then finish source/initial-UI coverage of history schedule ordering, template setup errors, editable field labels, and saved-plan activation boundaries. Record any additional distinct defects with subsequent PW IDs; do not treat old checked claims as fresh proof.
- Baseline source copies: `/tmp/liftrivals-program-astra-baseline/`. Use them to distinguish this pass from the many preexisting uncommitted changes.
- **Luna simulator handoff (October 25):** Debug build completed successfully with `CODE_SIGNING_ALLOWED=NO`; installed app reports version 1.0 (build 48), and `xcrun simctl launch booted com.liftrank.app` returned PID 32790. This confirms compile/install/launch only, not the individual workflows or visual fixes. No automated tests were run; no synthetic records, remote migrations or publishing occurred.
- **Focused verification and build update (October 25):** On iPhone 17 / iOS 26.5, verified representative history-import review loads against created prescriptions; inactive-plan reactivation; scoped edit of duplicated occurrences; 0 RIR save; date-only setup retaining custom prescription; whitespace-only workout name validation; protection of partially logged workout edits; and replacing a superset pair. PW-08 was verified on build 49; other runtime checks used the same current source on simulator. No automated tests or account-backed flows were run. For checks requiring saved test records, only scheduled workouts were created; no workout set or submitted-lift history was saved. All three temporary test workout days were deleted, and Full Body Foundation's original Aug 2, 2026 cycle start date was restored. One saved inactive demo plan named “Codex History Verification” remains from the history-import check; Full Body Foundation is active. Build 49 (version 1.0) remains installed and running on iPhone 17 / iOS 26.5. No remote migrations or publishing occurred.
- Verification handoff after implementation: build the current source; in an explicitly disposable local workflow check history import with a skipped exercise, per-day/overall totals, lb/kg load persistence; sole inactive-plan resume; two occurrences of one exercise; distinct superset pairs across weeks; 0 RIR; custom prescriptions retained during a date-only setup save including precise training max values; logged/completed session protection; new pair replacing old partners; plan/week copy substitutions; empty-name validation; duplicate and move destinations/queue order/history preservation; creation failure/retry/double-tap; draft cancel/relaunch/account switching once PW-13 is implemented. Do not claim save or sync success from source inspection.

## Profile visual identity pilot — October 25, 2026

User approved implementing the design direction after comparing the running app with the supplied MaxRep screenshots. This is the first-screen pilot (Me and public profile), separate from PW-01–13. Status: implemented, built, installed, launched, and visually inspected in the iPhone 17 / iOS 26.5 simulator on October 25. The local Debug app reports version 1.0 (build 49); that build number was already in the project settings, and the simulator now runs the newly rebuilt source.

- Me: open identity header, secondary Edit/Public preview links, visible strength record instead of a collapsed disclosure, prominent submitted total, three compact lift values with evidence labels, quieter activity stats and neutral utility icons. Settings and all existing destinations remain available.
- Public profile: open identity header, compact underline navigation (menu at accessibility text sizes), an 18-point strength card with prominent total and separate units, and adaptive benchmark layout. Profile-owned controls use the existing semantic orange accent. The selected Me tab and placeholder avatar match it.
- Me's three displayed lift records now use the existing `bestSubmittedLift(... repetitions: 1 ...)` utility so they correspond to the submitted total's one-rep components. Multi-rep submissions remain available through Manage lift submissions; this does not change stored records or ranking rules. Evidence is labeled using the existing resolved status, not described as verified.
- Source owners changed: `MainTabView.swift` (Me only), `ProfileLogic.swift`, `ProfileViewSections.swift`, `LiftSurfaces.swift` (optional avatar accent preserving existing defaults), and `FloatingTabBar.swift` (selected Me tint only). No new files, types, dependencies, or persistence changes. Prior edits were preserved against `/tmp/liftrivals-profile-style-baseline/`.
- Rebuilt with Xcode Debug for the iOS simulator (`CODE_SIGNING_ALLOWED=NO`), installed and launched `com.liftrank.app` on the open iPhone 17 simulator, then inspected Me and owner public preview. Both show the new design and truthful self-reported evidence. Me's displayed 1065 lb total matches 245 + 365 + 455 lb. `git diff --check` passed. No automated tests or record edits were made during this visual pass.
- Verification handoff: inspect visitor public profiles in light/dark mode, narrow widths and large accessibility text. Check long names/bios, missing photos, zero/partial one-rep records, kg/lb, and mixed multi-rep history. Confirm hidden public data stays hidden, all profile sections and Edit/Settings/Preview/Submit/detail routes work, and content clears the tab bar. Review error/empty states too. Fix any layout or navigation failures before treating the pilot as fully verified.
- Next design stage after visual approval: extend the accepted treatment to Home, Plans and Progress. No app-wide palette or navigation redesign has been applied yet.
