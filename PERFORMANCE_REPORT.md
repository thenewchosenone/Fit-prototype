# Lift Rivals client performance report

Measured July 13, 2026 against the local Vite production preview. Transfer values are encoded response bytes; local Playwright timings are regression diagnostics and Lighthouse uses its standard simulated mobile environment.

## Architecture and data flow

- React 18 + Vite single-page application using hash routes.
- A reducer-backed tracker context hydrates compatible user state from `localStorage` under the existing storage key. The static catalog is never persisted.
- Supabase remains authentication-only. There are no application data APIs or runtime location requests.
- The entry bundle contains authentication, navigation, shared state, Leaderboards, and Library. The other primary feature pages load from a shared route chunk.
- Initial state contains nine compact gym records required by seeded profiles, memberships, submissions, and leaderboard context. Gyms, Gym Detail, and Settings dynamically load and session-cache the validated complete catalog.
- Production hosting remains provider-neutral. Required caching, compression, HTTPS, headers, and hash-route behavior are documented in `PERFORMANCE.md`.

## Baseline versus final

| Metric | Baseline | Final | Change |
| --- | ---: | ---: | ---: |
| Entry JavaScript, compressed | 180.4 KB | 104.8 KB | -41.9% |
| Entry JavaScript, raw | 799.0 KB | 337.5 KB | -57.8% |
| Typical non-gym route transfer | ~195.6 KB | 118.7–131.9 KB | -32.6% to -39.3% |
| Mobile Library first load | ~554.0 KB | 147.8 KB | -73.3% |
| Complete gym catalog in initial route | 69.9 KB compressed | 0 KB | removed |
| Gym catalog dynamic chunk | n/a | 66.8 KB compressed | route-only |
| Muscle image set | 1,796 KB PNG | 295 KB AVIF | -83.6% for modern browsers |
| CSS, compressed | 13.7 KB | 13.9 KB | effectively unchanged |
| Mobile Library document height | ~89,000 px | ~79,100 px intrinsic layout | -11.1% |
| CLS | 0 | 0 | unchanged |
| Longest observed application task | 0 ms baseline sample | 111 ms final sample | below 200 ms budget |

The Library still renders all 268 current exercises and roughly 5,552 DOM nodes. `content-visibility` intentionally reduces offscreen image/layout work rather than changing “show all” or virtualizing the list. A controlled removal increased desktop first-load transfer from 326.7 KB to 385.1 KB and caused an extra mobile image request, so it was retained.

## Production harness results

| Route | Mobile transfer | Desktop transfer | Local LCP mobile | Local LCP desktop | CLS | Longest task |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Leaderboards | 118.7 KB | 118.7 KB | 88 ms | 176 ms | 0 | 0 ms |
| Submit | 131.9 KB | 131.9 KB | 368 ms | 400 ms | 0 | 0 ms |
| Library | 147.8 KB | 326.7 KB | 96 ms | 164 ms | 0 | 111 ms |
| Gyms | 199.0 KB | 199.0 KB | 412 ms | 432 ms | 0 | 0 ms |
| Community | 131.9 KB | 131.9 KB | 376 ms | 384 ms | 0 | 0 ms |
| Messages | 131.9 KB | 131.9 KB | 376 ms | 384 ms | 0 | 0 ms |
| Profile | 131.9 KB | 131.9 KB | 384 ms | 388 ms | 0 | 0 ms |

All automated budgets pass. The desktop Library allowance is 350 KB because a 1440 px viewport intentionally requests seven visible AVIF thumbnails; mobile remains capped at 250 KB.

## Lighthouse mobile results

| Route | Performance | LCP | CLS | Total blocking time |
| --- | ---: | ---: | ---: | ---: |
| Leaderboards | 99 | 1.66 s | 0 | 38 ms |
| Submit | 99 | 1.82 s | 0 | 0 ms |
| Library | 99 | 1.73 s | 0 | 44 ms |
| Gyms | 97 | 2.41 s | 0 | 6 ms |
| Community | 99 | 1.82 s | 0 | 0 ms |
| Messages | 99 | 1.81 s | 0 | 0 ms |
| Profile | 99 | 1.80 s | 0 | 0 ms |

Navigation-only Lighthouse runs do not produce an INP value. INP must be monitored with approved production real-user telemetry; the local interaction suite, long-task observer, and total-blocking-time results provide pre-launch regression coverage.

## Changes and tradeoffs

- Added accessible route loading and recovery UI, plus lazy feature-page delivery.
- Added atomic, retryable gym-catalog hydration with membership reconciliation only after successful loading.
- Added ten hashed AVIF assets with PNG fallbacks, intrinsic dimensions, async decoding, and lazy loading.
- Memoized Library filtering, gym filtering/sorting, global-search indexing, and community score/comment maps.
- Added production-only Playwright performance configuration and mobile/desktop budgets.
- Kept shared CSS because route splitting would not save the required 10 KB compressed.
- Kept the current reducer and persistence architecture, URLs, authentication behavior, and provider neutrality.
- Leaderboards and Library remain in the entry module because extracting them from the existing monolithic component file did not provide a demonstrated first-route transfer win in this pass. The remaining feature routes share one cached 13.2 KB compressed route chunk.
- PNG fallbacks remain in the deployment for older browsers, increasing stored build size but not modern-browser transfer.

## Verification

- `pnpm test`: 68 Vitest tests and 10 gym-source parser tests passed.
- `pnpm test:e2e`: 21 tests passed across 390 px, 768 px, and 1440 px widths.
- `pnpm perf`: both production performance projects passed.
- `pnpm build`: production build passed.
- Visual comparison covered every PNG/AVIF muscle pair; browser inspection found no warnings, errors, overflow, or broken Library navigation.

## Remaining bottlenecks and monitoring

- Gyms is the slowest Lighthouse route because it intentionally downloads and parses the full directory on first visit. A future launch phase could move directory querying behind a backend without changing this client snapshot strategy now.
- The Library preserves all cards in the DOM for browser search and accessibility; virtualization remains intentionally deferred.
- Monitor route-chunk failures, catalog load failures, authentication latency, LCP, INP, CLS, JavaScript errors, and cache hit ratios after production telemetry is approved.
