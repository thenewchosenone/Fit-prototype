import assert from "node:assert/strict";
import test from "node:test";

import {
  EOS_SOURCE_URL,
  YOUFIT_SOURCE_URL,
  fetchEosLocations,
  fetchYouFitLocations,
  parseEosLocations,
  parseYouFitLocations,
} from "./eos-youfit.mjs";

test("parseEosLocations keeps only open first-party US clubs", () => {
  const openClub = {
    id: "club-1",
    clubId: "club-1",
    name: "Fullerton: Starbuck St/Hughes Dr",
    street: "1973 W Malvern Ave",
    city: "Fullerton",
    state: "CA",
    zipCode: "92833",
    status: "Open",
    permalink: "fullerton-starbuck-st-hughes-dr",
    isExternal: false,
  };

  const result = parseEosLocations({
    clubs: [
      openClub,
      { ...openClub },
      { ...openClub, id: "club-2", clubId: "club-2", status: "ComingSoon" },
      { ...openClub, id: "club-3", clubId: "club-3", isExternal: true },
      { ...openClub, id: "club-4", clubId: "club-4", state: "ON" },
      { ...openClub, id: "club-5", clubId: "club-5", street: "" },
    ],
  });

  assert.deepEqual(result, [
    {
      sourceId: "club-1",
      brand: "EOS Fitness",
      name: "EOS Fitness - Fullerton: Starbuck St/Hughes Dr",
      address: "1973 W Malvern Ave",
      city: "Fullerton",
      state: "California",
      postalCode: "92833",
      countryCode: "US",
      officialUrl:
        "https://www.eosfitness.com/gym/fullerton-starbuck-st-hughes-dr",
      status: "Open",
    },
  ]);
});

test("parseYouFitLocations reads the embedded official directory data", () => {
  const locations = [
    {
      id: 1805914,
      title: "YouFit Gyms Weston<br>",
      address: {
        location: "us",
        street1: "15451 Southwest 13 Lane,",
        street2: null,
        city: "Sunrise",
        state: "FL",
        zip: "33326",
      },
      url: "locations/florida/weston",
    },
    {
      id: 2,
      title: "YouFit Gyms Toronto",
      address: {
        location: "ca",
        street1: "1 King St",
        city: "Toronto",
        state: "ON",
        zip: "M5H 1A1",
      },
      url: "locations/canada/toronto",
    },
  ];
  const encodedLocations = JSON.stringify(locations).replaceAll("'", "&#39;");
  const html = `<style>[data-locations='0'] { display: none }</style>
    <section data-locations='${encodedLocations}'></section>`;

  assert.deepEqual(parseYouFitLocations(html), [
    {
      sourceId: "1805914",
      brand: "YouFit",
      name: "YouFit Gyms - Weston",
      address: "15451 Southwest 13 Lane",
      city: "Sunrise",
      state: "Florida",
      postalCode: "33326",
      countryCode: "US",
      officialUrl: "https://youfit.com/locations/florida/weston",
      status: "Open",
    },
  ]);
});

test("parsers reject source payloads whose expected collection disappeared", () => {
  assert.throws(
    () => parseEosLocations({ results: [] }),
    /did not contain a clubs array/,
  );
  assert.throws(
    () => parseYouFitLocations("<html></html>"),
    /did not contain embedded location data/,
  );
});

test("fetch helpers use the official request shapes", async () => {
  const requests = [];
  const fetchImpl = async (url, init) => {
    requests.push({ url, init });
    if (url === EOS_SOURCE_URL) {
      return {
        ok: true,
        json: async () => ({ clubs: [] }),
      };
    }
    return {
      ok: true,
      text: async () => "<section data-locations='[]'></section>",
    };
  };

  await fetchEosLocations({ fetchImpl });
  await fetchYouFitLocations({ fetchImpl });

  assert.equal(requests[0].url, EOS_SOURCE_URL);
  assert.equal(requests[0].init.method, "POST");
  assert.deepEqual(JSON.parse(requests[0].init.body), {
    isGymStatusComingSoonIncluded: false,
    excludeExternalClubs: true,
  });
  assert.equal(requests[1].url, YOUFIT_SOURCE_URL);
  assert.equal(requests[1].init.headers.Accept, "text/html");
});
