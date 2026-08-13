import assert from "node:assert/strict";
import test from "node:test";

import {
  fetchCrunchLocations,
  fetchLaFitnessLocations,
  parseCrunchLocations,
  parseLaFitnessLocations,
} from "./crunch-la.mjs";

test("parseCrunchLocations keeps open US clubs and normalizes their fields", () => {
  const result = parseCrunchLocations({
    clubs: [
      {
        id: 607,
        name: "Six\u00a0Mile",
        slug: "six-mile",
        status: "open",
        address: {
          address_1: "9375 6 Mile Cypress Pkwy",
          address_2: "Suite 210",
          city: "Fort Myers",
          state: "FL",
          zip: "33966",
          country_code: "US",
        },
      },
      {
        id: 999,
        name: "No Online Sales",
        slug: "no-online-sales",
        status: "open_(no_online_sales)",
        address: {
          address_1: "1 Main St",
          address_2: "",
          city: "Austin",
          state: "TX",
          zip: "78701",
          country_code: "US",
        },
      },
      {
        id: 1000,
        name: "Coming Soon",
        slug: "coming-soon",
        status: "coming_soon",
        address: {
          address_1: "2 Main St",
          city: "Austin",
          state: "TX",
          zip: "78702",
          country_code: "US",
        },
      },
      {
        id: 1001,
        name: "Costa Rica",
        slug: "costa-rica",
        status: "open",
        address: {
          address_1: "3 Main St",
          city: "San Jose",
          state: "SJ",
          zip: "10101",
          country_code: "CR",
        },
      },
    ],
  });

  assert.deepEqual(result, [
    {
      sourceId: "607",
      brand: "Crunch Fitness",
      name: "Six Mile",
      address: "9375 6 Mile Cypress Pkwy, Suite 210",
      city: "Fort Myers",
      state: "FL",
      postalCode: "33966",
      countryCode: "US",
      officialUrl: "https://www.crunch.com/locations/six-mile",
      status: "Open",
    },
    {
      sourceId: "999",
      brand: "Crunch Fitness",
      name: "No Online Sales",
      address: "1 Main St",
      city: "Austin",
      state: "TX",
      postalCode: "78701",
      countryCode: "US",
      officialUrl: "https://www.crunch.com/locations/no-online-sales",
      status: "Open",
    },
  ]);
});

test("parseLaFitnessLocations keeps only open US LA Fitness clubs", () => {
  const result = parseLaFitnessLocations({
    d: [
      {
        ClubID: 1042,
        Description: "CHANDLER - ARIZONA AVE",
        ClubStatus: 1,
        IsEsporta: false,
        BrandId: 0,
        State: "AZ",
        City: "CHANDLER",
        Address: "3985 S ARIZONA AVE<br />CHANDLER,AZ 85248",
        ClubHomeURL: "clubhome.aspx?clubid=1042&amp;Chandler-Arizona+GYM",
      },
      {
        ClubID: 1078,
        Description: "EDMONTON - 186TH ST. NW",
        ClubStatus: 1,
        IsEsporta: false,
        BrandId: 0,
        State: "AB",
        City: "EDMONTON",
        Address: "10167 186TH ST NW<br />EDMONTON,AB T5S 0G5",
      },
      {
        ClubID: 2000,
        Description: "ESPORTA",
        ClubStatus: 1,
        IsEsporta: true,
        BrandId: 1,
        State: "FL",
        City: "MIAMI",
        Address: "1 MAIN ST<br />MIAMI,FL 33101",
      },
      {
        ClubID: 2001,
        Description: "COMING SOON",
        ClubStatus: 12,
        IsEsporta: false,
        BrandId: 0,
        State: "TX",
        City: "AUSTIN",
        Address: "2 MAIN ST<br />AUSTIN,TX 78701",
      },
    ],
  });

  assert.deepEqual(result, [
    {
      sourceId: "1042",
      brand: "LA Fitness",
      name: "CHANDLER - ARIZONA AVE",
      address: "3985 S ARIZONA AVE",
      city: "CHANDLER",
      state: "AZ",
      postalCode: "85248",
      countryCode: "US",
      officialUrl:
        "https://www.lafitness.com/Pages/clubhome.aspx?clubid=1042&Chandler-Arizona+GYM",
      status: "Open",
    },
  ]);
});

test("fetch helpers use the official request shapes", async () => {
  const requests = [];
  const fetchImpl = async (url, init) => {
    requests.push({ url, init });
    return {
      ok: true,
      json: async () => (url.includes("crunch.com") ? { clubs: [] } : { d: [] }),
    };
  };

  await fetchCrunchLocations({ fetchImpl });
  await fetchLaFitnessLocations({ fetchImpl });

  assert.equal(requests[0].url, "https://www.crunch.com/load-clubs");
  assert.equal(requests[0].init.headers.Accept, "application/json");
  assert.equal(
    requests[1].url,
    "https://www.lafitness.com/Pages/GetClubLocations.aspx/GetClubLocation",
  );
  assert.equal(requests[1].init.method, "POST");
  assert.equal(requests[1].init.body, "{}");
});
