# Lift Rivals iOS release policy

## Versioning

- `MARKETING_VERSION` is the user-visible semantic version. Patch releases fix defects, minor releases add compatible product changes, and major releases may change established behavior.
- `CURRENT_PROJECT_VERSION` is the App Store build number. Increase it for every archive uploaded to App Store Connect; never reuse an uploaded number.
- The current release candidate is `1.0.0 (2)`.

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

- [ ] Full simulator build succeeds with `xcodebuild -project Lift Rivals.xcodeproj -scheme Lift Rivals -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing`.
- [ ] Signup, login, restore session, logout, password reset, onboarding, and legal acceptance complete against staging.
- [ ] Profile photos are account-backed: authenticated profile saves upload image bytes to Supabase Storage before saving the profile draft, `profiles.avatar_path` stores the account path, and login/restore downloads the avatar back into the local cache.
- [ ] Completed workout deletion is account-backed: deleting locally creates a persisted tombstone and the sync service deletes the matching `completed_workout_snapshots` row for the authenticated owner.
- [ ] Bodyweight logs update the bodyweight table and current profile through the same repository upsert path.
- [ ] Awards and PR cards read from completed workouts/lift submissions consistently and do not show demo-only counts for real accounts.
- [ ] Onboarding and Edit Profile map the same identity/body/location fields to the same domain properties.
- [ ] Release builds do not silently enter demo mode when Supabase configuration is missing.
- [ ] No service-role keys, APNs private keys, admin secrets, or personal credentials are present in Xcode settings, Info.plist, app resources, or committed docs.

### App Store compliance

- [ ] Privacy Policy URL is live.
- [ ] Terms of Use URL is live.
- [ ] Support URL is live.
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
