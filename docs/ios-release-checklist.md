# LiftRank iOS release policy

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
