---
name: Codex Anti-Bloat Guardrails
description: Constraints to keep Codex changes small, direct, and maintainable.
apply_to: "**/*"
---

# Codex Anti-Bloat Guardrails

Keep this codebase lean. Solve the requested problem with the smallest clear change that fits existing architecture.

## Scope Control

- Make the smallest behavior-preserving change that satisfies the request.
- Do not opportunistically refactor, reformat, rename, reorganize, or modernize unrelated code.
- Preserve unrelated and uncommitted work. Never reset, stash, delete, or include it without explicit instruction.
- Avoid speculative engineering. Do not add files, types, interfaces, hooks, protocols, services, or dependencies for imagined future needs.
- Before adding a new file or abstraction, first search for the existing owner. Add the new structure only if it clearly reduces duplication, isolates a real responsibility, or matches an established local pattern.

## Structure

- Prefer existing project patterns over new architectural styles.
- Keep code flat where practical, but do not move backend, networking, persistence, or business logic into large SwiftUI views.
- Do not wrap framework primitives, native APIs, or library types unless the wrapper provides real project-specific behavior.
- Do not add generic managers, factories, helpers, mappers, extensions, or utilities unless there is current repeated use.
- Avoid defensive fallbacks that hide bugs. Propagate, surface, or handle errors through the existing error path.

## Edits

- Use line-level, targeted diffs. Do not rewrite whole files when a small block change is enough.
- Delete code made obsolete by your own change, but only when it is clearly related to the task.
- Never comment out dead code.
- Do not add logging, assertions, mocks, fixtures, sample data, or test scaffolding unless needed to verify the requested behavior.

## Verification

Before finishing, review the diff for:
- unnecessary new files
- unnecessary abstractions
- duplicated logic
- unrelated formatting churn
- hidden fallback behavior
- changes outside the requested scope

In the final response, list any new files, abstractions, or dependencies and briefly justify why each was necessary.

## Lift Rivals Data, Security, And Architecture

- Never apply a database migration to a remote project without explicit instruction and environment confirmation.
- PostgreSQL is authoritative for account and shared product data. SwiftData is an offline/local cache.
- Keep networking behind service protocols and DTO-to-domain mapping. Large SwiftUI views must not contain direct backend logic.
- Store canonical weights in kilograms. Convert units only at input and presentation boundaries.
- The server controls verification, ranking eligibility, roles, authority fields, and authoritative timestamps.
- Every RLS, grant, trigger, or security-definer change requires runtime SQL security tests.
- Never expose or ship service-role credentials in a client. The iOS app uses only the public client key under RLS.
- Do not modify an already-applied migration. Add a forward-only correction unless deployment history proves it is unapplied everywhere.
- Security-definer functions must use a fixed search path and fully qualified object names.
