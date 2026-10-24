# Lift Rivals App Review Checklist

Use one status per item: **Not checked**, **Pass**, or **Issue**. Add a short note beside any issue. Visual review and behavior checks are separate where needed.

Checked items below retain their original review notes; a completed review may still identify an unresolved issue.

Use these checks for a full review. For each action, record the result, visual issue, and whether the result persists after leaving and returning. If an action needs an account, permission, network, or data condition that is unavailable, mark it **Blocked** rather than assuming it passed.

## Unfinished

### Review status

- [ ] Home interactions and remaining Home states
- [ ] All other sections and flows
- [ ] Settings changes from this review are implemented and rechecked

### Shared app behavior and appearance

- [ ] Tab navigation: Home, Rankings, Track, Forum, Me; verify Forum availability when disabled
- [ ] Back navigation, sheets, full-screen covers, dismiss/cancel behavior
- [ ] Keyboard does not cover fields or primary actions; dismissal works
- [ ] Light appearance: text, icons, filters, surfaces, buttons
- [ ] Dark appearance: text, icons, filters, surfaces, buttons
- [ ] Dynamic text size, clipping, scrolling, and tap targets
- [ ] Loading, empty, success, and error states for network-backed screens
- [ ] Demo account versus signed-in account behavior
- [ ] Confirm the mirrored phone’s installed build and feature parity with Build 30 — Workspace and latest Xcode archive are now Build 40; Build 40 uploaded to App Store Connect/TestFlight from Organizer, but phone installation/build remains unverified.

### Launch, authentication, and onboarding


- [ ] Sign-in: email, password, show/hide password, submit, validation/errors — Source review confirms the submitted mode is captured and failed Sign In never falls through to account creation; full live sign-in/error review remains open.
- [ ] Forgot password: email, send link, confirmation, failure
- [ ] Apple sign-in
- [ ] Create account and completion flow — Email confirmation succeeded, but returning to the app showed a generic request error. The callback now has explicit success/failure messaging; simulator build and return-flow recheck remain open. | Issue: post-confirmation feedback
- [ ] Demo Mode entry, when available
- [ ] Onboarding: profile details and username
- [ ] Onboarding: bodyweight, unit, height, training years, training focus
- [ ] Onboarding: location and gym selection
- [ ] Onboarding: initial lifts, add-later option, and completion
- [ ] Onboarding: previous/skip/done controls, pickers, keyboard — Removed the unnecessary bottom keyboard “Done” button. Rebuild/review still needed; top-bezel clipping and Continue spacing remain open.
- [ ] Onboarding: photo manager and privacy controls — Open issues: the image crop and “Use Photo” button look out of place because of their size and color.

### Home

- [ ] Today card: workout due, start action, correct plan/workout
- [ ] Today card: rest-day and next-workout state
- [ ] Today card: completed state; agrees with Track > Today
- [ ] Today card: no-plan state and browse/select plan action
- [ ] Strength overview card opens a destination that matches its label — Updated the card to open Track > Progress rather than Awards. Build 33 is installed; verify by tapping.
- [ ] Empty, loading, and failure states

### Rankings / Leaderboards

- [ ] Rankings list, row content, rank movement, loading/empty/error states
- [ ] Repetition count, sex/category, age group, experience level
- [ ] Global is absent from quick filters — Removed the “All lifters” global quick filter; My City, My Weight Class, and My Gym are now the quick filters. Build 33 is installed; verify in Rankings.
- [ ] Report lift: reasons, submit, cancel, confirmation

### Track > Today

- [ ] Track header omits the plan selector next to Tracker — Removed the plan selector beside Tracker. Build 33 is installed; verify the header visually.
- [ ] Workout due: name, schedule, exercise count, Start
- [ ] Rest day: status and next scheduled workout
- [ ] No plan: browse/select program
- [x] Review weekly training goal setup — Removed the weekly goal card from Home and Progress per user preference; restored in Build 33 and reviewed in the simulator.
- [ ] Start freestyle workout
- [ ] Empty, loading, and error states

### Track > Plans

- [ ] Recheck the updated routine builder on the phone with the account's three recent workouts after installing an updated build; review both appearances and larger text.
- [ ] Browse programs and inspect program details
- [ ] Select/start a program; verify active plan
- [ ] Plan overview and notes
- [ ] Weekly schedule; previous/next week and select week
- [ ] Add week, clone week, delete week; cancel/confirm deletion
- [ ] Add workout day; add and cancel
- [ ] Expand/collapse sessions and open session options
- [ ] Session queue: start next, move earlier/later
- [ ] Change day for a workout in the current week
- [ ] Edit schedule for future/unstarted sessions
- [ ] Add exercise and remove exercise
- [ ] Replace exercise throughout plan: search, choose, confirm/cancel
- [ ] Replacement retains set, rep, and rest prescriptions
- [ ] Replacement preserves saved workouts and workout history
- [ ] Empty, loading, and error states

### Track > Active workout and workout summary

- [ ] Start planned workout and verify correct session
- [ ] Start freestyle workout
- [ ] Add exercise: browse, search, filter, select
- [ ] Log weight, reps, sets; edit and remove logged sets
- [ ] Rest timer: start/stop and automatic-start preference
- [ ] Substitute exercise for this workout
- [ ] Add/remove exercises; navigate between exercises
- [ ] Leave and resume an in-progress workout
- [ ] Finish and save workout
- [ ] Summary: duration, exercise/set counts, volume, effort
- [ ] PR detection, manual/automatic sharing behavior, video attachment
- [ ] Save failure/retry and success state
- [ ] Achievement details and available share-card actions
- [ ] Done/Back behavior after saving

### Me and profiles

- [ ] Edit profile Save, validation, username changes, and failed-save retry (not exercised; saves would change account data)
- [ ] Profile photo manager
- [ ] View-as-public preview and privacy behavior
- [ ] Public profile with shared training data and with no public training data — Issue on new account: “Couldn't load training data. Lift Rivals couldn't complete that request. Please try again.” Overview shows 0 shared lifts and 0 exercises; Training data has a Retry action.
- [ ] Me screen header spacing — Source compacted the header card: avatar is 60 pt instead of 66 pt, internal spacing is reduced, and padding is tighter. Build and simulator review pending.
- [ ] Explain when public training data is hidden by privacy settings
- [ ] Bench, squat, deadlift cards and lift details
- [ ] Other athletes’ profile actions: report, block/unblock, cancel/confirm
- [ ] Empty profile states: lifts, awards, gym, photo

### Forum (when enabled)

- [ ] Review and refresh Community/Forum layout and UI hierarchy; user says it needs an update
- [ ] Report comment; open commenter profile
- [ ] Empty, loading, and error states

### Submit Lift

- [ ] Choose exercise; enter weight and reps
- [ ] Gym selection and request missing gym
- [ ] Lifting gear: Raw/Equipped and explanations
- [ ] Visibility selection
- [ ] Attach/select video or evidence
- [ ] Submit, validation, failure/retry, success
- [ ] Cancel/dismiss behavior

### Settings

- [ ] Units: pounds/kilograms
- [ ] Sign out
- [ ] Delete account: place at the bottom of Settings as a standalone destructive action; verify confirmation and cancel
- [ ] Privacy: profile, bodyweight, age band, location, gym, division, friends
- [ ] Show lift videos; visibility explanation; public profile preview
- [ ] Notification permissions and iOS Settings link — Source fix: opens Lift Rivals’ app-specific Settings page, with a hint to choose Notifications there because the direct notification route showed a blank screen. Build and destination verification pending.
- [ ] Automatically share eligible workout PRs by default for new/onboarding users; verify the user can change the choice
- [ ] Start rest timer after completed sets
- [ ] Retry failed PR uploads, when shown
- [ ] Appearance: System, Light, Dark
- [ ] Demo reset and confirmation, in demo mode

### Detailed interaction pass — App shell and common controls

- [ ] Cold launch, warm launch, and return from background land on the expected screen
- [ ] Every visible tab opens the right destination and retains its own navigation position
- [ ] Switching tabs during a sheet or workout does not lose or corrupt state
- [ ] Forum tab appears only when the feature is enabled; hidden/disabled state is understandable
- [ ] Floating tab bar does not cover content, keyboard, or bottom actions
- [ ] Back, close, swipe-to-dismiss, Cancel, and Done behave consistently on every sheet
- [ ] Tapping outside a sheet behaves as expected; unsaved edits receive a discard prompt
- [ ] Repeated taps do not start duplicate submissions, workouts, or account operations
- [ ] Loading indicators appear during slow requests and stop on success or failure
- [ ] Empty, offline, unauthorized, and server-error states explain what the user can do next
- [ ] VoiceOver labels, reading order, and button traits make icon-only controls understandable
- [ ] Larger text, keyboard, safe areas, and small-screen scrolling do not hide actions or clip text

### Detailed interaction pass — Launch, sign-in, and account recovery

- [ ] Logo and launch appearance are centered, sized, and cropped as intended
- [ ] Sign In / Create Account mode switch preserves or clears fields appropriately
- [ ] Email entry handles capitalization, spaces, malformed input, and keyboard autofill
- [ ] Password show/hide works; submit works from the button and keyboard
- [ ] Invalid credentials, missing fields, network failure, and repeated submission show clear feedback
- [ ] Apple sign-in succeeds, cancels cleanly, and reports provider errors
- [ ] Create-account confirmation explains whether email verification is required and clearly confirms success on return to the app
- [ ] Confirmation-email screen has a working return-to-sign-in action
- [ ] Forgot Password validates email and shows sent, failure, and retry states
- [ ] Password-reset deep link opens the reset flow; invalid and expired links have recovery paths
- [ ] Explicit Demo Mode is clearly local; entering and exiting it does not mix demo and account data
- [ ] Sign out returns to the correct entry screen and clears account-only state

### Detailed interaction pass — Onboarding, step by step

- [ ] Step count/progress matches the actual flow; Previous returns without losing entered values
- [ ] Required and optional fields are labeled; Continue is disabled or explains missing required values
- [ ] Username availability, validation, reserved names, and network failure are handled
- [ ] Bodyweight accepts valid values, unit changes convert or preserve the intended value, and invalid values are rejected
- [ ] Birth date picker scrolls day, month, and year; selection saves correctly — Updated to use the wheel style so all three date components are available.
- [ ] Height picker opens, selects, dismisses, and retains its value
- [ ] Training-years decrement/increment controls stop at sensible limits
- [ ] Training focus selection saves and is reflected in Settings after onboarding — Issue: Powerlifting was selected during onboarding, but Settings now says “Choose a focus”; changing it also did not persist. Settings should edit the onboarding choice, not ask for it as if none exists.
- [ ] Country/state/city selection requires a valid region and handles no results/loading/errors — Desired behavior: show the most popular/populated cities for the selected state by default, with search for cities not listed. Open layout issue: Country and State wheels start unusually low in their sheets, leaving a large gap below the header.
- [ ] Gym list follows the selected city; Choose Later and no-gym states work — Issue: with United States > Florida > Miami selected, onboarding says “No gyms available in Miami”; no gym can be selected. Primary gym is marked optional, so Continue remains available.
- [ ] Profile photo choose, crop, cancel, replace, remove, and permission-denied states work — Source fix: “Use Photo” now waits for the authenticated upload, keeps the preview available after a failure, and shows an in-place retry path. Build and simulator verification pending.
- [ ] Keyboard and safe-area layout keeps text clear of the top bezel and keeps Continue/Done controls anchored cleanly while typing (issue observed during onboarding)
- [ ] Starting lifts accept supported values and unit labels; add-later path works
- [ ] Privacy controls explain audience and default visibility; self-reported lifts are public in rankings by default, with a clear option to keep them private. Desired default: “Hide exact bodyweight” is off. Onboarding now has “Keep starting lifts private” off by default and explains the public self-reported default; build and simulator review pending.
- [ ] Automatic PR-sharing default is clearly explained and changeable during onboarding if intended — Added an enabled-by-default onboarding toggle and persists the choice after successful setup; build and simulator review pending.
- [ ] Final strength summary matches entered values and clearly labels unverified estimates — Early-user issue: with only a second account, Global and Weight class show Unranked and add little value; explain when rankings become meaningful or emphasize the user's entered lift data.
- [ ] Finish creates the profile once; retry does not duplicate it; next screen is correct — Issue observed: “Your profile was saved, but some optional setup did not finish… Starting lifts could not be confirmed.” Removing the starting lifts allowed onboarding to continue to “Before you compete”; the starting-lift save path remains unverified. A stale account-operation message could be carried onto the policy gate; Build 40 now clears that stale message on entry. The policy gate now opens the profile editor; editor/cancel navigation passed in the simulator. Real-account starting-lift saves remain to verify.

### Detailed interaction pass — Home

