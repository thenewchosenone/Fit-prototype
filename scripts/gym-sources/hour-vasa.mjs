import { cleanText, normalizePostalCode, stateName } from "./normalize.mjs";

export const HOUR_FITNESS_SOURCE_URL = "https://api.24hourfitness.com/clubs";
export const VASA_SOURCE_URL = "https://vasafitness.com/wp-json/wp/v2/vasa_locations";

const HOUR_FITNESS_BASE_URL = "https://www.24hourfitness.com";
const VASA_BASE_URL = "https://vasafitness.com";

function firstPartyUrl(value, baseUrl, expectedHostname) {
  const rawValue = cleanText(value);
  if (!rawValue) return "";
  const candidate = new URL(rawValue, baseUrl);
  return candidate.hostname === expectedHostname ? candidate.href : "";
}

function uniqueBySourceId(locations) {
  const seen = new Set();
  return locations.filter((location) => {
    if (seen.has(location.sourceId)) return false;
    seen.add(location.sourceId);
    return true;
  });
}

export function parse24HourFitnessLocations(payload) {
  if (!Array.isArray(payload)) {
    throw new TypeError("24 Hour Fitness response was not an array");
  }

  const locations = [];
  for (const club of payload) {
    if (cleanText(club?.clubStatus).toLowerCase() !== "open") continue;

    const sourceId = cleanText(club?.clubNumber);
    const locationName = cleanText(club?.name);
    const address = [club?.address?.street, club?.address?.streetLine2]
      .map(cleanText)
      .filter(Boolean)
      .join(", ");
    const city = cleanText(club?.address?.city);
    const state = stateName(club?.address?.state);
    const postalCode = normalizePostalCode(club?.address?.zip);
    const officialUrl = sourceId
      ? new URL(`/Website/Club/${encodeURIComponent(sourceId)}`, HOUR_FITNESS_BASE_URL).href
      : "";

    if (!sourceId || !locationName || !address || !city || !state || !postalCode) continue;

    locations.push({
      sourceId,
      brand: "24 Hour Fitness",
      name: `24 Hour Fitness - ${locationName}`,
      address,
      city,
      state,
      postalCode,
      countryCode: "US",
      officialUrl,
      status: "Open",
    });
  }

  return uniqueBySourceId(locations);
}

export function parseVasaLocations(payload) {
  if (!Array.isArray(payload)) {
    throw new TypeError("VASA Fitness response was not an array");
  }

  const locations = [];
  for (const post of payload) {
    const details = post?.acf?.location_details?.[0];
    const gymStatus = cleanText(details?.gym_status).toLowerCase();
    if (post?.status !== "publish" || !["normal", "now-open"].includes(gymStatus)) continue;

    const sourceId = cleanText(post?.id);
    const locationName = cleanText(post?.title?.rendered)
      .replaceAll("&#038;", "&")
      .replaceAll("&amp;", "&");
    const address = [details?.address_line_1, details?.address_line_2]
      .map(cleanText)
      .filter(Boolean)
      .join(", ");
    const city = cleanText(details?.city);
    const state = stateName(details?.state);
    const postalCode = normalizePostalCode(details?.zip);
    const officialUrl = firstPartyUrl(post?.link, VASA_BASE_URL, "vasafitness.com");

    if (!sourceId || !locationName || !address || !city || !state || !postalCode || !officialUrl) continue;

    locations.push({
      sourceId,
      brand: "VASA Fitness",
      name: `VASA Fitness - ${locationName}`,
      address,
      city,
      state,
      postalCode,
      countryCode: "US",
      officialUrl,
      status: "Open",
    });
  }

  return uniqueBySourceId(locations);
}

async function checkedResponse(url, init, fetchImpl) {
  const response = await fetchImpl(url, init);
  if (!response.ok) throw new Error(`${url} returned HTTP ${response.status}`);
  return response;
}

export async function fetch24HourFitnessLocations({ fetchImpl = fetch, signal } = {}) {
  const response = await checkedResponse(
    HOUR_FITNESS_SOURCE_URL,
    { headers: { Accept: "application/json" }, signal },
    fetchImpl,
  );
  return parse24HourFitnessLocations(await response.json());
}

export async function fetchVasaLocations({ fetchImpl = fetch, signal } = {}) {
  const posts = [];
  let page = 1;
  let pageCount = 1;

  do {
    const url = new URL(VASA_SOURCE_URL);
    url.searchParams.set("per_page", "100");
    url.searchParams.set("page", String(page));
    const response = await checkedResponse(
      url.href,
      { headers: { Accept: "application/json" }, signal },
      fetchImpl,
    );
    pageCount = Number(response.headers.get("x-wp-totalpages") || 1);
    posts.push(...await response.json());
    page += 1;
  } while (page <= pageCount);

  return parseVasaLocations(posts);
}

