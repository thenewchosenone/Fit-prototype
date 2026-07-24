# LiftRank Architecture (Refactor-then-Condense)

## Ownership rules

- `LiftRankApp/Features/*`
  - Owns feature UI, feature-local orchestration, and feature-specific state adapters.
  - Feature files may call store/view-model APIs, but must not perform network calls directly.
- `LiftRankApp/Services/*`
  - Owns orchestration of networking, authentication, session coordination, and DTO↔domain mapping.
  - `ServiceProtocols` and `AppServiceContainer` are stable boundaries and should not change unless all call sites are migrated intentionally.
- `LiftRankApp/Domain/*`
  - Owns pure business rules, calculations, ranking/formatting/domain logic, and shared model semantics.
  - Types should be grouped by concept (competition, community, workouts, identity/session, notifications).
- `LiftRankApp/Data/*`
  - Owns repository implementations (Demo + Supabase).
  - Repositories map transport payloads into domain models.
- `LiftRankApp/ViewModels/*`
  - Owns lightweight selection/orchestration state between features, app screens, and repositories.

## "Where this belongs" checklist

- If a change requires API calls (`insert`, `fetch`, `submit`, `delete`, `update`) → move to `Services/*` or `Data/*`.
- If a change is pure logic (formatting, ranking math, validation, score calculation) → move to `Domain/*` or `Core/DesignSystem/*`.
- If a change controls user-visible flow/screen sections → move to `Features/*`.
- If a type is global reusable model/state across repo → place in `Domain/*` (not in views/stores).
- Root `Views/*` should stay shell/entry-level and delegate feature work to `Features/*`.
- Shell `Views/*` entry points may contain local state and navigation only; no service orchestration or repository calls.
- Avoid adding logic to `DomainModels.swift` except minimal legacy constants/aliases still required by existing code.
