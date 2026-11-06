# Lift Rivals App Store launch metadata

This file is a release-owner handoff. Replace each `REQUIRED` value with a live
production URL or App Store Connect value before submission. Do not submit the
repository or these placeholders as final metadata.

## Required URLs

- Privacy Policy: **BLOCKED** — the October 29, 2026 rendered live check returned HTTP 200 but showed a 2,283-character overview titled “Public by intention,” not the full 10-section notice in `LegalDocument.current`. It loads `/static-site.js?v=20260829-legal2`, which is absent from this checkout. The current checkout's GitHub Pages workflow deploys the React demo's `dist` artifact; it does not copy `website/privacy/index.html` or establish ownership of `liftrivals.com`. Historical deployment notes record a separate allowlisted deployment. Locate that site's source and deployment manifest, obtain approved full notice text, publish through its owner, and verify the rendered page. The October 28 check found no `/privacy-notice/` route; any required redirect remains to be verified.
- Terms of Use: **BLOCKED** — the October 29, 2026 rendered live check returned HTTP 200 but showed a 2,366-character overview titled “Compete with context,” not the full 14-section Terms in `LegalDocument.current`. It uses the same external JavaScript renderer. The November 1 local update aligns the introduction and sections 5 and 14 of `website/terms/index.html` with the existing native `LegalDocument.current`; no new legal terms or native acceptance version were introduced. Review that exact source, locate the production site's source and deployment manifest, publish through its owner, and verify the rendered terms page.
- Support: `https://liftrivals.com/support/` (rendered HTTP 200, checked October 29, 2026; page includes contact and account-deletion instructions)
- Marketing: `https://liftrivals.com/`

The October 29, 2026 browser check confirmed the privacy and terms routes render
through `/static-site.js?v=20260829-legal2`. The current checkout has no source
for that renderer. Its GitHub Pages workflow instead builds the hash-routed
React demo, whose canonical URL is `liftrank-demo.pages.dev`. Historical
deployment notes record a separate allowlisted site checkout for
`liftrivals.com`; current DNS and hosting ownership have not been verified. The
HTTP response and current overview content do not establish that the full legal
documents are published.

The native app requires the same current legal wording shown by
`LegalDocument.current` in `LiftRankApp/Domain/IdentityDomainModels.swift`.
The public pages must include the fitness disclaimer, account deletion method,
profile and workout data handling, profile-photo storage, visibility controls,
community content, and support contact.

## App Privacy answers

The current source manifest lists the following user-linked data categories.
This is a source-level record, not confirmation of actual production collection
or the current App Store Connect answers:

- Contact Info: name and email address.
- Identifiers: user ID and device ID for notifications.
- Location: coarse location selected for local rankings and gyms.
- Health and Fitness: workout history, lifts, bodyweight, and training data.
- Photos or Videos: profile photos, user-submitted lift videos, and forum photo/video attachments.
- User Content: posts, messages, reports, comments, and shared workouts.
- Usage Data: product interaction analytics.

In `LiftRankApp/PrivacyInfo.xcprivacy`, Contact Info, Device ID, Location,
Photos or Videos, and Other User Content list App Functionality as their
purpose. User ID and Fitness list both App Functionality and Analytics.
Product Interaction lists Analytics only. The manifest sets tracking to false
for every listed category. Confirm these purposes against production behavior
before finalizing the App Store answers; do not infer the approved disclosure
solely from source declarations.

Do not declare advertising tracking unless production behavior changes and is
reviewed.

October 26 comparison: App Store Connect listed the same nine data types, but
showed App Functionality as the purpose for User ID, Fitness, and Product
Interaction. The bundled manifest also declares Analytics for User ID and
Fitness, and Analytics for Product Interaction. Reconcile the disclosures with
actual production behavior before changing the published answers; the category
list alone is not a complete match.

Code-level analytics evidence updated November 1, 2026. Production analytics now
requires an explicit, account-specific opt-in on each device in Settings →
Privacy → Share usage analytics. The default is off, including for existing
installs without a recorded choice. The production service checks consent for
every event, including events sent directly by CompetitionStore. After opt-in,
events send an ID, `user_id`, name, timestamp, and properties through
`SupabaseAnalyticsService`; properties default to empty. Disabling the setting
stops subsequent analytics submissions; it does not delete historical events
or disable the service logs needed to run an account. This change does not
remove the need to disclose the optional collection in App Store Connect.

