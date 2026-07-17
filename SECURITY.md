# LiftRank security setup

The iOS/backend ownership model, local migration tests, and configuration instructions are documented in [`docs/backend-foundation.md`](docs/backend-foundation.md). Never place a service-role credential in either client.

LiftRank supports Supabase email/password authentication with PKCE. The local development app falls back to an explicitly labeled seeded demo identity when Supabase variables are absent. Production builds do not enable that fallback unless `VITE_AUTH_DEMO_MODE=true` is deliberately supplied.

The shareable public demo is a separate static sandbox selected by `VITE_PUBLIC_DEMO=true`. It uses the seeded identity and browser-local data, hides real account flows, and fails its build if any Supabase credential is present. This exception is limited to the clearly labeled `pages.dev` demo and must not be reused for the closed beta or production application.

## Activate authentication

1. Create a Supabase project and copy `.env.example` to `.env.local`.
2. Set `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_AUTH_DEMO_MODE=false`.
3. Apply `supabase/migrations/202607120001_security_foundation.sql` through the Supabase CLI or SQL editor.
4. In Supabase Auth, enable email confirmation and configure the production site URL plus `/reset-password` redirect URL.
5. Never expose the Supabase service-role key in Vite variables or browser code.

## Security boundary

- Public exercise and gym catalogs remain bundled application data.
- Authenticated data belongs in PostgreSQL and must be accessed under Row Level Security.
- Role, credential, ban, report-resolution, thread-creation, and moderation mutations should be implemented as audited Supabase Edge Functions using the service role.
- `src/store.tsx` remains the local prototype data path until each feature repository is migrated. Do not treat its localStorage permissions or privacy labels as a production security boundary.

## Production checklist

- Set `VITE_AUTH_DEMO_MODE=false` and verify protected routes reject guests.
- Configure HTTPS, HSTS, CSP, `X-Content-Type-Options`, `Referrer-Policy`, and a restrictive Permissions Policy at the hosting layer.
- Configure rate limits/CAPTCHA for authentication, posting, messaging, and reporting.
- Run RLS tests with anon, member, moderator, and admin JWTs before deploying.
- Add Edge Functions for moderation, role changes, message-thread creation, account export/deletion, and global session revocation.
