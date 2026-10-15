import {
  STATE_NAMES,
  cleanText,
  normalizePostalCode,
  stateName,
} from "./normalize.mjs";

export const ORANGETHEORY_SOURCE_URL =
  "https://api.orangetheory.com/all-studios?pageSize=400";
export const UFC_GYM_SOURCE_URL = "https://www.ufcgym.com/locations/list";

const ORANGETHEORY_BASE_URL = "https://www.orangetheory.com";
const UFC_GYM_BASE_URL = "https://www.ufcgym.com";
const USPS_STATE_CODES = new Set(Object.keys(STATE_NAMES));

function decodeHtmlEntities(value) {
  const named = new Map([
    ["amp", "&"],
    ["apos", "'"],
    ["gt", ">"],
    ["lt", "<"],
    ["nbsp", " "],
    ["quot", '"'],
  ]);

  return String(value ?? "").replace(
    /&(#x[\da-f]+|#\d+|amp|apos|gt|lt|nbsp|quot);/gi,
    (entity, code) => {
      const normalized = code.toLowerCase();
      if (normalized.startsWith("#x")) {
        return String.fromCodePoint(Number.parseInt(normalized.slice(2), 16));
      }
      if (normalized.startsWith("#")) {
        return String.fromCodePoint(Number.parseInt(normalized.slice(1), 10));
      }
      return named.get(normalized) ?? entity;
    },
  );
}

function studioText(value) {
  return cleanText(decodeHtmlEntities(value));
}

function orangetheoryLocationUrl(slug) {
  return new URL(
    `/en-us/locations/${encodeURIComponent(slug)}`,
    ORANGETHEORY_BASE_URL,
  ).href;
}

function ufcGymLocationUrl(code) {
  return new URL(`/locations/${encodeURIComponent(code)}`, UFC_GYM_BASE_URL)
    .href;
}

function orangetheoryPostalCode(value, stateCode) {
  const rawPostalCode = cleanText(value);
  const normalized = normalizePostalCode(rawPostalCode);
  if (normalized) return normalized;

  // Some official New Jersey studio pages serialize a leading-zero ZIP as a
  // four-digit number. Restoring that required USPS formatting is deterministic.
  if (stateCode === "NJ" && /^\d{4}$/.test(rawPostalCode)) {
    return rawPostalCode.padStart(5, "0");
  }
  return "";
}

function relevantOrangetheoryStudio(studio) {
  return (
    studio?.environment === "PROD" &&
    studio?.["country-state"] === "United States" &&
    studio?.["studio-status"] === "Active"
  );
}

/** Select and deduplicate active U.S. studios from an official index page. */
export function parseOrangetheoryStudioIndex(payload) {
  const studios = Array.isArray(payload) ? payload : payload?.data?.studios;
  if (!Array.isArray(studios)) {
    throw new TypeError(
      "Orangetheory response did not contain a data.studios array",
    );
  }

  const selected = [];
  const seen = new Set();
  for (const studio of studios) {
    if (!relevantOrangetheoryStudio(studio)) continue;

    const sourceId = cleanText(studio?.["location-id"]);
    const slug = cleanText(studio?.slug);
    const address = studioText(studio?.["physical-address"]);
    const city = studioText(studio?.["physical-city"]);
    const stateCode = cleanText(studio?.["physical-state"]).toUpperCase();
    if (
      !sourceId ||
      !slug ||
      !address ||
      !city ||
      !USPS_STATE_CODES.has(stateCode)
    ) {
      throw new Error(
        `Active U.S. Orangetheory studio ${sourceId || "(missing location-id)"} has incomplete index data`,
      );
    }

    if (seen.has(sourceId)) continue;
    seen.add(sourceId);
    selected.push({
      sourceId,
      slug,
      address,
      city,
      stateCode,
    });
  }
  return selected;
}

function extractAssignedJsonObject(source, variableName) {
  const html = String(source ?? "");
  const marker = new RegExp(
    `\\b(?:const|let|var)\\s+${variableName}\\s*=\\s*`,
  ).exec(html);
  if (!marker) {
    throw new TypeError(
      `Orangetheory studio page did not expose ${variableName}`,
    );
  }

  const start = html.indexOf("{", marker.index + marker[0].length);
  if (start < 0) {
    throw new TypeError(`${variableName} was not assigned a JSON object`);
  }

  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = start; index < html.length; index += 1) {
    const character = html[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character === "\\") {
        escaped = true;
      } else if (character === '"') {
        inString = false;
      }
      continue;
    }

    if (character === '"') {
      inString = true;
    } else if (character === "{") {
      depth += 1;
    } else if (character === "}") {
      depth -= 1;
      if (depth === 0) {
        try {
          return JSON.parse(html.slice(start, index + 1));
        } catch (error) {
          throw new TypeError(`${variableName} was not valid JSON`, {
            cause: error,
          });
        }
      }
    }
  }

  throw new TypeError(`${variableName} JSON object was incomplete`);
}

/** Extract the first-party `studioDetails` object embedded in a studio page. */
export function parseOrangetheoryStudioPage(html) {
  const details = extractAssignedJsonObject(html, "studioDetails");
  if (!details || Array.isArray(details) || typeof details !== "object") {
    throw new TypeError("Orangetheory studioDetails was not an object");
  }
  return details;
}

/** Merge the complete index with its official per-studio detail records. */
export function parseOrangetheoryLocations(indexStudios, studioDetails) {
  if (!Array.isArray(indexStudios) || !Array.isArray(studioDetails)) {
    throw new TypeError(
      "Orangetheory locations require index and studio-detail arrays",
    );
  }
  if (indexStudios.length !== studioDetails.length) {
    throw new Error(
      `Orangetheory detail count ${studioDetails.length} did not match index count ${indexStudios.length}`,
    );
  }

  const detailsById = new Map();
  for (const detail of studioDetails) {
    const sourceId = cleanText(detail?.["location-id"]);
    if (!sourceId || detailsById.has(sourceId)) {
      throw new Error(
        `Orangetheory returned a missing or duplicate detail location-id: ${sourceId || "(missing)"}`,
      );
    }
    detailsById.set(sourceId, detail);
  }

  return indexStudios.map((studio) => {
    const detail = detailsById.get(studio.sourceId);
    if (!detail) {
      throw new Error(
        `Orangetheory studio ${studio.sourceId} had no matching detail page`,
      );
    }

    const slug = cleanText(detail?.slug);
    const stateCode = cleanText(detail?.["physical-state"]).toUpperCase();
    const name = studioText(detail?.name);
    const address = studioText(detail?.["physical-address"]);
    const city = studioText(detail?.["physical-city"]);
    const postalCode = orangetheoryPostalCode(
      detail?.["physical-postal-code"],
      stateCode,
    );
    const matchesIndex =
      slug === studio.slug &&
      stateCode === studio.stateCode &&
      cleanText(detail?.environment) === "PROD" &&
      cleanText(detail?.["studio-status"]) === "Active";

    if (
      !matchesIndex ||
      !name ||
      !address ||
      !city ||
      !postalCode ||
      !USPS_STATE_CODES.has(stateCode)
    ) {
      throw new Error(
        `Orangetheory studio ${studio.sourceId} returned incomplete or mismatched detail data`,
      );
    }

    return {
      sourceId: studio.sourceId,
      brand: "Orangetheory",
      name: `Orangetheory - ${name}`,
      address,
      city,
      state: stateName(stateCode),
      postalCode,
      countryCode: "US",
      officialUrl: orangetheoryLocationUrl(slug),
      status: "Open",
    };
  });
}

async function checkedResponse(url, init, fetchImpl, sourceName) {
  const response = await fetchImpl(url, init);
  if (!response.ok) {
    throw new Error(
      `${sourceName} returned HTTP ${response.status ?? "unknown"}: ${url}`,
    );
  }
  return response;
}

async function concurrentMap(items, concurrency, callback) {
  if (!Number.isInteger(concurrency) || concurrency < 1) {
    throw new TypeError("detailConcurrency must be a positive integer");
  }

  const results = new Array(items.length);
  let nextIndex = 0;
  async function worker() {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await callback(items[index], index);
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, worker),
  );
  return results;
}

/** Fetch every active U.S. studio and enrich it from its official studio page. */
export async function fetchOrangetheoryLocations({
  fetchImpl = fetch,
  signal,
  detailConcurrency = 12,
} = {}) {
  const rawStudios = [];
  const seenCursors = new Set();
  let lastEvaluatedId = "";

  do {
    const url = lastEvaluatedId
      ? `${ORANGETHEORY_SOURCE_URL}&lastEvaluatedID=${encodeURIComponent(lastEvaluatedId)}`
      : ORANGETHEORY_SOURCE_URL;
    const response = await checkedResponse(
      url,
      { headers: { Accept: "application/json" }, signal },
      fetchImpl,
      "Orangetheory studio index",
    );
    const payload = await response.json();
    if (payload?.status !== "SUCCESS" || !Array.isArray(payload?.data?.studios)) {
      throw new TypeError(
        "Orangetheory response did not contain a successful data.studios page",
      );
    }
    if (
      Number.isFinite(Number(payload.data.count)) &&
      Number(payload.data.count) !== payload.data.studios.length
    ) {
      throw new Error("Orangetheory page count did not match its studio rows");
    }
    rawStudios.push(...payload.data.studios);

    const nextCursor = cleanText(payload.data.lastEvaluatedKey);
    if (nextCursor && seenCursors.has(nextCursor)) {
      throw new Error("Orangetheory pagination repeated a cursor");
    }
    if (nextCursor) seenCursors.add(nextCursor);
    lastEvaluatedId = nextCursor;
  } while (lastEvaluatedId);

  const indexStudios = parseOrangetheoryStudioIndex(rawStudios);
  if (!indexStudios.length) {
    throw new Error("Orangetheory returned no active U.S. studios");
  }

  const details = await concurrentMap(
    indexStudios,
    detailConcurrency,
    async (studio) => {
      const url = orangetheoryLocationUrl(studio.slug);
      const response = await checkedResponse(
        url,
        { headers: { Accept: "text/html" }, signal },
        fetchImpl,
        `Orangetheory studio ${studio.sourceId}`,
      );
      const detail = parseOrangetheoryStudioPage(await response.text());
      if (cleanText(detail?.["location-id"]) !== studio.sourceId) {
        throw new Error(
          `Orangetheory studio page ${studio.slug} returned a mismatched location-id`,
        );
      }
      return detail;
    },
  );

  return parseOrangetheoryLocations(indexStudios, details);
}

