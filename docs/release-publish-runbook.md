# Lift Rivals Publish Readiness Runbook

_Last updated: July 23, 2026_

## 1) Release track and ownership (weekly cadence)

Run a publish dry run every Monday before any new release branch freeze.

- **Release Lead**: gate orchestration, evidence bundle, freeze/release notes
- **iOS QA Lead**: simulator/device matrix, UI pass, packaging
- **Web QA Lead**: web/build/perf/e2e smoke and auth-route checks
- **Backend & Security Lead**: SQL/RLS/security checks, privacy/compliance gates
- **Ops/Tools Lead**: App Store Connect staging, cert/provisioning, APNs/audit artifacts

## 2) Standard release branch flow

1. Freeze features on current integration branch
2. Run local release gates:
   - `./scripts/release-gates.sh`
3. Push release branch and run CI on matching environments
4. Open evidence bundle and sign-off checklist
5. Run two-account staging rehearsal with real accounts (manual)
6. Run physical-device pass and TestFlight upload verification

## 3) Automated gate command set

### 3a) Service readiness preflight (Step #1)

Run before local gates each release cycle:

- `./scripts/check_publish_readiness_services.sh`

This script validates in-repo configuration for:
- Apple Sign in with Apple entitlement wiring
- APNs entitlement and environment settings
- auth callback path handling
- production mail/notification function prerequisites (requires manual confirmation where secrets are intentionally environment-only)

When run via `./scripts/release-gates.sh`, the output is captured as:
- `release-evidence/<RUN_ID>/ios-services-readiness.log`
- `release-evidence/<RUN_ID>/release-evidence.md` (summary entry)

If `LIFTRANK_SERVICE_CHECK_STRICT=1`, warning-level findings will fail the script.

### Baseline web commands (required)

- `pnpm test`
- `pnpm test:e2e`
- `pnpm test:demo`
- `pnpm perf`
- `pnpm build`
- `pnpm test:release-routes`

### iOS gates (best-effort local)

1. Unit suite on oldest supported iOS simulator
2. Unit suite on latest supported iOS simulator
3. UI suite on oldest supported iOS simulator
4. UI suite on latest supported iOS simulator
5. Unsigned Release build validation

### Backend/security gates

- `./scripts/test_backend_foundation.sh`
  - run twice (two clean resets)
- SQL migration chain checks in isolated environments
- RLS and security policy spot-checks tied to auth/session routes

### Feature and evidence flags

All gate output writes to `release-evidence/<RUN_ID>/`:

- `release-evidence.md`: human-readable evidence notes
- `summary.txt`: step|status|log
- `<step>.log`: command output for each step

## 4) Gating environment variables

- `RUN_WEB_FRONTEND_GATES` (default `1`)
- `RUN_IOS_GATES` (default `1`)
- `RUN_BACKEND_GATES` (default `1`)
- `RELEASE_GATES_STRICT` (`1` to enforce hard-fail semantics)
- `IOS_OLDEST_SIMULATOR_DESTINATION` (default iPhone 15, iOS 17.0; set to an installed simulator matching the minimum supported iOS version)
- `IOS_LATEST_SIMULATOR_DESTINATION` (default iPhone 17 Pro Max)
- `LIFTRANK_RELEASE_REPORT_DIR` (optional output root)
- `LIFTRANK_RELEASE_RUN_ID` (optional identifier)
- `LIFTRANK_RELEASE_COMMAND_TIMEOUT` (command timeout control)

The `ios.release_unsigned_simulator_build` gate disables code signing and only checks that a Release-configuration simulator build succeeds. It is not an archive, distribution-signing, entitlement, or provisioning-profile validation. Complete and record a separately signed archive/export validation before App Store release.

## 5) Remaining/remaining blockers (to be filled before publish)

- **Service gate outcome checklist**
  - Apple Sign in with Apple enabled for production App ID and associated services.
  - Push Notifications entitlement and production signing profile verified.
  - `send-notifications` function has APNs secrets and returns successful delivery updates in production.
  - Supabase Auth custom email is switched to production SMTP and validated with recovery + signup load traffic.
  - End-to-end Sign in with Apple, signup, password recovery, and account unlink flows validated on both small/large physical devices.

- Sign in with Apple + entitlement end-to-end behavior
- APNs key/bundle setup and production token lifecycle
- SMTP production throughput verification for auth emails
- Two-account rehearsal of signup/onboarding/lift flow/report/block/delete
- Legal/privacy/accessibility final review and App Store metadata
- Physical-device short/large screens smoke passes
- TestFlight and Organizer validation

## 6) Incident response and recovery (draft — not launch-ready)

This section is a response checklist, not evidence that monitoring, backups, or rollback have been configured or rehearsed. Do not use it to perform a production restore until the project identity, recovery point, approval, and restore procedure have been verified by the release owner.

### Recovery scope and provider limitations

