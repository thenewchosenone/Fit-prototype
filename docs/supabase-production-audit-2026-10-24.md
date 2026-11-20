# Supabase Production audit — October 23–24, 2026

Project: **LiftRank Production**, main, `ikjgbsrlriqiusuvezco`.
The user explicitly approved both Production migrations below after reviewing their scopes.
Existing uncommitted application changes and historical migration files were preserved.

## Repairs deployed

| Finding | Production repair |
| --- | --- |
| `get_profile_cards(uuid[])` was missing. The single-card RPC returned 14 fields, while the repository batch contract expected 16. | Restored the batch RPC and upgraded single-card/search results to include privacy-filtered logged bodyweight and its timestamp. |
| `delete_own_workout_plan(uuid)` and deletion tombstones were missing. | Restored atomic owner-scoped deletion, durable tombstones, idempotent retries, and rejection of stale plan reinserts. |
| The app sends 16 leaderboard arguments, but Production only had the 12-argument RPC. | Added the mobile overload, retaining the installed canonical ranking query and the existing overload. Added exact-repetition, city, experience, and evidence filters. |
| Avatar Storage reads admitted every authenticated account regardless of profile privacy. | Restricted avatar reads through `can_view_profile`. |
| The lift RPC used definer privileges without checking profile visibility. Public discovery views lacked an explicit block filter. | Added canonical profile visibility to lift RPC reads and block filtering to both discovery views, preserving their existing projections and options. |
| Internal `refresh_lift_review_state(uuid)` and trigger helper execution was granted to API clients. | Revoked direct client execution; trusted trigger/RPC execution remains available. |
| Direct authenticated lift-table SELECTs could bypass the profile/privacy checks enforced by the repaired RPC. | Added a restrictive SELECT policy using `can_view_profile(user_id)`, preserving owner/public/accepted-friend access and enforcing blocks. |

Applied forward migrations:

- [`202610230001_restore_mobile_contracts_and_profile_privacy.sql`](../supabase/migrations/202610230001_restore_mobile_contracts_and_profile_privacy.sql)
- [`202610230002_enforce_profile_privacy_on_direct_lift_reads.sql`](../supabase/migrations/202610230002_enforce_profile_privacy_on_direct_lift_reads.sql)

Both were committed transactionally through the Dashboard SQL Editor with bounded lock timeouts, recorded under their unique versions, and followed by a PostgREST schema-cache reload notification. No existing account, workout, lift, or media records were changed by these deployments.

The ledger contains one complete source string for each new migration. Live MD5 comparisons matched the repository files:

| Version | MD5 |
| --- | --- |
| `202610230001` | `a30e33d6785e1ddf50ba040c53ff9e04` |
| `202610230002` | `37e8e4688d854e42657819d31dab9b13` |

The first ledger write for `202610230001` escaped dollar delimiters incorrectly in its stored source string. Verification caught the mismatch; that metadata entry was corrected, and the exact-source check then passed. The executed function definitions were unaffected.

## Validation and limits

The following transactional SQL tests passed in disposable local PostgreSQL 15 databases:

- [`202610230001_restore_mobile_contracts_and_profile_privacy.test.sql`](../supabase/tests/202610230001_restore_mobile_contracts_and_profile_privacy.test.sql): API execution grants, plan ownership/deletion/retries/resurrection, cross-account tombstone isolation, batch ordering/limit, profile and bodyweight privacy, avatar visibility, blocks, and mobile leaderboard filters.
- [`202610230002_enforce_profile_privacy_on_direct_lift_reads.test.sql`](../supabase/tests/202610230002_enforce_profile_privacy_on_direct_lift_reads.test.sql): direct SELECT access for owners, private-profile outsiders, public-profile visitors, accepted friends, and blocked users.

The first suite passed against the full local schema and against a reconstruction of the observed Production drift: missing plan/batch RPCs, the older profile-card result, absent mobile leaderboard overload, broad avatar reads, and the extra `public_lifts.evidence_available` compatibility column. The final run applied both repairs to that reconstructed baseline and passed both suites. Fixture transactions rolled back.

