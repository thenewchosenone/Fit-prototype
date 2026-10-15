import assert from "node:assert/strict";
import test from "node:test";

import {
  ORANGETHEORY_SOURCE_URL,
  UFC_GYM_SOURCE_URL,
  fetchOrangetheoryLocations,
  fetchUfcGymLocations,
  parseOrangetheoryLocations,
  parseOrangetheoryStudioIndex,
  parseOrangetheoryStudioPage,
  parseUfcGymAppChunk,
  parseUfcGymAppChunkUrl,
  parseUfcGymLocations,
} from "./studios.mjs";

function orangetheoryIndex(overrides = {}) {
  return {
    "physical-state": "AL",
    "physical-city": "Tuscaloosa",
    "physical-address": "1451 Dr Edward Hillard Dr",
    "country-state": "United States",
    "location-id": "studio-0771",
    "studio-status": "Active",
    slug: "tuscaloosa-alabama-0771",
    environment: "PROD",
    ...overrides,
  };
}

function orangetheoryDetails(overrides = {}) {
  return {
    "location-id": "studio-0771",
    name: "Tuscaloosa, AL",
    "studio-status": "Active",
    environment: "PROD",
    "physical-postal-code": "35404",
    "physical-state": "AL",
    "physical-city": "Tuscaloosa",
    "physical-address": "1451 Dr Edward Hillard Dr",
    slug: "tuscaloosa-alabama-0771",
    ...overrides,
  };
}

function studioPage(details) {
  return `<html><script>let studioDetails = ${JSON.stringify(details)}\n</script></html>`;
}

function ufcLocation(overrides = {}) {
  return {
    id: 10073,
    code: "largo",
    type: "UFCGYM",
    status: "OPEN",
    name: "Largo",
    street: "1111 Missouri Ave N",
    city: "Largo",
    state: "FL",
    zip: "33770",
    ...overrides,
  };
}

function asWebpackJsonModule(value) {
  const encoded = JSON.stringify(value)
    .replaceAll("\\", "\\\\")
    .replaceAll("'", "\\'");
  return `35631:function(e){"use strict";e.exports=JSON.parse('${encoded}')}`;
}

test("Orangetheory parsers keep active PROD U.S. studios and enrich official details", () => {
  const active = orangetheoryIndex();
  const index = parseOrangetheoryStudioIndex({
    data: {
      studios: [
        active,
        active,
        orangetheoryIndex({ "location-id": "dev", environment: "DEV" }),
        orangetheoryIndex({
          "location-id": "canada",
          "country-state": "Canada",
        }),
        orangetheoryIndex({
          "location-id": "inactive",
          "studio-status": "Inactive",
        }),
      ],
    },
  });
  assert.equal(index.length, 1);

  const details = parseOrangetheoryStudioPage(
    studioPage(orangetheoryDetails({ name: "Tuscaloosa {Downtown}, AL" })),
  );
  assert.deepEqual(parseOrangetheoryLocations(index, [details]), [
    {
      sourceId: "studio-0771",
      brand: "Orangetheory",
      name: "Orangetheory - Tuscaloosa {Downtown}, AL",
      address: "1451 Dr Edward Hillard Dr",
      city: "Tuscaloosa",
      state: "Alabama",
      postalCode: "35404",
      countryCode: "US",
      officialUrl:
        "https://www.orangetheory.com/en-us/locations/tuscaloosa-alabama-0771",
      status: "Open",
    },
  ]);
});

test("Orangetheory restores the official leading-zero New Jersey ZIP", () => {
  const index = parseOrangetheoryStudioIndex([
    orangetheoryIndex({
      "location-id": "studio-0169",
      slug: "new-providence-new-jersey-0169",
      "physical-address": "1260 Springfield Ave #11A",
      "physical-city": "New Providence",
      "physical-state": "NJ",
    }),
  ]);
  const result = parseOrangetheoryLocations(index, [
    orangetheoryDetails({
      "location-id": "studio-0169",
      name: "New Providence, NJ",
      slug: "new-providence-new-jersey-0169",
      "physical-address": "1260 Springfield Ave #11A",
      "physical-city": "New Providence",
      "physical-state": "NJ",
      "physical-postal-code": "7974",
    }),
  ]);

  assert.equal(result[0].postalCode, "07974");
  assert.throws(
    () =>
      parseOrangetheoryLocations(index, [
        orangetheoryDetails({
          "location-id": "studio-0169",
          name: "New Providence, NJ",
          slug: "new-providence-new-jersey-0169",
          "physical-city": "New Providence",
          "physical-state": "AL",
          "physical-postal-code": "7974",
        }),
      ]),
    /incomplete or mismatched detail data/,
  );
});

