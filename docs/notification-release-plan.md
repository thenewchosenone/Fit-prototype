# Notification release plan

Updated November 6, 2026. Local SQL and simulator checks completed; production APNs delivery has not been verified on a physical device.

## Deployed November 6, 2026 — database changes

After explicit production approval, the Supabase plugin applied `202611060001_gym_overtake_notifications.sql` to LiftRank Production (`ikjgbsrlriqiusuvezco`). Supabase recorded it as version `20261106225236`, name `gym_overtake_notifications`. These versions identify the same migration; do not apply the local file again. No other pending migrations were deployed. Production and staging history were inspected before deployment. The eligibility helper matches production’s verified ranking predicate, including its required video asset, rather than the different legacy local review-field predicate.

- Gym-overtake alerts default off. They compare verified single-lift absolute rankings in the recipient's primary gym, age band, and division. Both profiles and comparison fields must be public, proof must satisfy the existing verified ranking rules, and blocked pairs are excluded. Ties and improvements by someone already ahead do not notify. A unique index limits alerts to one per recipient/gym/movement per UTC day.
- Inbox grants explicitly allow authenticated owners to read notifications and update only `read_at` under RLS; clients cannot author or rewrite events.
- The Settings switch is shown only when the backend returns the new preference field. Ranking notification routes preserve gym, age group, division, movement, and verified evidence filters.
- Friend notifications open a Friends screen supporting search, requests, acceptance, and decline. The new relationship-card RPC exposes only a participant's display name and relationship state to the other participant, including when the full profile is private. Blocks hide cards. Renewed requests after decline/cancellation create a new notification.
- Friends activity is visible within Feed. PR cards include exercise, load, reps, caption, and evidence status through the existing RLS-protected lift read; unavailable/private lifts are omitted. Full workout sets remain private.
- Foreground account notifications already refresh the inbox without a banner or sound; rest-timer alerts retain their active-workout behavior. No redundant top-three push was added.

SQL validation: `scripts/test_backend_foundation.sh` passed two clean PostgreSQL 15 resets, including all 35 new notification/privacy assertions. Debug simulator build passed. Three focused unit tests passed (rival matching/privacy and notification routing); the UI test passed for inline Friends PR details and a fully visible, swipeable Home rival carousel. Screenshots were inspected. Tests used mock/demo data and an unsigned artifact at `/tmp/liftrivals-feed-build/Build/Products/Debug-iphonesimulator/LiftRank.app`; no real-account sign-in was tested. Production verification confirmed the default-off preference (zero opted-in accounts), enabled trigger, valid daily-coalescing index, fixed function search paths, and read/mark-read-only inbox grants. Transactional role/RLS probes confirmed empty anonymous-context reads and rejected settings/content writes; no production user rows were changed by these probes. The security advisor added only the expected authenticated SECURITY DEFINER notice for the participant-scoped friend-card RPC; participant/stranger/block tests cover that intentional access. Existing unrelated advisories remain. See [Supabase’s advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Production APNs delivery and the server invocation schedule remain unverified; this migration creates inbox events and does not configure an APNs sender or its schedule.

## What exists

- The Release app registers an APNs token after authentication only when permission already exists. Settings → Notifications → Enable notifications requests permission explicitly; workout/rest reminders request it when first scheduled. Signing configuration, not the Release/Debug label, selects sandbox or production APNs. Token registration failures appear in Settings with Retry.
- The app has an in-app notification inbox and routes workout, lift, ranking, profile, gym, and forum destinations.
- Database triggers create notifications for lift moderation, friend requests, forum replies, and messages. The deployed `send-notifications` Edge Function can deliver pending rows to APNs when called with server credentials.
- The focused launch profile deliberately skips message and forum push delivery. The July production provisioning record says APNs credentials were absent. The current remote secrets and server invocation schedule have not been checked.
- Settings provides separate, default-off account-scoped choices for dated local "Workout today" alerts and next-day "Missed workout" alerts at a user-selected time for unfinished sessions in the active selected plan. The former device-global workout-day opt-in is not inherited because its account owner cannot be established. Both event types share a 48-request cap and refresh on app activity, plan changes, and workout completion. Completed, skipped/rest, queue-based, inactive, and ended plans do not generate future alerts. Legacy repeating weekday requests are removed. Tapping either alert opens Track Today. Denied permission and scheduling failures appear in Settings with Retry. Local missed alerts have not been verified on a signed device; there is no server-side missed-workout sender yet.
- The rest timer schedules a local notification with the system default sound. Its foreground notification respects the iOS sound setting. The tone is cached, uses the ambient audio category to respect silent mode and mix with music, and deactivates its audio session after playback. Local alert bodies omit exercise and program names. Delivered alerts are cleared when account notification state is cleared. Other foreground notifications refresh the inbox without an extra banner or sound.
- Local `send-notifications` source now sends only a generic Lift Rivals update in the visible APNs payload and uses the notification ID as a collapse ID. This coalesces pending retries; it is not proof of exactly-once delivery. The full event remains in the authenticated inbox. These server changes have not been deployed.

## First notifications to ship

Current implementation: rest-complete alerts, local workout-day reminders, and opt-in local next-day missed-workout reminders are in the app. Signed-device delivery, remote missed-workout APNs, and lift-review push delivery remain release gates. Other accountability event preferences are still backlog items.

| Priority | Notification | Trigger and destination | Guardrail |
| --- | --- | --- | --- |
| 1 | Rest complete | Local timer reaches zero; return to the active workout | Test audible behavior with music playing and the app both open and backgrounded. |
| 1 | Workout today | A scheduled session is due; open Track Today | User chooses a reminder time; refresh when the plan changes or a session is recorded. |
| 1 | Missed workout | Yesterday's scheduled session remains incomplete; open Track Today | Send at most once per missed session; skip rest days, completed sessions, and paused plans. |
| 1 | Lift review update | Existing moderation event; open the lift/profile | Only send when the status actually changes. |
| 2 | Friend request or acceptance | Existing relationship event; open the relevant social screen | Fix destination routing before enabling push. |
| 2 | Reply to your post or comment | Existing forum event; open the exact post/comment | Enable only after the forum route and notification preference are verified. |
| 3 | Training milestone | A real completed-workout or verified-lift milestone; open Progress | No generic engagement or streak-pressure messages. |

## Delivery gate for TestFlight

1. On a release-signed physical device, confirm notification permission, an APNs environment matching the actual signing entitlement, token registration, and a non-revoked `device_tokens` row for that account.
2. Confirm APNs key, team ID, key ID, and bundle ID are configured only in the Edge Function environment. Do not put APNs or service-role credentials in the app.
3. Configure and verify a server-side invocation of `send-notifications`; confirm a known pending notification receives `push_sent_at` and appears on the device.
4. Test a denied-permission device, then enable permission in iOS Settings and return to the app. Verify registration retries.
5. Test foreground, background, and music-playing behavior for the rest timer separately from remote push.

## Phase 2 scheduling follow-up

Today offers an optional move action for a missed, untouched session when an unoccupied date remains in its existing program week. It never shifts later weeks, changes completed/started sessions, or moves workouts automatically. The setting is under Notifications. Sessions from an expired program week retain the existing Do this workout today action; a date override across weeks is not implemented.

Local notification delivery, permission denial recovery, and cold-start routing still need a physical-device delivery check. Remote APNs and missed-workout push remain separate release gates.

Verification: GPT-6 Luna ran two focused simulator tests successfully: local reminder date/time and invalid-minute handling; rescheduling availability, intended date after moving, expired cycle, protected session, and queue exclusions. Physical notification delivery remains unverified.