| Event | Additional properties | Source call site | Owner review needed |
| --- | --- | --- | --- |
| `signup_completed` | None | `LiftRankApp/ViewModels/AppViewModels.swift:487` | Confirm actual use and User ID/Product Interaction purposes. |
| `onboarding_completed` | None | `LiftRankApp/ViewModels/AppViewModels.swift:707` | Same. |
| `weekly_return` | None | `LiftRankApp/ViewModels/AppViewModels.swift:800` | Same; event name does not prove weekly-only collection. |
| `first_workout_started` | None | `LiftRankApp/Features/Training/ActiveWorkout/AppState+ActiveWorkout.swift:76,96` | Confirm treatment of workout activity and applicable purposes. |
| `workout_completed` | `workout_id` (UUID string) | `LiftRankApp/Features/Training/ActiveWorkout/AppState+ActiveWorkout.swift:187–189` | Confirm treatment of activity and account-linked workout reference. |
| `pr_submitted` | `movement` (name) | `LiftRankApp/Features/Competition/CompetitionStore.swift:703` | Confirm Fitness/Product Interaction classification and purposes. |
| `video_backed_pr_submitted` | `movement` (name) | `LiftRankApp/Features/Competition/CompetitionStore.swift:733` | Same; the analytics payload contains no video bytes. |

These call sites do not prove successful production delivery. The insert
suppresses errors, and the October 26 App Store Connect comparison above is
historical. The database permits `workout_shared`, but there is no corresponding
event in the current Swift event enum or call sites; do not treat it as emitted.
Owner review must confirm production use, retention, access/export, provider
logging, and the purposes before changing the manifest or App Store answers.

The preserved October 26 build 49 archive and extracted IPA contain app privacy
manifests matching the inspected source manifest, but their recorded source was
dirty and predates this inspection. This is historical binary evidence only;
verify the final candidate archive after release changes.

## Review notes

Provide one stable production reviewer account for the production Release
build. Enter its credentials only in App Store Connect's reviewer login fields.
Verify that it has no email-verification, 2FA, payment, or approval gate. Include:

- The account can complete onboarding and legal acceptance.
- A profile photo, bodyweight entry, completed workout, and lift submission
  can be tested.
- Delete Account is under Settings and requires a recent authenticated session.
- Lift verification and ranking are server-controlled; self-reported lifts are
  not presented as verified competition results.

Never put a service-role key, database password, APNs private key, or other
server secret in App Store notes or the iOS bundle.

## Historical candidate 1.0 (30) — review handoff

This handoff describes build 30 and must be updated and checked against the actual selected candidate before submission. Build 48 was recorded as uploaded on October 25, 2026; the current working tree is configured for build 49. App Store Connect remains the authority for uploaded and selected builds.

Contact name: Robert Jeanty. Support email: support@liftrivals.com. Retain or
confirm the review contact's existing phone number in App Store Connect.

Supported deployment: iPhone, iOS 17.0 and later. The build targets iPhone only;
iPad use must be checked in iPhone compatibility mode before claiming it was
tested. Only iOS 26.5 simulators are currently installed on the preparation Mac.

External services: Supabase Auth, PostgreSQL database, Storage, Edge Functions,
and first-party product analytics stored in Supabase; Apple Sign in with Apple
and Apple Push Notification service. No advertising tracking is declared.

### Draft review notes

Sign-in is required for the review account. Use the credentials in the App
Review Information login fields. The supplied account must be checked against
the exact uploaded TestFlight build before Update Review is used.

1. Launch Lift Rivals and tap Sign In with the supplied account. Sign in with
   Apple is also available on the authentication screen. New email accounts
   require email confirmation; the reviewer account should already be confirmed.
2. Home summarizes recent workouts, personal records, and training progress.
   In Track, use Today for a workout, Plans for programs, Library for exercises,
   and Progress for history and charts. A freestyle workout can be started
   without selecting a program.
3. To test logging: start a freestyle or planned workout, open an exercise,
   enter weight and reps, complete the working sets, then Finish workout and
   Save & finish. For adaptive programs, effort ratings are shown on working
   sets and guide the next matching workout's suggested weight.
4. Rankings and gyms use server-controlled eligibility and verification.
   Starting lifts entered during onboarding are private. Submit eligible public
   lifts separately to participate in rankings.
5. For user-generated content, open another athlete or lift to find reporting
   and blocking actions. Forum discussion details also offer reporting; own
   posts can be edited or deleted.
6. To delete the signed-in account: open Me, tap the settings gear, choose
   Account, then Delete Account and confirm. This permanently deletes that
   review account, so test deletion last. Sign Out is also in Settings → Account.
7. Photos and videos use the system photo picker: only selected items are
   shared, with no camera or full-library permission. Notification permission
   is requested when enabling notifications or scheduling a workout/rest alert,
   not automatically after sign-in. These permissions are optional for logging.
