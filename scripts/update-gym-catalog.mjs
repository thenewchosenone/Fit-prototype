import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { fetchCrunchLocations, fetchLaFitnessLocations, CRUNCH_SOURCE_URL, LA_FITNESS_SOURCE_URL } from "./gym-sources/crunch-la.mjs";
import { fetchEosLocations, fetchYouFitLocations, EOS_SOURCE_URL, YOUFIT_SOURCE_URL } from "./gym-sources/eos-youfit.mjs";
import { fetchAnytimeLocations, fetchGoldsLocations, parseAnytimeDirectoryHtml } from "./gym-sources/anytime-golds.mjs";
import { catalogId, normalizedAddressKey, slug, stateName } from "./gym-sources/normalize.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputPath = resolve(root, "src/gymCatalog.json");
const allowLargeChange = process.argv.includes("--allow-large-change");
const preserveBlockedSource = process.argv.includes("--preserve-blocked-source");
const anytimeHtmlFlag = process.argv.indexOf("--anytime-html");
const anytimeHtmlPath = anytimeHtmlFlag >= 0 ? process.argv[anytimeHtmlFlag + 1] : null;
if (anytimeHtmlFlag >= 0 && !anytimeHtmlPath) throw new Error("--anytime-html requires a file path");
const getAnytimeLocations = anytimeHtmlPath
  ? async () => parseAnytimeDirectoryHtml(await readFile(resolve(anytimeHtmlPath), "utf8"))
  : fetchAnytimeLocations;

const sourceDefinitions = [
  { brand: "Crunch Fitness", url: CRUNCH_SOURCE_URL, fetchLocations: fetchCrunchLocations },
  { brand: "LA Fitness", url: LA_FITNESS_SOURCE_URL, fetchLocations: fetchLaFitnessLocations },
  { brand: "EOS Fitness", url: EOS_SOURCE_URL, fetchLocations: fetchEosLocations },
  { brand: "YouFit", url: YOUFIT_SOURCE_URL, fetchLocations: fetchYouFitLocations },
  { brand: "Anytime Fitness", url: "https://www.anytimefitness.com/locations", fetchLocations: getAnytimeLocations },
  { brand: "Gold's Gym", url: "https://www.goldsgym.com/locations/", fetchLocations: fetchGoldsLocations }
];

function normalizeLocation(location) {
  const normalized = {
    ...location,
    name: location.brand === "Crunch Fitness" && !location.name.startsWith("Crunch Fitness")
      ? `Crunch Fitness - ${location.name}`
      : location.name,
    state: stateName(location.state),
    postalCode: String(location.postalCode).trim(),
    countryCode: "US",
    status: "Open"
  };
  normalized.id = location.brand === "Crunch Fitness"
    ? `gym-${slug(location.name.replace(/^Crunch Fitness\s*-\s*/i, ""))}`
    : catalogId(normalized);
  delete normalized.sourceId;
  return normalized;
}

function validateLocations(locations) {
  const ids = new Set();
  const addresses = new Set();
  for (const gym of locations) {
    for (const field of ["id", "brand", "name", "address", "city", "state", "postalCode", "countryCode", "officialUrl", "status"]) {
      if (!gym[field]) throw new Error(`${gym.brand || "Unknown brand"} has a location missing ${field}`);
    }
    if (gym.countryCode !== "US" || gym.status !== "Open") throw new Error(`${gym.name} is not an open U.S. location`);
    if (!/^https:\/\//.test(gym.officialUrl)) throw new Error(`${gym.name} has an invalid official URL`);
    if (ids.has(gym.id)) throw new Error(`Duplicate gym ID: ${gym.id}`);
    ids.add(gym.id);
    const addressKey = normalizedAddressKey(gym);
    if (addresses.has(addressKey)) throw new Error(`Duplicate gym address: ${gym.name}`);
    addresses.add(addressKey);
  }
}

const previousCatalog = existsSync(outputPath) ? JSON.parse(await readFile(outputPath, "utf8")) : null;
const collected = [];
const sources = [];

for (const source of sourceDefinitions) {
  let locations;
  try {
    locations = await source.fetchLocations();
  } catch (error) {
    const previous = previousCatalog?.gyms?.filter((gym) => gym.brand === source.brand) ?? [];
    if (!preserveBlockedSource || !previous.length) throw error;
    locations = previous;
    console.warn(`${source.brand}: preserving ${previous.length} prior records because refresh failed: ${error.message}`);
  }
  const normalized = locations.map(normalizeLocation);
  const previousCount = previousCatalog?.counts?.[source.brand] ?? 0;
  if (!allowLargeChange && previousCount > 0 && normalized.length < previousCount * 0.85) {
    throw new Error(`${source.brand} dropped from ${previousCount} to ${normalized.length}; rerun with --allow-large-change after verification`);
  }
  collected.push(...normalized);
  sources.push({ brand: source.brand, url: source.url, count: normalized.length });
}

validateLocations(collected);
collected.sort((a, b) => a.state.localeCompare(b.state) || a.city.localeCompare(b.city) || a.brand.localeCompare(b.brand) || a.name.localeCompare(b.name));
const counts = Object.fromEntries(sources.map((source) => [source.brand, source.count]));
const catalog = { generatedAt: new Date().toISOString(), sources, counts, gyms: collected };
await writeFile(outputPath, `${JSON.stringify(catalog, null, 2)}\n`);
console.log(`Wrote ${collected.length} open U.S. gyms to ${outputPath}`);
console.log(counts);
