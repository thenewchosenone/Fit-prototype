import { request as httpsRequest } from "node:https";

/**
 * Official locator adapters for Crunch Fitness and LA Fitness.
 *
 * These endpoints are the same first-party sources used by each brand's public
 * location finder. Keep the parsers pure so saved responses can be checked
 * without making a network request.
 */

export const CRUNCH_SOURCE_URL = "https://www.crunch.com/load-clubs";
export const LA_FITNESS_SOURCE_URL =
  "https://www.lafitness.com/Pages/GetClubLocations.aspx/GetClubLocation";

const CRUNCH_BASE_URL = "https://www.crunch.com";
const LA_FITNESS_BASE_URL = "https://www.lafitness.com/Pages/";

// Crunch treats both values as operating clubs. The latter simply cannot sell
// memberships through the website.
const CRUNCH_OPEN_STATUSES = new Set(["open", "open_(no_online_sales)"]);

// USPS state, district, and inhabited-territory abbreviations. Canadian
// provinces in the LA Fitness feed (currently AB and ON) are intentionally not
// included.
const US_REGION_CODES = new Set([
  "AL",
  "AK",
  "AZ",
  "AR",
  "CA",
  "CO",
  "CT",
  "DE",
  "DC",
  "FL",
  "GA",
  "HI",
  "ID",
  "IL",
  "IN",
  "IA",
  "KS",
  "KY",
  "LA",
  "ME",
  "MD",
  "MA",
  "MI",
  "MN",
  "MS",
  "MO",
  "MT",
  "NE",
  "NV",
  "NH",
  "NJ",
  "NM",
  "NY",
  "NC",
  "ND",
  "OH",
  "OK",
  "OR",
  "PA",
  "RI",
  "SC",
  "SD",
  "TN",
  "TX",
  "UT",
  "VT",
  "VA",
  "WA",
  "WV",
  "WI",
  "WY",
  "AS",
  "GU",
  "MP",
  "PR",
  "VI",
]);

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
      return namedEntities[normalizedCode];
    },
  );
}

