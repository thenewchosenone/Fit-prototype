# MaxRep comparison notes — October 25, 2026

Scope: user-authorized review of MaxRep, beginning through iPhone Mirroring and continuing in its Mac app. Observations below describe visible screens; they do not establish backend behavior or product quality. LiftRivals comparison uses its current source and the simulator screens already inspected in this chat. The user subsequently authorized complete program/workout flows with synthetic data in an unused account. No purchases or trials are allowed; no invitations or messages to other people have been sent. Earlier canceled-flow observations below are historical; the October 26 continuation records the subsequently completed flows.

## Product focus

The user wants to emphasize **workout/PR tracking and training with friends**. In MaxRep's interest picker, selected only **Track workouts & PRs** and **Train with friends**, then continued. Coach classes, AI plans, and AI food tracking were left unselected. Do not interpret their presence as requests to add those features to LiftRivals.

Latest explicit priority: **workout tracker, program creation and sharing, and community**. Focus subsequent investigation and recommendations on those workflows. Nutrition, classes and AI coaching are outside the requested product emphasis.

## Onboarding observations

1. **Welcome:** prominent brand, animated/illustrated athletes, feature-preview chips, headline “Your coach. Your plan. Your crew.”, a primary Get started action, and secondary Log in. It communicates several benefits before asking for information. For LiftRivals, lead with an actual training/strength-record preview and a focused promise about logging, visible progress, and friends; the proposed athlete-record identity is more relevant than generic coach artwork.
2. **Intent selection:** five multi-select feature cards explain a concrete outcome in one sentence. Selection uses a checkmark, border, tinted surface, and icon change; Continue is disabled until selection. An “I want it all” shortcut is visible. Good pattern: explicit intent and clear selected states. LiftRivals currently asks for training goals/styles (Get stronger, Build muscle, Powerlifting, General fitness), which answers a different question. Consider asking for the user's first action and using it to guide the initial destination, without duplicating goal questions.
3. **Workout walkthrough:** “Log a set in one tap” with an app mockup showing editable load/reps, target vs previous, set progression, and Finish set. Demonstrating the actual workflow gives the claim context. Do not repeat the one-tap claim in LiftRivals unless its real flow supports it.
4. **Friends walkthrough:** “Better with your crew,” a workout-feed example, muscle coverage, and Kudos/Comment/Share. It explains the social loop through a concrete result. LiftRivals should demonstrate only its available social features and keep workout privacy understandable before sharing.
5. **Walkthrough pacing:** segmented progress indicators and Skip/Next are visible. The workout slide advanced to the friends slide without a deliberate second Next tap during observation; this appears to be a timed/story presentation. For LiftRivals, prefer explicit Next and a reliable Back; avoid requiring users to read against a timer. One screenshot captured an in-flight transition, so clipped transitional text is not recorded as a confirmed layout defect.
6. **Unselected features still promoted:** the final walkthrough panel showed AI food logging (Pro), although food tracking was not selected. The picker promises to show selected features first, not to remove the rest. Opportunity for LiftRivals: keep initial education relevant to the chosen purpose and move other capabilities into later discovery.
7. **Name:** first and last name appear on a separate screen, with the reason explained: visible on posts and leaderboards. Continue was disabled while either field was empty. Entered fictional first/last-name details with the user's permission. Mirroring keyboard entry was unreliable; this is an input/tool limitation, not recorded as a MaxRep defect. Opportunity: LiftRivals can ask for a public display name rather than suggesting a legal first/last-name requirement, with a clear explanation of where it appears.
8. **Goal:** six single-choice options: Build muscle, Get stronger, Lose fat, Get fitter, Train for an event, Feel better overall. Chose Get stronger as a sample. The flow then advanced to authentication without an observed explicit Continue tap. Avoid unannounced auto-advancement in our selection screens; keep a clear confirmation step.
9. **Authentication gate:** headline “Your routine. Saved from day one.” Email or Phone tabs, a Send email code button, and copy saying workout reminders/tips will be emailed and can be turned off in Settings. No guest/skip entry is visible on this screen. The user pointed out a real reachable inbox is needed for the code. No email or phone was entered and no code was requested. Opportunity: explain account benefits while preserving a clear low-friction way to experience LiftRivals first; make notification/marketing preferences explicit rather than burying them in footer copy.
10. **User completed authentication:** resumed with permission to continue and an explicit instruction not to pay. The agent did not enter account credentials or verification codes.
11. **Initial subscription offer:** chosen goal/interests appear as chips above the offer, which still leads with AI planning. Annual subscription was preselected at a displayed $139/year with a seven-day trial; monthly displayed $19.99/month. These are observations of this phone/account's offer, not verified universal prices. Selected Not now; never tapped the purchase/Continue action.
12. **Second subscription offer:** dismissing the initial offer immediately opened a discounted annual offer, displaying $92.99/year after a seven-day trial. Selected No thanks. No trial or subscription was started. Opportunity: if LiftRivals offers a subscription, keep the free route clear and avoid making users decline repeated offers before their first workout.
13. **Permissions education:** a “Stay on track” screen showed sample workout reminders, friend kudos and PR notifications; it explained Notifications and Apple Health, and stated camera/microphone requests happen when those features are used. Continued. No iOS permission prompt was displayed during this observation; Apple Health subsequently showed On. This does not establish what grants already existed or which data is accessible. No explicit permission was granted by the agent.
14. **Friends invitation:** sample message/share artwork, a primary Invite friends button, optional “Invited by a friend?” action, and secondary Maybe later. Chose Maybe later. No invitations or other messages were sent. This completed onboarding and opened Record → Gym.

