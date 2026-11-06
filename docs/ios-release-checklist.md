# Lift Rivals iOS release policy

## Versioning

- `MARKETING_VERSION` is the user-visible semantic version. Patch releases fix defects, minor releases add compatible product changes, and major releases may change established behavior.
- `CURRENT_PROJECT_VERSION` is the App Store build number. Increase it for every archive uploaded to App Store Connect; never reuse an uploaded number.
- As of November 5, 2026, the app target is version `1.0`, build `52`. Build 52 was validated and uploaded through Xcode for internal TestFlight testing. Use a higher unused build number for the next upload. See the current full audit in `release-readiness.md`.

### Latest TestFlight upload

- November 5, 2026, 10:08 p.m. Eastern: Xcode reported **LiftRank 1.0 (52) uploaded** through TestFlight (Internal Testing Only). Organizer records successful validation at 10:06 p.m. and upload at 10:08 p.m., both without warnings. The production-signed archive, frozen source, fingerprints, and upload metadata are preserved in `work/release-build-52-20261105/`. Apple processing, tester availability, and physical installation were not independently verified. Existing public-release gates remain open.
- October 26, 2026, 10:22 p.m. Eastern: Xcode Organizer reported **LiftRank 1.0 (49) uploaded** after successful App Store Connect validation. App Store Connect subsequently listed build 49 as Ready to Submit in the existing internal Lift Rivals Testing group; physical installation was not yet verified. The signed archive is `work/release-readiness-20261026/LiftRivals-1.0-49.xcarchive`; the local signature and production backend/entitlements were checked. Long automated suites, isolated SQL, staging and physical-device gates remain incomplete; a targeted leaderboard UI test passed and a profile UI test failed.
- October 25, 2026, 8:11 a.m. Eastern: Xcode Organizer → Distribute App → App Store Connect reported **LiftRank 1.0 (48) uploaded**. Organizer records build 48 as Uploaded to Apple.
- Production-signed Release archive: `/Users/robertjeanty/Library/Developer/Xcode/Archives/2026-10-25/LiftRivals-1.0-48.xcarchive`. Archive build and system signature verification passed; production backend configuration was confirmed. Package versions remained locked. Service preflight passed with server-side APNs/SMTP verification warnings. Long automated tests were skipped per the release owner's standing instruction.
- Apple's subsequent processing, tester availability and external beta review were not verified by this upload confirmation.

## Required release gate

Run the unified gate orchestrator when preparing publication:

`./scripts/release-gates.sh`

This is the preferred command before any App Store archive activity.

Before creating an App Store archive:

1. Resolve the committed Swift package lock without updating dependencies.
2. Run `./scripts/check_publish_readiness_services.sh` and capture Step #1 evidence.
3. Run all unit and UI tests on the oldest supported iOS release and the current iOS release.
4. Test on a small and a large physical iPhone.
5. Build an unsigned Release configuration and inspect it for credentials, debug/demo entry points, and unintended URLs.
6. Run the Supabase SQL security tests against an isolated local or staging database. Never apply migrations to production as part of this gate.
7. Confirm signup, confirmation, login, restoration, logout, password reset, and account deletion against staging.
8. Archive with production signing and validate the archive in Xcode Organizer before TestFlight upload.

## Promotion criteria

- No critical defect or known data-loss issue.
- At least 99.5% crash-free sessions and seven stable days in external TestFlight.
- Privacy disclosures, support and privacy URLs, age rating, export compliance, screenshots, review notes, and reviewer credentials are complete.
- The release owner has monitoring, support, incident-response, and rollback procedures ready.

TestFlight upload and App Store submission are deliberate manual actions. They are not performed by local build or test commands.

## Lift Rivals 1.0 launch-hardening checklist

Use this checklist before uploading the first App Store candidate. Mark an item complete only with current build, staging, or App Store Connect evidence.

### Code readiness

- [x] Full simulator build succeeds with `xcodebuild -project LiftRank.xcodeproj -scheme LiftRank -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing`.
- [ ] Signup, login, restore session, logout, password reset, onboarding, and legal acceptance complete against staging.
- [ ] Profile photos are account-backed: authenticated profile saves upload image bytes to Supabase Storage before saving the profile draft, `profiles.avatar_path` stores the account path, and login/restore downloads the avatar back into the local cache.
- [ ] Completed workout deletion is account-backed: deleting locally creates a persisted tombstone and the sync service deletes the matching `completed_workout_snapshots` row for the authenticated owner.
- [ ] Bodyweight logs update the bodyweight table and current profile through the same repository upsert path.
- [ ] Awards and PR cards read from completed workouts/lift submissions consistently and do not show demo-only counts for real accounts.
- [ ] Onboarding and Edit Profile map the same identity/body/location fields to the same domain properties.
- [ ] Release builds do not silently enter demo mode when Supabase configuration is missing.
- [x] No service-role keys, APNs private keys, admin secrets, or personal credentials are present in Xcode settings, Info.plist, app resources, or committed docs.

### App Store compliance

- [ ] Privacy Policy URL is live.
- [ ] Terms of Use URL is live.
- [x] Support URL is live.
- [ ] App Privacy nutrition labels match `LiftRankApp/PrivacyInfo.xcprivacy` and the actual production SDK/service behavior.
- [ ] Health and fitness disclaimer is visible before use and does not imply medical advice.
- [ ] Delete Account is discoverable in-app, calls the backend deletion function, signs the user out, and clears local authenticated data.
- [ ] App Review notes include either reviewer credentials or clear account-creation instructions.
- [ ] Complete the values and reviewer steps in `docs/app-store-launch-metadata.md`; no `REQUIRED_*` placeholders remain.

### Supabase production readiness

- [ ] Production archive points to the production Supabase project, not staging.
- [ ] The iOS app ships only the public anon/publishable Supabase key.
- [ ] RLS/security tests pass against an isolated local or staging database.
- [ ] `profile-avatars` and `lift-videos` storage buckets exist with owner-scoped policies.
- [ ] Migration `202607240002_profile_avatars.sql` is applied to production and its pgTAP contract passes before profile-photo round-trip testing.
- [ ] Completed workout history, editable plans, bodyweight/profile data, legal acceptances, and account deletion round-trip across reinstall/login.
- [ ] Seeded/demo workouts, users, gyms, messages, rankings, and media do not appear for authenticated production accounts.
- [ ] User-facing error states are readable for configuration, permission, network, validation, and server failures.
