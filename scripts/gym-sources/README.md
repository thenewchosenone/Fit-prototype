# Gym catalog refresh

Run `pnpm gyms:update` to rebuild `src/gymCatalog.json` from 15 complete first-party brand sources. The refresh includes only open United States locations with a source ID, full address, and official URL. It fails instead of writing a partial brand when pagination, detail enrichment, required fields, or first-run minimum counts do not validate. It also stops when an established source unexpectedly drops by more than 15 percent.

- `--allow-large-change` accepts a reviewed large removal, but never bypasses a source's completeness minimum.
- `--preserve-blocked-source` keeps a previously validated brand when its official source is temporarily unavailable.

The current adapters cover Crunch Fitness, 24 Hour Fitness, LA Fitness, Esporta Fitness, EOS Fitness, VASA Fitness, YouFit, Anytime Fitness, Gold's Gym, Life Time, Workout Anytime, Onelife Fitness, The Edge Fitness Clubs, Orangetheory, and UFC GYM.

## Deferred official-source audit

These chains are intentionally absent. Their current public sources do not yet support a repeatable complete open-location import without inference:

- Planet Fitness: the complete directory is Cloudflare-gated and requires a recursive crawl whose full open-status set could not be verified.
- YMCA: the official directory mixes facilities and associations and exposes no reliable gym/open status.
- Chuze Fitness: the complete inline locator payload is Cloudflare-gated to browser sessions.
- Retro Fitness, Snap Fitness, Genesis Health Clubs, and In-Shape Family Fitness: their complete published directories expose no operational-status field.
- F45 Training: two official U.S. records lack usable structured branch address data; accepting free-text recovery would make the import inconsistent.
- Burn Boot Camp: branch pages identify coming-soon sites, but treating every unlabeled site as open would be an inference.

Source parser tests run as part of `pnpm test`. The generated catalog records the refresh time, official source URLs, and per-brand counts. Location records never contain generated Lift Rivals activity.
