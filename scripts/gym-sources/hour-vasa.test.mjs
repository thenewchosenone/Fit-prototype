import assert from "node:assert/strict";
import test from "node:test";

import {
  HOUR_FITNESS_SOURCE_URL,
  VASA_SOURCE_URL,
  fetch24HourFitnessLocations,
  fetchVasaLocations,
  parse24HourFitnessLocations,
  parseVasaLocations,
} from "./hour-vasa.mjs";

test("24 Hour Fitness parser keeps complete open clubs", () => {
  const result = parse24HourFitnessLocations([
    {
      clubNumber: "00351",
      name: "Alameda Ave (Denver)",
      clubStatus: "Open",
      address: {
        street: "4120 E. Alameda Avenue",
        streetLine2: "Colorado Plaza",
        city: "Denver",
        state: "CO",
        zip: "80246",
      },
    },
    {
      clubNumber: "00999",
      name: "Temporarily Closed",
      clubStatus: "Temporarily closed",
      address: { street: "1 Main St", city: "Denver", state: "CO", zip: "80202" },
    },
  ]);

  assert.deepEqual(result, [{
    sourceId: "00351",
    brand: "24 Hour Fitness",
    name: "24 Hour Fitness - Alameda Ave (Denver)",
    address: "4120 E. Alameda Avenue, Colorado Plaza",
    city: "Denver",
    state: "Colorado",
    postalCode: "80246",
    countryCode: "US",
    officialUrl: "https://www.24hourfitness.com/Website/Club/00351",
    status: "Open",
  }]);
});

test("VASA parser excludes coming-soon locations", () => {
  const location = {
    id: 455764,
    status: "publish",
    link: "https://vasafitness.com/locations/wi/menasha/",
    title: { rendered: "Menasha" },
    acf: {
      location_details: [{
        gym_status: "now-open",
        address_line_1: "1700 S Appleton Rd",
        address_line_2: "",
        city: "Menasha",
        state: "WI",
        zip: "54952",
      }],
    },
  };

  const result = parseVasaLocations([
    location,
    { ...location, id: 2, acf: { location_details: [{ ...location.acf.location_details[0], gym_status: "coming-soon" }] } },
  ]);

  assert.equal(result.length, 1);
  assert.equal(result[0].name, "VASA Fitness - Menasha");
  assert.equal(result[0].state, "Wisconsin");
});

test("24 Hour Fitness and VASA fetchers use their complete official endpoints", async () => {
  const requests = [];
  const fetchImpl = async (url, init) => {
    requests.push({ url: String(url), init });
    return {
      ok: true,
      headers: { get: () => "1" },
      json: async () => [],
    };
  };

  await fetch24HourFitnessLocations({ fetchImpl });
  await fetchVasaLocations({ fetchImpl });

  assert.equal(requests[0].url, HOUR_FITNESS_SOURCE_URL);
  assert.equal(requests[1].url, `${VASA_SOURCE_URL}?per_page=100&page=1`);
});

