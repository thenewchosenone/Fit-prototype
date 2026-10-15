/**
 * Official location adapters for Workout Anytime, Onelife Fitness, and
 * The Edge Fitness Clubs.
 *
 * Workout Anytime publishes its complete locator data in the locations page.
 * Onelife's public site is backed by a paginated HubDB table. The Edge's
 * public locator calls its HubSpot serverless endpoint with a nationwide
 * coordinate range.
 */

import {
  STATE_NAMES,
  cleanText,
  normalizePostalCode,
  stateName,
} from "./normalize.mjs";

export const WORKOUT_ANYTIME_SOURCE_URL = "https://workoutanytime.com/locations/";
export const ONELIFE_SOURCE_URL =
  "https://api.hubapi.com/hubdb/api/v2/tables/673686/rows";
export const EDGE_SOURCE_URL =
  "https://info.theedgefitnessclubs.com/_hcms/api/locator?coordinates=37.0902,-95.7129&range=25000";

const ONELIFE_PORTAL_ID = "2094550";
const ONELIFE_BASE_URL = "https://www.onelifefitness.com";
const EDGE_BASE_URL = "https://www.theedgefitnessclubs.com";

function decodeHtmlEntities(value) {
  const namedEntities = {
    amp: "&",
    apos: "'",
    gt: ">",
    lt: "<",
    nbsp: " ",
    quot: '"',
  };

  return String(value ?? "").replace(
    /&(#x[\da-f]+|#\d+|amp|apos|gt|lt|nbsp|quot);/gi,
    (entity, code) => {
      const normalizedCode = code.toLowerCase();
      if (normalizedCode.startsWith("#x")) {
        return String.fromCodePoint(Number.parseInt(normalizedCode.slice(2), 16));
      }
      if (normalizedCode.startsWith("#")) {
        return String.fromCodePoint(Number.parseInt(normalizedCode.slice(1), 10));
      }
      return namedEntities[normalizedCode] ?? entity;
    },
  );
}

function stateCode(value) {
  const aliases = { WVA: "WV" };
  const sourceCode = cleanText(value).replaceAll(".", "").toUpperCase();
  const code = aliases[sourceCode] ?? sourceCode;
  return Object.hasOwn(STATE_NAMES, code) ? code : "";
}

function lastPostalCode(value) {
  return [...String(value ?? "").matchAll(/\b\d{5}(?:-\d{4})?\b/g)].at(-1)?.[0] ?? "";
}

function uniqueBySourceId(locations) {
  const seen = new Set();
  return locations.filter((location) => {
    if (seen.has(location.sourceId)) return false;
    seen.add(location.sourceId);
    return true;
  });
}

function firstPartyUrl(value, baseUrl, expectedHostname) {
  const rawValue = cleanText(value);
  if (!rawValue) return "";

  const candidate = new URL(rawValue, baseUrl);
  return candidate.hostname === expectedHostname ? candidate.href : "";
}

function escapeRegularExpression(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function workoutAddressParts(store, code) {
  const postalCode = lastPostalCode(store?.address) || lastPostalCode(store?.add);
  if (!postalCode) return null;

  const fullStateName = stateName(code);
  const statePattern = [code, fullStateName]
    .map(escapeRegularExpression)
    .join("|");
  const stateSuffix = new RegExp(`^(.*?)(?:\\s+|^)(${statePattern})\\s*\\.?$`, "i");

  for (const sourceAddress of [store?.address, store?.add]) {
    const decodedAddress = decodeHtmlEntities(sourceAddress)
      .replace(/<br\s*\/?\s*>/gi, ", ")
      .replace(/<[^>]*>/g, " ")
      .replace(/[\u00a0\u2007\u202f]/g, " ");
    const segments = decodedAddress
      .split(/\s*,\s*/)
      .map((segment) => cleanText(segment).replace(/^[,\s]+|[,\s]+$/g, ""))
      .filter(Boolean)
      .map((segment) => cleanText(segment.replace(postalCode, "")))
      .map((segment) => segment.replace(/^[,\s]+|[,\s]+$/g, ""))
      .filter(Boolean);

    while (/^(?:US|USA|United States)$/i.test(segments.at(-1) ?? "")) {
      segments.pop();
    }

    let stateIndex = -1;
    let cityFromStateSegment = "";
    for (let index = segments.length - 1; index >= 0; index -= 1) {
      const match = segments[index].match(stateSuffix);
      if (!match) continue;
      stateIndex = index;
      cityFromStateSegment = cleanText(match[1]).replace(/[.\s]+$/g, "");
      break;
    }

    if (stateIndex < 0) continue;

    const cityIndex = cityFromStateSegment ? stateIndex : stateIndex - 1;
    let cityFromAddress = cityFromStateSegment || segments[cityIndex];
    let addressSegments = segments.slice(0, cityIndex);

    if (addressSegments.length === 0 && cityIndex === 0) {
      const splitAddress = segments[cityIndex].match(
        /^(.*\b(?:Ave(?:nue)?|Blvd|Boulevard|Cir(?:cle)?|Ct|Court|Dr|Drive|Hwy|Highway|Ln|Lane|Pkwy|Parkway|Pl|Place|Rd|Road|St|Street|Trl|Trail|Way)\.?)\s+(.+)$/i,
      );
      if (splitAddress) {
        addressSegments = [cleanText(splitAddress[1])];
        cityFromAddress = cleanText(splitAddress[2]);
      }
    }

    const city = cleanText(store?.city || cityFromAddress);
    const address = addressSegments.join(", ");
    if (address && city) return { address, city, postalCode };
  }

  return null;
}

function embeddedWorkoutAnytimeLocations(html) {
  const sourceHtml = String(html ?? "");
  const markerIndex = sourceHtml.search(/\bvar\s+storeDataAry\s*=/);
  if (markerIndex < 0) {
    throw new TypeError("Workout Anytime page did not contain storeDataAry");
  }

  const arrayStart = sourceHtml.indexOf("[", markerIndex);
  if (arrayStart < 0) {
    throw new TypeError("Workout Anytime storeDataAry was not an array");
  }

  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = arrayStart; index < sourceHtml.length; index += 1) {
    const character = sourceHtml[index];
    if (inString) {
      if (escaped) escaped = false;
      else if (character === "\\") escaped = true;
      else if (character === '"') inString = false;
      continue;
    }

    if (character === '"') inString = true;
    else if (character === "[") depth += 1;
    else if (character === "]") {
      depth -= 1;
      if (depth === 0) {
        const stores = JSON.parse(sourceHtml.slice(arrayStart, index + 1));
        if (!Array.isArray(stores)) break;
        return stores;
      }
    }
  }

  throw new TypeError("Workout Anytime storeDataAry was incomplete");
}

/** Normalize the complete store array embedded in Workout Anytime's locator. */
export function parseWorkoutAnytimeLocations(html) {
  const stores = embeddedWorkoutAnytimeLocations(html);
  const locations = [];

  for (const store of stores) {
    if (cleanText(store?.status).toLowerCase() !== "active") continue;

    const code = stateCode(store?.stateAbr);
    const addressParts = code ? workoutAddressParts(store, code) : null;
    const sourceId = cleanText(store?.postID);
    const locationName = cleanText(decodeHtmlEntities(store?.name));
    const locationSlug = cleanText(store?.slug);
    const siteUrl = cleanText(store?.siteurl);
    let officialUrl = "";

    if (locationSlug && siteUrl) {
      const baseUrl = new URL(siteUrl);
      if (["workoutanytime.com", "www.workoutanytime.com"].includes(baseUrl.hostname)) {
        officialUrl = new URL(locationSlug, `${baseUrl.origin}/`).href;
      }
    }

    if (!sourceId || !locationName || !addressParts || !officialUrl) continue;

    locations.push({
      sourceId,
      brand: "Workout Anytime",
      name: `Workout Anytime - ${locationName}`,
      address: addressParts.address,
      city: addressParts.city,
      state: stateName(code),
      postalCode: addressParts.postalCode,
      countryCode: "US",
      officialUrl,
      status: "Open",
    });
  }

  return uniqueBySourceId(locations);
}

/** Normalize decoded rows from Onelife Fitness's official HubDB table. */
export function parseOnelifeLocations(payload) {
  const rows = Array.isArray(payload) ? payload : payload?.objects;
  if (!Array.isArray(rows)) {
    throw new TypeError("Onelife Fitness response did not contain an objects array");
  }

  const locations = [];
  for (const row of rows) {
    const values = row?.values;
    const isOpen = row?.publishStatus === "PUBLISHED"
      && Number(row?.deletedAt) === 0
      && Number(values?.["89"] ?? 0) !== 1
      && Number(values?.["100"] ?? 0) !== 1
      && Number(values?.["118"] ?? 0) !== 1;
    if (!isOpen) continue;

    const code = stateCode(values?.["9"]);
    const sourceId = cleanText(row?.id);
    const locationName = cleanText(values?.["1"]);
    const address = cleanText(values?.["11"]);
    const city = cleanText(values?.["10"]);
    const postalCode = normalizePostalCode(values?.["12"]);
    const pagePath = cleanText(row?.path);
    const officialUrl = /^[a-z0-9][a-z0-9-]*$/i.test(pagePath)
      ? firstPartyUrl(`/gyms/${pagePath}`, ONELIFE_BASE_URL, "www.onelifefitness.com")
      : "";

    if (!code || !sourceId || !locationName || !address || !city || !postalCode || !officialUrl) {
      continue;
    }

    locations.push({
      sourceId,
      brand: "Onelife Fitness",
      name: `Onelife Fitness - ${locationName}`,
      address,
      city,
      state: stateName(code),
      postalCode,
      countryCode: "US",
      officialUrl,
      status: "Open",
    });
  }

  return uniqueBySourceId(locations);
}

/** Normalize the official Edge locator's decoded nationwide response. */
export function parseEdgeLocations(payload) {
  if (!Array.isArray(payload)) {
    throw new TypeError("The Edge Fitness Clubs response was not an array");
  }

  const locations = [];
  for (const club of payload) {
    if (Number(club?.active) !== 1) continue;

    const code = stateCode(club?.state);
    const sourceId = cleanText(club?.abc_club_id);
    const locationName = cleanText(club?.name);
    const address = cleanText(club?.address);
    const city = cleanText(club?.city);
    const rawPostalCode = cleanText(club?.zip_code);
    const postalCode = normalizePostalCode(rawPostalCode)
      || (/^\d{4}$/.test(rawPostalCode) ? rawPostalCode.padStart(5, "0") : "");
    const pagePath = cleanText(club?.page_path);
    const officialUrl = /^[a-z0-9][a-z0-9-]*$/i.test(pagePath)
      ? firstPartyUrl(`/locations/${pagePath}`, EDGE_BASE_URL, "www.theedgefitnessclubs.com")
      : "";

    if (!code || !sourceId || !locationName || !address || !city || !postalCode || !officialUrl) {
      continue;
    }

    locations.push({
      sourceId,
      brand: "The Edge Fitness Clubs",
      name: `The Edge Fitness Clubs - ${locationName}`,
      address,
      city,
      state: stateName(code),
      postalCode,
      countryCode: "US",
      officialUrl,
      status: "Open",
    });
  }

  return uniqueBySourceId(locations);
}

async function checkedResponse(url, init, fetchImpl) {
  if (typeof fetchImpl !== "function") {
    throw new TypeError("A Fetch API-compatible function is required");
  }

  const response = await fetchImpl(url, init);
  if (!response.ok) throw new Error(`${url} returned HTTP ${response.status}`);
  return response;
}

export async function fetchWorkoutAnytimeLocations({ fetchImpl = globalThis.fetch, signal } = {}) {
  const response = await checkedResponse(
    WORKOUT_ANYTIME_SOURCE_URL,
    { headers: { Accept: "text/html" }, signal },
    fetchImpl,
  );
  const html = await response.text();
  const stores = embeddedWorkoutAnytimeLocations(html);
  const expectedCount = stores.filter((store) => (
    cleanText(store?.status).toLowerCase() === "active" && stateCode(store?.stateAbr)
  )).length;
  const locations = parseWorkoutAnytimeLocations(html);
  if (locations.length !== expectedCount) {
    throw new Error(
      `Workout Anytime normalized ${locations.length} of ${expectedCount} active US locations`,
    );
  }
  return locations;
}

export async function fetchOnelifeLocations(options = {}) {
  const {
    fetchImpl = globalThis.fetch,
    pageSize = 100,
    signal,
  } = options;
  if (!Number.isInteger(pageSize) || pageSize < 1) {
    throw new RangeError("Onelife Fitness pageSize must be a positive integer");
  }

  const rows = [];
  let offset = 0;
  let expectedTotal;

  while (true) {
    const url = new URL(ONELIFE_SOURCE_URL);
    url.searchParams.set("portalId", ONELIFE_PORTAL_ID);
    url.searchParams.set("limit", String(pageSize));
    url.searchParams.set("offset", String(offset));
    const response = await checkedResponse(
      url.href,
      { headers: { Accept: "application/json" }, signal },
      fetchImpl,
    );
    const page = await response.json();
    if (!Array.isArray(page?.objects)) {
      throw new TypeError("Onelife Fitness response did not contain an objects array");
    }

    const reportedTotal = Number(page.totalCount ?? page.total);
    if (Number.isFinite(reportedTotal) && reportedTotal >= 0) {
      expectedTotal = reportedTotal;
    }
    rows.push(...page.objects);

    if (expectedTotal !== undefined && rows.length >= expectedTotal) break;
    if (page.objects.length < pageSize && expectedTotal === undefined) break;
    if (page.objects.length === 0) {
      throw new Error("Onelife Fitness pagination ended before its reported total");
    }
    offset += page.objects.length;
  }

  return parseOnelifeLocations(rows);
}

export async function fetchEdgeLocations({ fetchImpl = globalThis.fetch, signal } = {}) {
  const response = await checkedResponse(
    EDGE_SOURCE_URL,
    { headers: { Accept: "application/json, text/plain, */*" }, signal },
    fetchImpl,
  );
  return parseEdgeLocations(await response.json());
}