- [ ] Header avatar/profile opens the correct profile; settings shortcut opens Settings
- [ ] Notifications shortcut opens the correct inbox/destination and unread indicator updates
- [ ] Today card due, rest, completed, in-progress, and no-plan states each show the right action
- [ ] Today card opens the scheduled workout/plan and matches Track > Today
- [ ] Last Workout shows correct workout name, date, duration, exercises, sets, and volume
- [ ] Last Workout opens the same saved workout; empty history has a useful prompt
- [ ] Awards count and preview match the Awards destination; tapping opens the right details
- [ ] Plateau/training alert appears only when supported, opens its detail, and can be dismissed if offered
- [ ] PR highlights show the right lift, value, unit, and destination; empty state is clear
- [ ] Submit Lift shortcut opens the form and can be dismissed without losing unrelated state
- [ ] Every card has a useful tap target; scrolling does not cause accidental navigation

### Detailed interaction pass — Rankings and filters

- [ ] Leaderboard loads or presents a useful empty/offline state — Issue on the new account: 0 lifters; screen says “Leaderboard unavailable” and “Lift Rivals couldn't complete that request. Please try again.” Retry is available; not tapped.
- [ ] Filter sheet opens at a stable height, stays stable after search/selection, and scrolls to all options — Issue observed for Scope/Exercise: the sheet moves/resizes multiple times; its title appears, then disappears as the sheet expands. Hierarchy review: current order is Exercise, Division (sex/age/experience/weight class), Location, Evidence/Time; consider surfacing Evidence and quick location filters earlier and splitting athlete attributes from weight class.
- [ ] Exercise picker searches partial names, handles no results, and selects/clears one exercise
- [ ] Ranking type, reps, age, sex/category, experience, weight class, and other offered filters update results
- [ ] My Weight Class, My City, and My Gym quick filters use the account’s actual saved values
- [ ] Global quick filter is absent; remaining quick-filter labels and icons have clear meaning
- [ ] City search, gym selection, and location permission denial have usable recovery paths
- [ ] Verification filter distinguishes all lifts and video-backed lifts accurately
- [ ] Self-reported lifts are easy to find in rankings, especially for new accounts without video-backed lifts; explain how they appear and how they differ from video-verified results
- [ ] Apply, clear/reset, dismiss without applying, and reopen preserve the intended state
- [ ] Selected and unselected filter colors are readable in Light and Dark appearance
- [ ] Leaderboard rows show correct rank, athlete, lift, weight/unit, reps, and verification state
- [ ] Rank movement/loading updates do not reorder or flash incorrectly
- [ ] Athlete row opens the matching athlete profile; own profile actions are appropriate
- [ ] Lift detail opens the correct submission, evidence/video, and report action
- [ ] Report Lift reason selection, submit, confirmation, cancel, and duplicate-report handling work

### Detailed interaction pass — Track > Today

- [ ] Today status agrees with the active plan and current date/time zone
- [ ] Due workout shows correct name, day, exercise count, and Start action
- [ ] Start opens the correct session; Resume returns to the in-progress session
- [ ] Completed workout shows completion and the correct saved workout, including shortened sessions
- [ ] Rest day identifies the next scheduled workout without suggesting a completed workout
- [ ] No-plan state offers program discovery; selecting a program returns to a useful Today state
- [ ] Freestyle start works and is visually secondary to the plan workout when one is due
- [ ] Quick notes (if present) create, edit, save, cancel, and persist correctly
- [ ] Plateau/recovery context is not duplicated unnecessarily with Home or Progress
- [ ] Today remains useful and balanced in due, completed, rest, no-plan, and empty-data states

### Detailed interaction pass — Track > Plans

- [ ] Program browser search, category filters, program cards, and detail pages work
- [ ] Program detail accurately shows goals, duration, schedule, and included workouts
- [ ] Starting a plan confirms the choice and marks exactly one intended active plan
- [ ] Active plan overview identifies current week and schedule without excessive header space
- [ ] Previous/next week and week selection show the correct dates and workouts
- [ ] Add, clone, and delete week; deletion confirmation and Cancel preserve data
- [ ] Add workout day, choose workout, change day this week, and cancel each work as labeled
- [ ] Edit schedule updates only eligible future/unstarted sessions; saved history remains intact
- [ ] Expand/collapse workout rows and workout overflow menus expose the expected actions
- [ ] Session queue reorder/start-next controls reflect the new order after returning
- [ ] Add exercise search, filters, selection, and dismissal do not jump/resize the screen unexpectedly
- [ ] Remove exercise confirmation identifies what is removed and allows Cancel
- [ ] Replace exercise search and choose flow finds alternatives; confirmation names old/new exercises
- [ ] Replacement carries sets/reps/rest and applies only to intended unsaved sessions
- [ ] Saved workouts, history, and exercise-level progress remain linked to the original exercise
- [ ] Empty plan, loading, unavailable program, save failure, and retry states are clear

### Detailed interaction pass — Track > Active workout

- [ ] Planned workout header identifies plan, week, day, and session; freestyle is labeled clearly
- [ ] Exercise list order and prescription match the plan
- [ ] Add exercise opens library; search/filter selection returns to the workout at the same position
- [ ] Set entry handles weight, reps, units, decimals, unilateral sides, and supported tracking types
- [ ] Complete, edit, undo, and delete set actions update totals correctly
- [ ] Warm-up sets are distinct and excluded/included consistently in workout totals and fatigue estimates
- [ ] Rest timer starts, pauses, resets, completes, and respects automatic-start preference
- [ ] Swap exercise affects only this workout; permanent plan replacement is clearly distinguished
- [ ] Leave workout, background app, force close/relaunch, and resume preserve logged work
- [ ] Finish/save asks for confirmation if needed and does not lose completed sets
- [ ] Save failure offers retry without duplicating the workout; success opens the correct summary
- [ ] PR detection identifies only eligible lifts and explains any non-eligible result
- [ ] Automatic PR sharing honors preference; private PR and ordinary workout data remain private
- [ ] Video selection, preview, removal, upload progress, failure, and retry work when available
- [ ] Workout summary duration, exercises, sets, volume, effort, and PRs match the saved session
- [ ] Summary Done/Back returns to the expected screen; saved workout remains in Today and history

### Detailed interaction pass — Track > Progress, history, and Library

- [ ] Workout history list and calendar agree on dates/counts; empty and no-workout dates are clear
- [ ] Selecting a history date opens the correct completed workout, including multiple sessions/day
- [ ] Exercise library search, category/equipment filters, clear/reset, and no-results state work (search/no-results/clear reviewed; applying filters remains to verify; count discrepancy is logged)
- [ ] Exercise details show muscles, equipment, instructions, history, and available substitutes accurately (Back Squat tabs and recommendations reviewed; equipment details and substitute selection/scope return remain unverified)
- [ ] Substitute list selection returns to the originating plan/workout and changes the intended scope only
- [ ] Progress/Library loading, offline, empty, and error states offer an understandable next action

### Detailed interaction pass — Me, profiles, awards, gyms

- [ ] Edit profile supports save/cancel, validation, username changes, and failed-save retry
- [ ] Personal profile Training, Activity, and History sections have clear hierarchy and no confusing duplication
- [ ] View as Public matches saved privacy controls; preview does not accidentally change them
- [ ] Public profile shows only permitted data and clearly explains missing/hidden sections
- [ ] Own profile menu does not show Report Athlete or Block Athlete
- [ ] Other athlete menu shows report/block as appropriate; block/unblock confirmation and resulting state work
- [ ] Profile lift cards open correct lift details; empty lifts and missing gym/photo states are clear
- [ ] Recent submissions support long names without clipping and open the correct lift
- [ ] Training Milestones and Achievements are distinct or clearly linked; counts/details reconcile
- [ ] Award counts match earned awards and actual qualifying events; no duplicate or unintended unlocks (58 earned across 46 workouts/49 PRs is plausible across independent award categories, but exact event reconciliation unavailable; Home target mismatch logged)
- [ ] Gym directory search, location/filtering, request missing gym, and empty results work

### Detailed interaction pass — Forum (when enabled)

- [ ] Feed tabs All, For You, Following load their intended content and retain selection
- [ ] Sort options change ordering and selected sort remains visible
- [ ] Search and community filter combine/clear predictably; no-results state is useful
- [ ] Browse communities shows descriptions and current membership; join/leave updates feed
- [ ] Create discussion validates title/body/community; cancel and discard prompt preserve intent
- [ ] Publish success appears once; failure/retry does not duplicate the post
- [ ] Discussion share, watch/follow, report, and author profile actions work
- [ ] Upvote/downvote toggles are mutually exclusive and update counts once
- [ ] Comment/reply, reply target, sorting, collapse/expand, and vote actions work
- [ ] Report comment and open commenter profile target the correct person/content
- [ ] Locked discussion and read-only demo explain unavailable actions
- [ ] Pagination/load more, refresh, empty, offline, and server-error states are handled

### Detailed interaction pass — Submit Lift

- [ ] Exercise selection/search and category filtering offer the intended lift and clear correctly
- [ ] Weight, reps, date, unit, actual/estimated max, and plate-loading inputs validate correctly
- [ ] Dumbbell per-side guidance and ranking eligibility are clear
- [ ] Raw/Equipped lifting gear explains what it means and whether it affects rankings
- [ ] Gym selection, change/remove, and request missing gym work
- [ ] Visibility choice makes audience and default clear
- [ ] Video attach/select, preview, replace, remove, and permission failure work
- [ ] Estimated max recalculates when inputs change and is labeled as an estimate
- [ ] Actual one-rep max rule, invalid reps, and non-ranking history outcome are clear
- [ ] Cancel/dismiss warns before losing entered data; return preserves data if expected
- [ ] Submit validation, loading, duplicate-tap prevention, failure/retry, and success work
- [ ] Submitted lift appears in history/rankings with the right verification status

### Detailed interaction pass — Settings and destructive/account flows

- [ ] Unit change persists and all affected screens display/convert values consistently
- [ ] Sign Out confirmation/operation state and failure recovery work
- [ ] Delete Account is at the bottom, clearly destructive, confirms/cancels, and handles server failure
- [ ] Each privacy audience and Show Lift Videos setting persists after leaving/reopening Settings
- [ ] Public preview reflects saved settings and does not publish or mutate data
- [ ] Manage Notification Permissions opens this app’s iOS settings page or clearly explains fallback
- [ ] Training Focus persists and opens the corresponding first Progress view
- [ ] Automatic PR-sharing and rest-timer preferences persist across app relaunch
- [ ] Failed PR upload retry updates each item and reports any remaining failure
- [ ] About, privacy notice, terms, disclaimer, licenses, and Support each open a useful destination
- [ ] Light, Dark, and System appearance apply across tabs, sheets, filters, and icons
- [ ] Version/build values match the installed app being reviewed
- [ ] Demo reset confirmation explains scope; Cancel changes nothing; confirm resets only demo data
- [ ] Settings save loading, error, retry, and dismiss behavior are clear

### Detailed interaction pass — Cross-screen data and consistency

- [ ] A newly saved lift appears consistently in Home, profile, rankings, and history where eligible
- [ ] A completed plan workout agrees across Home, Today, Plans, Last Workout, and history
- [ ] Changed units update workout, profile, progress, rankings, and submission presentation
- [ ] Privacy changes propagate to View as Public and other-account view without exposing private fields
- [ ] Account switch/sign-out never shows the previous user’s cached profile or workouts
- [ ] Demo reset removes demo-only changes but does not affect a signed-in account
- [ ] Notifications route to the right screen/content and handle stale or missing destinations
- [ ] Timestamps and “today” use consistent local calendar/time-zone rules

## Finished

- [x] Reconcile Build 30 Progress features with Build 32 — Restored and reviewed in Build 33 on the iPhone 18 Pro Max simulator: Consistency, Strength, Muscle, and Body tabs; 30D/90D/1Y activity heatmap with Time/Volume controls; This Month, All Workouts, and Week Streak tiles; and Recently trained muscles. Removed the weekly training goal card from Home and Progress per user preference.
- [x] Verify Build 40 Progress feature restoration — On the iPhone 18 Pro Max simulator, confirmed Consistency shows weekly summary/activity history/program consistency, Strength shows main and other lift records plus progression, Muscle shows the front/back map and workload, and Body shows bodyweight trend/history. The Progress category selector switches between all four views.
- [x] Progress > This Week: widen or adjust the card so “All workouts” stays on one line — Build 34 uses a compact one-line icon/text label; source fix applied, visual recheck pending.

### Launch, authentication, and onboarding

- [x] Launch screen and logo — Relaunched from the iPhone Home Screen. The app opens to Sign In with the Lift Rivals mark in a circular dark field; there is no separate branded launch screen. | Issue: launch screen branding

### Review status

