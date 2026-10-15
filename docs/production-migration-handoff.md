# Production migration handoff

Before enabling account-backed profile photos for production, run the
forward-only migration `supabase/migrations/202607240002_profile_avatars.sql`
against the production project configured for Release builds.

Required evidence after deployment:

1. The `profile-avatars` bucket exists, is private, accepts only JPEG files,
   and has the five megabyte size limit.
2. The pgTAP contract in
   `supabase/tests/202607240002_profile_avatars.test.sql` passes.
3. An authenticated test account can upload and restore its own avatar.
4. A second authenticated account cannot write, update, or delete the first
   account's avatar path.
5. Account deletion removes the account's avatar objects.

Do not apply this migration from an unconfirmed environment. Record the
production project ID, migration version, test run, and round-trip account
test in the release evidence bundle.