The local schema runner used the repository's existing Auth/Storage bootstrap. It executed duplicate-version files in filename order and added a temporary-only city conflict-target index to work around an existing staging migration incompatibility. Therefore these runs verify runtime SQL behavior, **not** a clean, release-ready migration chain or an exact dump of Production.

Retained local evidence is under `/private/tmp/liftrivals-production-repair-20261023/`: `security-tests-full-schema.log`, `security-tests.log`, `direct-read-tests.log`, and `migrations.log`. The disposable server was stopped after each run; it had TCP listening disabled and never connected to Supabase.

Post-deployment Production verification passed for the first migration's exact source, authenticated RPC execution with an unused audit identity, execution permissions, tombstone RLS, and preservation of the 19-column public lift view. The verification transaction used nonexistent profile/plan/exercise identifiers, inserted no Production fixtures, and rolled back. A final catalog check confirmed the second migration's source hash and restrictive SELECT policy. No audit fixture users were present.

These are SQL and metadata checks. Actual iOS UI flows, authenticated PostgREST HTTP dispatch, signed-media playback, and external Auth/Storage service integrations were not exercised end to end.

## Other live checks

- All **67/67** public tables have RLS enabled after the repair.
- The earlier RPC inventory found 28 of 30 sampled app RPC names. The two missing names are now deployed and execute successfully in the live SQL verification. The leaderboard argument mismatch was separately identified and repaired; presence by name alone is insufficient validation.
- The initial 83 public security-definer functions all had an explicit search path. Anonymous and authenticated roles cannot create objects in `public`.
- Anonymous users cannot SELECT the whole `profile_private_details` table or its birth date, height, or sex-category columns.
- Existing bodyweight and completed-workout policies are owner-scoped. Workout-plan deletion ownership and new tombstone isolation were tested at runtime locally.
- Account integrity counts found zero Auth users missing profiles, privacy rows, or private-details rows. No identifying account data was exported.
- `lift-videos` and `profile-avatars` buckets are private; their configured limits were 524,288,000 and 5,242,880 bytes respectively.

## Open findings

1. **High — no scheduled project backups.** The live Dashboard states that the current Free plan does not include project backups. A recovery plan needs either a user-selected paid backup capability or an independently operated backup/restore process, including separate Storage-object recovery. No billing or backup settings were changed, and no restore was attempted.

2. **High — historical migration chain remains ambiguous.** The repository version gate still fails on duplicate `202610100001` and `202610100002` prefixes. Production recorded `202610100001` as `profile_training_goals_permissions`, while the same-numbered plan-deletion implementation was absent. The new unique repair restores the required behavior without falsifying earlier ledger entries. Other earlier/later versions remain unrecorded; a high recorded version does not mean the intervening migrations were applied. Audit all deployed environments before renaming/removing historical files or bulk-pushing the chain. Older overlapping CREATE statements may conflict with the repaired objects.

3. **Medium — legacy public media can bypass later access changes.** `lift-evidence` is public and empty; `lift-evidence-approved` is public and contains one object. No counted object belonged to a profile currently marked nonpublic, based on Storage owner metadata. Public object delivery cannot enforce a later profile/block change. Object bytes and consuming legacy clients were not inspected. Moving that media to private delivery requires a separate compatibility plan; bucket settings were preserved.

4. **Medium — lift response projection needs review.** `get_visible_lift_submissions` serializes the visible lift row with `to_jsonb(l)` and masks bodyweight fields. It still includes columns outside the mobile DTO, such as review metadata and pending evidence paths. An explicit owner/public projection would reduce accidental disclosure. No actual review-note or evidence content was inspected during this audit.

5. **Traceability — the earlier manual `202610190004` entry remains historical evidence debt.** It has an empty statements array and was applied with an extra Production view column preserved. This audit did not fabricate a historical SQL body or rewrite the already-applied migration file. The two new forward migrations have complete, hash-verified source records; the earlier manual deployment remains documented in the chat and this report.

No new dependencies or application abstractions were introduced. New files are limited to the two forward migrations, their required runtime security tests, and this audit record.