function cleanText(value) {
  return decodeHtmlEntities(value)
    .replace(/[\u00a0\u2007\u202f]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function responseArray(payload, property, sourceName) {
  let parsedPayload = payload;
  if (typeof parsedPayload === "string") {
    parsedPayload = JSON.parse(parsedPayload);
  }

  if (Array.isArray(parsedPayload)) {
    return parsedPayload;
  }

  let records = parsedPayload?.[property];
  if (typeof records === "string") {
    records = JSON.parse(records);
  }
  if (!Array.isArray(records)) {
    throw new TypeError(`${sourceName} response did not contain a ${property} array`);
  }
  return records;
}

function uniqueBySourceId(locations) {
  const seen = new Set();
  return locations.filter((location) => {
    if (seen.has(location.sourceId)) return false;
    seen.add(location.sourceId);
    return true;
  });
}

function crunchOfficialUrl(slug) {
  return new URL(`/locations/${encodeURIComponent(slug)}`, CRUNCH_BASE_URL).href;
}

/**
 * Normalize a decoded Crunch `/load-clubs` response.
 */
export function parseCrunchLocations(payload) {
  const clubs = responseArray(payload, "clubs", "Crunch Fitness");
  const normalized = [];

  for (const club of clubs) {
    const sourceStatus = cleanText(club?.status).toLowerCase();
    const sourceCountry = cleanText(club?.address?.country_code).toUpperCase();
    if (!CRUNCH_OPEN_STATUSES.has(sourceStatus) || sourceCountry !== "US") continue;

    const sourceId = cleanText(club?.id);
    const name = cleanText(club?.name);
    const address = [club?.address?.address_1, club?.address?.address_2]
      .map(cleanText)
      .filter(Boolean)
      .join(", ");
    const city = cleanText(club?.address?.city);
    const state = cleanText(club?.address?.state).toUpperCase();
    const postalCode = cleanText(club?.address?.zip);
    const slug = cleanText(club?.slug);

    if (!sourceId || !name || !address || !city || !state || !postalCode || !slug) {
      continue;
    }

    normalized.push({
      sourceId,
      brand: "Crunch Fitness",
      name,
      address,
      city,
      state,
      postalCode,
      countryCode: "US",
      officialUrl: crunchOfficialUrl(slug),
      status: "Open",
    });
  }

  return uniqueBySourceId(normalized);
}

function parseLaAddress(addressHtml) {
  const rawAddress = String(addressHtml ?? "");
  const [streetHtml = ""] = rawAddress.split(/<br\s*\/?>/i);
  const address = cleanText(streetHtml.replace(/<[^>]*>/g, " "));
  const addressText = cleanText(
    rawAddress.replace(/<br\s*\/?>/gi, " ").replace(/<[^>]*>/g, " "),
  );
  const postalCode = addressText.match(/\b\d{5}(?:-\d{4})?\b/)?.[0] ?? "";
  return { address, postalCode };
}

function laFitnessOfficialUrl(relativeUrl, sourceId) {
  const fallback = new URL(`clubhome.aspx?clubid=${encodeURIComponent(sourceId)}`, LA_FITNESS_BASE_URL);
  const rawUrl = cleanText(relativeUrl);
  if (!rawUrl) return fallback.href;

  const candidate = new URL(rawUrl, LA_FITNESS_BASE_URL);
  return candidate.hostname === "www.lafitness.com" || candidate.hostname === "lafitness.com"
    ? candidate.href
    : fallback.href;
}

/**
 * Normalize a decoded LA Fitness `GetClubLocation` response.
 *
 * ClubStatus 1 is open. BrandId 0 with IsEsporta false identifies LA Fitness;
 * the same corporate feed also contains Esporta and other Fitness International
 * brands, which are deliberately excluded here.
 */
export function parseLaFitnessLocations(payload) {
  const clubs = responseArray(payload, "d", "LA Fitness");
  const normalized = [];

  for (const club of clubs) {
    const isOpen = Number(club?.ClubStatus) === 1;
    const isLaFitness = Number(club?.BrandId) === 0 && club?.IsEsporta !== true;
    const state = cleanText(club?.State).toUpperCase();
    if (!isOpen || !isLaFitness || !US_REGION_CODES.has(state)) continue;

    const sourceId = cleanText(club?.ClubID);
    const name = cleanText(club?.Description);
    const city = cleanText(club?.City);
    const { address, postalCode } = parseLaAddress(club?.Address);
    if (!sourceId || !name || !address || !city || !postalCode) continue;

    normalized.push({
      sourceId,
      brand: "LA Fitness",
      name,
      address,
      city,
      state,
      postalCode,
      countryCode: "US",
      officialUrl: laFitnessOfficialUrl(club?.ClubHomeURL, sourceId),
      status: "Open",
    });
  }

  return uniqueBySourceId(normalized);
}

async function fetchJson(url, init, fetchImpl) {
  if (typeof fetchImpl !== "function") {
    throw new TypeError("A Fetch API-compatible function is required");
  }

  const response = await fetchImpl(url, init);
  if (!response.ok) {
    throw new Error(`${url} returned HTTP ${response.status}`);
  }
  return response.json();
}

function fetchJsonWithHttps(url, init) {
  return new Promise((resolve, reject) => {
    const request = httpsRequest(
      url,
      {
        method: init.method,
        headers: init.headers,
        signal: init.signal,
        // LA Fitness sends a very large Content-Security-Policy response
        // header. Node's Fetch API rejects it at its lower fixed limit.
        maxHeaderSize: 128 * 1024,
      },
      (response) => {
        const chunks = [];
        response.setEncoding("utf8");
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          const body = chunks.join("");
          const status = response.statusCode ?? 0;
          if (status < 200 || status >= 300) {
            reject(new Error(`${url} returned HTTP ${status}`));
            return;
          }

          try {
            resolve(JSON.parse(body));
          } catch (error) {
            reject(new Error(`${url} returned invalid JSON`, { cause: error }));
          }
        });
      },
    );

    request.on("error", reject);
    if (init.body) request.write(init.body);
    request.end();
  });
}

/** Fetch and normalize the current official Crunch Fitness US locations. */
export async function fetchCrunchLocations(options = {}) {
  const { fetchImpl = globalThis.fetch, signal } = options;
  const payload = await fetchJson(
    CRUNCH_SOURCE_URL,
    {
      headers: { Accept: "application/json" },
      signal,
    },
    fetchImpl,
  );
  return parseCrunchLocations(payload);
}

/** Fetch and normalize the current official LA Fitness US locations. */
export async function fetchLaFitnessLocations(options = {}) {
  const { fetchImpl, signal } = options;
  const requestInit = {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json; charset=utf-8",
      "Content-Length": "2",
    },
    body: "{}",
    signal,
  };
  const payload = fetchImpl
    ? await fetchJson(LA_FITNESS_SOURCE_URL, requestInit, fetchImpl)
    : await fetchJsonWithHttps(LA_FITNESS_SOURCE_URL, requestInit);
  return parseLaFitnessLocations(payload);
}
