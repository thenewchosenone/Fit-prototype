import assert from "node:assert/strict";
import test from "node:test";
import { gzipSync } from "node:zlib";

import {
  LIFETIME_SOURCE_URL,
  decodeLifetimeJsonBody,
  fetchLifetimeLocations,
  parseLifetimeLocations,
} from "./lifetime.mjs";

function openClub(overrides = {}) {
  return {
    countryCode: "US",
    country: "USA",
    mmsClubId: 350,
    marketingClubName: "Harbour Island",
    open: "open",
    clubTypeId: 2,
    street1: "900 S Harbour Island Blvd",
    city: "Tampa",
    state: "Florida",
    stateAbbr: "FL",
    zip: "33602",
    approvedForWeb: true,
    hideFromPublicView: false,
    excludeFromLocation: false,
    locationPagePath: "https://www.lifetime.life/locations/fl/harbour-island",
    prospectPagePath: "https://www.lifetime.life/locations/fl/harbour-island.html",
    ...overrides,
  };
}

test("Life Time parser keeps complete public open US athletic clubs", () => {
  const result = parseLifetimeLocations([
    openClub({ street2: "Suite 100" }),
    openClub({ street2: "Suite 100" }),
    openClub({
      countryCode: "",
      mmsClubId: 351,
      marketingClubName: "Life Time Studio at Riverside",
      clubTypeId: "1",
      street1: "390 Hackensack Ave",
      street2: "",
      city: "Hackensack",
      state: "New Jersey",
      stateAbbr: "",
      zip: "07601-6302",
      locationPagePath: "https://locations.example.com/hackensack",
      prospectPagePath: "/locations/nj/riverside.html",
    }),
  ]);

  assert.deepEqual(result, [
    {
      sourceId: "350",
      brand: "Life Time",
      name: "Life Time - Harbour Island",
      address: "900 S Harbour Island Blvd, Suite 100",
      city: "Tampa",
      state: "Florida",
      postalCode: "33602",
      countryCode: "US",
      officialUrl: "https://www.lifetime.life/locations/fl/harbour-island",
      status: "Open",
    },
    {
      sourceId: "351",
      brand: "Life Time",
      name: "Life Time Studio at Riverside",
      address: "390 Hackensack Ave",
      city: "Hackensack",
      state: "New Jersey",
      postalCode: "07601-6302",
      countryCode: "US",
      officialUrl: "https://www.lifetime.life/locations/nj/riverside.html",
      status: "Open",
    },
  ]);
});

test("Life Time parser enforces every source visibility and club-type filter", () => {
  const result = parseLifetimeLocations([
    openClub({ mmsClubId: 1, countryCode: "CA", country: "Canada" }),
    openClub({ mmsClubId: 2, open: "waitlist" }),
    openClub({ mmsClubId: 3, open: "Open" }),
    openClub({ mmsClubId: 4, clubTypeId: 10 }),
    openClub({ mmsClubId: 5, approvedForWeb: false }),
    openClub({ mmsClubId: 6, hideFromPublicView: true }),
    openClub({ mmsClubId: 7, excludeFromLocation: true }),
    openClub({ mmsClubId: 8, street1: "" }),
    openClub({ mmsClubId: 9, locationPagePath: "https://example.com/club", prospectPagePath: "" }),
  ]);

  assert.deepEqual(result, []);
  assert.throws(
    () => parseLifetimeLocations({ clubs: [] }),
    /response was not an array/,
  );
});

test("Life Time compressed response helper decodes gzip JSON", () => {
  const payload = [openClub()];
  const body = gzipSync(Buffer.from(JSON.stringify(payload)));

  assert.deepEqual(decodeLifetimeJsonBody(body, "gzip"), payload);
  assert.throws(
    () => decodeLifetimeJsonBody(body, "compress"),
    /unsupported content encoding/,
  );
});

test("Life Time fetcher uses the complete official feed request", async () => {
  const requests = [];
  const fetchImpl = async (url, init) => {
    requests.push({ url, init });
    return {
      ok: true,
      json: async () => [openClub()],
    };
  };

  const locations = await fetchLifetimeLocations({ fetchImpl });

  assert.equal(locations.length, 1);
  assert.equal(requests[0].url, LIFETIME_SOURCE_URL);
  assert.equal(requests[0].init.method, "GET");
  assert.equal(requests[0].init.headers.Accept, "application/json");
  assert.equal(requests[0].init.headers["Accept-Encoding"], "gzip");
});

