# Lift Rivals website/app handoff

## Synchronization completion plan

| Phase | Outcome | Status | Exit check |
| --- | --- | --- | --- |
| 1. Shared contract | One Supabase authority and matching field/status/privacy meanings | Complete | Parity contracts fail if either client drifts |
| 2. New-account onboarding | Bio, training years, measurements, location, privacy, gym, and starting lifts survive a fresh Release signup | Complete | Same production account matches in app, private website account, and anonymous public profile |
| 3. Training activity | Completed workouts and bodyweight check-ins use the same ownership, unit, volume, and current-vs-history rules | In progress | Create one fresh workout/check-in in the app and compare exact website output |
| 4. Relationship privacy | Public, Friends, Gym, and Private audiences are enforced for representative viewers | Pending | Relationship test accounts see only their authorized fields/lifts |
| 5. Production readiness | Required migrations and both client releases are reviewed, deployed, and smoke-tested | Pending authorization | City IDs resolve, deployed builds pass the same-account checklist, and production has no client-only fallbacks |

Every shared-data defect must be fixed at the common contract/service boundary where possible, then guarded in both clients. Client-specific presentation fixes must add a parity fixture or test so the other client cannot silently diverge later.

## Shared-data contract

- Supabase/PostgreSQL is the source of truth for account, profile, workout, lift, verification, ranking, gym, and privacy data.
- Browser or local app storage is an offline/demo cache only and must never override authenticated server data.
- The current bodyweight shown on an account comes from the profile’s current bodyweight field. Historical bodyweight records are used only for history and charts.
- Public verified lifts, proof links, verified counts, totals, and rank come only from canonical public verified records. A submission being approved is not itself proof that it is public or ranking-eligible.
- The website and app must use the same account identity and field names when shared data is connected.

## Current implementation status

- The website reads authenticated profile, submission, workout, and public-record data from Supabase.
- The website now gives the current profile bodyweight precedence over historical bodyweight records.
- The Swift iOS app in `LiftRankApp/` has Supabase services for authenticated profiles, privacy, bodyweight history, workout plans and completed workouts, gym memberships, lift submissions, public rankings, verification, and media.
- iOS onboarding now captures and saves bio, years training, validated bodyweight, location, privacy, primary gym, and optional starting lifts. Starting lifts are private self-reported actual 1RMs and use retry-safe onboarding markers so a failed retry does not duplicate them.
- The complete iOS unit test target is green (272 tests) and covers canonical leaderboard authority, profile parity, workout synchronization, Friends-only visibility, guarded submission removal, and retry-safe onboarding lift creation.
- The complete database migration and policy suite passes against two fresh databases, including the coordinated-removal finalizer and concurrent gym-membership limits.
- Website validation is green for 15 pages, 8 performance budgets, and 38 parity contracts, including shared removal, protected-record classification, owner-scoped submission history, conservative privacy fallback, current-bodyweight authority, self-reported status mapping, approved lift-video privacy, account-action safeguards, and canonical gym-region mapping.
- Production project `ikjgbsrlriqiusuvezco` has migration `202608080001_coordinated_lift_removal.sql` and the `remove-lift-submission` Edge Function deployed. The live endpoint enforces submission ownership; no real owned lift was removed during acceptance.
- Production migration `202608080002_reassign_seeded_lifts_to_rob.sql` intentionally assigns the six seeded fixture submissions and their related media/removal ownership to Rob's profile. Their verification and public-ranking eligibility are preserved, so the authenticated website correctly shows seven owned submissions after refresh.
- The React client in `src/` is a separate browser prototype. Its `store.tsx` state is local/demo-only and must not be used as evidence of native-app synchronization.
- Profile bios are part of the existing `profiles.bio` contract. The iOS domain model, editor, authenticated save/restore path, and public profile display must all retain that value.

## Parity matrix

| Area | Authority | iOS app | Website | Required parity rule |
| --- | --- | --- | --- | --- |
| Identity and bio | `profiles` | Supabase profile service; bio editable/displayed | Authenticated and public profile reads | Same text after save and refresh |
| Training experience | `profile_private_details.years_experience` | Editable years plus separately calculated strength level | Authenticated/public profile context | Years are user profile data; strength level remains calculated |
| Current bodyweight | `profile_private_details.bodyweight_lb` | Profile save/read | Profile read | Current value wins over history |
| Bodyweight history | `bodyweight_records` | Sync and entry writes | Authenticated account history in the preferred display unit | History never overrides current profile value; stored pounds convert only at the display boundary |
| Privacy | `profile_privacy` | `public`, `friends`, `gym`, and `private` audience controls | Applied to public/account rendering | Same audience semantics; no legacy hide flag may broaden access |
| Gym membership | `gym_memberships` | Home/Me directory, search, join/leave/primary services, and gym-scoped top lifters | Reads primary gym, directory, and gym-scoped public rankings | Same active primary membership, canonical `gyms.region` location, and gym-filtered leaderboard scope |
| Workouts | `workout_plan_documents`, `completed_workout_snapshots` | Offline cache plus Supabase synchronization | Reads completed snapshots | Same sessions after refresh; volume excludes warmups/non-weight sets and converts each recorded unit into the workout display unit |
| Lift submissions | `lift_submissions` | Submit/read/update through competition services | Reads rows constrained to the authenticated owner | Same owner, exercise, result, gym, date, and canonical status (`Self Reported`, `Video Submitted`, `Video Verified`, `Community Verified`, or `Competition Verified`) |
| Submission removal | `remove-lift-submission` Edge Function plus `lift_removal_requests` | Uses the shared function after distinct ordinary/protected confirmation | Uses the same authenticated function and refreshes owner history | One durable, retryable workflow cleans proof, media, moderation, and ranking state before final deletion |
| Lift visibility | `lift_submissions.visibility` | Public, Friends, or Private | Owner history plus server-filtered public records | Friends-only and private lifts never enter public profiles or rankings |
| Approved lift videos | `profile_privacy.show_lift_videos` | Editable in profile and privacy settings | Displayed on the authenticated account; enforced by server-filtered public lifts | The canonical boolean controls whether approved proof videos appear publicly; legacy audience fields are fallback-only |
| Public lifts and proof | Canonical public lift interfaces and media authority | Competition/leaderboard/media services | Public athlete/lift/evidence reads | Only eligible public evidence is counted or linked |
| Rankings and totals | Canonical leaderboard RPCs/views | Supabase leaderboard service | Same leaderboard RPC family | No client-local ranking may be presented as authoritative |
| Local persistence | Device cache/demo data | SwiftData/local snapshots | Browser preview seed data | Must not override newer authenticated server state |