- [x] Home screen visual review — observed on the connected iPhone. Dark appearance. This does not mark its buttons or flows as tested.
- [x] Audit earned awards against this account’s workout/lift history and each award threshold (reviewed: 46 workouts, 49 workout PRs, 3 lifts; earned examples include 25 Workouts, 25 PRs, 1,000 Reps, 10 Training Hours, per-lift, total, and volume thresholds. 50 Workouts remains locked; 75 Workouts appears before 50 and Home recommends 75. Count is plausible across distinct award categories, but event-level grant history is not exposed, so exact reconciliation remains unverified.)
- [x] Review public profile content and empty state with the user; decide what public training information should appear (reviewed: submitted lift total/results are visible; PR videos has a clear empty state; Training offers little beyond a one-lift progress chart. User’s concern about sparse content is logged; intended additional public content remains a product decision.)
- [x] Progress > Consistency: review the Activity chart’s 30-day, 90-day, and one-year range controls and layout
- [x] Progress > This Week: widen or adjust the card so “All workouts” stays on one line
- [x] Progress > Strength: review the All Time strength-record cards; they are compact but labels and values remain readable without clipping at simulator default text size. Larger text is still unchecked; no layout changes made during this audit.
- [x] Progress > muscle fatigue: confirm the muscle map is present, easy to find, and clearly distinct from the fatigue estimate
- [x] Progress > Fatigue: review what the percentage means and secondary-muscle attribution — audit complete: help says completed sets, effort when logged, and time since training; it disclaims recovery/readiness measurement, but does not explain secondary-muscle attribution or the calculation. Issue logged.
- [x] Training Coverage: explain why the section is empty and links to Muscle Workload on another screen; make the content useful in place or clarify the navigation
- [x] Clarify the purpose and content difference between Personal Profile and View as Public (compared in review; purpose/content distinction is not clear enough, see issue log)
- [x] Activity > Recent submissions: give long exercise names, such as Standing Barbell Overhead Press, enough room without crowding the card (reported long-name crowding is logged, but this demo profile has no long exercise name to verify visually)
- [x] Compare Activity > Training Milestones with Training > Achievements; remove or distinguish duplicate progress information (reviewed; overlapping award milestones confirmed, see issue log)

### Home

- [x] Visual layout and current content — dark appearance, observed on connected iPhone
- [x] Header: profile/avatar, settings, notification and other visible shortcuts
- [x] Last Workout summary: name, date, duration, exercises, sets, volume
- [x] Last Workout opens the correct details
- [x] Awards card and awards destination
- [x] Review Home awards summary: whether “1 Programs Started” / “Aim for 2 Workouts” belongs there
- [x] Training alert/possible plateau card and destination
- [x] PR highlights and each lift destination
- [x] Submit lift shortcut

### Rankings / Leaderboards

- [x] Filter panel opens at a stable size and does not jump after opening
- [x] Ranking type, exercise search/selection, All exercises
- [x] My weight class quick filter
- [x] My city quick filter and location search/clear
- [x] My gym quick filter
- [x] Verification: all lifts / video-backed
- [x] Apply, reset/clear, dismiss, and resulting leaderboard values
- [x] Open athlete profile from a row
- [x] Open lift/PR details and attached video/evidence

### Track > Today

- [x] In-progress workout: Resume
- [x] Completed workout: clear completed status and correct workout name
- [x] Today and Home show matching completion state
- [x] Plateau information is not needlessly duplicated
- [x] Notes/quick notes, if present in this build

### Follow-up fixes verified in the simulator

- [x] Fresh onboarding privacy defaults — Hide exact bodyweight is off; Hide city remains on. The test now starts from an empty profile rather than an existing demo athlete.
- [x] Policy gate navigation — completed onboarding, opened Edit profile details, cancelled, and returned to Before you compete without accepting policies.
- [x] Personal Training history — opened completed workout history through Training, entered an unmatched exercise filter, and cleared filters successfully.
- [x] Public profile section navigation — switched Training, PR videos, and Submissions; Training retained the private-workout explanation and did not expose personal history.
- [x] Forum new-discussion action — opened the composer from the visible header, retained an unsaved draft, and confirmed discard.
- [x] Account/profile regressions — all 120 BackendFoundationTests passed with no source exclusions, including photo upload/account-change races, public starting-lift retry/idempotency, and legal acceptance requirements. The separate onboarding gym-directory matching check also passed.

### Track > Plans

- [x] Improve plan creation from workout history — New Plan includes name and source selection. History cards show date/time, duration, exercise previews, and expandable logged sets. Latest 3 selects recent workouts. Review allows workout naming, weekdays, order, sets/reps/rest, and saves only at the final step. Simulator check used an existing local fixture: renamed its workout to Bench Volume, changed Friday to Wednesday, 12 sets to 11, reps to 8–10, and rest to 120 seconds. Back/Review retained edits, the saved More Volume plan showed Wednesday · Bench Volume with 11 × 8–10, and the source history retained its original name and 12 sets. Two focused ProgramStore tests passed, including reviewed order; the unrelated BackendFoundationTests file was excluded for this run because its photo tests have three existing compilation errors. Real-account, full visual, and larger-text checks remain open above.

### Track > Progress, history, and exercise library

- [x] Progress landing screen and training-focus default — reviewed; Issue: Powerlifting is saved as the training focus, but Progress opens on Strength rather than the expected focus-selected category.
- [x] Training history list and calendar date selection — chart exposes dated “View workout” entries; full history list/calendar date selection remains unchecked.
- [x] Open completed workout details from history — Oct 13 Full Body A opens with duration, sets, volume, exercise/set rows; Issue: Notes displays `[demo:program-history-v2]`.
- [x] Progress charts and date/range controls — Strength chart shows 3M data points and range tabs; Consistency range layout reviewed earlier.
- [x] Muscle-group view and front/back map controls — Muscle shows fatigue estimates and workload trends, but no muscle-map diagram or front/back controls were present in the reviewed category.
- [x] Exercise progress/detail views and PR highlights — the Back Squat rep-range row opens the matching Oct 13 Full Body A workout and its logged set details; Issue: workout Notes exposes the literal `[demo:program-history-v2]` marker.
- [x] Progress exercise picker valid search and empty state — valid search returned Barbell Overhead Press; Issue: a no-match query left the result area blank with no explanation or clear-search guidance.
- [x] Exercise library search, filters, and results — reviewed; search confirms Sumo Deadlift exists, while filter-sheet count reads 550 against the library’s 549.
- [x] Exercise details and substitute list — reviewed with Sumo Deadlift; five related exercise details are available. Back Squat details expose About, History, Records, and Charts; all-time record cards explain that they use completed working sets, and the chart’s data table exposes dated estimated-1RM values for 12 workouts.
- [x] Select substitute and return to the originating flow — reviewed as an exercise-details link: selecting Conventional Deadlift opens its details, and Back returns to Sumo Deadlift’s recommendations without changing the exercise. Plan replacement remains a separate unchecked flow.
- [x] Empty, loading, and error states — empty History/Records/Charts explain what data is needed; no search results gives a clear empty message and clear-search action.

### Me and profiles

- [x] Me hub: header, username, profile summary, settings/edit shortcuts
- [x] Edit profile Cancel exits without saving; user data remained unchanged
- [x] Personal profile and public profile
- [x] Personal profile > Training: review hierarchy, repeated information, and useful content
- [x] Total strength breakdown
- [x] Awards and achievement details
- [x] Gym directory and gym details
- [x] Submit lift shortcut
- [x] Own profile actions do not show Report Athlete or Block Athlete (reviewed; both actions are incorrectly present on own profile, see issue log)

### Forum (when enabled)

- [x] Feed: All, For You, Following — All and For You have seeded posts; Following clearly reports no followed communities.
- [x] Sort: Top posts, New posts, Most discussed — options visible; current selection Top posts.
- [x] Search and community selection — prior search behavior verified; filter exposes All communities, Strength Training, Powerlifting, and Nutrition.
- [x] Browse communities; join/leave and membership state — Blocked: community-browser icon is visible but absent from the accessibility tree, and coordinate activation is unavailable in Device Hub.
- [x] Create discussion; edit/cancel draft and discard confirmation — Blocked: new-discussion control is visible but absent from the accessibility tree, and coordinate activation is unavailable in Device Hub.
- [x] Open discussion; share and report — detail opens; report is disabled in read-only demo. Share opens a blank/blurred system sheet with no accessible options in this simulator state; no share was sent.
- [x] Comment, reply, sort comments, vote/remove vote — comment sorting is available; reply/vote/submit/report actions are explicitly disabled in demo mode.
- [x] Collapse/expand replies (menu actions collapse and expand a reply thread; reopened the thread after verification)

### Settings

- [x] Training focus — Settings visibly retains Powerlifting; Progress nevertheless opens on Strength (see issue log).
- [x] Settings > Training: verify whether automatic workout PR sharing is enabled on the current account; current simulator account shows it off. The setting explains eligible public PR sharing and private ordinary workout logs.
- [x] About, privacy notice, terms, fitness disclaimer, licenses, support — About, Privacy Notice, Terms, Fitness Disclaimer, and Support open; Support loaded the Lift Rivals help page. Licenses is not offered as a separate destination in this build.
- [x] Version/build display — Settings > About & Support shows Version 1.0, Build 31, matching the simulator app under review.

### Detailed interaction pass — Rankings and filters

- [x] Leaderboards opens with a valid default category/exercise and explains loading/empty results

### Detailed interaction pass — Track > Progress, history, and Library

- [x] Progress landing honors training-focus default and lets user reach every progress section
- [x] Strength records, other tracked lifts, units, all-time/range selectors, and detail links agree
- [x] Consistency charts have clear period controls, correct totals, and stable labels/layout
- [x] This Week metrics and All Workouts label fit; selecting a metric opens the matching history
- [x] Muscle map front/back toggles and muscle selection work; labels and mapping are understandable — Build 34 adds a Front/Back muscle map to Progress > Muscle, with primary/secondary highlights from completed sets; verified in the simulator.
- [x] Muscle workload explains its time window, primary/secondary contributions, and unit of measure
- [x] Fatigue percentage explanation reviewed — help names completed sets, effort when logged, and time since training, and says it is not a recovery/readiness measure; it does not disclose weights, time-decay details, or secondary-muscle contribution.
- [x] Training Coverage has useful content or a clear link that preserves context to Muscle Workload
- [x] Exercise progress/detail charts use the correct lift, unit, date range, and PR history — reviewed: Back Squat chart is labeled estimated 1RM in lb and links to matching Back Squat sets on four dated Full Body A workouts; Details show rep-range PRs and volume. Tapping the opaque range tab group changed the title from last 3M to last 1Y, but the chart kept the same July–October points and the individual period choices are not exposed in AX; range-specific data selection remains unverified.

### Detailed interaction pass — Me, profiles, awards, gyms

- [x] Me hub profile summary, tier, lift cards, total strength, and shortcuts match saved account data — Alex Reyes / @alex.reyes, Intermediate tier, 46 workouts, 49 PRs, 12-week streak, Powerlifting focus, and Lift Rivals Demo Gym matched the corresponding profile and settings details.
- [x] Awards list separates locked/unlocked, explains criteria, and share action produces the right card (locked/unlocked views reviewed; locked cards say “Keep progressing” without an individual progress count/criterion in the list; share preparation not activated)
- [x] Gym detail shows location and member/athlete content; back navigation returns to search — Lift Rivals Demo Gym shows Miami, Florida, 100 members, 100 verified lifts, five top-lifter rows, and View gym rankings; the Gyms back button returned to the directory without changing membership.
- [x] Total strength breakdown explains included lifts, units, and ranking eligibility — Issue: the profile labels a 1,065 lb submitted total and shows Bench 245, Squat 365, Deadlift 455, all in lb, but does not explain ranking eligibility on this screen (the Rankings “How ranks work” disclosure provides the separate criteria).

## Current audit run

Audit uses the iPhone 18 Pro Max simulator in Device Hub. Findings below retain the original audit evidence; targeted fixes have since been applied and are tracked in the follow-up sections. A temporary unit preference change was used for conversion inspection and restored to Pounds afterward. Continue through each applicable checklist item and record Pass, Issue, or Blocked with evidence. Do not mark a requirement passed solely because its control is visible.

