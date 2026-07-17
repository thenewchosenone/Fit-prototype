# LiftRank Backend Foundation

## Architecture

Supabase Auth owns account identity. PostgreSQL owns profiles, privacy, gyms, memberships, friendships, and the shared exercise catalog. Row-level security (RLS) limits readable rows, while secured database functions perform sensitive mutations using the caller's Auth identity.

The iOS app uses `supabase-swift` 2.51.0 behind service protocols. Database DTOs map into existing domain models; SwiftUI does not call the SDK directly. SwiftData and `DemoRepository` remain local stores, not account authorities.

## Migration sequence

1. `202607120001_security_foundation.sql` — preserved historical prototype schema.
2. `202607140001_identity_social_foundation.sql` — forward identity/social correction, private details, privacy, canonical gyms/memberships/friendships, secured mutations, and transactional profile save.
3. `202607140002_exercise_catalog.sql` — versioned exercise IDs, aliases, ranking mappings, read-only client catalog, and retired-history resolution.

Never edit a migration after it has been applied outside a disposable environment. Use a forward correction.

## Local SQL validation

The runner creates and destroys databases only in its temporary local PostgreSQL cluster:

```sh
./scripts/test_backend_foundation.sh
```

It requires PostgreSQL 15+ development binaries, `/usr/bin/perl`, `make`, and network access for pgTAP 1.3.4. Override the PostgreSQL location with `LIFTRANK_POSTGRES_ROOT`.

Each of two clean resets runs 64 identity/social assertions, 20 exercise assertions, and 4 independent-connection concurrency assertions. A rejected competing fourth-gym join is an expected logged error.

## iOS configuration

Never commit credentials. Add these environment variables to the LiftRank Run scheme:

- `LIFTRANK_SUPABASE_URL`
- `LIFTRANK_SUPABASE_ANON_KEY`

They can alternatively be supplied as Xcode build settings for generated Info.plist entries. Use only the public client key, never a service-role key. Hosted endpoints require HTTPS; HTTP is accepted only for localhost development.

Missing configuration shows a setup-required screen and never silently enters demo mode. Demo mode is an explicit, isolated choice.

## Account flow

1. Launch restores the Supabase Auth session.
2. No session routes to Sign In/Create Account.
3. Signup creates a minimal profile through the Auth trigger.
4. An incomplete profile routes to onboarding.
5. Onboarding claims a username and calls `save_own_profile`, saving profile, private details, privacy, and completion together.
6. Gym and friendship actions call secured functions; caller identity comes from `auth.uid()`.
7. Other-user identity comes from `get_profile_card`, which applies field privacy and never returns birth date.

Workout, lift, leaderboard, forum, and messaging synchronization are out of scope. Existing local screens are not remotely synchronized account data.

## Exercise identity

Canonical IDs are lowercase hyphenated strings and do not change with display names. Exercise identity is separate from ranking movement. Conventional and sumo deadlifts are separate exercises mapping to `deadlift`; incline bench does not map to competition bench.

`docs/exercise-identifier-reconciliation.csv` contains 478 inspected iOS/web identifiers. Regenerate it with:

```sh
python3 scripts/reconcile_exercises.py
```

Rows with `seeded_in_migration_2=no` remain reviewed local catalog candidates. They are not silently assigned unsafe competitive identities.

## Ownership and security

- Exact birth dates and private details are owner-only.
- Anonymous users cannot browse beta profiles, memberships, relationships, or exercises.
- Users cannot directly mutate memberships or relationship state.
- Gym joins serialize per profile, preventing concurrent bypass of the three-gym limit.
- Profile timestamps, roles, gym verification, and catalog writes are server controlled.
- Passwords, tokens, Auth payloads, and configuration values must never be logged.

## Known limitations

Migrations and RLS are runtime-tested in disposable PostgreSQL. This machine does not have a full local Supabase Auth/PostgREST stack, so real GoTrue signup, email confirmation, SDK session persistence, and PostgREST serialization remain unverified end to end. Unit tests cover account routing and service boundaries using deterministic doubles.

The initial remote exercise seed contains shared/core identities. The full reconciliation report intentionally leaves non-core variations for a later reviewed catalog expansion.

## Troubleshooting

- **Configuration required:** provide both iOS environment values.
- **Permission denied:** verify a session and migration order; do not bypass RLS.
- **Username unavailable:** choose another lowercase 3–24 character username.
- **Fourth gym rejected:** expected server enforcement.
- **Primary gym cannot be left:** choose another joined gym as primary first.

## Next recommended phase

Add dated bodyweight records, completed-workout synchronization, canonical exercise linking for workout snapshots, and an explicit offline-conflict policy. Verification and rankings should follow authoritative records.

