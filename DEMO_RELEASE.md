# Lift Rivals public demo release

This environment is an interactive sandbox. It must never be configured with Supabase credentials or presented as the production Lift Rivals account system.

## Local release gate

```sh
pnpm test
pnpm test:e2e
pnpm test:demo
pnpm perf
pnpm build
```

`pnpm test:demo` and `pnpm perf` create temporary public-demo builds. Always finish the release gate with the normal `pnpm build` command so `dist` is not left in demo-auth mode.

Every build removes the previous `dist` first. If environment validation or compilation fails, there is no stale directory available to deploy accidentally.

## Cloudflare Pages settings

- Git repository: `thenewchosenone/Fit-prototype`
- Project name: `LiftRivals-demo`
- Production branch: `codex/public-demo`
- Framework preset: React (Vite), or no preset with the same values below
- Build command: `pnpm build`
- Build output: `dist`
- Root directory: repository root
- Build system: v3
- Node: `22.16.0`, pinned in `.nvmrc`
- pnpm: `11.7.0`, pinned in `package.json`

Production environment variables:

```text
VITE_PUBLIC_DEMO=true
VITE_AUTH_DEMO_MODE=true
```

Do not define `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, or any service-role credential. The build deliberately fails when public-demo mode detects a Supabase variable.

The generated `public/_headers` file configures immutable assets, HTML revalidation, CSP, HSTS, privacy headers, frame protection, and search-engine exclusion. Cloudflare Pages supplies HTTPS and Brotli/Gzip. Hash routing does not require a rewrite file.

## Acceptance after deploy

1. Open the generated `pages.dev` URL in a clean browser and confirm the welcome panel identifies the sandbox.
2. Exercise all seven primary routes, mutate local demo data, reset it, and confirm the seeded state returns.
3. Confirm login routes redirect, logout is absent, and the network log contains no Supabase request.
4. Inspect response headers on `/`, `/index.html`, and one hashed `/assets/` file.
5. Run Lighthouse mobile and require Performance at least 90, LCP at most 2.5 seconds, and CLS at most 0.1.
6. Validate the 1200×630 share card, favicon, legal pages, and GitHub feedback link.

Cloudflare references: [Git integration](https://developers.cloudflare.com/pages/get-started/git-integration/), [build configuration](https://developers.cloudflare.com/pages/configuration/build-configuration/), [headers](https://developers.cloudflare.com/pages/configuration/headers/), and [serving Pages](https://developers.cloudflare.com/pages/configuration/serving-pages/).
