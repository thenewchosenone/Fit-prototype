import assert from "node:assert/strict";
import test from "node:test";

import {
  EDGE_SOURCE_URL,
  ONELIFE_SOURCE_URL,
  WORKOUT_ANYTIME_SOURCE_URL,
  fetchEdgeLocations,
  fetchOnelifeLocations,
  fetchWorkoutAnytimeLocations,
  parseEdgeLocations,
  parseOnelifeLocations,
  parseWorkoutAnytimeLocations,
} from "./regional.mjs";

function workoutHtml(stores) {
  return `<script>var storeDataAry = ${JSON.stringify(stores)};</script>`;
}

test("Workout Anytime parser reads active stores and robustly splits addresses", () => {
  const baseStore = {
    state: "**Alabama**",
    name: "Jacksonville AL",
    slug: "jacksonville-al",
    postID: 8162,
    address: "1555 Pelham Road South,<br />\r\nSte D,<br />\r\nJacksonville, AL 36265",
    city: "Jacksonville",
    stateAbr: "AL",
    status: "active",
    siteurl: "https://workoutanytime.com/",
  };
  const result = parseWorkoutAnytimeLocations(workoutHtml([
    baseStore,
    { ...baseStore },
    {
      ...baseStore,
      postID: 163199,
      name: "Lakewood Park",
      slug: "lakewood-park",
      address: "4806 N. Kings Highway,<br />Fort Pierce,<br />Florida, USA 34951",
      city: "Fort Pierce",
      stateAbr: "FL",
    },
    {
      ...baseStore,
      postID: 8313,
      name: "Cornelia",
      slug: "cornelia",
      address: "378 Habersham Hills Cir Cornelia, GA 30531",
      city: "",
      stateAbr: "GA",
    },
    { ...baseStore, postID: 3, status: "coming_soon" },
    { ...baseStore, postID: 4, stateAbr: "ON" },
  ]));

  assert.deepEqual(result, [
    {
      sourceId: "8162",
      brand: "Workout Anytime",
      name: "Workout Anytime - Jacksonville AL",
      address: "1555 Pelham Road South, Ste D",
      city: "Jacksonville",
      state: "Alabama",
      postalCode: "36265",
      countryCode: "US",
      officialUrl: "https://workoutanytime.com/jacksonville-al",
      status: "Open",
    },
    {
      sourceId: "163199",
      brand: "Workout Anytime",
      name: "Workout Anytime - Lakewood Park",
      address: "4806 N. Kings Highway",
      city: "Fort Pierce",
      state: "Florida",
      postalCode: "34951",
      countryCode: "US",
      officialUrl: "https://workoutanytime.com/lakewood-park",
      status: "Open",
    },
    {
      sourceId: "8313",
      brand: "Workout Anytime",
      name: "Workout Anytime - Cornelia",
      address: "378 Habersham Hills Cir",
      city: "Cornelia",
      state: "Georgia",
      postalCode: "30531",
      countryCode: "US",
      officialUrl: "https://workoutanytime.com/cornelia",
      status: "Open",
    },
  ]);
});

test("Onelife parser excludes hidden, presale, and coming-soon rows", () => {
  const openRow = {
    id: 5472888488,
    deletedAt: 0,
    publishStatus: "PUBLISHED",
    path: "martinsburg",
    values: {
      "1": "Martinsburg",
      "9": "WVA",
      "10": "Martinsburg",
      "11": "830 Foxcroft Ave",
      "12": "25401",
      "89": 0,
      "100": 0,
      "118": 0,
    },
  };
  const result = parseOnelifeLocations({
    objects: [
      openRow,
      { ...openRow },
      { ...openRow, id: 2, values: { ...openRow.values, "89": 1 } },
      { ...openRow, id: 3, values: { ...openRow.values, "100": 1 } },
      { ...openRow, id: 4, values: { ...openRow.values, "118": 1 } },
      { ...openRow, id: 5, publishStatus: "DRAFT" },
      { ...openRow, id: 6, deletedAt: 123 },
      { ...openRow, id: 7, values: { ...openRow.values, "9": "ON" } },
    ],
  });

  assert.deepEqual(result, [{
    sourceId: "5472888488",
    brand: "Onelife Fitness",
    name: "Onelife Fitness - Martinsburg",
    address: "830 Foxcroft Ave",
    city: "Martinsburg",
    state: "West Virginia",
    postalCode: "25401",
    countryCode: "US",
    officialUrl: "https://www.onelifefitness.com/gyms/martinsburg",
    status: "Open",
  }]);
});

