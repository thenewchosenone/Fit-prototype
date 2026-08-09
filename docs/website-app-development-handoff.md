# Lift Rivals website/app handoff

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
- The complete iOS unit test target is green (270 tests), including canonical leaderboard authority, profile parity, workout synchronization, Friends-only visibility, and guarded submission removal.
- The complete database migration and policy suite passes against two fresh databases, including the coordinated-removal finalizer and concurrent gym-membership limits.
- Website validation is green for 15 pages, 6 performance budgets, and 22 parity contracts after both clients switched to the shared removal function.
- The React client in `src/` is a separate browser prototype. Its `store.tsx` state is local/demo-only and must not be used as evidence of native-app synchronization.
- Profile bios are part of the existing `profiles.bio` contract. The iOS domain model, editor, authenticated save/restore path, and public profile display must all retain that value.

## Parity matrix

| Area | Authority | iOS app | Website | Required parity rule |
| --- | --- | --- | --- | --- |
| Identity and bio | `profiles` | Supabase profile service; bio editable/displayed | Authenticated and public profile reads | Same text after save and refresh |
| Training experience | `profile_private_details.years_experience` | Editable years plus separately calculated strength level | Authenticated/public profile context | Years are user profile data; strength level remains calculated |
| Current bodyweight | `profile_private_details.bodyweight_lb` | Profile save/read | Profile read | Current value wins over history |
| Bodyweight history | `bodyweight_records` | Sync and entry writes | Not an account-history UI yet | History never overrides current profile value |
| Privacy | `profile_privacy` | `public`, `friends`, `gym`, and `private` audience controls | Applied to public/account rendering | Same audience semantics; no legacy hide flag may broaden access |
| Gym membership | `gym_memberships` | Join/leave/primary services | Reads primary gym and public gym data | Same active primary membership |
| Workouts | `workout_plan_documents`, `completed_workout_snapshots` | Offline cache plus Supabase synchronization | Reads completed snapshots | Same sessions after refresh; volume excludes warmups/non-weight sets and converts each recorded unit into the workout display unit |
| Lift submissions | `lift_submissions` | Submit/read/update through competition services | Reads owner submissions | Same exercise, result, gym, date, and canonical status (`Self Reported`, `Video Submitted`, `Video Verified`, `Community Verified`, or `Competition Verified`) |
| Submission removal | `remove-lift-submission` Edge Function plus `lift_removal_requests` | Uses the shared function after distinct ordinary/protected confirmation | Uses the same authenticated function and refreshes owner history | One durable, retryable workflow cleans proof, media, moderation, and ranking state before final deletion |
| Lift visibility | `lift_submissions.visibility` | Public, Friends, or Private | Owner history plus server-filtered public records | Friends-only and private lifts never enter public profiles or rankings |
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

## Remaining acceptance work

- Run same-account checks with a Release app build. The website and Release configuration share production project `ikjgbsrlriqiusuvezco`; Debug intentionally uses staging project `dfpvamnucwyafxklnjwt`.
- The production-configured Release simulator build succeeds and reaches sign-in. The acceptance simulator currently has no saved production session, so authenticated comparisons require the same account to be signed in there and on the local website.
- Production public-profile smoke testing passed for the current athlete record: partial-total labeling, four canonical ranking modes, one verified public lift, proof status, and hidden exact bodyweight all rendered without browser errors.
- The production `remove-lift-submission` function and `lift_removal_requests` contract are not deployed yet (the function currently returns not found), so removal acceptance must wait until the migration and function are applied.
- Save a non-empty bio, years-training value, and current bodyweight from a real authenticated iOS session, then refresh the website and confirm exact values.
- Confirm Public, Friends, Gym, and Private profile audiences with accounts that represent each viewer relationship.
- Confirm a Friends-only lift is visible to an accepted friend but absent from anonymous public profiles and canonical public rankings.
- Apply migration `202608080001_coordinated_lift_removal.sql`, deploy `remove-lift-submission`, then acceptance-test evidence-free deletion and protected-record removal without leaving storage, proof, moderation, or ranking orphans.
- Confirm the iOS profile’s canonical global total rank and score match the website for the same account. City, state, and age-group ranks remain links/scopes rather than invented profile values until each canonical scope is fetched.
- Deploy both committed client versions before production acceptance. Local validation alone does not prove production parity.
