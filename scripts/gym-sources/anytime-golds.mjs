import { cleanText, normalizePostalCode, stateName } from "./normalize.mjs";

const ANYTIME_URL = "https://www.anytimefitness.com/locations";
const GOLDS_URL = "https://www.goldsgym.com/locations/";

function cookieHeader(headers) {
  const values = typeof headers.getSetCookie === "function" ? headers.getSetCookie() : [headers.get("set-cookie")].filter(Boolean);
  return values.map((value) => value.split(";", 1)[0]).join("; ");
}

export function parseAnytimeDirectoryHtml(html) {
  if (/Incapsula|Additional security check is required/i.test(html)) {
    throw new Error("Anytime Fitness blocked the catalog refresh with its security challenge. Run from an approved network or pass an official saved directory page to the parser.");
  }
  const rows = [];
  const rowPattern = /<div[^>]+class="[^"]*(?:location-row|w-dyn-item)[^"]*"[^>]*>([\s\S]*?)<\/div>/gi;
  for (const match of html.matchAll(rowPattern)) {
    const text = cleanText(match[1].replace(/<\/(?:div|span|p|li|td)>/gi, " | ").replace(/<[^>]*>/g, " "));
    const parts = text.split(/\s*\|\s*/).map(cleanText).filter(Boolean);
    const status = /\b(Open|Coming Soon|Pre Sales|Closed)\b/i.exec(text)?.[1] ?? "";
    const postalCode = normalizePostalCode(text);
    const cityStatePart = parts.find((part) => /,\s*(?:[A-Z]{2}|[A-Za-z ]+)(?:\s+\d{5})?$/.test(part)) ?? text;
    const cityState = /([^,|]+),\s*([A-Z]{2}|[A-Za-z ]+?)(?:\s+\d{5})?(?:\s|$)/.exec(cityStatePart);
    const address = parts.find((part) => /^\d/.test(part) && !/^\d{5}(?:-\d{4})?$/.test(part) && !/^\(?\d{3}\)?[\s-]/.test(part))
      ?? /(?:^|\|)\s*(\d[^|]+?)(?:\||$)/.exec(text)?.[1];
    if (!postalCode || !cityState || !address || !/^open$/i.test(status)) continue;
    rows.push({
      brand: "Anytime Fitness",
      name: `Anytime Fitness - ${cleanText(cityState[1])}`,
      address: cleanText(address),
      city: cleanText(cityState[1]),
      state: stateName(cityState[2]),
      postalCode,
      countryCode: "US",
      officialUrl: ANYTIME_URL,
      status: "Open"
    });
  }
  return rows;
}

export async function fetchAnytimeLocations({ fetchImpl = fetch } = {}) {
  const response = await fetchImpl(ANYTIME_URL, { headers: { "user-agent": "Mozilla/5.0 LiftRank catalog refresh" } });
  if (!response.ok) throw new Error(`Anytime Fitness locator returned ${response.status}`);
  const locations = parseAnytimeDirectoryHtml(await response.text());
  if (!locations.length) throw new Error("Anytime Fitness locator returned no open U.S. locations");
  return locations;
}

export function parseGoldsLocations(gyms) {
  if (!Array.isArray(gyms)) throw new TypeError("Gold's Gym response was not an array");
  return gyms
    .filter((gym) => gym.country === "US" && gym.gym_status === "open")
    .map((gym) => ({
      sourceId: String(gym.gym_id),
      brand: "Gold's Gym",
      name: `Gold's Gym - ${cleanText(gym.gym_name || gym.choose_location)}`,
      address: cleanText([gym.address, gym.address_2].filter(Boolean).join(", ")),
      city: cleanText(gym.city),
      state: stateName(gym.state),
      postalCode: normalizePostalCode(gym.zip),
      countryCode: "US",
      officialUrl: `https://www.goldsgym.com/locations/${gym.gym_slug}/`,
      status: "Open"
    }))
    .filter((gym) => gym.sourceId && gym.name && gym.address && gym.city && gym.state && gym.postalCode && gym.officialUrl);
}

export async function fetchGoldsLocations({ fetchImpl = fetch } = {}) {
  const page = await fetchImpl(GOLDS_URL, { headers: { "user-agent": "Mozilla/5.0 LiftRank catalog refresh" } });
  if (!page.ok) throw new Error(`Gold's Gym locator returned ${page.status}`);
  const html = await page.text();
  const nonce = /wpApiSettings\s*=\s*\{[^}]*"nonce":"([^"]+)"/.exec(html)?.[1];
  if (!nonce) throw new Error("Gold's Gym locator did not expose a refresh nonce");
  const headers = {
    "user-agent": "Mozilla/5.0 LiftRank catalog refresh",
    "x-wp-nonce": nonce,
    cookie: cookieHeader(page.headers),
    referer: GOLDS_URL
  };
  const firstResponse = await fetchImpl("https://www.goldsgym.com/wp-json/gg-gym-data/gyms?per_page=100&page=1", { headers });
  if (!firstResponse.ok) throw new Error(`Gold's Gym location endpoint returned ${firstResponse.status}`);
  const pageCount = Number(firstResponse.headers.get("x-wp-totalpages") || 1);
  const gyms = await firstResponse.json();
  for (let pageNumber = 2; pageNumber <= pageCount; pageNumber += 1) {
    const response = await fetchImpl(`https://www.goldsgym.com/wp-json/gg-gym-data/gyms?per_page=100&page=${pageNumber}`, { headers });
    if (!response.ok) throw new Error(`Gold's Gym page ${pageNumber} returned ${response.status}`);
    gyms.push(...await response.json());
  }
  return parseGoldsLocations(gyms);
}
