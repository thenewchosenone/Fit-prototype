# Lift Rivals App Store launch metadata

This file is a release-owner handoff. Replace each `REQUIRED` value with a live
production URL or App Store Connect value before submission. Do not submit the
repository or these placeholders as final metadata.

## Required URLs

- Privacy Policy: `https://liftrivals.com/privacy-notice/`
- Terms of Use: `https://liftrivals.com/terms/`
- Support: `https://liftrivals.com/support/`
- Marketing: `https://liftrivals.com/`

Verified on 2026-10-17: marketing, support, privacy, and the rendered `/terms/`
page load. The earlier checklist's `/terms-of-use/` address returns HTTP 404;
use the working `/terms/` address in review notes.

The native app requires the same current legal wording shown by
`LegalDocument.current` in `LiftRankApp/Domain/IdentityDomainModels.swift`.
The public pages must include the fitness disclaimer, account deletion method,
profile and workout data handling, profile-photo storage, visibility controls,
community content, and support contact.

## App Privacy answers

Declare data used for app functionality, linked to the user and not used for
tracking:

- Contact Info: name and email address.
- Identifiers: user ID and device ID for notifications.
- Location: coarse location selected for local rankings and gyms.
- Health and Fitness: workout history, lifts, bodyweight, and training data.
- Photos or Videos: profile photos and user-submitted lift videos.
- User Content: posts, messages, reports, comments, and shared workouts.
- Usage Data: product interaction analytics. User IDs and fitness data also
  declare analytics as a purpose in the bundled privacy manifest.

Do not declare advertising tracking. `LiftRankApp/PrivacyInfo.xcprivacy` sets
tracking to false and lists these app-functionality data categories.

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

## Candidate 1.0 (30) — review handoff

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
   review account, so test deletion last. Sign Out is on the main Settings page.
7. Camera/photo access is requested when using the corresponding media feature;
   notification permission may be requested after legal acceptance. These
   prompts do not need to be accepted to log a basic workout.

The same account and backend are used across supported regions; the app has no
per-region feature switch. Current onboarding country choices are United States,
Canada, United Kingdom, Ireland, Australia, New Zealand, and South Africa.
Do not describe location setup as worldwide coverage.

Privacy: https://liftrivals.com/privacy-notice/
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
