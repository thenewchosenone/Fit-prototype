# App screen copy audit

Date: October 13, 2026

Scope: source review of the SwiftUI screens, sheets, dialogs, empty states, validation messages, accessibility labels, and shared presentation strings in `LiftRankApp`. This is a wording audit, not a completed visual walkthrough of every account and network state. Existing uncommitted changes were preserved.

## Findings and edits

| Screen or flow | Finding and outcome |
| --- | --- |
| Sign in, create account, email confirmation, password reset and recovery | Simplified the account introduction and replaced “Enter Explicit Demo Mode” with “Explore demo.” Removed the backend provider name from the demo explanation. Retained actionable email and password validation. |
| Onboarding: welcome and goals | Removed the promise that every lift becomes a ranking. Replaced “Prepare for the platform” under local competition with “Compare with nearby lifters.” Simplified the initial action to “Get started.” |
| Onboarding: profile and location | State selection prompts now mention provinces as well. Required fields and privacy controls retain their existing meaning. |
| Onboarding: starting lifts and comparison | Explained one-rep max (1RM). Made it clear that starting lifts are private, comparisons are estimates, and a leaderboard rank requires an eligible public submission. |
| Home, active workout banner and quick actions | Simplified the resume prompt, sync messages and training-day goal explanation. Replaced “stale” and “training signals” with ordinary language. |
| Notifications and streak sheet | “Read all” now says “Mark all as read.” Simplified the streak instructions while preserving the requirement to train on separate days. |
| Leaderboards, filters and selectors | Clarified the comparison selector, exact rep input, hidden bodyweight label, weight-class shortcut and total calculation explanations. “Load more lifters” replaces the batch-size label. |
| Submit lift, video selection and result | Clarified the one-rep max selector and missing-video instruction. Removed unsupported promises that a result is entering the leaderboard. An absent result now says “Not shown” and directs the user to eligibility and filters. “New max” no longer implies every submission is a personal record. The result uses the preferred weight unit. |
| PR details and video playback | Evidence and moderation status now use readable labels instead of raw values such as `video_backed` and `under_review`. Retained video loading and unavailable states. |
| Me, strength cards and awards | Replaced “lifts ranked” with “lifts logged” for tiers derived from workouts. Standardized username wording and simplified the closest-awards heading. Accessibility hints no longer imply a logged set is necessarily an actual one-rep max. |
| Personal/public profile, submissions and history | Simplified submission-progress headings. Removal dialogs describe the lift, video and ranking record instead of internal cleanup terminology. Actual and estimated max labels now match the selected lift. Fixed lift-detail conversion of the stored pound value and removed repeated unit suffixes from the total breakdown. |
| Edit profile and photo editor | Bodyweight field uses a field label rather than an action label. Username and photo-removal confirmations explain the visible result. Retained photo cropping and save/error instructions. |
| Gym directory, gym details and gym requests | Reviewed search, join/leave, primary gym, membership limits, empty states and request form. Existing instructions remain actionable; verified-lift counts retain their distinct meaning. |
| Tracker Today, Plans and workout conflicts | Conflict actions identify the workout being reviewed or discarded. End-of-program and recorded-session messages direct users to the correct place: saved workouts in history/Progress, skipped and rest sessions in Plans. |
| Plan details, session cards and queue | Reviewed week/day editing, deletion, repeating, queue ordering and completion states. Retained the distinction between saved workout history and scheduled training. |
| Program preview and progression setup | Explained training max (TM), one-rep max (1RM), and reps in reserve (RIR). Preview prescriptions spell out reps in reserve. |
| Active workout, exercise tracking and set logging | An unavailable workout no longer claims it was saved. Remaining-set instructions refer to finishing the workout. Explained RPE beside the optional effort controls and clarified warm-up/previous-set wording. |
| Add/configure/custom exercise and library filters | Reviewed selection, required inputs, equipment, tracking methods and no-results states. Preserved catalog tracking identifiers. |
| Exercise details, muscle map and substitutes | “Suggested sets and reps” replaces “Suggested template.” Missing technique guidance no longer claims an editorial review is in progress. Substitute reasons use “logging method.” Timed-record help describes the displayed duration instead of storage details. |
| Progress: overview, muscle workload, strength, bodyweight and training health | Simplified history-sync wording. “Recently trained muscles” replaces “Recovery context”; the existing explanation still says elapsed time does not establish recovery. Reviewed charts, set-count definitions, comparisons, bodyweight history and health-entry labels. |
| Plateau card and detail sheet | The card now describes little change in recent logged workouts instead of claiming no improvement. Retained the detailed metric definition and guidance to review context. |
| Workout review, saved summary and public PR sharing | Clarified when badges and tiers are earned. Sharing text says attaching a video does not mean the lift has been reviewed. Retained the distinction between saving a workout and publishing selected PRs. |
| Completed workout, editing and deletion | Fixed singular/plural linked-submission wording and warm-up spelling. Replaced “workout snapshot” with “workout from your history.” The deletion notice explicitly keeps linked public submissions public. |
| Forum feed, communities, composer, discussion, comments and reports | Standardized community wording across discovery and the composer. Simplified empty-state prompts. Reviewed voting, sorting, locks, replies, owner deletion, reporting and demo restrictions. |
| Settings, privacy, policies, About and support entry points | Standardized “Age group,” explained the default Progress category and personal records (PRs), and simplified account deletion and policy-acceptance introductions. Policy document text was read for context and left unchanged. |
| Moderator review and report forms | “Request more evidence” names the action. Reviewed report submission, optional details, moderation reasons and confirmation messages. |