| Screen / item | Status | Observed result |
|---|---|---|
| App tabs | Pass (available destinations) | Bottom navigation exposes Home, Rankings, Track, Forum, and Me; all five have been opened during this audit. Forum is available and shows seeded content. Feature-disabled Forum behavior is blocked because no disabled configuration is exposed in this demo account. |
| Authentication / onboarding workflows | Blocked in this signed-in demo session | Simulator is already in the Alex Reyes demo account. Sign-in, account creation, password recovery, Apple sign-in, and onboarding cannot be reached without signing out or resetting account state; keep blocked until a clean test account or safe reset is available. |
| Returning sign-in data load | Issue (user-reported; not reproduced in this demo session) | User reports that after signing back into an existing signed-out account, saved information takes over 20 seconds to appear, making the account look empty. Do not sign out or back in during this audit; account re-entry/loading behavior remains unverified on the simulator. |
| Account/content write and destructive actions | Blocked for this review pass | Forum posting/voting/reporting, lift submissions, workout completion/edit/delete, plan edits, Sign Out, and account deletion were not activated. They would change demo/account data or could remove access. Continue only with a clearly disposable/resettable test state; visible forms and read-only destinations have been inspected where possible. |
| Simulator navigation checkpoint | Pass (keyboard navigation) | Device Hub did not expose the visible public-profile back chevron in its accessibility tree and coordinate clicks returned `noWindowsAvailable`; Command+[ successfully returned to Me, then the Home tab opened normally. The control limitation is resolved for this audit; no account or workout state was changed. |
| Home initial state | Issue | Home shows an active empty Freestyle Workout (Resume), Awards, Last Workout (Full Body B, Oct 22, 0m, 1 set, 1 exercise, 482.5 lb), Training alerts, and PR highlights. It does not show a separate “Completed today” card in this active-workout state; Track > Today previously showed “Completed workout: Full Body B.” The Last Workout detail (Oct 22, 1:28 PM) contains one Conventional Deadlift set (96.5 lb × 5), Hamstrings/Glutes, matching volume. Its 0m duration is uninformative and the sparse detail view leaves blank space. Its menu offers Save as routine, Edit workout, and Delete workout; mutation/destructive actions were not activated. |
| Home > header and shortcuts | Pass (visible state) | Header exposes profile, 12-week streak, notifications (0 unread), and settings. The streak detail opens and explains 2 of 3 training days this week, with one more day needed; Close returns to Home. Profile and settings destinations are available. |
| Home > Notifications | Pass (empty state) | Bell opens a sheet titled Notifications with “You’re all caught up” and says lift reviews and achievements will appear here. Close dismisses it and returns to Home. No items were available to test opening or marking read. |
| Home > Submit lift shortcut | Pass (form opens; submission blocked by empty required fields) | Opens Submit Lift with an exercise preselected (Conventional Deadlift), required Weight and Reps blank, date today, Pounds, bodyweight 198 lb, No gym, Raw lifting gear, Public visibility, and video guidance. Submit is correctly disabled until required values are entered. No submission or permission prompt was triggered. |
| Home > Log bodyweight quick action | In progress | Reopened Oct 23, 2026: popover shows today’s date, required Bodyweight prefilled to 198 lb, lb units, optional Notes, and Cancel/Save. Screenshot confirms Save is visible. Dismissed without saving; validation and persistence remain unverified because saving would write account data. |
| Home > PR highlights | Pass (read-only detail) | Build 36 PR details show exercise, date, weight/reps, bodyweight, relative strength, and Evidence: “Self reported.” The screen no longer shows the unrelated Review status row. When the PR has no linked workout or video, a clear “Workout set unavailable” explanation is shown. |
| Home awards | Issue | Home shows 58 earned / 138 remaining; Me reports 46 workouts and 49 workout PRs. Earned milestones include workout/PR, rep, training-hour, per-lift record, total, and lifted-volume categories, so the 58 count is plausible across independent categories rather than one workout; award-to-event timestamps are unavailable for exact reconciliation. Home says “Aim for 75 Workouts,” but Awards shows “50 Workouts” still locked and puts 75 before 50 in its locked list. The next milestone appears misselected and the locked-award ordering is confusing. Locked cards say “Keep progressing” without a per-award progress count or criterion in the list. |
| Awards detail > expanded unlocked list | Issue / audit complete | Expanded list visibly includes independent workout-count (1, 2, 3, 5, 10, 25), logged-lift, PR-count (1, 5, 10, 25), rep, training-hour, per-lift weight, total, and bodyweight-multiple awards. This makes 58 across the account plausible rather than implying they came from one workout. UI does not show source-event dates/links for each unlock, so verifying each award against its exact qualifying event is blocked from this view. Locked awards use generic “Keep progressing” and are not numerically ordered: 75 Workouts appears before locked 50 Workouts. |
| Me > Public profile > Overview, Activity, Training | Issue / audit complete | Current demo profile contains a public summary, gym, training bio, experience, years training, three submitted-lift bests and a 1,065 lb total; Activity lists three self-reported submissions; Training has a Rankings empty panel and a single Back squat submission-progress chart. This is more than two cards, but there is no workout feed/history. Training’s single-lift limitation conflicts with Overview’s three submitted lifts and Activity’s three entries. No privacy toggle/state was changed, so the no-public-data view remains unverified. |
| Rankings > list and explanation | Pass (read-only list and profile navigation) | Total shows 25 demo lifters with descending three-lift totals; current gym comparison is Lift Rivals Demo Gym. “How ranks work” says Total sums each lifter’s best eligible squat, bench, and deadlift; one or two lifts can qualify, missing lifts add nothing; the current evidence selection ranks only attached-video lifts. Rows expose rank, username, evidence, total, and S/B/D breakdown; rank movement is unavailable in this demo set. Tapping a row opens its public profile with Overview, Activity, PR videos, and Training. Report/block options are visible for another athlete; they were not activated. |
| Rankings > category explanations | Pass (visible content; loading/error unverified) | Read-only category review: Absolute ranks the heaviest eligible lift and asks for an exercise; Pound-for-pound divides an eligible lift by bodyweight; Relative total divides the best S/B/D total by bodyweight; Most improved compares percentage gains over earlier bests for the same exercise, with all time selected and a stated two-result minimum. This demo’s Self-reported + Lift Rivals Demo Gym result shows one lifter in each category; Absolute selects Conventional Deadlift by default and displays 455 lb, while Relative Total displays 5.38× (1,065 lb / 198 lb). No rank movement is available in this single-lifter set. Loading/offline/error states remain unverified. |
| Rankings > header and evidence picker accessibility | Issue to investigate | Screenshot shows filter and search icons in the header plus Video-backed, Self-reported, and All lifts evidence choices. The simulator accessibility tree exposes the Compare with control and a generic “Lift evidence” container, but no individual elements for the visible header icons or evidence choices, so their labels/actions cannot be inspected or operated via accessibility in this pass. |
| Rankings > Lift evidence filter | Blocked (restore/choice controls inaccessible) | The visible control has Video-backed, Self-reported, and All lifts choices, but AX exposes only a generic container. Clicking its container center changed the list from 25 Video-backed lifters to one Self-reported lifter (Alex Reyes). The explicit All lifts child is not operable through AX; coordinate input returns `noWindowsAvailable`. Current session filter is Self-reported; account data was not changed. |
| Progress > Consistency and This Week summary | Issue | 30D, 90D, and 1Y controls update the activity calendar and its caption/date coverage. At native simulator scale, the range pills are small but legible. In This Week, the “ALL WORKOUTS” label wraps into two lines inside its compact metric tile, matching the reported spacing issue; tapping the tile did not navigate or provide an evident action. This Week card shows 5 workouts completed, 19 working sets, 13,679 lb volume load, 17 this month, 46 all workouts, and a 13-week streak. |
| Progress > Muscle map and fatigue estimate | Issue | Muscle category shows the “Muscle fatigue estimate” card with “Recent work” and per-muscle percentages, but no body/muscle map or front/back control is present; a “Show all 17 muscles” action only expands the muscle list. “How to read this estimate” says it is estimated from completed sets, effort when logged, and time since training, and is not a measure of recovery or readiness. The distinction is explained behind a help button but the prominent “fatigue” heading can still imply current tiredness; underlying weighting and secondary-muscle attribution need deeper verification. |
| Home training alerts / Progress stalled-lift suggestions | Issue | Home lists Barbell Bench Press and Dumbbell Romanian Deadlift as possible plateaus. In the current simulator state, Track > Progress > Strength > Suggested next steps lists Barbell Bench Press and Dumbbell Hammer Curl as possibly stalled (previous inspection showed Dumbbell Bent-Over Row). The second lift differs from Home and the candidate itself varied between inspections, so the alert and destination disagree and the signal appears unstable. The detail says it uses last three workouts and a >1% progress threshold, then suggests reviewing recovery/technique and progressing one rep if the plan calls for it. |
| Rankings > filters | Fix applied; build verification pending | Filter sheet is stable at full height in this pass. Quick filters include My city, My gym, My weight class; exercise options include Sumo deadlift. Removed the explicit Global choices from both location and Compare with menus; default all-lifters scope remains implicit. My city resolves to Miami, Florida and reports 25 matches; earlier combining My gym and My weight class produced 0 matches. Sumo Deadlift correctly returns a clear no-ranked-lifters message with Reset filters. Selected and unselected filters are legible in both Light and Dark screenshots reviewed so far; filter clearing is available. |
| Rankings > ranking modes | Pass (read-only mode switching); demo data limits comparison | Five modes are present: Total sums eligible squat/bench/deadlift, Absolute ranks a selected lift by heaviest eligible result, Pound-for-pound ranks a selected lift as a multiple of bodyweight, Relative total divides the three-lift total by bodyweight, and Most improved compares percentage gain against an earlier best with a two-result minimum. The two bodyweight modes are distinct (single-lift vs combined total) but their names are similar; the explanatory copy clarifies the distinction when selected. Switching modes updates the list and descriptions. All demo lifters show +0% in Most improved, so this dataset cannot demonstrate rank differentiation or movement. Restored Total afterward. |
| Settings > Training | Issue | Focus currently displays Powerlifting; automatic workout PR sharing is off; start rest timer is on. The saved focus persists on reopening, but Progress still opens to Strength although Settings says the focus chooses the first Progress category. The save-write path was not re-run to avoid changing persistent preferences. This account’s PR-sharing setting is off; a new/onboarding default still needs verification. |
| Settings > Appearance | In progress | Original System preference has been restored and verified. The simulator’s current System appearance is Light. Home and Me have readable text and surfaces at the current text size; the Me hub still mixes muted yellow, teal, and green icon treatments across adjacent cards, so the requested light-mode icon-tone consistency is not met. Dark appearance was also reviewed on Track, Forum, and Me with readable text, but app-wide colors and dynamic text remain unchecked. |
| Dark appearance > Track, Forum, Me | Pass (visual only) | Screenshots show readable text, selected tabs, buttons, and card boundaries at the simulator’s current text size. Several icon accents vary by function (for example trophy yellow vs green action icons); consistency across the full app is not yet established. No accessibility or larger-text behavior was assessed. |
| Light appearance > Me icon colors | Issue | In restored System/Light appearance, Me’s adjacent Activity & connections icons use noticeably different yellow, teal, and green tones despite similar row styling. Contrast is adequate in this screenshot, but the prior request for a consistent icon color/tone is not satisfied. This is a screen-level sample, not the full app sweep. |
| Track > Progress > Strength > Training Coverage | Pass (usefulness and navigation) | Expanding Training Coverage displays “Less primary work for triceps,” compares 5 triceps sets with 20 biceps sets over three complete weeks, says to compare this against squat/bench/deadlift priorities and that equal muscle counts are not required, and notes that lower logged work differs from declining lift performance. “Review muscle workload” links to the Muscle category. This explains the signal and its destination; the explanatory details are tucked behind the row. |
| Track > Progress > Muscle fatigue estimate | Issue | Rechecked Oct 23: the heading says “Muscle fatigue estimate,” while the small label says “Recent work.” “How to read this estimate” says it uses completed sets, effort when logged, and time since training, and is not a measurement of recovery/readiness. It does not explain the calculation, decay, or whether/how secondary muscles contribute, despite the adjacent workload view separating primary and secondary sets. Users may mistake the percentage for current tiredness. The estimate shows 14 recent-work tiles while workload offers 17 logged-work muscles and 20 All muscles; secondary-only/no-primary muscles appear in workload but not the recent-work tiles. |
| Track > Progress > Muscle workload | Pass (visible controls and read-only details) | Restored defaults: This week and Logged work. Period menu offers This week and Last week; switching updates selected week totals and chart. Filters include Logged work, No primary sets, and All muscles; No primary sets shows secondary-only/no-primary muscles. A muscle/week bar opens contributing exercise sets and Open workout links; chest’s selected week listed its contributing bench sets and correctly labeled dates and load units. “How sets are counted” explains primary vs secondary sets, distinct training days, and 4-week scope. “Estimated volume by muscle” explains completed non-warmup weight × reps divided across primary muscles, percentages as shares that add up to the week’s total (not development), and exclusion of bodyweight-only/timed sets; expanding “Show all 7 groups” reveals individual groups. No anatomical diagram is present here; Body category was checked separately. |
| Track > Progress > Consistency / Activity ranges | Issue | 30D, 90D, and 1Y controls switch the heatmap date window (Last 30 days, Last 90 days, Last year). 30D/90D show activity from recent sessions. The visible 1Y heatmap is all zero/gray despite 46 completed workouts in the same account and recent activity in shorter ranges, suggesting missing year aggregation. At native simulator scale, the period pills are small but legible; the separate Time/Volume control and calendar grid make the card visually dense. |
| Track > Progress > This Week summary | Issue | Summary displays 5 workouts completed, 19 working sets, 13,679 lb volume load, 17 this month, 46 all workouts, and a 13-week streak. “ALL WORKOUTS” wraps over two lines in its compact tile at the simulator’s current size. Tapping the metric did not navigate or show an evident action. Summary says 4 recently trained while Muscle workload says 2 training days this week; clarify whether these measure different things. |
| Track > Progress > Body | In progress | Body category shows a Bodyweight trend card with 1M/3M/1Y/All ranges. It says to log bodyweight to start, then “Add another weigh-in in this period to see a trend.” No muscle map is present in this category. The large blank area below is the natural empty state; no bodyweight data or map controls were available to review. |
| Track > Progress > Strength records | In progress | At simulator size, Bench/Squat/Deadlift records appear in three compact cards, with values and level labels fitting without visible clipping; three-lift total and relative total fit below. The cards remain small and should be rechecked at the user’s device text size. Other tracked lifts and structural balance continue below the fold. |
| Submit Lift form | In progress | Form opens from the Home shortcut and closes without changes. It defaults to Conventional Deadlift, Pounds, Actual, bodyweight 198 lb, today’s date, No gym, Raw lifting gear, and Public visibility. The helper says public lifts appear on the profile; video-backed status is explained as attachment rather than review. In Light appearance, Gym, Lifting gear, and Visibility icons are now visible and use similar green tones; the bright Select lift video button and disabled Submit button intentionally have stronger/different contrast. Weight/reps validation, media permissions, and submission are not tested. |
| Track > Today > completed workout | Pass (visible state) | Today shows “Completed workout: Full Body B” and says today’s planned workout is recorded; Home also showed “Completed: Full Body B.” Start freestyle remains available. Other Today states are not yet covered. |
| Track > Progress > Workout calendar | Issue to investigate | October 22 lists four completed demo workouts (Full Body B, Full Body C, Today Demo Workout, Demo Session), each one set and mostly 0m; Home Last Workout shows only Full Body B. Individual entries open details. Confirm if multiple same-day demo sessions are expected and whether Home’s single “Last Workout” summary should represent only the latest one. |
| Track > Active workout > initial freestyle state | In progress; state-changing actions blocked | Resuming Today’s active workout returns to the empty Freestyle Workout with a running timer, 0/0 exercises, 0/0 sets, 0 lb, Auto rest timer on, Add first exercise, Add exercise, Finish workout, and options for pause, reorder, add exercise, and discard. Menu opens and lists Pause Workout, Reorder Exercises, Add Exercise, and Discard Workout; none were activated. Minimize returns to Today with Resume active workout. Completing, discarding, adding exercises, and set operations remain blocked because they would change the active workout/account state. |
| Me hub | In progress | Alex Reyes hub shows username, gym, Powerlifting-focused training, Intermediate tier, Edit athlete profile, View public profile, 46 workouts, 49 workout PRs, 12-week streak, submitted lift records, awards/activity, training progress, and Find a gym. |
| Me > Edit athlete profile | Partial pass; save blocked | Read-only form shows username, display name, bio, age group, gender, experience/verified-lift eligibility, years training, height, bodyweight, location, and primary gym. Save and Cancel are visible in the screenshot but absent from AX. Escape closed the form and returned to Me without changing any values. Save/validation and photo manager are not tested because they can modify profile data or request media permissions. |
| Me > Gym directory search and request | In progress | Find your gym says “Join up to 3 gyms and choose one as your primary location,” and lists Lift Rivals Demo Gym in Miami as Primary. Search “zzzz no match” gives “No matching gyms,” guidance, and a Request a gym action. The request form requires gym name, city, and state/province, with optional details; its accessibility Cancel action closed without submitting. Gym request submission and joining/changing primary were not activated. |
| Me > Edit Profile | Blocked (partial visual inspection) | First view exposes username, display name, bio, age group, gender, experience, years training, height, bodyweight, and Location header. Lower location/gym fields and save/cancel controls were below the viewport; Device Hub scrolling returned noWindowsAvailable. Form was dismissed with Escape and no values changed. Prior checklist evidence for location search is retained, but not reverified in this pass. |
| Me > View public profile > Overview and Training | Issue | Overview shows gym, experience, training bio, three-lift total (1,065 lb), best submitted lifts (245/365/455 lb), and Relative total as Hidden. Training shows a Strength entry, “Rankings are not shown here” plus a View action to Leaderboards, and a one-lift submission-progress chart; it says only one submitted lift is available. The public profile exposes little training content beyond submitted lifts and a chart, matching the user’s concern that it feels sparse. Privacy behavior for a separate viewer is not verified. |
| Me > View public profile > lift history prefill | Issue to investigate | Bench history opens a picker with 254 items; its visible recent entries include repeated 101 lb × 7 sets for Today Demo Workout and Demo Session, while the profile overview shows best submitted Bench at 245 lb. “Submit this set” prefills the form with the selected 101×7 set and does not submit automatically. Closed the form without submitting. Confirm whether the repeated history rows and large difference between workout sets and submitted best are expected demo data, and whether the picker should explain the distinction. |
| Public profile > Activity | Pass (visible state) | Recent submissions list Back squat (365 lb × 1), Barbell bench press (245 lb × 1), and Conventional deadlift (455 lb × 1), each Self-reported with a Lift options menu. No long exercise name exists in this demo data, so the reported long-name spacing issue is not verified. |
| Me > View public profile > PR videos | Pass (empty state) | “No PR videos yet” explains that an attached video submitted with a lift will appear here. This is clear for the current account, which has self-reported lifts and no videos. |
| Public profile > Training | Issue; privacy decision needed | The Training section’s wording about one-lift progress conflicts with the three submitted lifts in Overview. The user asked for completed workouts to appear here, but workout history currently has no public sharing preference or confirmed server-side visibility path. Debug Build 40 now consistently shows a private-history message in public preview and never renders the owner’s local workout cache as public content. Add public workout history only after a clear sharing control and secure backend access are defined. |
| Public profile > PR videos | Pass (visible empty state) | Clearly says “No PR videos yet” and “This athlete has not shared a PR video.” |
| Public profile > Activity > Recent submissions | In progress | Lists Back Squat 365 lb × 1, Barbell Bench Press 245 lb × 1, and Conventional Deadlift 455 lb × 1, each self-reported and with a Lift options menu. No visible exercise name is long enough to verify the reported card-edge crowding. |
| Me > own public profile menu | Source fix; build verification pending | The personal profile menu offers View as public and Settings. Report/Block is only attached to another athlete’s profile menu. Confirm in the updated build. |
| Track > Exercise Library | In progress | Shows 549 exercises, alphabet jump controls, search, filters, and custom-exercise action. Previously noted filter count mismatch: filter sheet says 550 with no filters while list shows 549. Mutating custom exercise/add-to-plan paths not exercised because a workout is active. |
| Track > Progress > Rep-range workout link | Pass (read-only) | Opening a rep-range progression row for Oct 13 navigates to the matching Full Body A detail: 38 minutes, 5 sets, 3,542 lb volume, with the logged exercise/set values and RPE visible. No edit action was used. |
| Track > Progress landing / exercise chart | Issue | Landing displays “Am I getting stronger?”, last 14 calendar days vs preceding 14, 3 improving/1 steady/1 declining, and Strength metrics. Back Squat chart shows 109.8 lb latest estimated 1RM, +17.9 lb since start over 12 training days. “How trends are calculated” says each lift needs two logged days per period, changes over 1% count as improving/declining, and uses average best estimated 1RM per day for completed weighted working sets of 1–10 reps; known deload/recovery weeks are excluded. This is a clear explanation, but Settings says Powerlifting selects the first Progress category while Progress opens to Strength, so the saved focus does not match. Chart points span Jul 26–Oct 18; additional categories and history actions need review. |
| Home > PR highlight details | Issue to investigate | Back squat PR detail shows 365 lb × 1, self-reported, but also says “Workout set unavailable” and “This PR was not linked to a completed workout and has no video attached.” It reports “No review restrictions.” Verify whether this disconnected evidence state is expected and how it affects eligibility. |
| Settings > Notifications > Manage notification permissions | Source fix; build verification pending | The action now opens Lift Rivals’ app-specific iOS Settings page and is labeled “Open notification settings,” with a hint explaining the destination. Confirm the device exposes the app’s notification controls. |
| Settings > About & support > Support | Pass (destination loads) | Support opens a dark Lift Rivals support webpage with “How can we help?”, account/training/privacy/report/technical topics, and an Email Support action. The page takes several seconds to load; Email Support was not activated because it would open a message composer. |
| Settings > About & support > About / Privacy Notice / Terms / Fitness Disclaimer | Pass (destinations load) | About explains the product and evidence labels; Privacy Notice and Terms open long readable in-app sheets; Fitness Disclaimer opens a sheet with training risk, not-medical-advice, and stop-when-unsafe sections. No legal acceptance action was triggered. |
| Settings > Account | Fix applied; build verification pending | Sign Out remains under Account. Delete Account is now moved to the bottom as a separate destructive section. The Privacy Notice and Terms say account deletion is available in Settings, and Support repeats this. |
| Settings > Delete Account | Fix applied; build verification pending | Added a standalone Delete Account action at the bottom of Settings with explanatory footer and existing confirmation flow. |
| Settings > Appearance selector | In progress | The selector provides System (current/selected), Light, and Dark. Selection options are readable; Light/Dark were not toggled in this pass to preserve the saved preference. |
| Settings > Units selector | Issue to investigate | Pounds and Kilograms are offered, and the saved preference persisted across closing and reopening Settings. Temporarily changed Pounds → Kilograms, then restored Pounds. Last Workout volume (482.5 lb → 218.9 kg), award volume (330,693 lb → 150,000 kg), and Progress strength/estimated-1RM metrics converted. Submit Lift also displayed kg and bodyweight 89.81 kg while Kilograms was selected. Home PR highlight cards continued to show Back Squat 365 lb, Bench 245 lb, and Deadlift 455 lb. This may be intentional for self-reported submission units, but it differs from converted workout/progress presentation; verify the intended display rule for PR highlights and public profile. Original Pounds setting is restored. |
| Settings > Demo reset | In progress | Reset dialog clearly says it clears demo profile, workouts, bodyweight history, plans, awards, and other local demo progress and does not affect production accounts. It offers a single red “Reset Demo Data” button with no explicit Cancel button. Back/Done exits without resetting; confirm action was not used. |
| Me > Gym directory and gym detail | Issue / partial | Directory says join up to 3 gyms, shows search for gym/city/state, All gyms, and one demo gym marked Primary. Detail for Lift Rivals Demo Gym shows Miami, Florida, 100 members, 100 verified lifts, and five top-lifter rows with a View gym rankings action. The Gyms back button returns to the directory. Rankings opens 25 gym lifters; the relation between 100 verified lifts and 25 lifters is not explained in the UI. Additional gyms/search, membership changes, and request-missing flow not verified. |
| Me > Gym rankings | In progress | View gym rankings opens Rankings > Total filtered to Lift Rivals Demo Gym, showing 25 lifters and the Video-backed evidence option selected. Data is demo-only; sort/rank movement remains unavailable. |
| Settings > Privacy | Fix applied; build verification pending | Visibility controls remain available for profile, bodyweight, age group, location, gym, gender category, friend list, and lift videos. Removed the “How visibility works” disclosure as requested. Per-field persistence and second-account visibility remain unverified. |
| Settings > Privacy > Preview public profile | In progress | Preview says “Preview uses your saved settings” and opens the own public profile without changing any privacy controls. Profile overview shows submitted three-lift data while relative total is Hidden. Cross-account visibility remains unverified. |
| Settings > Privacy > Preview return path | Resolved in Debug Build 40 simulator | Public preview shows a visible Done button; activating it returns to the personal profile. |
| Track > Progress > Strength category | Pass (visible content) | Category picker includes Consistency, Strength, Muscle, and Body. Strength shows all-time estimated 1RM cards (Bench 251.3 lb, Squat 365 lb, Deadlift 455 lb), three-lift total 1,071.3 lb, 5.41× relative total, other tracked lifts, structural-balance ratios, exercise progress, and weight trends. “How strength records are estimated” says e1RM uses completed working sets up to 10 reps; bars compare the three lifts with the strongest, and tiers use bodyweight-based standards. Expanded Records and recent sessions shows best sets by rep range (6/7/8-rep PRs), best set/session volume, and Rep-range progression with view-workout links. Native simulator screenshot shows the three record cards are compact but text and values remain legible without clipping. Larger text and record-card detail links still need review. |
| Track > Progress > Exercise progress > workout link | Pass (matching read-only destination) | Selecting the Oct 13 Back Squat rep-range row opened Full Body A on Tuesday, Oct 13 at 4:48 PM. Detail showed 38m, 5 sets, 3,542 lb, and the corresponding logged exercises, sets/reps, and RPE values. The Notes section also displayed the literal text `[demo:program-history-v2]`, which looks like internal demo metadata and should be reviewed. The detail screen has a visible Done button, but returning through it could not be rechecked after Device Hub input began failing. |
| Track > Progress > Body category | Issue to investigate | Shows Bodyweight trend with 1M/3M/1Y/All range controls, but no weigh-in data; card says “Log bodyweight to start tracking your trend” and “Add another weigh-in in this period to see a trend.” No muscle map found in Body or Muscle categories. |
| Track > Progress > Muscle category | Issue | Full muscle list, logged workload chart, and explanatory disclosures are present. “Show all 17 muscles” expands the logged-work list; All muscles shows 20 groups. No anatomical body map found in this category. The 14 recent-work tiles and 17/20 workload groups use different inclusion rules without an obvious link between the summaries. |
| Track > Today with active freestyle | Partial fix applied; simulator verified | Today now keeps the Resume active workout card and shows plan context when no workout is scheduled. In the current demo state it says no workout is scheduled today and names Full Body Foundation. No workout was started, finished, or discarded. |
| Track > Today > current contents | Partial fix applied; simulator verified | Rebuilt Debug simulator shows “Today's training,” the active Freestyle Workout card, “No plan workout scheduled today” with Full Body Foundation, and Start empty workout. The duplicate plateau and Browse Workout Programs cards are gone while a plan is active. Quick notes and other scheduled-plan states remain open for review. |
| Track > Plans > saved Full Body B status | Issue | Today previously showed “Completed workout: Full Body B,” while Plans currently labels the same session “Shortened session saved · 0/5 exercises completed” and offers “Repeat workout.” The session detail confirms one saved deadlift set; Plan overview progress remains 0/3 workouts with all sets complete. Clarify the difference between a saved/shortened session and the user-facing “completed workout” status so screens do not imply conflicting completion states. Plan edit controls are disabled while the empty Freestyle Workout is active, with a message to finish or discard it; no plan or active-workout changes were made. |
| Track > Progress > exercise chart help | Superseded by current source; runtime review pending | Current exercise-progress chart code has no “About this trend” disclosure or 28-day/14-day copy. The old finding does not describe the current source; review the visible chart labels and selected-range behavior in the updated build. |
| Track > Progress > expanded exercise detail | Issue / partial review | Current Back Squat chart shows estimated 1RM in lb, latest 109.8 lb from 91.9 lb across 12 training days; rep-range PRs for 6/7/8 reps (91.5/85/94.5 lb), best set volume 756 lb, best session volume 2,268 lb, and weekly links to workouts from Sep 22–Oct 13. Verified Oct 13 opens Full Body A, 38m, 5 sets, 3,542 lb, with Back Squat 91.5 lb × 6 (1/1 sets in target range); Oct 6 opens Full Body A, 48m, 14 sets, 9,683 lb, with Back Squat 94.5 lb × 8 for 3/3 target-range sets; Sep 29 opens Full Body A, 43m, 14 sets, 9,216 lb, with Back Squat 85 lb × 7 for 3/3; Sep 22 opens Full Body A, 38m, 14 sets, 8,184.5 lb, with Back Squat 88 lb × 6 for 3/3. Exercise/date/set links match in all four samples and calculated volume matches the logged weighted sets. All four saved details expose the internal note `[demo:program-history-v2]`. Selecting the opaque range tab group changes the title from last 3M to last 1Y, but the same July–October data points remain; other range choices and their data are not inspectable through AX. |
| Track > Plans | Blocked (edit flows; read-only schedule reviewed) | Schedule shows Monday Full Body A (5 exercises, 14 sets), Thursday Full Body B (saved shortened session; 0/5 planned exercises completed), Friday Full Body C (5 exercises, 13 sets). Expanded workout details include exercise, set/rep prescription, target RIR, and per-exercise options. Week 1 phase details say Foundation, “Build technique and work capacity,” phase week 1 of 4/program week 1. Next week advanced to Week 2 and showed the same schedule; the selector lists Weeks 1–12, labeling deloads and the Week 12 Recovery & Performance Check. Week 1 was restored; Previous week is correctly disabled at the beginning. Program library reports 20 programs. Full Body Foundation preview shows Beginner, 3 days/week, 3 days, 15 exercises, 39 sets; the 12-week structure is Weeks 1–3 Foundation, Week 4 Deload, Weeks 5–7 Progressive overload, Week 8 Deload, Weeks 9–11 Intensification, and Week 12 Recovery and performance check. It says “You already have this program” and “Resume keeps your schedule and progress.” Other setup options lists Edit existing setup and Set up a new cycle, but both are disabled while the active freestyle exists. Plan Overview shows 0 of 3 workouts with all sets completed and 1 of 39 planned sets logged, but says “Start next workout: Full Body A” despite Full Body B saved Thursday, Full Body C on Friday, and Progress previously saying Full Body C is next; this is logged as a cross-screen mismatch. Plan Notes are “Bundled 12-week general program.” Review saved workout opens Full Body B on Oct 22 at 1:28 PM and shows 0m, 1 set, 482.5 lb, one Conventional Deadlift set (96.5 lb × 5), matching prior detail. Week options and plan settings were opened read-only; Add/Duplicate/Delete Week, plan creation/rename/duplicate/progression/delete/stop, Edit schedule, Change day, and Add Workout Day are disabled while the empty freestyle is active. Edit flows remain blocked pending a safe session state. |
| Track > Library > search and exercise detail | Pass (read-only flow; filter count issue separate) | Library contains 549 exercises. Searching “Sumo Deadlift” returns Sumo Deadlift and Kettlebell Sumo Deadlift, confirming the lift exists in the library; Rankings had no eligible Sumo Deadlift lifters in this demo account. Sumo Deadlift detail exposes About, History, Records, and Charts, with instructions, safety tips, and five substitute recommendations: Conventional Deadlift, Barbell Stiff-Leg Deadlift, Deficit Deadlift, Good Morning, and Hex Bar Deadlift. Empty states are clear: History says complete the exercise in a workout; Records shows em dashes and says only completed working sets count; Charts says weighted working sets are needed. Back Squat History shows dated plan sessions; Records explains completed working sets and shows e1RM/session-volume/set-volume/heaviest-weight records; Charts exposes a 12-workout e1RM chart and a dated data table. Selecting and applying a substitute remains unverified. |
| Track > Library > exercise filters | Issue to investigate | With no filters applied, the Library says 549 exercises, but the filter sheet’s primary action says “Show 550 Exercises.” The filter sheet includes equipment, body area, and primary-muscle options. No filter was applied. |
| Rankings > athlete profile > activity and video evidence | Issue to investigate | Rank 1 opens Demo Lifter 25’s public profile with an Overview, four Video-backed submissions, and a PR videos tab. The Back Squat submission row itself is plain text in the accessibility tree and tapping it did not open details; its options menu offered Report lift. The report form lists Incorrect weight, Mismatched exercise, Unusable or edited video, Depth, Range of motion, Lockout, Harassment or bullying, Hate speech, Nudity or sexual content, Violence or dangerous behavior, Spam or scam, and Other; details are optional, Submit is disabled until a reason is selected, and Cancel returns to Rankings. No report was sent. Selecting Play Conventional deadlift lift video opened a player with the lift, 725 lb × 1, date, and Video-backed badge, but the media area displayed a black unavailable-video symbol. The player showed a one-second duration and changed Play to Pause, so metadata is present but playable evidence was not visibly available in this demo. |
| Forum > feeds, search, filters, sort | Issue / partially verified | All shows seeded posts across Strength Training, Powerlifting, and Nutrition; For You shows one pinned seeded post; Following gives “No followed communities yet.” Filter sheet opens at half height with Community and Sort controls. Choices are All communities, Strength Training, Powerlifting, Nutrition; sort choices are Top posts, New posts, Most discussed. Existing search behavior was checked earlier: “Strength Training” narrows results and Clear restores all. Reset and Done are visible in the screenshot but absent from the accessibility tree. The community-browser grid and new-discussion plus icons also have no corresponding accessibility elements; their destinations remain unverified. Discussion detail is read-only, so vote/reply/report mutation behavior is blocked. |
| Forum > discussion detail | Partial pass; write/report actions blocked | Opened a seeded discussion with 3 comments. Best/New sort changes order; collapsing and re-expanding the first reply thread hides and restores its nested reply. Share discussion and comment-action menus are present. Banner says “Demo forum is read-only. Sign in to post, reply, vote, or report.” Vote, reply, submit, and comment Report controls are disabled, so write/report interactions cannot be assessed on this account. |
| Forum > Share discussion | Issue to investigate | Tapping Share discussion presents a blank/blurred sheet over the discussion; no share targets or actions appear in the accessibility tree after the sheet settles. Dismissed without sharing. |
| Me > Activity and Training achievements | Issue | Activity’s expanded Progress timeline shows dated milestone entries (workout streak, lifted volume, workout count, rival tier, PR/lift thresholds); the visible timeline entries are disabled and cannot be opened. Training > Achievements separately repeats award tiles including First Workout, 2/3/5/10/25 Workouts and First Lift Logged, matching the Awards catalog. This confirms substantial overlap across the three destinations; the Activity milestones do not offer a working detail route in this state. |
| Me > Training layout | Issue | Personal Training contains a “Strength & awards” card, a Rankings empty state with a View action, a Back squat submission-progress chart (“One lift shown; add another submission to see a trend”), an Achievements list with 22 visible entries, and a private-workout-history shortcut. The same workout-count, lift-count, and PR-count award names appear in Activity > Training milestones and Awards. Ranking content points users to Leaderboards, while the single-lift chart only summarizes submitted-lift progress. This confirms the user’s concern about a crowded, repetitive hierarchy; no content was edited. |
| Settings > About & support > build | Pass (visible state) | About & Support displays Version 1.0 and Build 31 in this simulator. |
| Settings > About & support > legal pages | Pass (read-only destinations) | About Lift Rivals, Privacy notice, Terms of use, and Fitness disclaimer each open an in-app sheet with content and a Done action. No acceptance or external transmission occurred. |
| Settings > About & support > Support | Pass (destination loads after delay) | Support eventually opens liftrivals.com in the in-app browser, with “How can we help?”, support-topic content, and an Email Support action. Email was not activated. Support page also says account deletion is in Settings, conflicting with the blank Account page and missing Delete Account control. |
| Track > Active workout > add exercise picker | Pass (read-only browsing); selection blocked | Opened from the empty active Freestyle Workout. Picker exposes search, muscle filters, equipment options, custom exercise entry, and alphabetical results. Search/filter behavior was exercised for Sumo Deadlift and Barbell equipment, then restored to All and cleared. No exercise was selected or saved; custom exercise form was opened then dismissed without saving. Active workout remains empty. |
| Track > Active workout > logging, finish, and save | Blocked (preserve account/workout data) | Active freestyle remains at 0 exercises, 0 sets, 0 lb with a running timer. Adding/selecting an exercise, logging/editing/deleting sets, pausing, finishing/saving, or discarding would change the active session and were not performed per instruction. |
| Track > Progress > Strength records and charts | Pass (visible state); focus mismatch remains | Strength page exposes Bench/Squat/Deadlift records, other tracked lifts, structural balance, Back Squat 3M trend, and rep-range workout links. Default text appeared readable in AX; large-text rendering not checked. Saved focus is Powerlifting while Progress opens Strength (issue already logged). |
| Track > Progress > exercise picker empty state | Superseded by current source | The Progress exercise picker is a fixed menu of exercises with completed history and has no search results area. The Exercise Library search now displays “No exercises found,” suggests changing search/filters, and provides a Clear filters action. Recheck the live Library search state in the final review. |
| Track > Plans > program preview | Partial pass; remaining actions blocked | Full Body Foundation preview shows Beginner, 3 days/week, 3 days, 15 exercises, 39 sets, Week 1 exercises, and a 12-week structure. Expanded Monday A lists Back Squat 3×6–8, Barbell Bench Press 3×6–8, Seated Cable Row 3×8–12, Romanian Deadlift 2×8–10, and Plank 3×30–60 sec, with target muscles and 3 reps in reserve. Preview says “You already have this program” and “Resume keeps your schedule and progress.” Workout B is Wednesday in the template preview, while the active plan schedule shows Thursday; this appears to be template vs customized active schedule. Resume and other setup options are disabled because an empty freestyle workout is active. Selecting or changing a plan was not activated. |
| Track > Plans > Beginner Powerlifting Base preview | Partial pass; setup confirmation blocked | Preview identifies Powerlifting, Beginner, three days/week; default start date is Oct 23, 2026 and the note says weeks advance every seven days and missed workouts stay available. Progression choices are RIR + Rep Range, Adaptive Rep Range, and Fixed Sets + Reps (selected); training days are Monday Squat + Bench, Wednesday Deadlift + Press, Friday Squat + Bench Volume. Week 1 shows 3 days, 12 exercises, 34 sets; Monday preview lists Back Squat 3×5, Bench Press 3×5, Seated Cable Row 3×8–12, Cable Crunch 3×10–15. The 12-week structure is Weeks 1–3 Foundation, Week 4 Deload, Weeks 5–7 Progressive overload, Week 8 Deload, Weeks 9–11 Intensification, and Week 12 Recovery and performance check. Start new cycle is disabled because the active freestyle workout must be finished or discarded. No date or progression selection changed. |
| Settings > Privacy / View as Public | Partial pass | Current saved settings show Profile Public, Bodyweight Private, Age group Public, Location Private, Gym Public, Gender category Public, Friend list Friends, and Show lift videos on. “How visibility works” explains profile access, field audiences, private achievements, and indirect bodyweight inference. Preview correctly reflects the saved profile with Overview, Activity, PR videos, and Training; Relative total is Hidden. Own-profile menu still offers Report athlete and Block athlete (confirmed issue). No Back or Close control is visible or exposed in AX; Escape returns to Privacy and a second Escape closes Settings. Swipe-dismiss behavior remains unverified. No privacy values were changed. |
| View as Public > Training > Rankings link | Superseded by current source | The current public Training section no longer contains the Rankings panel or its obscured View action. Current Training presents only the public workout-history privacy state; workout sharing remains a separate privacy/backend issue. |
| Rankings > Compare with options | Source fix; build verification pending | Explicit Global choices are absent from the current location and Compare with menus; all-lifters scope is the implicit default. My City, My Weight Class, and My Gym remain available as requested. |
| Rankings > Absolute > Sumo Deadlift | Pass (empty result state) | Sumo Deadlift is present in the exercise selector. Selecting it produces “0 lifters” with an explanation that no lifters match the current gym/evidence filters and a Reset filters action. Returned Exercise to All after review. |
| Track > Progress > history detail route | Source fix; Build 40 compiled | Workout details now remove internal demo metadata tags from user-facing notes. The Oct 13 detail was not reopened in the current run, so runtime confirmation remains part of the review. |
| Main tabs and Track segments | Pass (navigation presence) | Home, Rankings, Track, Forum, and Me tabs are present. Track contains Today, Plans, Library, and Progress. Selecting tabs did not stop or modify the active freestyle workout. Detailed actions within remaining tabs are still in progress. |

## Issue log

| Date | Screen / control | What happened | Expected behavior | Status |
|---|---|---|---|---|
| 2026-10-23 | Track > Progress suggested next workout vs Plans overview | Progress says “Next planned: Full Body C,” while Plan Overview says “Start next workout: Full Body A”; Full Body B is saved as a shortened session and the active freestyle hides Today’s plan status. | Today, Progress, Plans, and Home should agree on the next scheduled workout and clearly distinguish saved-shortened from fully completed sessions. | Resolved in Build 39: overview prioritizes the current program week and reports unfinished sets rather than linking to an older session; simulator verified |
| 2026-10-23 | Track > Progress > Strength > exercise picker | Searching and choosing Barbell Overhead Press updates the exercise chart and summary (latest estimated 1RM 134.3 lb, +42.5 lb since start, 12 logged training days). The second stalled-lift suggestion changed order during navigation. | Plateau ordering remains stable across refreshes/screens unless the underlying data or criteria changes. | Source fix: plateau candidates now use exercise ID as a deterministic tie-break for equal workout dates; Build 40 compile and simulator verification pending |
| 2026-10-22 | Settings > Training Focus | Powerlifting appeared selected, but after returning the field showed “Choose a focus.” The selection did not persist. | Focus remains Powerlifting after leaving and reopening Settings. | Resolved and verified on Build 34 demo: changed to Bodybuilding and reopened Settings to confirm, then restored Powerlifting and confirmed it persisted. |
| 2026-10-22 | Onboarding > automatic workout PR sharing | Existing demo Settings preference is off, but onboarding initializes automatic workout PR sharing to on and saves that choice after profile setup. | Clearly explain public automatic PR sharing and enable it by default, with a choice to change it. | Default confirmed in Build 35 source; new-account UI flow still needs verification |
| 2026-10-22 | Settings > Privacy explanation | “How visibility works” takes space and was judged unnecessary. | Remove this disclosure from Settings privacy. | Removed in source and included in the compiled Build 39; screen verification remains pending. |
| 2026-10-23 | Progress > Strength > Rep-range progression > Workout details | Opening the Oct 13 chart row correctly shows Full Body A and its recorded totals/sets, but the Notes section displays `[demo:program-history-v2]`. | Keep internal demo metadata out of user-facing workout notes. | Workout detail strips both internal demo metadata tags; included in compiled Build 39. Screen verification remains pending. |
| 2026-10-22 | Settings > Delete Account | Account heading/section feels repetitive; delete action should be easier to distinguish from Sign Out. | Move Delete Account to the bottom of Settings as a standalone destructive action with confirmation. | Delete Account is a standalone destructive section after Settings content, separate from Sign Out; included in compiled Build 39. Screen verification remains pending. |
| 2026-10-22 | Home > Awards | Home showed 34 earned awards and one program started; user was concerned many may have unlocked after one workout. | Compare earned awards with actual workout/lift history and published thresholds; confirm awards are not being granted too easily. | Source audit complete: award criteria are lifetime totals (workouts, reps, hours, volume, lifts/PRs, strength thresholds, streaks, profile/program milestones), not per-session awards. The demo had 46 completed workouts and three submitted PRs, so 34 is not explained by a single workout. No threshold bug confirmed; keep award values unchanged. |
| 2026-10-22 | Home summary | User says the single-workout/single-exercise summary is not useful. | Remove the low-value one-workout/one-exercise summary. | Current source no longer has that summary; Home presents Today and Strength overviews. Build/simulator confirmation pending. |
| 2026-10-22 | Settings > Support / notification permissions | Support takes several seconds but loads the Lift Rivals support page. Manage notification permissions opens an associated iOS Settings page, but it is blank. | Support gives a working contact route; notification action opens usable app-specific notification controls or explains the fallback. | Support issue not reproduced after waiting; notification destination issue confirmed |
| 2026-10-23 | Settings > Account / Delete Account | Account subsection was blank, Delete Account absent from Settings, while the support page instructs users to choose Delete Account in Settings. | Provide the promised account deletion entry and keep it distinct from Sign Out. | Code fix applied; build verification pending |
| 2026-10-23 | Training focus > Progress default | Settings showed Powerlifting while Progress opened to Strength. Powerlifting intentionally maps to Strength, and the saved focus now survives a Settings save/reopen on Build 34 demo. | Opening Progress honors the selected focus and Settings retains it. | Resolved and verified in Build 34 demo |
| 2026-10-22 | Me > View public profile | The personal profile has Overview, PR videos, Training, Workout history, Timeline, and Submissions. Debug Build 40 shows completed workout names, dates, sets, and Program/Freestyle tags in private Training history; public preview shows shared lift data and keeps completed workouts private. The preview Done control closes the sheet and returns to the personal profile. | Review useful public profile content while respecting privacy settings. | Personal history and preview navigation verified; public workout sharing remains blocked on an explicit privacy choice and secure backend support |
| 2026-10-22 | Me > Personal profile > Training | User finds the training view unorganized, crowded with possibly unnecessary information, and poorly arranged. | Audit the information hierarchy and remove/reorder low-value content. | Source fixed: profile sections now show one screen at a time. Training contains completed workout history and filters. Repeated achievement tiles and placeholder ranking grids were removed; full awards remain in Me > Awards. Simulator checks passed for separate public profile sections and personal workout-history filtering. |
| 2026-10-22 | Me > Own profile actions menu | Current source shows View as public and Settings for the current user; Report/Block is only built for other athletes. Build 35 opened the personal profile, but its toolbar menu could not be expanded for runtime confirmation. | Hide report/block actions on the current user’s own profile. | Source fix present; menu interaction still needs verification |
| 2026-10-22 | Me > Activity > Recent submissions | Long exercise names such as “Standing Barbell Overhead Press” look crowded and close to the card edge. | Improve wrapping and spacing so long names fit comfortably. | Source fix: allow exercise names up to three lines and prioritize the text column over the options menu. Simulator visual verification pending. |
| 2026-10-22 | Me > Activity milestones and Training achievements | Activity has training milestones and Training has achievements; workout milestone information may be repeated. | Compare both sections and remove duplication or make their purposes clearly different. | Build 40 separates the profile views: Timeline now contains workout-count milestones and comebacks, while Training excludes workout-count awards; full awards remain on the Awards screen. Compiled and installed; screen review pending. |
| 2026-10-22 | Personal Profile vs View as Public | User wants the distinction and purpose clarified; defer explanation and keep it on the checklist. | Make the two views’ purposes and content differences clear. | Source clarified: personal Training identifies completed workout history as private; public Training explains that workouts are not shared. Section content is separate and own-profile report/block actions remain hidden. Simulator checks passed for separate public profile sections and personal workout-history filtering. |
| 2026-10-22 | Track > Progress > Consistency > Activity | The 30-day, 90-day, and one-year range controls/layout look strange. | Review layout and make range choices clear and consistent. | Review requested |
| 2026-10-22 | Track > Progress > This Week card | “All workouts” wrapped onto two lines. | Give the card slightly more width or adjust its layout so the label stays on one line. | Resolved in Build 34: compact icon/text label fits on one line in simulator. |
| 2026-10-23 | Light appearance > icon color consistency | The Me hub uses different icon colors for adjacent Activity & connections rows (yellow, teal, green) while the user requested a consistent icon tone across the app. | Standardize light-mode icon shading while maintaining sufficient contrast. | Confirmed on Me; app-wide sweep incomplete |
| 2026-10-22 | Track > Progress > Strength > All Time cards | Strength records and other tracked-lift cards felt small, with text squeezed into them. | Improve card sizing/spacing so labels and values are comfortable to read. | Build 40 changes both key-lift and supplemental-lift grids from three columns to two, giving each card more width. Compiled; simulator layout check pending. |
| 2026-10-22 | Track > Progress > Muscle map | User expected a muscle map but could not find it while reviewing the muscle-fatigue estimate. | Confirm the map exists in the expected place and make it discoverable. | Build 34 added and verified a Front/Back map under Progress > Muscle; recent source also keeps it there. |
| 2026-10-23 | Home training alerts vs Progress > Suggested next steps | Home used the first two plateau results from every lift, while Progress showed only squat/bench/deadlift plateau results. That allowed different lifts to appear on Home and its destination. | The Home alert and its destination show the same strength-lift plateau signals. | Build 36 aligns Home to the Progress filter; same-lift runtime comparison pending because no plateau alert appears in current demo Home |
| 2026-10-23 | Home > PR details > Attempt details | The details showed an internal “self_reported” value and a “Review status: clear” row, but Lift Rivals has no user-facing review process. | Show readable “Self reported” evidence and omit review status. | Resolved and verified in Build 36 simulator; accessibility tree shows “Self reported” and no review-status row |
| 2026-10-23 | Progress > Consistency > one-year activity | An earlier 1Y heatmap showed 0 minutes despite recent activity in 30D/90D. | Year view includes the same account’s activity in the relevant date range or clearly explains its empty state. | Resolved in Build 34: year view opens at the latest dates and showed recent October activity in simulator. |
| 2026-10-23 | Progress > Muscle summary and workload | Muscle fatigue estimate showed fewer recent-work tiles than the workload view, because secondary-only muscles were absent from the recent-work summary. A body map is available under Progress > Muscle. | Show muscles used as either primary or secondary and keep the map discoverable. | Source fix: recent-work summaries now include primary and secondary muscle involvement; simulator visual/data verification pending. |
| 2026-10-23 | Progress > Muscle fatigue estimate > How to read this estimate | The recent-work summary did not explain secondary muscle attribution or distinguish logged activity from soreness/readiness. | Explain which logged work contributes to each summary and distinguish recent training activity from muscle readiness. | Source fix: card now says primary and secondary muscles count and clarifies that it is not a soreness/readiness score; simulator verification pending. |
| 2026-10-23 | Home > Awards target and locked-award list | An earlier Home build said “Aim for 75 Workouts” with 46 workouts recorded; Awards showed “50 Workouts” still locked. | Show the actual next milestone in Home and make locked-award ordering/progress clear. | Current source has no Home award-target card; Awards sorts scored locked milestones by progress ratio, so 50 workouts precedes 75 at 46 completed. Build 40 compiled; simulator screen verification pending. |
| 2026-10-23 | Forum > header and filter accessibility | Community-browser grid and new-discussion plus are visible in the screenshot but absent from the accessibility tree. Filter sheet’s Reset and Done buttons are also visible but absent from the accessibility tree. Coordinate activation was unavailable in Device Hub during this check. | Expose these controls with meaningful VoiceOver labels and confirm their destinations. | New discussion now sits in the visible Forum header rather than only the navigation toolbar. Browse communities and sorting have explicit identifiers and selected sort value. The former filter sheet has already been replaced by community chips and a sort menu. Simulator composer check passed: opening New discussion, keeping an unsaved draft, and confirming discard all work. |
| 2026-10-23 | Me > Public profile > Overview vs Training | An earlier build showed three submitted lifts in Overview but described only one lift in Training. | Keep lift totals consistent and explain which data belongs in Training. | Current source separates submitted lifts in Overview/PR Videos/Submissions from completed workout history in Training. Other athletes’ workout histories remain private; public sharing needs an explicit privacy choice and secure backend support before implementation. |
| 2026-10-23 | Rankings > athlete profile > PR video playback | A Video-backed Conventional Deadlift row opens a player with correct lift metadata, but the media pane shows a black unavailable-video symbol; reported duration is one second. | Video-backed evidence can be opened and played, or a clear unavailable/error state explains why playback is missing. | Source fixed: shared video player observes loading/playback failures and shows Video unavailable with Try again instead of an unexplained black player. PR-video selection now compares weights in kilograms across recorded units. Real evidence-file playback still needs account data. |
| 2026-10-23 | Rankings > filter/search header and evidence picker | Header filter/search icons and the Video-backed/Self-reported/All lifts options were visible, but the accessibility tree exposed only a generic “Lift evidence” container and omitted individual controls. | Expose the controls as accessible elements with useful names and selected state. | Build 40 adds names, selected values, and identifiers to filter options, quick filters, Reset/Done, search field, and search toggle. Compiled and installed; runtime accessibility verification is pending because Device Hub clicks currently fail with no frame. |
| 2026-10-23 | Track > Plan Overview next workout | Plan Overview showed “Start next workout: Full Body A” on a rest day even though Full Body C was the next scheduled workout later that week. In the current demo, week 12 shows A/B/C saved as shortened; Today reports no session today and Plan Overview had linked to an older unfinished deload week. | The next-workout action matches today’s workout or the next upcoming scheduled session for the selected week, and saved-shortened sessions do not cause an older day to be suggested. | Build 39 verified in simulator: Overview now shows Current week · Week 12, 0 of 3 workouts fully complete, 15 of 24 sets logged, and “Unfinished sets remain in this week”; no stale Full Body A action or older week link. |
| 2026-10-23 | Me > Edit athlete profile actions | Save and Cancel are visible on the editor screen but omitted from the accessibility tree; profile save was not activated because it would change account data. Escape exited the form without changes. | Expose Save and Cancel to accessibility; verify save/validation separately on a disposable profile. | Save and Cancel now have explicit identifiers. The simulator onboarding UI check opened Edit profile details from the policy screen and cancelled successfully. Account/profile regression suite: 120 tests passed. |
| 2026-10-23 | Sign-in > returning account data load | User reports saved account information takes more than 20 seconds to appear after signing back into a signed-out account, making it look as if no information was saved. Static review found normal sign-in did not start completed-workout history sync until a later app-activation event; the sync was only part of the immediate post-auth path in UI tests. | Fetch saved workout history as part of the immediate post-sign-in refresh and show a loading state instead of an empty appearance. | Code fix applied; simulator sign-in timing still needs verification |

### Build 34 follow-up

| Screen / issue | Current result | Remaining |
|---|---|---|
| Track > Progress > Consistency > 1Y activity | Fixed and verified in the simulator: the year view opens at the latest dates and shows recent October activity. | Verify the All Workouts one-line label visually after simulator service recovers. |
| Track > Progress > Muscle | Fixed and verified in the simulator: Muscle now has a Front/Back map with primary and secondary highlights for the selected week. | Review mapping/inclusion rules against more exercises and workload totals. |
| Rankings filters | Verified in the simulator: quick filters are My City, My Weight Class, and My Gym; Global is absent. Self-reported and time filters now appear before Division/Location. | The sheet’s individual control accessibility and filter-search header controls remain under review. |
| Awards > locked list | Build 34 now orders scored locked awards by current progress. | Verify the resulting order and reconcile the Home “next milestone” card against the same progress source. |
| Me > Training timeline | Build 34 fixes workout milestone count interpolation so events display “5 workouts”, “10 workouts”, etc. | Check the overlap between these timeline events and award unlock entries before deciding whether to remove duplicates. |
| Progress > This Week | Build 34 keeps the All Workouts label on one line in the simulator; it fits the metric tile at native display size. | No additional action needed for this layout item. |
| Light-mode action icons | Build 34 shows consistent adaptive green icons across the Me hub’s Activity & Connections rows, with sufficient contrast in Light mode. | The full app icon sweep remains open; destructive controls stay red. |

### Build 35 follow-up

| Screen / issue | Current result | Remaining |
|---|---|---|
| Sign-in > returning account data load | Build 35 starts completed-workout history synchronization alongside launch-data refresh immediately after sign-in. The compiled Build 35 app is installed in the iPhone 18 Pro Max simulator. | A real signed-out/sign-in timing check is still needed; do not treat the user’s account as test data without consent. |
| Track > Progress default focus | Powerlifting persists through Settings save/reopen and maps to the Strength category. | No additional action needed. |

### Build 36 follow-up

| Screen / issue | Current result | Remaining |
|---|---|---|
| Home training alert vs Progress > Suggested next steps | Build 36 filters Home plateau alerts to the same squat, bench, and deadlift IDs used by Progress. The app is installed and running in the iPhone 18 Pro Max simulator; installed bundle version is 36. | Compare the displayed lift names on both screens when the current demo has plateau alerts to show. |

### Build 37 follow-up

| Screen / issue | Current result | Remaining |
|---|---|---|
| Track > Plans > Plan Overview next workout | Build 37 compiles and is installed. In the simulator, the active plan is in Week 12 with shortened saved sessions for Monday A, Wednesday B, and Friday C; Today says no plan workout is scheduled and Overview still says Full Body A. | The fallback still selects A when the saved sessions leave no upcoming incomplete row. Correct the date/completion selection, then verify Today and Plan Overview agree. |

### Build 38 follow-up

| Screen / issue | Current result | Remaining |
|---|---|---|
| Track > Plans > Plan Overview next workout | Build 38 removes the unscheduled first-incomplete-session fallback. It reports unfinished sets instead of claiming all sets are done when saved sessions are shortened. | Build and simulator verification pending. |

### Build 39 follow-up

| Screen / issue | Current result | Remaining |
|---|---|---|
| Track > Plans > Plan Overview unfinished week | Build 39 prioritizes the current program week when it has unfinished sessions, before linking to an older incomplete week. | Verified on simulator: Week 12 selected and its unfinished-set status shown. |

### Build 40 follow-up

| Screen / issue | Current result | Remaining |
|---|---|---|
| Build 40 distribution | Xcode Organizer reports “Uploaded to Apple” for version 1.0 (40). | Wait for App Store Connect/TestFlight processing before treating it as available to testers. |
| Rankings filter and search accessibility | Added explicit labels, selected values, and accessibility identifiers for filter choices, search controls, and sheet actions. Build 40 compiled and installed on the iPhone 18 Pro Max simulator. | Device Hub is displaying the app, but current AX clicks fail because embedded controls have no frame; runtime accessibility inspection is pending. |
| Personal profile Timeline vs Training achievements | Timeline no longer repeats every unlocked award; profile Training omits workout-count awards already represented as Timeline milestones. Full award collection remains available under Me > Awards. | Review the revised presentation on-device. |
| Track > Progress > Strength record cards | Key lifts and other tracked lifts now use two columns instead of three, giving their names and values more room. | Review the revised layout on-device. |
| Profile > Public preview navigation and training privacy | Debug Build 40 shows an accessible Done button that closes the preview; completed workout history stays private in this public surface. | Navigation is resolved; public workout sharing needs an explicit setting and secure backend support. |
| Track > Progress category restoration | Confirmed in the Build 40 simulator: Consistency, Strength, Muscle, and Body each load their corresponding content; Strength shows key lifts, other tracked lifts, charts/rep-range progression, while Muscle shows its map and workload. | No restoration issue remains; broader accessibility and detailed interaction checks are still open. |
| Onboarding > Before you compete policy gate | Cleared stale account-operation text on gate entry so an earlier optional setup error does not appear as a policy-acceptance failure. | Verify with a new account flow; the policy gate now has an Edit profile details route; the simulator editor/cancel flow passed. |

### Current follow-up fixes after Build 40

#### Fixed remaining scope (six items)

| Item | Status | Evidence / next check |
|---|---|---|
| 1. Blank simulator launch | Fixed and visually verified | Added the missing UIApplicationSceneManifest to the existing Info.plist. iPhone 18 Pro Max on iOS 27 now displays Sign In with its fields, logo, and buttons. No simulator data erased. |
| 2. Public workout history | Implementation and local SQL security tests complete; deployment pending | New workouts default to shared summaries, with Keep workout private before saving and in workout details. Existing history without a sharing decision remains private. Summary RPC exposes name/date/duration/completed working-set count/exercise names, excluding notes/bodyweight/gym/full payload. Local checks passed for explicit sharing, private profiles, blocked visitors, owner access, and snapshot isolation. |
| 3. Production leaderboard / starting lifts / gyms | Miami cause fixed; signed-in app checks pending | Read-only Production public-client request found 10 Miami gyms, all stored with region FL. Onboarding compared against Florida. Added postal codes to the existing US region catalog and canonical matching, also used for profile gym ordering. Debug points to staging; a Release simulator build is being prepared for Production review. Saved production audit documents deployed mobile leaderboard/API repairs. |
| 4. Returning sign-in delay | Source fix and local account regressions passed; production timing pending | Profile/details/privacy requests and post-authentication account refreshes run concurrently. Refresh also starts after onboarding/policy completion. Real-account timing must be observed. |
| 5. Photo / video | Local regression checks passed; actual-media checks pending | 127 unit checks passed: 123 BackendFoundationTests plus four focused media/gym checks. These cover avatar download/upload/account-switch behavior, new/legacy workout privacy, privacy changes behind an older upload, signed-video URL refresh, and FL/Florida gym matching. Actual account upload/playback still needs verification. |
| 6. Visual review | In progress | Light/dark/larger-text review follows the final build. |

| Screen / issue | Current result | Remaining |
|---|---|---|
| Onboarding city and wheel pickers | Country, state, height, and bodyweight wheels are anchored below their headers. State selection supplies bundled suggested cities immediately; remote search still finds other cities. Selecting a city no longer triggers a query change that clears the selected city. | Fresh-account visual and location/gym-data checks remain open. Bundled suggestions are curated city choices, not a live population ranking. |
| Onboarding privacy and draft retention | Hide exact bodyweight starts off for a new setup. Draft initialization runs once, and saved profile/location fields are retained on resume. | Fresh-account simulator check passed: Hide exact bodyweight is off and Hide city remains on. Physical-device relaunch verification remains open. |
| Onboarding final summary | Replaced hardcoded Unranked cards and the unrelated account score with the entered three-lift total, bodyweight, and starting-lift count. Comparison copy now distinguishes self-reported and video-backed rankings. | Final visual review and real leaderboard availability remain open. |
| Policy gate navigation | Added Edit profile details, reusing the existing profile editor without bypassing policy acceptance. Simulator UI check opened and cancelled the editor successfully. | Full onboarding rerun passed with a fresh-profile fixture, including opening and cancelling the profile editor at the policy gate. |
| Photo save feedback and races | Missing upload files now fail through the existing error path. Saving a photo verifies that account and mutation still match before updating local state. Updated async photo regression tests. | Focused checks passed; all 120 BackendFoundationTests passed with no exclusions. Device upload/retry visual checks remain open. |
| Personal profile layout | Each section opens separately. Training shows completed workouts; Overview keeps submitted-lift progress; duplicate achievements and empty ranking grids were removed. | Simulator public-section navigation and personal-history filter checks passed; the fresh-account privacy check also passed. Public workout sharing still needs a privacy model and secure backend support. |
| Video player and lifting gear | Video failures now show a retry state. Submit Lift says Lifting gear and explains Raw/Equipped; the estimate action icon uses the shared adaptive tone. | Device media playback and final visual review remain open. |
| Forum actions | New discussion is an accessible button in the visible header. Community browse and sort controls have identifiers and a selected-sort value. | Simulator composer navigation and discard confirmation passed. |
| Returning-account loading follow-up | Account refresh now starts history, plans, lifts/rankings, gyms, bodyweight, and avatar requests concurrently. Plan/photo requests, return analytics, and notification authorization no longer delay the start of history loading. | Real-account sign-out/sign-in timing remains unverified; no production latency claim yet. |
| Gym directory feedback | Onboarding distinguishes loading, request failure with Retry loading gyms, and a successfully loaded directory with no matching gyms. Directory feedback clears when switching accounts. | Verify actual Miami directory coverage with the production account. |
| Remaining light-mode accents and video loading | Onboarding milestone icon, Joined gym badge, profile chart points, and positive rank movement use the shared adaptive accent. Video player shows Loading video while preparing media, alongside its existing failure/retry state. | Full light/dark/larger-text visual pass and real-file playback remain open. |
| Public Training history backend review | Existing workout-share access is limited to owners and mutual connections. It does not provide public workout-history access. | Public history still requires an explicit sharing/privacy flow and a secured backend contract; no remote migration applied. |
| Latest follow-up build / runtime review | Debug simulator build succeeded and installed. Normal launch and isolated demo launch both returned process IDs. | Device Hub currently shows a blank simulator display with no app controls, so this batch has not passed visual/runtime review. No tests were run for this batch. |
