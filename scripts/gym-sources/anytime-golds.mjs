import { cleanText, normalizePostalCode, stateName } from "./normalize.mjs";

export const ANYTIME_SOURCE_URL = "https://react.anytimefitness.com/api/locations/?country=usa";
const ANYTIME_DIRECTORY_URL = "https://www.anytimefitness.com/locations";
const GOLDS_URL = "https://www.goldsgym.com/locations/";

function cookieHeader(headers) {
  const values = typeof headers.getSetCookie === "function" ? headers.getSetCookie() : [headers.get("set-cookie")].filter(Boolean);
  return values.map((value) => value.split(";", 1)[0]).join("; ");
}

export function parseAnytimeLocations(payload) {
  const locations = Array.isArray(payload) ? payload : payload?.items;
  if (!Array.isArray(locations)) {
    throw new TypeError("Anytime Fitness response did not contain an items array");
  }

  return locations
    .filter((location) => location?.status === "OPEN" && location?.address?.country_abbr === "USA")
    .map((location) => {
      const address = location.address;
      return {
        sourceId: cleanText(location.id || location.location_id),
        brand: "Anytime Fitness",
        name: `Anytime Fitness - ${cleanText(location.name)}`,
        address: [address.address1, address.address2].map(cleanText).filter(Boolean).join(", "),
        city: cleanText(address.city),
        state: stateName(address.state),
        postalCode: normalizePostalCode(address.postal_code),
        countryCode: "US",
        officialUrl: ANYTIME_DIRECTORY_URL,
        status: "Open"
      };
    })
    .filter((location) => location.sourceId && location.name && location.address && location.city && location.state && location.postalCode);
}

export async function fetchAnytimeLocations({ fetchImpl = fetch } = {}) {
  const response = await fetchImpl(ANYTIME_SOURCE_URL, { headers: { Accept: "application/json" } });
  if (!response.ok) throw new Error(`Anytime Fitness locator returned ${response.status}`);
  const locations = parseAnytimeLocations(await response.json());
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