## Remaining verification and product questions

- Run a visual pass at standard and accessibility text sizes, especially onboarding paragraphs, the longer notification action, filter labels and submission-result cards. Source review alone cannot confirm wrapping or truncation.
- The initial submission UI check failed at a very large text size because the test tapped the toggle while it was behind a fixed bar. The follow-up test uses smaller scroll gestures and passed through submission to the result screen, including the evidence-filter explanation.
- The build 25 follow-up renamed “Request verification” to “Require lift video” and explains that attached evidence does not establish review or approval. The submission behavior is unchanged.
- The build 25 follow-up explains known placement restrictions and failed refreshes. When no specific reason is available, it explicitly says the lift was not returned for the selected ranking and filters rather than guessing a server eligibility decision.
- Every ranking mode now has an explanation. “Raw” and “Equipped” remain specialist equipment terms that could benefit from contextual definitions in a later review.
- Province prompts improve the current wording, but the country catalog also includes nations, territories and regions. Country-specific region labels would be a separate presentation improvement.

## Validation

- Updated existing UI test lookups for renamed onboarding, demo, awards and submission-result labels.
- Swift syntax parsing passed for all changed Swift files.
- The Debug simulator build passed. Existing Swift concurrency warnings remain outside this copy audit.
- All 29 `WorkoutPresentationFormattingTests` passed.
- `testFreshOnboardingRequiresProfileDetailsBeforeAdvancing` and `testAwardsSectionPrioritizesUnlockedAndClosestEntries` passed.
- `testSubmitLiftProducesSubmissionResult` failed on the disabled Submit button, and again on a focused rerun after shortening the validation message. The captured verification switch remained on. The remaining result-screen assertions consequently failed too.
- The final lift-detail formatter changes compiled successfully in a subsequent simulator build; the shortened validation message compiled during the focused test rerun.
- A full visual walkthrough remains outstanding.

No dependencies or new architectural abstractions were added. The only new file is this report, which records screen coverage, decisions and remaining checks. A display label was added to the existing moderation-status enum, following the evidence-status pattern and preserving persisted values.

## Build 25 follow-up fixes

The read-only build 25 review identified 15 further wording and accessibility issues. The authorized correction pass addresses them as follows:

- Rival Tier explains that the level must be reached in all three lifts, matching the existing minimum-tier calculation.
- The video control says “Require lift video”; its explanation distinguishes attached evidence from review.
- Leaderboard accessibility labels use the same video-backed/self-reported evidence labels as the visible UI.
- Public submission help no longer promises immediate leaderboard entry.
- Submission results distinguish non-public lifts, actual one-rep-max requirements, moderation restrictions, refresh errors, evidence filters and another representative result. Unknown server reasons remain explicitly unknown.
- Absolute, pound-for-pound, total and relative-total modes all have definitions available through “How this ranking works,” including exercise-specific views.
- Most improved explains percentage gains against earlier bests for the same exercise and identifies the selected comparison range.
- Estimated-max help labels the calculated one-rep max and the recorded set separately.
- The Progress total shows its unit once and names the three component lifts beneath it.
- Progress explains the estimate without requiring knowledge of the Epley formula name.
- The privacy setting formerly called “Division” says “Gender category,” matching the field controlled by `division_audience`.
- The workout launcher consistently uses “freestyle workout” and explains that exercises are added as you go.
- Forum timestamps use the existing relative-time formatter, including “ago,” instead of duration-style text.
- Demo comments show sample training conversations rather than internal development notes.
- Decorative award icons are hidden from accessibility so a workout-count award is not announced as “Verified.”

No new files, abstractions, dependencies or database changes were needed for this follow-up. Existing UI tests were updated for the new labels, and the submission test scrolls the entire toggle above the footer before tapping it.

Follow-up validation:

- The updated simulator app and UI test targets compiled successfully.
- All 29 formatting tests passed.
- Awards and freestyle-workout launcher UI checks passed.
- The submission UI check passed after correcting the scroll gesture, including an assertion for the new “Video filter active” result message.
- The final submission loading/error-state changes also compiled and passed the focused submission UI check.
- Syntax parsing and whitespace checks passed for the changed files.
- A manual follow-up preview was unavailable because the Mac was locked. No claim is made that every changed screen has completed a visual walkthrough.