## Initial free-app screens inspected

- **Record / Gym:** landed directly on workout entry, matching the selected tracking interest. Above several workout actions is a large “Set up your main program” panel with Create a program and Start a class. The list includes starting a workout, logging a completed workout, using history, AI generation, cardio and ready-made programs. Strong: direct routes for distinct logging intents. Opportunity for LiftRivals: one clearly dominant Start workout action, with secondary choices grouped; avoid making a program feel mandatory or promoting classes to a user who did not choose them.
- **Record / Plans:** search plus prominent add button; “Choose your main program,” Your plans with an empty state, New plan / Plan with AI tiles, and curated programs below. The plus, Create new, New plan tile and main-program prompt compete as entry points. LiftRivals can present one creation entry, clearly distinguish saved programs from the active schedule, and let templates be browsed without confusing activation with saving.
- **Community / Buddies:** after loading, “No Buddies Connected” explains accountability but shows no direct connect/invite action inside the empty card. Opportunity: every empty social view should offer a concrete next step, including when users skipped invitations during onboarding.
- **Community / Groups:** My Groups empty state; Discover Groups with search, Join with code, several public group rows with Join actions, and a Create Group panel. Inspected without joining or creating anything. Clear discover/join/create distinctions are useful; retain visible membership status and a concise explanation of group purpose.
- **You / Progress / Overview:** a small weekly stat strip (streak, sessions, volume), Overview/Progress/Journal selector, Today’s focus and a training calendar. The initial state has no training history. Good pattern: summarize the week before detailed reporting. A motivational statement should link to a useful first action rather than merely restating zero activity.
- **You / Progress / Progress:** the first large card is bodyweight/energy planning, with a 12-week estimate, weight check-in and Log weight—even though workout/PR tracking and friends were selected. Opportunity: make strength/workout progress the default for that chosen focus; show bodyweight only as a relevant optional route. Do not treat unavailable data as a meaningful forecast or fabricated progress.

## LiftRivals source comparison and opportunities

- `OnboardingView.swift` currently has four stages: welcome, goals, profile, optional starting lifts; a step counter and segmented progress; optional profile details and later legal acceptance. Its welcome uses the logo, “Track your lifts. See your progress.” and descriptive text. These are source observations, not a fresh runtime audit.
- Preserve the shorter setup. Add a convincing product preview or brief demonstration before the profile form instead of increasing required information.
- Use a coherent identity across welcome, profile, records, and training: restrained orange, neutral utility controls, readable numbers and accurate submission/evidence language. The profile pilot is already implemented; do not duplicate that work.

## Direct Mac audit continuation

The user installed and launched the App Store iPhone/iPad app on the Mac. Connected directly through CUA to the running MaxRep app (`com.maxrep.MaxRepApp`). The installed `/Applications/MaxRep.app` identifier was ambiguous with a running wrapper; attaching to the full running wrapper path succeeded. This establishes that direct auditing works without iPhone Mirroring or a nearby phone while the Mac and app remain available. The running wrapper path is temporary and may need rediscovery in a later session.

Native accessibility labels expose tabs and form controls, making this faster than coordinate-only Mirroring. Wide Mac layouts differ from iPhone: the top navigation and unusually wide/empty panes are not evidence of iPhone defects. A notifications education sheet was dismissed with Not now; notifications were not enabled.

### Program creation and sharing

