import assert from "node:assert/strict";
import test from "node:test";
import { parseAnytimeDirectoryHtml, parseGoldsLocations } from "./anytime-golds.mjs";

test("Anytime parser keeps only complete open U.S. directory rows", () => {
  const html = `<div class="location-row"><span>Abbeville, LA</span><span>3015 Veterans Memorial Dr</span><span>70510</span><span>Open</span></div>
    <div class="location-row"><span>Austin, TX</span><span>1 Main St</span><span>78701</span><span>Coming Soon</span></div>`;
  assert.deepEqual(parseAnytimeDirectoryHtml(html), [{
    brand: "Anytime Fitness",
    name: "Anytime Fitness - Abbeville",
    address: "3015 Veterans Memorial Dr",
    city: "Abbeville",
    state: "Louisiana",
    postalCode: "70510",
    countryCode: "US",
    officialUrl: "https://www.anytimefitness.com/locations",
    status: "Open"
  }]);
});

test("Anytime parser fails clearly on the official security challenge", () => {
  assert.throws(() => parseAnytimeDirectoryHtml("Additional security check is required by Incapsula"), /security challenge/);
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
