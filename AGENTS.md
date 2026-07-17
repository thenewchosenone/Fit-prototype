# LiftRank Repository Rules

- Preserve unrelated and uncommitted work. Never reset, stash, reformat, or include it without explicit instruction.
- Never apply a database migration to a remote project without explicit instruction and environment confirmation.
- PostgreSQL is authoritative for account and shared product data. SwiftData is an offline/local cache.
- Keep networking behind service protocols and DTO-to-domain mapping. Large SwiftUI views must not contain direct backend logic.
- Store canonical weights in kilograms. Convert units only at input and presentation boundaries.
- The server controls verification, ranking eligibility, roles, authority fields, and authoritative timestamps.
- Every RLS, grant, trigger, or security-definer change requires runtime SQL security tests.
- Never expose or ship service-role credentials in a client. The iOS app uses only the public client key under RLS.
- Do not modify an already-applied migration. Add a forward-only correction unless deployment history proves it is unapplied everywhere.
- Security-definer functions must use a fixed search path and fully qualified object names.