8. In Forum, open a discussion or reply’s actions to report content or block its
   author. These controls do not establish that pre-publication screening is
   live; the screening release gate below must be closed before submission.

The same account and backend are used across supported regions; the app has no
per-region feature switch. Current onboarding country choices are United States,
Canada, United Kingdom, Ireland, Australia, New Zealand, and South Africa.
Do not describe location setup as worldwide coverage.

Privacy: https://liftrivals.com/privacy/
Terms: https://liftrivals.com/terms/
Support: https://liftrivals.com/support/

### Beta description draft

Track workouts, sets, personal records, and bodyweight. Choose a workout program
or train freestyle, review progress, and use adaptive programs for suggested
working weights based on logged reps and effort. Explore athlete rankings,
gyms, and training discussions, with reporting, blocking, and account deletion
available in the app.

### Physical-device video shot list

Record the final TestFlight build on a physical device. Keep the recording short:
launch → reviewer login → Home → Track and a saved workout → Rankings/gym or
Forum → report/block controls → Settings account-deletion flow. Include any
permission prompts. Demonstrate deletion last with a disposable account; keep
the submitted reviewer credentials working. Attach the recording in App Review
Information after confirming that it matches the uploaded build.

- [ ] Confirm the reviewer credentials and contact phone in App Store Connect.
- [ ] Test the exact uploaded build on a clean physical iPhone and on iPad.
- [ ] Verify Sign in with Apple on a physical device.
- [ ] Record and attach the matching review video.
- [ ] Confirm screenshots, privacy answers, notes, and selected build match.
- [ ] Use Update Review only after the above checks pass.


## November 1, 2026 alignment release gates

These are current candidate requirements; they do not change the historical
App Store Connect records above. Do not submit until the applicable gates close.

- **BLOCKED** — Forum screening is not implemented/deployed. Sightengine is the
  selected integration direction following the owner's preference for a service;
  see the concrete rollout in `docs/app-layout-audit.md`. Pro currently includes
  the audio coverage needed for videos. No subscription, provider credentials,
  content transfer, or database deployment was performed. Posting rules,
  report/block controls, and moderator tools are necessary but do not replace
  screening or timely human handling of reports and appeals.
- **BLOCKED** — Public full legal pages and App Store privacy-purpose parity
  remain unverified. The November 1 web reader could not fetch the public legal
  routes; this neither proves an outage nor closes the October 29 findings.
  Before activating Sightengine, approve the processor/retention terms, disclose
  the new recipient, and obtain explicit permission before transmitting content.
  Do not add ATT unless tracking behavior actually requires it.
- **BLOCKED** — The push sender's generic lock-screen payload and collapse ID are
  local source changes only. Deploy to a confirmed environment and verify signed
  device delivery, denial recovery, mute/Focus, foreground behavior, sign-out,
  recipient checks, and retries. Local signing configuration now determines the
  APNs environment; a development-signed Release uses sandbox APNs.
- Accessibility labels: leave each unverified claim unset. Evaluate common tasks
  with VoiceOver, Voice Control, larger text, contrast, Reduce Motion, and other
  claimed features on each supported device. Selected UI automation is not a
  completed assistive-technology evaluation. iPad compatibility, small phones,
  and portrait-only limitations must be assessed explicitly.
- Performance: preserve the launch and initial-training-sync measurements as
  distinct intervals. Measure cold/warm production-device launches, poor network,
  scrolling, media playback, memory, and energy before claiming thresholds met.
- Product page: capture the exact release candidate using fictional/demo data.
  Use actual app UI for Home, workout logging, Plans, Progress, Forum, and Me.
  Describe optional media as lift evidence; only server-verified results may be
  labeled verified. No claims of AI coaching, Apple Health, nutrition, avatar
  leveling, or side-by-side transformation comparison. Do not claim screening
  is active, offline sync is verified, or every accessibility feature works
  until there is matching evidence. Use Apple's official App Store badge only
  when a valid product-page destination is available; do not draw a substitute.
- Recheck age-rating answers for messaging/user content and the actual moderation
  controls. Supply a reachable support contact, an owned review account, and
  exact navigation notes. Preserve build/source provenance with the uploaded
  artifact; the previous build 49 evidence is not proof for a changed binary.

Apple sources checked November 1: [App Review](https://developer.apple.com/app-store/review/guidelines/),
[privacy details](https://developer.apple.com/app-store/app-privacy-details/),
[Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/),
[product page](https://developer.apple.com/app-store/product-page/), and
[marketing](https://developer.apple.com/app-store/marketing/guidelines/).
