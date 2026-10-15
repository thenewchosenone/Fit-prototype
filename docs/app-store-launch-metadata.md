# Lift Rivals App Store launch metadata

This file is a release-owner handoff. Replace each `REQUIRED` value with a live
production URL or App Store Connect value before submission. Do not submit the
repository or these placeholders as final metadata.

## Required URLs

- Privacy Policy: `https://liftrivals.com/privacy-notice/`
- Terms of Use: `https://liftrivals.com/terms-of-use/`
- Support: `https://liftrivals.com/support/`

The native app requires the same current legal wording shown by
`LegalDocument.current` in `LiftRankApp/Domain/IdentityDomainModels.swift`.
The public pages must include the fitness disclaimer, account deletion method,
profile and workout data handling, profile-photo storage, visibility controls,
community content, and support contact.

## App Privacy answers

Declare data used for app functionality, linked to the user and not used for
tracking:

- Contact Info: email address.
- Identifiers: user ID.
- Health and Fitness: workout history, lifts, bodyweight, and training data.
- Photos or Videos: profile photos and user-submitted lift videos.
- User Content: posts, messages, reports, comments, and shared workouts.

Do not declare advertising tracking. `LiftRankApp/PrivacyInfo.xcprivacy` sets
tracking to false and lists these app-functionality data categories.

## Review notes

Provide one staging reviewer account created specifically for App Review, or
provide deterministic account-creation instructions. Include:

- The account can complete onboarding and legal acceptance.
- A profile photo, bodyweight entry, completed workout, and lift submission
  can be tested.
- Delete Account is under Settings and requires a recent authenticated session.
- Lift verification and ranking are server-controlled; self-reported lifts are
  not presented as verified competition results.

Never put a service-role key, database password, APNs private key, or other
server secret in App Store notes or the iOS bundle.
