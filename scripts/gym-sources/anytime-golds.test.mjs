import assert from "node:assert/strict";
import test from "node:test";
import {
  ANYTIME_SOURCE_URL,
  fetchAnytimeLocations,
  parseAnytimeLocations,
  parseGoldsLocations,
} from "./anytime-golds.mjs";

test("Anytime API parser keeps only complete open U.S. locations", () => {
  const result = parseAnytimeLocations({ items: [
    {
      id: "club-3573",
      name: "Kailua",
      status: "OPEN",
      address: {
        address1: "26 Hoolai St",
        city: "Kailua",
        state: "Hawaii",
        country_abbr: "USA",
        postal_code: "96734",
      },
    },
    {
      id: "club-9999",
      name: "Future",
      status: "COMING_SOON",
      address: {
        address1: "1 Main St",
        city: "Austin",
        state: "Texas",
        country_abbr: "USA",
        postal_code: "78701",
      },
    },
  ] });

  assert.deepEqual(result, [{
    sourceId: "club-3573",
    brand: "Anytime Fitness",
    name: "Anytime Fitness - Kailua",
    address: "26 Hoolai St",
    city: "Kailua",
    state: "Hawaii",
    postalCode: "96734",
    countryCode: "US",
    officialUrl: "https://www.anytimefitness.com/locations",
    status: "Open",
  }]);
});

test("Anytime fetcher uses the complete official U.S. endpoint", async () => {
  const requests = [];
  const fetchImpl = async (url, init) => {
    requests.push({ url, init });
    return { ok: true, json: async () => ({ items: [] }) };
  };

  await assert.rejects(fetchAnytimeLocations({ fetchImpl }), /no open U\.S\. locations/);
  assert.equal(requests[0].url, ANYTIME_SOURCE_URL);
  assert.equal(requests[0].init.headers.Accept, "application/json");
});

test("Gold's parser keeps complete open U.S. gyms", () => {
  const result = parseGoldsLocations([
    { gym_id: 2, gym_name: "Rosslyn", address: "1700 North Moore Street", city: "Arlington", state: "VA", zip: "22209", country: "US", gym_status: "open", gym_slug: "rosslyn" },
    { gym_id: 3, gym_name: "Future", address: "1 Main St", city: "Austin", state: "TX", zip: "78701", country: "US", gym_status: "presale", gym_slug: "future" },
    { gym_id: 4, gym_name: "Toronto", address: "1 King St", city: "Toronto", state: "ON", zip: "M5H 1A1", country: "CA", gym_status: "open", gym_slug: "toronto" }
  ]);
  assert.equal(result.length, 1);
  assert.equal(result[0].state, "Virginia");
  assert.equal(result[0].officialUrl, "https://www.goldsgym.com/locations/rosslyn/");
});
