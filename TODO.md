# To-do

- [ ] Finish and visually verify the full exercise icon replacement pass. Reopened: earlier named replacements left generic/misleading icons across the catalog and separate ranking/submission mappings. See [full icon audit](docs/exercise-icon-audit.md).
- [x] Review the tracker screen for first-time-user clarity after the icon pass: no-plan guidance, program browsing, and accessible plan controls are now explicit.
- [x] Clarify the tracker home header: “Workout Plan” should explain or guide users when no program has been selected.
- [x] Audit every workout plan against its title and intended training style: exercise selection, rep ranges, RIR guidance, percentage work, progression, and powerlifting specificity.
- [x] Fix the workout calendar to support navigating to any prior/future month, preserve empty months, and align every day to the real calendar grid; verify October 2026 includes October 1–31 correctly.
- [x] Audit bodyweight entry validation and copy: clarify why actual bodyweight is marked optional, or make it required when saving a bodyweight entry.
- [x] Verify “Find Your Gym” in both demo and production: demo behavior is covered by the mock directory and location-filter regression; the production catalog currently has 991 active gyms, including 10 in Miami, so an empty state indicates loading/error state rather than missing catalog data.
- [x] Condense the Submit a Lift flow: required lift, context, and video controls remain visible while estimated-max and plate-loading details are grouped behind one collapsed “More details” section.
- [x] Audit the Privacy Notice, Terms of Use, and Fitness Disclaimer against the production feature set: current in-app copies cover the implemented data/features and pass the coverage test. Legal sign-off remains an external release gate.
- [x] Enable forum browsing in the simulator/demo build without requiring production account services; verify read-only forum access in the next build.
- [x] Expand the awards catalog from roughly 100–105 to about 200: audit existing awards, remove overlap, and add balanced milestones for consistency, strength, volume, technique, exploration, and community engagement.
- [x] Fix RPE chip contrast in the workout tracker, especially RPE 7: the number must remain readable in both selected and unselected states and meet accessible contrast expectations.
- [x] Remove the ambiguous “Best set” card from workout summary; a bare weight × reps result lacks exercise context and unclear scoring criteria.
- [x] Restore workout-completion celebrations for meaningful milestones, including new PRs, volume PRs, and other unlocked achievements.

## Tracker improvements for strength and hypertrophy

- [x] Make program completion count finished planned workouts from completed history as well as in-progress set logs; keep session and week completion in sync after finishing, editing, deleting, or backdating a workout. Completion now maps saved sets back to their source prescriptions and refreshes when workout history changes.
- [ ] Define and label training metrics consistently: working sets, volume load (weight × reps), estimated 1RM, adherence, and training frequency.
  - [x] Show weekly non-warmup working sets grouped by normalized primary muscle, with a drill-down to a recent contributing workout.
  - [x] Label volume load explicitly as weight × reps from completed working sets, and exclude time-tracked sets from Home weekly volume.
  - [x] Normalize volume load categories through each exercise’s resolved primary-muscle profile so body-part aliases do not fragment the summary; recovery and working-set summaries already use canonical muscle regions.
  - [x] Document and label estimated 1RM, adherence, and training-frequency calculations consistently across views: Epley estimates use completed working sets up to 10 reps, adherence is labeled as exercise/session coverage, and frequency reports active weeks out of four.
- [x] Make Today clearly show the next planned workout, an in-progress workout, a rest day, a missed session, or a completed program, with the appropriate next action.
- [ ] Clarify plan selection and overview: current week, sessions complete, next session, progression method, and the difference between changing a plan and editing it; provide a useful action when a program ends.
  - [x] Label the plan list as the place to choose the active plan, separately from editing the selected plan’s weeks and workouts.
  - [x] In Plan Overview, count only workouts that contain exercises and offer a direct next action: start the next workout, review an unfinished week, or add a week after program completion.
- [x] Show the prescribed set count, rep range, target RIR, training-max percentage, and target load in the in-workout exercise header; convert target load to the active workout unit.
- [ ] Label previous performance and make set completion, warmups, RPE, rest, add-set, and substitution controls clear.
  - [x] Label the per-set prior-performance action as “Prev” and expose its workout values accessibly, including a clear no-history state.
  - [x] Show the historical load unit and convert copied previous values into the current workout's unit.
- [ ] Keep progress feedback during a workout clear about working sets completed and remaining, and distinguish a full, shortened, or skipped session when finishing.
  - [x] Show planned-session completion versus a shortened session and report logged working sets against the original session prescription count on the finish screen.
  - [ ] Define and surface an explicit skip outcome for planned workouts without creating a misleading completed-workout record.
- [ ] Add a Strength view for key lift bests, estimated 1RM trends, three-lift totals, and bodyweight-relative strength, with estimates linked to the logged sets they use.
  - [x] Summarize squat, bench, and deadlift estimated 1RMs; show a total only when all three exist and a relative total when bodyweight is known.
  - [x] Preserve the source workout through daily exercise-trend aggregation and let a selected weight or estimated-1RM chart point open that workout.