## Acceptance checklist

Before calling the clients synchronized, verify with the same account:

Preflight: run `./scripts/check_client_environment_parity.sh /absolute/path/to/website` and use a Release app build for every production website comparison. Debug intentionally points to staging and cannot prove production parity.

1. Profile bodyweight matches after an app save and website refresh.
2. Profile fields and privacy settings match.
3. Completed workouts appear on the website after app sync.
4. Lift exercise, gym, proof, verification level, and public/ranking eligibility match.
5. Rank, verified-lift count, totals, and weight class are calculated from the same public records.
6. Offline/local cache values do not override newer server values.
7. Bio edits made in the app appear on the website and public profile according to profile visibility.
8. The same verification label and eligibility explanation appears for each lift in both clients.
9. Approved lift-video visibility saved in the app matches the website account and public proof visibility after refresh.
10. Bodyweight check-ins saved in the app appear in website history in the preferred unit without overriding current profile bodyweight.

## Fresh-account production acceptance (2026-08-09)

- A new confirmed production account completed the entire Release-app onboarding flow and reached the signed-in home screen.
- The app saved and the production database retained the same username/display name, non-empty bio, four years training, 187 lb current bodyweight, 70 in height, birth date, Miami/Florida/US location text, and onboarding completion state.
- The default privacy contract persisted: profile/location/gym public, exact bodyweight private, friend list friends-only, and approved lift videos visible when otherwise eligible.
- Four optional starting lifts persisted as private, self-reported, clear-moderation 1RM submissions: bench 225 lb, squat 315 lb, deadlift 405 lb, and overhead press 135 lb. A regression test verifies retries do not create duplicates.
- The app gym directory found and joined Crunch Fitness Brickell and persisted it as the active primary membership. The website displayed the same primary gym.
- The same authenticated website account displayed the exact bio, years training, calculated beginner level, Miami/Florida location, current bodyweight, primary gym, preferred unit, and four owner-scoped lift submissions.
- The anonymous public profile displayed the public bio, gym, location, and calculated experience while correctly hiding exact bodyweight and all four private self-reported lifts.
- Website submission labels now match the app/backend contract: these records display `Self-reported` with the explanation that they are not independently verified, not `Pending review`.
- The fresh account has no completed workouts or bodyweight-history entries yet, so those two data paths remain covered by automated contracts but were not exercised by this new-account manual run.

## Remaining acceptance work

- Production is missing the `public.search_cities` RPC defined by `202607240001_canonical_locations.sql`. The app safely falls back to bundled city text, so Miami/Florida/US syncs, but `profile_private_details.city_id` remains null until that reviewed migration is explicitly authorized and deployed.
- Create one completed workout and one bodyweight-history check-in with the fresh Release-app account, then confirm the exact session, set/volume rules, and history entry on the website.
- Production public-profile smoke testing passed for the current athlete record: partial-total labeling, four canonical ranking modes, one verified public lift, proof status, and hidden exact bodyweight all rendered without browser errors.
- Production migration history confirms `202608080001` and `202608080002` are applied and the `remove-lift-submission` function is live. Owner-guard testing correctly rejected records before reassignment; the six fixture records are now intentionally owned by Rob. Complete the positive-path acceptance with a deliberately created disposable owner submission and verify protected-record cleanup separately.
- Confirm Public, Friends, Gym, and Private profile audiences with accounts that represent each viewer relationship.
- Confirm a Friends-only lift is visible to an accepted friend but absent from anonymous public profiles and canonical public rankings.
- Toggle approved lift-video visibility from an authenticated iOS session, then confirm the website account label and anonymous public proof links update after refresh.
- Acceptance-test evidence-free deletion and protected-record removal with deliberately created disposable owner records, confirming that storage, proof, moderation, and ranking data leave no orphans.
- Confirm the iOS profile’s canonical global total rank and score match the website for the same account. City, state, and age-group ranks remain links/scopes rather than invented profile values until each canonical scope is fetched.
- Deploy both committed client versions before production acceptance. Local validation alone does not prove production parity.
