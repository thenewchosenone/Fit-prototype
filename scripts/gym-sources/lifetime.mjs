import { request as httpsRequest } from "node:https";
import {
  brotliDecompressSync,
  gunzipSync,
  inflateSync,
} from "node:zlib";

import { cleanText, normalizePostalCode, stateName } from "./normalize.mjs";

export const LIFETIME_SOURCE_URL = "https://www.lifetime.life/bin/lt/club.ef";

const LIFETIME_BASE_URL = "https://www.lifetime.life";
const OPEN_CLUB_TYPE_IDS = new Set([1, 2]);

function firstPartyUrl(value) {
  const rawValue = cleanText(value);
  if (!rawValue) return "";

  try {
    const candidate = new URL(rawValue, LIFETIME_BASE_URL);
    return candidate.protocol === "https:" && candidate.hostname === "www.lifetime.life"
      ? candidate.href
      : "";
  } catch {
    return "";
  }
}

function displayName(value) {
  const clubName = cleanText(value);
  if (!clubName) return "";
  return /^Life\s*Time\b/i.test(clubName)
    ? clubName
    : `Life Time - ${clubName}`;
}

function uniqueBySourceId(locations) {
  const seen = new Set();
  return locations.filter((location) => {
    if (seen.has(location.sourceId)) return false;
    seen.add(location.sourceId);
    return true;
  });
}

/** Normalize Life Time's complete first-party club feed. */
export function parseLifetimeLocations(payload) {
  const clubs = typeof payload === "string" ? JSON.parse(payload) : payload;
  if (!Array.isArray(clubs)) {
    throw new TypeError("Life Time response was not an array");
  }

  const locations = [];
  for (const club of clubs) {
    const isUsClub =
      cleanText(club?.countryCode).toUpperCase() === "US" ||
      cleanText(club?.country).toUpperCase() === "USA";
    const isPublicOpenClub =
      cleanText(club?.open) === "open" &&
      OPEN_CLUB_TYPE_IDS.has(Number(club?.clubTypeId)) &&
      club?.approvedForWeb === true &&
      club?.hideFromPublicView === false &&
      club?.excludeFromLocation === false;
    if (!isUsClub || !isPublicOpenClub) continue;

    const sourceId = cleanText(club?.mmsClubId);
    const name = displayName(club?.marketingClubName);
    const address = [club?.street1, club?.street2]
      .map(cleanText)
      .filter(Boolean)
      .join(", ");
    const city = cleanText(club?.city);
    const state = stateName(club?.stateAbbr || club?.state);
    const postalCode = normalizePostalCode(club?.zip);
    const officialUrl =
      firstPartyUrl(club?.locationPagePath) ||
      firstPartyUrl(club?.prospectPagePath);

    if (
      !sourceId ||
      !name ||
      !address ||
      !city ||
      !state ||
      !postalCode ||
      !officialUrl
    ) {
      continue;
    }

    locations.push({
      sourceId,
      brand: "Life Time",
      name,
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

/** Decode the compressed JSON body returned by Life Time's endpoint. */
export function decodeLifetimeJsonBody(body, contentEncoding = "") {
  const source = Buffer.isBuffer(body) ? body : Buffer.from(body);
  const encoding = cleanText(contentEncoding).toLowerCase().split(",", 1)[0];
  let decoded;

  if (!encoding || encoding === "identity") {
    decoded = source;
  } else if (encoding === "gzip" || encoding === "x-gzip") {
    decoded = gunzipSync(source);
  } else if (encoding === "deflate") {
    decoded = inflateSync(source);
  } else if (encoding === "br") {
    decoded = brotliDecompressSync(source);
  } else {
    throw new Error(`Life Time returned unsupported content encoding: ${encoding}`);
  }

  try {
    return JSON.parse(decoded.toString("utf8"));
  } catch (error) {
    throw new Error("Life Time returned invalid JSON", { cause: error });
  }
}

function fetchJsonWithHttps(url, init) {
  return new Promise((resolve, reject) => {
    const request = httpsRequest(
      url,
      {
        method: "GET",
        headers: init.headers,
        signal: init.signal,
        // The endpoint includes a very large Content-Security-Policy header.
        maxHeaderSize: 128 * 1024,
      },
      (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("error", reject);
        response.on("end", () => {
          const status = response.statusCode ?? 0;
          if (status < 200 || status >= 300) {
            reject(new Error(`${url} returned HTTP ${status}`));
            return;
          }

          try {
            resolve(
              decodeLifetimeJsonBody(
                Buffer.concat(chunks),
                response.headers["content-encoding"],
              ),
            );
          } catch (error) {
            reject(error);
          }
        });
      },
    );

    request.on("error", reject);
    request.end();
  });
}

/** Fetch and normalize the current official Life Time US locations. */
export async function fetchLifetimeLocations({ fetchImpl, signal } = {}) {
  const init = {
    method: "GET",
    headers: {
      Accept: "application/json",
      "Accept-Encoding": "gzip",
    },
    signal,
  };

  let payload;
  if (fetchImpl !== undefined) {
    if (typeof fetchImpl !== "function") {
      throw new TypeError("fetchImpl must be a function");
    }
    const response = await fetchImpl(LIFETIME_SOURCE_URL, init);
    if (!response.ok) {
      throw new Error(`${LIFETIME_SOURCE_URL} returned HTTP ${response.status}`);
    }
    payload = await response.json();
  } else {
    payload = await fetchJsonWithHttps(LIFETIME_SOURCE_URL, init);
  }

  return parseLifetimeLocations(payload);
}

