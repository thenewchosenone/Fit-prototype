# Lift Rivals App Store launch metadata

This file is a release-owner handoff. Replace each `REQUIRED` value with a live
production URL or App Store Connect value before submission. Do not submit the
repository or these placeholders as final metadata.

## Required URLs

- Privacy Policy: `https://www.liftrivals.com/privacy/`
- Terms of Use: `https://www.liftrivals.com/terms/`
- Support: `https://www.liftrivals.com/support/`

The public routes and their current contents must be verified before
submission. A prior audit note records a live-route check on 2026-10-20; this
turn has not revalidated those pages. Compare the live privacy and terms pages
with the in-product legal notice and checked-in `website/` pages; confirm
retention, data categories, account-deletion guarantees, warranty/liability,
and dispute terms with the legal owner. A source comparison is not a legal
determination, and an HTTP 200 response alone does not establish content
accuracy.

The native app requires the same current legal wording shown by
`LegalDocument.current` in `LiftRankApp/Domain/IdentityDomainModels.swift`.
The public pages must include the fitness disclaimer, account deletion method,
profile and workout data handling, profile-photo storage, visibility controls,
community content, and support contact.

## App Privacy answers — provisional; verify before App Store Connect

This source-based inventory is not a final Apple questionnaire determination.
Confirm it against production provider settings, actual SDK behavior, and the
current App Store Connect definitions before submission.

The app privacy manifest currently declares these linked, non-tracking data
types and purposes:

| Data category | Repository-supported examples | Declared purpose |
| --- | --- | --- |
| Contact Info | Email address | App functionality |
| Name | Sign in with Apple name / account profile name | App functionality |
| User ID | Account UUID used for profile ownership and linked analytics | App functionality and Analytics |
| Device ID | Persistent app-generated device UUID used with push-token registration | App functionality |
| Coarse Location | User-selected city/gym and privacy notice's IP-derived or user-selected coarse location | App functionality |
| Health and Fitness | User-entered bodyweight, lifts, workout history, training and readiness data; PR analytics includes the movement label only | App functionality; analytics use of the movement label requires final taxonomy confirmation |
| Photos or Videos | Profile photos and lift videos | App functionality |
| User Content | Native forum posts, comments, report text, and other user-generated community content | App functionality |
| Product Interaction | App interaction events sent to `analytics_events` | Analytics |

**Native analytics source trace (2026-10-20):** the current event enum includes
signup completion, onboarding completion, first workout started, workout
completed, PR submitted, video-backed PR submitted, and weekly return. Current
call sites send an account UUID, event name, and client event timestamp; PR
events additionally send a movement label. The inspected native call sites do
not include weight, repetitions, video, caption, or location in analytics
properties. The database row also has a server-created timestamp and is removed
by the profile foreign-key cascade on account deletion. No time-based retention
or aggregation job for `analytics_events` was found in checked-in migrations;
confirm deployed retention, admin access, exports, and any provider-side
processing before finalizing the App Store answers. This source trace does not
prove the behavior of uninspected deployed code or external providers.

**Native release-scope check (2026-10-19):** the inspected `LiftRankApp` navigation and Swift sources expose forum/community posts, comments, and reports, but no direct-message thread or composer. Messaging exists in the separate web/demo and backend source. Do not treat project-wide messaging code as proof that the iOS binary collects message contents; recheck the exact release target and its provider flows before submission. Apple's current App Privacy taxonomy lists “Emails or Text Messages” separately from “Other User Content,” so classify any messaging feature that ships in iOS using its actual collection and use rather than folding it into this provisional example ([Apple App Privacy Details](https://developer.apple.com/go/?id=info-1)). Apple says App Store Connect answers apply at the app level across platforms, so confirm whether the App Store record includes other shipped platforms/features before using this iOS-only scope check as the complete disclosure inventory ([Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)).

The current native private-profile DTO maps `birth_date`, `sex_category`, and
`height_cm` between the app and the server; birth date and sex category also
inform age/weight-class ranking. These are routine account/profile fields, so
do not assume they qualify for Apple's optional-disclosure exception. Apple's
published taxonomy has no dedicated date-of-birth or sex-category row; confirm
the appropriate data type and purpose in App Store Connect with the legal
owner rather than assuming they are covered by Fitness or Sensitive Info.
Training features also store injury/readiness entries; trace their collection
and destination separately before finalizing the disclosure. Apple's guidance
requires identifying all collected types unless every optional-disclosure
criterion is met ([App Privacy Details](https://developer.apple.com/go/?id=info-1)).

The manifest sets `NSPrivacyTracking` to false and has no tracking domains.
The checked-in iOS source contains no Core Location, HealthKit, IDFA, or
advertising-identifier API use; this does not establish the behavior of every
linked SDK or external provider. Do not declare tracking only after confirming
the production integrations do not use data for cross-app/site tracking.

**Required-reason API spot check (2026-10-20):** `plutil -lint` accepts the
current manifest, and the successful generic Simulator build contains
`LiftRank.app/PrivacyInfo.xcprivacy`. Source usage matches the declared reasons:
`UserDefaults.standard`/`@AppStorage` use app-local defaults (`CA92.1`), and
`LocalWorkoutVideoStore` reads modification dates under the app's
Application Support container (`C617.1`). Apple's current reason list defines
these reasons for app-only defaults and file metadata inside the app container
([Required Reason API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons?language=objc)). This source/build check does not validate every linked SDK's manifest or substitute for archive/App Store Connect validation.

Reconcile the legal notice's additional statements about push-notification
tokens, diagnostics, authentication events, timestamps, and IP-derived
location with Supabase/Apple provider configuration and App Store Connect
categories. These may be provider-generated rather than direct app SDK
collection, and repository inspection alone cannot settle their disclosure.
The privacy manifest is not a substitute for the App Store privacy answers.

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
