# Lift Rivals production performance

## Reproduce the local production check

Run `pnpm perf`. It creates a production build with local demo authentication enabled only for the performance lab, serves `dist`, and measures the seven primary routes at 390×844 and 1440×900. Never deploy a build created with `VITE_AUTH_DEMO_MODE=true`.

The automated budgets cover entry JavaScript, Library transfer size, LCP, CLS, and long tasks. Library first load is capped at 250 KB on mobile and 350 KB on desktop; the larger desktop allowance accounts for the additional visible muscle thumbnails requested above the fold. Run mobile Lighthouse against the same local preview for the launch report; local Playwright timings are regression signals, not field Web Vitals.

## Provider-neutral hosting requirements

- Serve fingerprinted `/assets/*` files with Brotli or Gzip and `Cache-Control: public, max-age=31536000, immutable`.
- Serve `index.html` with `Cache-Control: no-cache` so releases are discovered immediately.
- Keep authenticated and user-specific responses private and non-cacheable.
- Enforce HTTPS, HSTS, CSP, `X-Content-Type-Options`, `Referrer-Policy`, and a restrictive Permissions Policy at the hosting layer.
- Preserve hash routes by serving `index.html` at the site root; no server rewrite is required for the current router.
- Monitor real-user LCP, INP, CLS, JavaScript errors, route chunk failures, and Supabase request latency once production telemetry is approved.