Treat recovery as a multi-service operation, not a database-only restore. Supabase database backups include Storage metadata but **not the uploaded object bytes**; a restored database can therefore contain `lift-videos` or `profile-avatars` references whose objects are unavailable. Maintain and test an independent, access-controlled copy/recovery procedure for required Storage objects and bucket configuration. A restore to a new Supabase project also requires manual recovery of Storage objects/settings, Edge Functions, Auth settings/API keys, Realtime settings, and database extensions/settings ([Database Backups](https://supabase.com/docs/guides/platform/backups), [Restore to a new project](https://supabase.com/docs/guides/platform/clone-project)).

Before a physical clone is used for recovery or analysis, isolate its outbound network/integrations: Supabase documents that restored `pg_cron`, webhook triggers, or wrappers can start running as soon as the restore completes. Prefer a logical restore where those definitions must be inspected before execution. Confirm the current project’s actual backup/PITR availability, retention, restore permissions, and billing in the Dashboard; do not infer them from plan assumptions. PITR is a paid add-on and requires at least a Small compute add-on according to the current [PITR documentation](https://supabase.com/docs/guides/platform/backups#point-in-time-recovery).

### Declare and contain

1. Record the incident start time (UTC), affected app build/revision, environment/project, symptoms, and the first known-good observation. Do not include passwords, tokens, private user content, or raw personal data in the incident log.
2. Assign an incident lead and a technical owner; record the approved contact/escalation route before release.
3. Pause further release promotion using the currently verified App Store Connect/TestFlight process. Do not assume an already-installed iOS app can be downgraded.
4. If a server feature flag or provider control is proposed as containment, first confirm it exists, its blast radius, and the exact reversal path. Otherwise prefer a tested forward fix; do not improvise production SQL, migration rollback, or data deletion.
5. Preserve relevant redacted app, Edge Function, Auth, and database logs with timestamps and request/event identifiers. Restrict access and follow the retention policy.

### Restore or roll forward

1. Confirm the target project using its recorded provider project reference and environment label; a project name alone is insufficient. Require a second-person confirmation before any production recovery action.
2. For suspected data loss/corruption, record the affected tables/users/time range and agree on the recovery point and expected data loss with the incident lead. Confirm the actual backup/PITR availability, retention, and provider restore semantics in the dashboard before acting.
3. Restore only into an isolated recovery project first. Validate schema/migration history, account isolation, representative user records, storage-object references, and core signup/workout/lift journeys. Compare the result to the incident’s agreed recovery point.
4. Do not point clients at the recovery project or overwrite production until the release owner approves the cutover plan, rollback path, and user-impact communication. Never run a destructive restore or migration reversal from this checklist alone.
5. For an application-only incident, verify the candidate fix against staging, the release gate, and the affected core journey; then promote through the normal signed-build/review path.

### Close and learn

- Record containment, recovery/cutover decisions, evidence locations, user impact, data gaps, and follow-up owners without copying unnecessary personal data.
- Confirm the affected alert is resolved, the recovery target is stable, and customer-support guidance is current before closing the incident.
- Schedule a post-incident review and update this runbook with the exact tested provider actions and evidence.

### Required before this becomes operational

- [ ] Named incident lead/on-call contact and escalation route.
- [ ] Verified production and staging provider project references; two-person production-action approval.
- [ ] Crash/error alert source, threshold, recipient route, and a successful test alert.
- [ ] Backup/PITR configuration, retention, restore permissions, and provider-specific restore instructions.
- [ ] Agreed recovery-point and recovery-time objectives (RPO/RTO), including storage/media recovery semantics.
- [ ] Isolated restore rehearsal with date, source backup point, validation results, elapsed time, and evidence link.
- [ ] App Store Connect/TestFlight containment and promotion-reversal rehearsal, including limitations for already-installed builds.
- [ ] Named owner and current evidence bundle for the above checks.

Until these items have current evidence, monitoring, incident response, backup restoration, and rollback remain release blockers; this draft does not satisfy the release checklist’s “ready” criterion.

### Recovery rehearsal evidence record (blank template)

Copy this record for each isolated rehearsal. Store evidence in the restricted release evidence location; record references rather than credentials, tokens, user data, or backup contents here. A completed record documents a rehearsal only—it does not authorize a production restore.

- Rehearsal date/time (UTC):
- Incident/rehearsal owner and second reviewer:
- Environment label and provider project reference (non-secret):
- Service/data scope, including database and media/storage dependencies:
- Provider-confirmed backup/PITR source and recovery timestamp:
- Provider-confirmed retention and restore permissions:
- Approved RPO / expected data-loss window:
- Approved RTO:
- Isolated recovery target and isolation check:
- Restore start/end time (UTC) and elapsed time:
- Schema/migration-history validation result:
- Account-isolation and representative-record validation result:
- Storage-object/reference validation result:
- Signup, workout, and lift journey validation result:
- Application promotion/reversal or database cutover steps exercised:
- Deviations, data gaps, and follow-up owners:
- Evidence bundle reference and access classification:
- Reviewer sign-off and date:
- Isolated recovery data cleanup/retention decision:
