/**
 * Official locator adapters for EOS Fitness and YouFit.
 *
 * EOS's public gym finder calls the JSON API below. YouFit's public directory
 * embeds its location records as JSON in a `data-locations` attribute. Keeping
 * both parsers pure makes source snapshots easy to test without network access.
 */

export const EOS_SOURCE_URL =
  "https://api-be7615e9.joinnow.eosfitness.com/v2/clubs/filters";
export const YOUFIT_SOURCE_URL = "https://youfit.com/locations/";

const EOS_GYM_BASE_URL = "https://www.eosfitness.com/gym/";
const YOUFIT_BASE_URL = "https://youfit.com/";

const US_STATE_NAMES = new Map([
  ["AL", "Alabama"],
  ["AK", "Alaska"],
  ["AZ", "Arizona"],
  ["AR", "Arkansas"],
  ["CA", "California"],
  ["CO", "Colorado"],
  ["CT", "Connecticut"],
  ["DE", "Delaware"],
  ["DC", "District of Columbia"],
  ["FL", "Florida"],
  ["GA", "Georgia"],
  ["HI", "Hawaii"],
  ["ID", "Idaho"],
  ["IL", "Illinois"],
  ["IN", "Indiana"],
  ["IA", "Iowa"],
  ["KS", "Kansas"],
  ["KY", "Kentucky"],
  ["LA", "Louisiana"],
  ["ME", "Maine"],
  ["MD", "Maryland"],
  ["MA", "Massachusetts"],
  ["MI", "Michigan"],
  ["MN", "Minnesota"],
  ["MS", "Mississippi"],
  ["MO", "Missouri"],
  ["MT", "Montana"],
  ["NE", "Nebraska"],
  ["NV", "Nevada"],
  ["NH", "New Hampshire"],
  ["NJ", "New Jersey"],
  ["NM", "New Mexico"],
  ["NY", "New York"],
  ["NC", "North Carolina"],
  ["ND", "North Dakota"],
  ["OH", "Ohio"],
  ["OK", "Oklahoma"],
  ["OR", "Oregon"],
  ["PA", "Pennsylvania"],
  ["RI", "Rhode Island"],
  ["SC", "South Carolina"],
  ["SD", "South Dakota"],
  ["TN", "Tennessee"],
  ["TX", "Texas"],
  ["UT", "Utah"],
  ["VT", "Vermont"],
  ["VA", "Virginia"],
  ["WA", "Washington"],
  ["WV", "West Virginia"],
  ["WI", "Wisconsin"],
  ["WY", "Wyoming"],
  ["AS", "American Samoa"],
  ["GU", "Guam"],
  ["MP", "Northern Mariana Islands"],
  ["PR", "Puerto Rico"],
  ["VI", "U.S. Virgin Islands"],
]);

const US_STATE_NAME_LOOKUP = new Map(
  [...US_STATE_NAMES.values()].map((name) => [name.toLowerCase(), name]),
);

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