- Plans → New plan first asks Manual Builder versus AI Plan Creator (Pro), despite entering via the manual-looking New plan tile. Opportunity: a clearly manual creation action should open its editor directly; paid/guided alternatives can remain secondary.
- Manual editor begins with cover artwork, title/notes, progressive overload, privacy and training phases, followed by workout days and exercises. These capabilities are visible, but artwork and advanced settings precede the core routine. Opportunity: start with day/exercise construction and place optional cover/advanced settings after the useful training content.
- Exercise picker offers search, muscle/activity categories, descriptions and separate information/add controls. Selecting bench added it to the unsaved plan and returned to the editor. The prescription table showed three sets, each at 135 lb × 8, plus Add Set and Create Superset. These are visible initial defaults; their derivation is unknown. LiftRivals should clearly distinguish intended targets, previous performance and suggestions.
- Private is initially selected. Public (Shareable) changes the explanation to anyone in MaxRep being able to search/discover the plan. Inspected this only in the unsaved draft, reset it to Private, and canceled. No plan was saved or published. Public discoverability is not the same as sending a private copy to a friend; our sharing language should make that distinction clear.
- LiftRivals source already contains Share editable program copy, Import shared program, and imports into an inactive editable copy (`TrainingTrackerView+Sections.swift`, `TrainingTrackerForms.swift`, `ProgramStore.swift`). Do not count sharing as absent. Future audit: sender preview, copy/import effort, imported fields, attribution, privacy and what happens when the author edits their original. These flows were source-inspected only during this comparison.
- Plans displayed retryable load errors on Mac during one visit. This is an environment/session observation; persistence and iPhone reproduction were not verified. Do not label it a universal MaxRep outage.

### Workout tracking

- Start a workout opens the timer immediately, before any exercise is chosen, with a clear Add a movement empty state. For LiftRivals, decide explicitly whether preparation time counts as training and communicate that timing behavior.
- Selected bench in an unlogged audit session. Its active card showed three set selectors, large weight/reps inputs, Target versus Previous, Completed Sets disclosure, and a persistent Finish Set action. The hierarchy makes the current set easy to find; this can inform our tracker layout without copying its appearance.
- Displayed target was 135 lb × 8 and Previous was 135 lb × 10, while the inspected Home feed showed no logged workouts. The origin of Previous was not verified. Opportunity: LiftRivals should show an honest no-history state and a source/date for prior performance where useful.
- Workout menu includes notes, a rest timer, add exercise and discard. No set was finished or saved. Canceled the agent-created unlogged session using Discard; the app returned to Record/Gym. This was not deletion of an existing user workout.
- Remaining comparison needs real logging evidence before conclusions about save reliability, editing completed sets, PR calculation or restart recovery. Do not claim those from a visible button.

### Community

- Reconfirmed the Buddies empty state lacks a direct connection action in its content, while Groups offers search, Join with code, public groups and Create Group.
- Opened Create Group: name, description/rules, category (initially Powerlifting), Private Group toggle (off initially), and a disabled Create action before required input. Canceled without entering fields or creating/joining a group.
- Priority for LiftRivals: direct find/invite actions, meaningful group previews and privacy before joining, and a visible connection between shared routines, workouts and discussion. Do not infer member-only feeds or moderation behavior from the public discovery view.

## October 26 — completed program, workout and private-group flows

The user explicitly authorized saving synthetic programs and workouts in this unused account to complete the comparison. The current focus is shared programs and community: training together and competing against each other.

### Saved and activated program

- Created private **Workflow Audit — Upper / Lower**, with description “Synthetic test routine for workflow comparison. Not training advice.” Progressive overload and training phases were off. Upper A contains bench targets 95 lb × 8, 100 lb × 8, 105 lb × 6, plus three cable-row sets at 135 lb × 8. Day 2 contains three squat sets at 135 lb × 8. Day 2 was not successfully renamed; do not report it as Lower B.
- Confirmed the saved plan and its description under Your Plans. Activated it as the main program. The detail explained that saving a plan or doing a single workout does not change the main program—a useful distinction.
- The roadmap displayed four weeks/one phase while the activation summary displayed one week/two workouts per week. After activation, the schedule/completion denominator was eight sessions over four weeks. This is an observed duration inconsistency, not a verified backend defect.
- Public draft visibility explicitly means searchable/discoverable by anyone in MaxRep. The saved audit plan remains private. Its card menu showed Edit Plan, Delete Plan and main-program status; absence of Share in that menu does not establish absence elsewhere. Recipient-side program sharing remains unverified.

### Completed and saved workout