test("The Edge parser keeps complete active US clubs", () => {
  const activeClub = {
    abc_club_id: "8148",
    active: 1,
    name: "St Peters, MO",
    address: "4025 Veteran's Memorial Pkwy.",
    city: "St Peters",
    state: "MO",
    zip_code: "6878",
    page_path: "missouri-st-peters",
  };
  const result = parseEdgeLocations([
    activeClub,
    { ...activeClub },
    { ...activeClub, abc_club_id: "2", active: 0 },
    { ...activeClub, abc_club_id: "3", state: "ON" },
    { ...activeClub, abc_club_id: "4", address: "" },
  ]);

  assert.deepEqual(result, [{
    sourceId: "8148",
    brand: "The Edge Fitness Clubs",
    name: "The Edge Fitness Clubs - St Peters, MO",
    address: "4025 Veteran's Memorial Pkwy.",
    city: "St Peters",
    state: "Missouri",
    postalCode: "06878",
    countryCode: "US",
    officialUrl: "https://www.theedgefitnessclubs.com/locations/missouri-st-peters",
    status: "Open",
  }]);
});

test("regional parsers reject payloads whose expected collection disappeared", () => {
  assert.throws(
    () => parseWorkoutAnytimeLocations("<html></html>"),
    /did not contain storeDataAry/,
  );
  assert.throws(
    () => parseOnelifeLocations({ results: [] }),
    /did not contain an objects array/,
  );
  assert.throws(
    () => parseEdgeLocations({ results: [] }),
    /was not an array/,
  );
});

test("regional fetchers use the complete official request shapes", async () => {
  const requests = [];
  const onelifeRow = {
    id: 1,
    deletedAt: 0,
    publishStatus: "PUBLISHED",
    path: "club-one",
    values: {
      "1": "Club One",
      "9": "VA",
      "10": "Reston",
      "11": "1 Main St",
      "12": "20190",
      "89": 0,
      "100": 0,
      "118": 0,
    },
  };
  const fetchImpl = async (url, init) => {
    const requestUrl = String(url);
    requests.push({ url: requestUrl, init });
    if (requestUrl === WORKOUT_ANYTIME_SOURCE_URL) {
      return { ok: true, text: async () => workoutHtml([]) };
    }
    if (requestUrl.startsWith(ONELIFE_SOURCE_URL)) {
      const offset = Number(new URL(requestUrl).searchParams.get("offset"));
      return {
        ok: true,
        json: async () => ({
          objects: [{ ...onelifeRow, id: offset + 1 }],
          total: 2,
        }),
      };
    }
    if (requestUrl === EDGE_SOURCE_URL) {
      return { ok: true, json: async () => [] };
    }
    throw new Error(`Unexpected request: ${requestUrl}`);
  };

  await fetchWorkoutAnytimeLocations({ fetchImpl });
  await fetchOnelifeLocations({ fetchImpl, pageSize: 1 });
  await fetchEdgeLocations({ fetchImpl });

  assert.equal(requests[0].url, WORKOUT_ANYTIME_SOURCE_URL);
  assert.equal(requests[0].init.headers.Accept, "text/html");
  assert.equal(
    requests[1].url,
    `${ONELIFE_SOURCE_URL}?portalId=2094550&limit=1&offset=0`,
  );
  assert.equal(
    requests[2].url,
    `${ONELIFE_SOURCE_URL}?portalId=2094550&limit=1&offset=1`,
  );
  assert.equal(requests[3].url, EDGE_SOURCE_URL);
  assert.equal(requests[3].init.headers.Accept, "application/json, text/plain, */*");
});

test("Workout Anytime fetcher refuses to return a partial active feed", async () => {
  const incompleteStore = {
    postID: 1,
    name: "Incomplete",
    slug: "incomplete",
    status: "active",
    stateAbr: "GA",
    siteurl: "https://workoutanytime.com/",
    address: "Address unavailable",
  };
  const fetchImpl = async () => ({
    ok: true,
    text: async () => workoutHtml([incompleteStore]),
  });

  await assert.rejects(
    fetchWorkoutAnytimeLocations({ fetchImpl }),
    /normalized 0 of 1 active US locations/,
  );
});