/** Locate the current first-party Next.js application chunk in directory HTML. */
export function parseUfcGymAppChunkUrl(html) {
  const source = String(html ?? "");
  const path = /<script\b[^>]*\bsrc=["']([^"']*\/_next\/static\/chunks\/pages\/_app-[^/"']+\.js(?:\?[^"']*)?)["'][^>]*>/i
    .exec(source)?.[1];
  if (!path) {
    throw new TypeError("UFC GYM directory did not expose its _app chunk");
  }

  const url = new URL(path, UFC_GYM_BASE_URL);
  if (
    url.protocol !== "https:" ||
    url.hostname !== "www.ufcgym.com" ||
    !url.pathname.startsWith("/_next/static/chunks/pages/_app-")
  ) {
    throw new Error("UFC GYM directory exposed a non-first-party app chunk");
  }
  return url.href;
}

function decodeJavaScriptString(source) {
  let decoded = "";
  for (let index = 0; index < source.length; index += 1) {
    let character = source[index];
    if (character !== "\\") {
      decoded += character;
      continue;
    }

    index += 1;
    character = source[index];
    if (character === undefined) {
      throw new SyntaxError("UFC GYM app chunk ended inside a string escape");
    }

    const simpleEscapes = {
      "'": "'",
      '"': '"',
      "\\": "\\",
      "/": "/",
      b: "\b",
      f: "\f",
      n: "\n",
      r: "\r",
      t: "\t",
      v: "\v",
      0: "\0",
    };
    if (Object.hasOwn(simpleEscapes, character)) {
      decoded += simpleEscapes[character];
      continue;
    }

    if (character === "x") {
      const hex = source.slice(index + 1, index + 3);
      if (!/^[\da-f]{2}$/i.test(hex)) {
        throw new SyntaxError("UFC GYM app chunk had an invalid hex escape");
      }
      decoded += String.fromCharCode(Number.parseInt(hex, 16));
      index += 2;
      continue;
    }

    if (character === "u") {
      const hex = source.slice(index + 1, index + 5);
      if (!/^[\da-f]{4}$/i.test(hex)) {
        throw new SyntaxError("UFC GYM app chunk had an invalid Unicode escape");
      }
      decoded += String.fromCharCode(Number.parseInt(hex, 16));
      index += 4;
      continue;
    }

    if (character === "\n") continue;
    if (character === "\r") {
      if (source[index + 1] === "\n") index += 1;
      continue;
    }
    decoded += character;
  }
  return decoded;
}

function webpackJsonParsePayloads(appChunk) {
  const source = String(appChunk ?? "");
  const marker = /\.exports\s*=\s*JSON\.parse\(\s*(["'])/g;
  const payloads = [];
  for (const match of source.matchAll(marker)) {
    const quote = match[1];
    const start = match.index + match[0].length;
    let end = start;
    for (; end < source.length; end += 1) {
      if (source[end] === "\\") {
        end += 1;
      } else if (source[end] === quote) {
        break;
      }
    }
    if (end >= source.length) continue;

    try {
      payloads.push(
        JSON.parse(decodeJavaScriptString(source.slice(start, end))),
      );
    } catch {
      // Other webpack JSON modules are irrelevant to the location export.
    }
  }
  return payloads;
}

function isUfcGymLocationExport(value) {
  const requiredFields = [
    "id",
    "code",
    "status",
    "name",
    "street",
    "city",
    "state",
    "zip",
  ];
  return (
    Array.isArray(value) &&
    value.length > 0 &&
    value.every(
      (item) =>
        item &&
        typeof item === "object" &&
        requiredFields.every((field) => Object.hasOwn(item, field)),
    )
  );
}

/** Normalize UFC GYM's exported first-party location array. */
export function parseUfcGymLocations(payload) {
  if (!Array.isArray(payload)) {
    throw new TypeError("UFC GYM location export was not an array");
  }

  const locations = [];
  const seen = new Set();
  for (const location of payload) {
    const stateCode = cleanText(location?.state).toUpperCase();
    if (location?.status !== "OPEN" || !USPS_STATE_CODES.has(stateCode)) {
      continue;
    }

    const sourceId = cleanText(location?.id);
    const code = cleanText(location?.code);
    const locationName = studioText(location?.name);
    const address = studioText(location?.street);
    const city = studioText(location?.city);
    const postalCode = normalizePostalCode(location?.zip);
    if (
      !sourceId ||
      !code ||
      !locationName ||
      !address ||
      !city ||
      !postalCode
    ) {
      throw new Error(
        `OPEN U.S. UFC GYM location ${sourceId || "(missing id)"} has incomplete data`,
      );
    }
    if (seen.has(sourceId)) {
      throw new Error(
        `UFC GYM returned duplicate OPEN U.S. location id ${sourceId}`,
      );
    }

    seen.add(sourceId);
    locations.push({
      sourceId,
      brand: "UFC GYM",
      name: `UFC GYM - ${locationName}`,
      address,
      city,
      state: stateName(stateCode),
      postalCode,
      countryCode: "US",
      officialUrl: ufcGymLocationUrl(code),
      status: "Open",
    });
  }
  return locations;
}

/** Extract and normalize the location JSON module from a current app chunk. */
export function parseUfcGymAppChunk(appChunk) {
  const candidates = webpackJsonParsePayloads(appChunk).filter(
    isUfcGymLocationExport,
  );
  if (candidates.length !== 1) {
    throw new TypeError(
      `UFC GYM app chunk exposed ${candidates.length} location exports; expected one`,
    );
  }
  return parseUfcGymLocations(candidates[0]);
}

/** Fetch the directory, discover its current app chunk, and parse all locations. */
export async function fetchUfcGymLocations({ fetchImpl = fetch, signal } = {}) {
  const directory = await checkedResponse(
    UFC_GYM_SOURCE_URL,
    { headers: { Accept: "text/html" }, signal },
    fetchImpl,
    "UFC GYM directory",
  );
  const appChunkUrl = parseUfcGymAppChunkUrl(await directory.text());
  const appChunk = await checkedResponse(
    appChunkUrl,
    { headers: { Accept: "application/javascript" }, signal },
    fetchImpl,
    "UFC GYM app chunk",
  );
  const locations = parseUfcGymAppChunk(await appChunk.text());
  if (!locations.length) {
    throw new Error("UFC GYM returned no open U.S. locations");
  }
  return locations;
}

