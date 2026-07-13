# Gym catalog refresh

Run `pnpm gyms:update` to rebuild `src/gymCatalog.json` from the six official brand locators. The command includes only complete, open United States locations and stops when a source unexpectedly drops by more than 15 percent.

- `--allow-large-change` accepts a reviewed large removal.
- `--preserve-blocked-source` keeps the previous records for a temporarily unavailable locator.
- `--anytime-html <path>` parses an official Anytime Fitness directory page saved after its human security check.

Source parser tests run as part of `pnpm test`. The generated catalog records the refresh time, official source URLs, and per-brand counts. Location records never contain generated LiftRank activity.