test("Orangetheory fetcher paginates with an encoded cursor and fails mismatched detail pages", async () => {
  const secondIndex = orangetheoryIndex({
    "location-id": "studio-0169",
    slug: "new-providence-new-jersey-0169",
    "physical-address": "1260 Springfield Ave #11A",
    "physical-city": "New Providence",
    "physical-state": "NJ",
  });
  const requests = [];
  const fetchImpl = async (url) => {
    requests.push(url);
    if (url === ORANGETHEORY_SOURCE_URL) {
      return {
        ok: true,
        json: async () => ({
          status: "SUCCESS",
          data: {
            count: 1,
            lastEvaluatedKey: "cursor/+?&",
            studios: [orangetheoryIndex()],
          },
        }),
      };
    }
    if (
      url ===
      `${ORANGETHEORY_SOURCE_URL}&lastEvaluatedID=cursor%2F%2B%3F%26`
    ) {
      return {
        ok: true,
        json: async () => ({
          status: "SUCCESS",
          data: { count: 1, studios: [secondIndex] },
        }),
      };
    }
    if (url.endsWith("/tuscaloosa-alabama-0771")) {
      return {
        ok: true,
        text: async () => studioPage(orangetheoryDetails()),
      };
    }
    if (url.endsWith("/new-providence-new-jersey-0169")) {
      return {
        ok: true,
        text: async () =>
          studioPage(
            orangetheoryDetails({
              "location-id": "studio-0169",
              name: "New Providence, NJ",
              slug: "new-providence-new-jersey-0169",
              "physical-address": "1260 Springfield Ave #11A",
              "physical-city": "New Providence",
              "physical-state": "NJ",
              "physical-postal-code": "7974",
            }),
          ),
      };
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  const result = await fetchOrangetheoryLocations({
    fetchImpl,
    detailConcurrency: 2,
  });
  assert.equal(result.length, 2);
  assert.equal(result[1].postalCode, "07974");
  assert.ok(
    requests.includes(
      `${ORANGETHEORY_SOURCE_URL}&lastEvaluatedID=cursor%2F%2B%3F%26`,
    ),
  );

  await assert.rejects(
    fetchOrangetheoryLocations({
      detailConcurrency: 1,
      fetchImpl: async (url) => {
        if (url === ORANGETHEORY_SOURCE_URL) {
          return {
            ok: true,
            json: async () => ({
              status: "SUCCESS",
              data: { count: 1, studios: [orangetheoryIndex()] },
            }),
          };
        }
        return {
          ok: true,
          text: async () =>
            studioPage(
              orangetheoryDetails({ "location-id": "wrong-studio" }),
            ),
        };
      },
    }),
    /mismatched location-id/,
  );
});

test("UFC GYM parser keeps complete OPEN locations in USPS states", () => {
  const result = parseUfcGymLocations([
    ufcLocation(),
    ufcLocation({ id: 2, code: "presale", status: "PRESALE" }),
    ufcLocation({ id: 3, code: "ontario", state: "ON" }),
  ]);

  assert.deepEqual(result, [
    {
      sourceId: "10073",
      brand: "UFC GYM",
      name: "UFC GYM - Largo",
      address: "1111 Missouri Ave N",
      city: "Largo",
      state: "Florida",
      postalCode: "33770",
      countryCode: "US",
      officialUrl: "https://www.ufcgym.com/locations/largo",
      status: "Open",
    },
  ]);

  assert.throws(
    () => parseUfcGymLocations([ufcLocation(), ufcLocation()]),
    /duplicate OPEN U\.S\. location id/,
  );
  assert.throws(
    () =>
      parseUfcGymLocations([
        ufcLocation({ id: 4, code: "missing-zip", zip: "" }),
      ]),
    /has incomplete data/,
  );
});

test("UFC GYM chunk parser decodes its exported first-party JSON", () => {
  const chunk = [
    asWebpackJsonModule({ unrelated: true }),
    asWebpackJsonModule([
      ufcLocation({ name: "Largo's UFC GYM", street: "1111 Missouri \\ Ave" }),
    ]),
  ].join(",");

  const result = parseUfcGymAppChunk(chunk);
  assert.equal(result.length, 1);
  assert.equal(result[0].name, "UFC GYM - Largo's UFC GYM");
  assert.equal(result[0].address, "1111 Missouri \\ Ave");
});

test("UFC GYM fetcher discovers the current official _app chunk", async () => {
  const chunkUrl =
    "https://www.ufcgym.com/_next/static/chunks/pages/_app-deadbeef.js?v=1";
  const html = `<script src="/_next/static/chunks/pages/_app-deadbeef.js?v=1"></script>`;
  assert.equal(parseUfcGymAppChunkUrl(html), chunkUrl);
  assert.throws(
    () =>
      parseUfcGymAppChunkUrl(
        '<script src="https://example.com/_next/static/chunks/pages/_app-bad.js"></script>',
      ),
    /non-first-party/,
  );

  const requests = [];
  const fetchImpl = async (url) => {
    requests.push(url);
    if (url === UFC_GYM_SOURCE_URL) {
      return { ok: true, text: async () => html };
    }
    if (url === chunkUrl) {
      return {
        ok: true,
        text: async () => asWebpackJsonModule([ufcLocation()]),
      };
    }
    throw new Error(`Unexpected request: ${url}`);
  };

  const result = await fetchUfcGymLocations({ fetchImpl });
  assert.equal(result.length, 1);
  assert.deepEqual(requests, [UFC_GYM_SOURCE_URL, chunkUrl]);
});