- Ran Upper A and logged all six sets: bench 95 × 8, 100 × 9, 105 × 6; cable row 135 × 8 three times. The deliberately altered bench rep count was retained. Saved prescriptions populated the session correctly.
- Completing sets advanced the current set/exercise and progress. A rest overlay showed the next prescription with Skip rest, minimize and duration adjustment. Skipped rests for the audit.
- “Previous” initially displayed 135 lb × 10 without visible logged history, then showed the immediately preceding set in the current session. Its initial source remains unknown. Our UI should distinguish previous-session performance from the last set in this session.
- Finish opened a review before saving: two exercises, six sets, 5,530 lb volume and 4:37 duration. Independently checked volume: 760 + 900 + 630 + 3,240 = 5,530 lb.
- Saved as **Workflow Audit — Upper A**, explicitly selecting **Only You (Private)**. The confirmation said it was saved on this device and would upload when connected. Remote synchronization was not verified.
- Confirmed the private feed card and exact set details, then the settled You overview showed one session, 5.5k lb and a one-day streak. The main program updated to one of eight workouts complete (12%). No completed-history edit or restart-recovery test was performed.
- Workout sharing offered Photo/Card/Sticker and destination options. Share link produced workout-summary text with an App Store URL. This was the private-workout flow; do not generalize it to public shares. Copied only; nothing was sent. The card reported six new PRs while feed callouts named two exercises; their counting semantics were not verified.

### Private group: together and against each other

- Created **Workflow Audit Lab**, private, category Powerlifting, with only the audit account as a member. No invitations, shared posts, events or partner requests were sent/created. Do not publish its join code.
- Group sections are Pulse, Plan, Connect and People. Pulse includes group posts, weekly activity and a **Group Momentum** leaderboard over the last 14 days. The empty state requires a shared workout to join the standings; the earlier private workout was not counted as group activity.
- The leaderboard exposes Overall, Active days, Sessions and PRs. Its explanation favors active days, then sessions, personal bests and helpful group posts, with reduced credit for extra same-day workouts. It explicitly excludes calories, body weight, distance, likes and raw lifting volume from rank. These are displayed rules, not independently validated scoring behavior.
- Plan offers events with RSVPs for workouts/classes/runs/meetups. This is scheduling together; it does not establish shared workout-program ownership or synchronized program progression.
- Connect offers Find a partner and Trained together; request copy says requests close automatically. We inspected these entry points without creating requests or involving other users.
- **Explicit challenge creation and head-to-head rivalry flows have not been verified.** Earlier spoken language suggesting both were established MaxRep features was too broad. Confirmed competitive evidence is the group activity leaderboard. Two-person membership, invitation, RSVP and scoring behavior remain untested.

### Implementation direction for LiftRivals (proposals, not completed changes)

- Source check: `ForumStore.swift` already supports communities, discussions, comments and voting; the current community composer creates a Discussion with `liftID: nil` (`MainTabView.swift`). “Following” currently refers to joined communities, not followed athletes. Make this distinction clear rather than implying an athlete feed already exists.
- Source check: friendship backend migrations/tests and friends-audience concepts exist, but the current client `SocialService` exposes search/report/block, and `AccountSocialStore` covers gym memberships/blocks. A complete find → request → accept → friends-list workflow was not established by this inspection. Verify and complete that foundation before depending on it for shared training or challenges.
- Preserve existing editable program copy sharing/import. Improve preview, attribution, save-versus-start clarity and the path from a shared routine into training with friends.
- Connect a saved workout to an optional community post with accurate session/PR data and explicit audience. Saving a workout must not require publishing it.
- Add small, understandable friend/group competition with defined dates and rules. Keep consistency/participation standings distinct from existing strength rankings and their verification requirements.
- Consider group schedules/RSVPs and partner requests after the workout → shared program → community loop is dependable. Event scheduling alone does not make a program collaborative.
- Prioritize a clear first friend/group action and current training/competition activity over an empty discussion destination. Exact missing capabilities require source and runtime confirmation before implementation.
- Recommended sequence: friend connection flow → approachable program sharing → workout/program activity in community → shared-program progress → time-limited challenges. The latter two are larger new capabilities, not cosmetic fixes. Existing strength/video-verification and gym leaderboards should remain the foundation for eligible strength competition.

## Continuation checkpoint

Onboarding, saving/activating the private synthetic program, logging/saving its six-set workout, and inspecting the private group's leaderboard/event/partner entry points are complete. Current MaxRep screen: Workflow Audit Lab → Group Momentum full leaderboard. The audit program, private saved workout and private one-member group remain in the authorized unused account. No purchase/trial, invitation, external message or public post was made. Workout remote upload, recipient program sharing, two-user community behavior and an explicit challenge lifecycle remain unverified. Do not repeat onboarding or recreate the test data. No LiftRivals app code has been changed during this comparison; recommendations are not implementation claims.