- [ ] Add a Muscle view for weekly working sets by muscle, training frequency, and four-week comparisons; keep volume load as a separate metric from set count.
  - [x] Compare four calendar weeks of primary-muscle working-set counts, show training frequency, and drill down to a workout that contributed sets.
- [ ] Add a Consistency view for planned versus completed sessions and sets, missed or backdated sessions, and calendar history.
  - [x] Add a Progress summary for selected-week planned workouts completed and prescribed exercises logged, with a program-browsing empty state.
  - [x] Label the percentage as exercise coverage (planned prescriptions with a completed non-warmup set), separate from fully completed workout count.
  - [x] Show planned working-set coverage separately and describe workout counts as sessions with every prescribed exercise logged.
- [ ] Show rep-range progression and, when a plan prescribes RIR, compare target RIR with logged effort.
  - [x] Compare completed reps against each workout's historical numeric rep-range prescription; show sets in range and best in-range load, excluding duration targets.
  - [x] Make each rep-range progression entry open its source workout and logged sets.
  - [x] Compare target RIR with estimated RIR from completed-set RPE, using historical workout prescription snapshots when available.
- [ ] Make charts and calendar entries open the workout and relevant sets; explain when a metric has too little history to display a useful trend.
  - [x] Calendar workout entries open the saved workout detail.
  - [x] Exercise weight and estimated-1RM trend selections offer the source workout.
  - [x] Verify chart selections scroll the exact logged set into view in the source workout detail with a simulator UI test.
  - [x] Show a current estimated 1RM instead of a zero-change comparison with one workout, and explain that another session is needed for a trend; the simulator UI test verifies this single-workout state.
- [x] Reorganize Progress around Strength, Muscle, and Consistency while keeping the calendar usable for browsing history and empty months; the calendar remains in the default Consistency view.
- [ ] Keep workout completion concise and focused on meaningful PRs, program progress, and milestones; put detailed trends and history in Progress.

## Gamification expansion — implementation order

- [ ] Enrich the existing workout-finish celebration after a successful save: highlight earned weight, rep, and volume PRs, program milestones, and awards; lead with the most meaningful result and provide View all achievements.
  - [x] Show a post-save confirmation only after the workout save succeeds, with key workout metrics and the top PR, volume-PR, or achievement highlights.
  - [x] Provide a working View all achievements disclosure on the saved screen.
  - [ ] Add program-milestone context and order the celebration by significance rather than category.
- [x] Add a user-selected weekly training-day goal to Home and Tracker, updated after workouts; count multiple workouts on one day once, respect rest days, and show the next attainable milestone. Goal choice is persisted in the existing local workout-preference snapshot and can be disabled.
- [ ] Add program milestones for the first week, halfway point, and completion based on completed scheduled sessions; missed workouts logged later count toward their original date and matching session.
- [ ] Add a personal progress timeline with dated milestones linked to workouts, including comeback milestones; let users choose public profile badges and keep achievements private.
- [ ] Add optional monthly consistency challenges and earned profile titles/frames without encouraging unnecessary weight or volume increases.
- [ ] Add friend rivalries and gym/community challenges with invitations, individual goals, privacy controls, shared progress, and server validation.
- [ ] Extend the existing workout/achievement system with PostgreSQL-authoritative rewards and an offline cache; associate rewards with source workouts, prevent duplicate awards on retries, and recalculate appropriately after backdated entries, edits, or deletions.
- [ ] Verify ordinary and PR finishes, offline sync, duplicate saves, backdated plan workouts, and account reloads. Deliver the richer finish screen and weekly goals first, verify them in the simulator, and identify the TestFlight build containing them.

## Exercise icon follow-up

- [x] Inventory all 337 built-in training exercises, six ranking choices, shared renderers, custom/prescription fallback paths, and existing icon tests; document source findings in [full icon audit](docs/exercise-icon-audit.md). Runtime visual verification remains pending.
- [ ] Unify exercise identity/rendering across Add Exercises, Library, workout/plan/substitute/Progress views, leaderboard pickers, and Submit a Lift; eliminate independent mappings that leave old icons visible.
- [ ] Replace remaining generic figures, equipment-only fallbacks, and arrows across the full inventory; correct core-first matching, pullover spelling, upright-row, and custom/prescription fallback cases.
- [ ] Review a labeled full-catalog contact sheet at picker and tile sizes in light/dark mode; verify every affected screen and replace tests that currently expect weak placeholders.
- [ ] Record the source revision and actual TestFlight build containing the visually verified icons before marking the icon pass complete.
- [ ] Replace the generic up-arrow on standing and seated calf raises with movement-specific icons; keep calf raises visually distinct from front raises.
- [ ] Replace misleading shared icons for wrist curls, shrugs, band pull-aparts, stiff-leg deadlifts, hip thrusts, glute bridges, hip abductions, upright rows, band lat pulldowns, and band overhead triceps extensions; update all exercises sharing those mappings.
- [ ] Distinguish barbell, dumbbell, and band overhead presses where the movement icon otherwise looks identical, then verify the affected families in the exercise library and other screens using catalog icons.