function cleanText(value) {
  return decodeHtmlEntities(value)
    .replace(/<[^>]*>/g, " ")
    .replace(/[\u00a0\u2007\u202f]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function cleanAddressPart(value) {
  return cleanText(value).replace(/[\s,]+$/g, "");
}

function decodedPayload(payload) {
  return typeof payload === "string" ? JSON.parse(payload) : payload;
}

function stateName(value) {
  const state = cleanText(value);
  return (
    US_STATE_NAMES.get(state.toUpperCase()) ??
    US_STATE_NAME_LOOKUP.get(state.toLowerCase()) ??
    ""
  );
}

function uniqueBySourceId(locations) {
  const seen = new Set();
  return locations.filter((location) => {
    if (seen.has(location.sourceId)) return false;
    seen.add(location.sourceId);
    return true;
  });
}

function eosDisplayName(value) {
  const locationName = cleanText(value).replace(
    /^E(?:O|o|ō)S Fitness\s*[-–—:]?\s*/iu,
    "",
  );
  return locationName ? `EOS Fitness - ${locationName}` : "";
}

function youFitDisplayName(value) {
  const locationName = cleanText(value).replace(
    /^YouFit Gyms\s*[-–—:]?\s*/i,
    "",
  );
  return locationName ? `YouFit Gyms - ${locationName}` : "";
}

function firstPartyUrl(relativeUrl, baseUrl, expectedHostname) {
  const rawUrl = cleanText(relativeUrl);
  if (!rawUrl) return "";

  const candidate = new URL(rawUrl, baseUrl);
  return candidate.hostname === expectedHostname ? candidate.href : "";
}

/** Normalize a decoded EOS `/v2/clubs/filters` response. */
export function parseEosLocations(payload) {
  const parsedPayload = decodedPayload(payload);
  const clubs = Array.isArray(parsedPayload) ? parsedPayload : parsedPayload?.clubs;
  if (!Array.isArray(clubs)) {
    throw new TypeError("EOS Fitness response did not contain a clubs array");
  }

  const normalized = [];
  for (const club of clubs) {
    const isOpen = cleanText(club?.status).toLowerCase() === "open";
    const state = stateName(club?.state);
    if (!isOpen || club?.isExternal === true || !state) continue;

    const sourceId = cleanText(club?.clubId ?? club?.id ?? club?.clubBusinessId);
    const name = eosDisplayName(club?.name);
    const address = cleanAddressPart(club?.street);
    const city = cleanText(club?.city);
    const postalCode = cleanText(club?.zipCode);
    const permalink = cleanText(club?.permalink);
    const officialUrl = firstPartyUrl(
      permalink,
      EOS_GYM_BASE_URL,
      "www.eosfitness.com",
    );

    if (
      !sourceId ||
      !name ||
      !address ||
      !city ||
      !postalCode ||
      !officialUrl
    ) {
      continue;
    }

    normalized.push({
      sourceId,
      brand: "EOS Fitness",
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

  return uniqueBySourceId(normalized);
}

function embeddedYouFitLocations(html) {
  const sourceHtml = String(html ?? "");
  const match = sourceHtml.match(
    /<[a-z][^>]*\bdata-locations\s*=\s*(["'])(\s*\[[\s\S]*?\])\1/i,
  );
  if (!match) {
    throw new TypeError("YouFit page did not contain embedded location data");
  }

  const locations = JSON.parse(decodeHtmlEntities(match[2]));
  if (!Array.isArray(locations)) {
    throw new TypeError("YouFit embedded location data was not an array");
  }
  return locations;
}

/** Normalize the location JSON embedded in YouFit's official directory HTML. */
export function parseYouFitLocations(html) {
  const locations = embeddedYouFitLocations(html);
  const normalized = [];

  for (const location of locations) {
    const sourceCountry = cleanText(location?.address?.location).toLowerCase();
    const state = stateName(location?.address?.state);
    if (sourceCountry !== "us" || !state) continue;

    const sourceId = cleanText(location?.id);
    const name = youFitDisplayName(location?.title);
    const address = [location?.address?.street1, location?.address?.street2]
      .map(cleanAddressPart)
      .filter(Boolean)
      .join(", ");
    const city = cleanText(location?.address?.city);
    const postalCode = cleanText(location?.address?.zip);
    const officialUrl = firstPartyUrl(
      location?.url,
      YOUFIT_BASE_URL,
      "youfit.com",
    );

    if (
      !sourceId ||
      !name ||
      !address ||
      !city ||
      !postalCode ||
      !officialUrl
    ) {
      continue;
    }

    normalized.push({
      sourceId,
      brand: "YouFit",
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

  return uniqueBySourceId(normalized);
}

async function checkedResponse(url, init, fetchImpl) {
  if (typeof fetchImpl !== "function") {
    throw new TypeError("A Fetch API-compatible function is required");
  }

  const response = await fetchImpl(url, init);
  if (!response.ok) {
    throw new Error(`${url} returned HTTP ${response.status}`);
  }
  return response;
}

/** Fetch and normalize the current official EOS Fitness US locations. */
export async function fetchEosLocations(options = {}) {
  const { fetchImpl = globalThis.fetch, signal } = options;
  const response = await checkedResponse(
    EOS_SOURCE_URL,
    {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        isGymStatusComingSoonIncluded: false,
        excludeExternalClubs: true,
      }),
      signal,
    },
    fetchImpl,
  );
  return parseEosLocations(await response.json());
}

/** Fetch and normalize the current official YouFit US locations. */
export async function fetchYouFitLocations(options = {}) {
  const { fetchImpl = globalThis.fetch, signal } = options;
  const response = await checkedResponse(
    YOUFIT_SOURCE_URL,
    {
      headers: { Accept: "text/html" },
      signal,
    },
    fetchImpl,
  );
  return parseYouFitLocations(await response.text());
}