## Profile page follow-up

- [ ] Ensure Training history shows only workouts belonging to the viewed athlete; test own and another athlete's profile so no private or misattributed workouts appear.
- [ ] Give blank demo/incomplete profiles a meaningful name or completion prompt instead of an empty name and lone “@”.
- [ ] Clarify the Overview / PR videos / Training / History / Submissions navigation: make it true section selection or clearly identify it as shortcuts within one scrolling page; avoid confusing duplicate section labels.
- [ ] Replace the prominent all-zero strength card with a compact empty state and Submit Lift action until qualifying lifts exist; show the full total and breakdown once data exists.
- [ ] Make the profile header actions self-explanatory, especially Submit Lift and Edit Profile; ensure the Training shortcut opens or reaches its collapsed content.
- [ ] Check the profile layout with empty, partially complete, and populated accounts in light and dark mode, including larger text sizes.

## Settings follow-up

- [ ] Wire Allow comments and Notification preferences to real saved behavior, or remove the switches until that behavior exists.
- [ ] Keep Settings visible while profile/privacy changes save; show progress, success or a recoverable error instead of dismissing before the result is known.
- [ ] Make Private profile's effects on the individual audience controls clear and reversible; rename Hide exact age to match the age-band behavior.
- [ ] Clarify which settings save immediately versus on Done, confirm before Reset Demo Data, and fix the About text that refers to a missing feedback link.

## Leaderboard follow-up

- [ ] Show eligible PRs without video on the Self-reported leaderboard when automatic sharing is enabled; attaching video updates the same lift to Video-backed. Keep results to 100 per page with Load more, search, and Jump to my rank.
- [ ] Correct ranking semantics and user rank: avoid a client-side result cap hiding a valid rank, remove fabricated movement values, and define what All exercises ranks.
- [ ] Apply every filter consistently in demo and production, including location/gym, age, class, evidence, reps, and calendar time ranges; keep selected scope when returning to the page.
- [ ] Show the qualifying lift's exercise, reps, date, evidence status, and weight basis (including per-hand dumbbell weight), with a direct path to the lift; distinguish loading errors from no results.
- [ ] Simplify duplicate filter controls and improve demo athletes so location, class, evidence, and Most Improved filters can be meaningfully tested.

## Verification before adding production training data

- [ ] Implement and test the profile/history and settings safety fixes, then install a verified new build on the phone; local changes are not present in the current production app or TestFlight build automatically.
- [ ] On that build, complete one small test workout and verify its saved record in the production backend and after a fresh sign-in before relying on it for a full workout; do not reinstall while sync is uncertain.

## Forum workflow plan

- [ ] Define the forum information architecture: neutral hub, All / For You / Following feeds, community directory, community detail, rules, and membership states.
- [ ] Inventory every visible forum control and assign an end-to-end action: feed selection, community selection, join/leave, sort, new post, open post, nested reply, vote, share, report, block, and notifications.
- [ ] Complete the post and comment workflow: drafts, validation, loading, success, retry, locked posts, deleted content, empty states, and offline/network errors.
- [ ] Finish nested discussion behavior: reply targets, indentation, collapse/expand branches, orphan handling, comment counts, and refresh after posting.
- [ ] Implement one-vote-per-user reactions with visible selected state, undo, server-authoritative counts, and protection against voting on one’s own content; decide whether downvotes affect ranking or are private feedback.
- [ ] Add community and content moderation roles enforced by server permissions: report queues, review states, remove/restore, lock, moderator labeling, appeals, audit history, and no moderation controls for regular users.
- [ ] Add abuse safeguards: rate limits, duplicate-submit protection, blocked-user filtering, report reasons, and clear user-facing moderation outcomes.
- [ ] Add notifications for replies, mentions, and meaningful reactions with read/unread state and deep links back to the exact post or comment.
- [ ] Add forum acceptance tests covering every button, role, feed, nested reply, vote, report, moderation action, and failure state in demo and production configurations.

### Findings to fix before a user beta

- [ ] Load membership from the server on launch; make Following reflect joined communities, give For You its own defined behavior, and show Restricted requests as Pending rather than Joined.
- [ ] Replace placeholder Top and Most discussed sorting with real vote and comment metrics; add post pagination and search beyond the first 50 posts.
- [ ] Replace hard-coded post/comment counts and decorative vote, share, report, rules, and overflow controls with working actions or remove them; show the actual community and author on each post.
- [ ] Make demo forum actions clearly read-only or persist their state across navigation, so the simulator does not imply a post, reply, or vote was saved when it was not.
- [ ] Route forum-reply notifications to the exact thread/comment; handle unknown notification destinations without dropping the entire notification list.
- [ ] Add forward-only database corrections and runtime security tests: banned members cannot rejoin/post, removed posts/comments cannot be read, moderators can view their community reports, and reply parents must belong to the same post.
- [ ] Verify all forum flows against a real authenticated backend with regular-user and moderator accounts before inviting beta users; confirm the deployed schema separately from source migrations.
