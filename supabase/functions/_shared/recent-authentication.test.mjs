import assert from "node:assert/strict";
import test from "node:test";
import { hasRecentAuthentication } from "./recent-authentication.js";

const now = 1_800_000_000;

function token(claims) {
  const payload = btoa(JSON.stringify(claims)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  return `header.${payload}.signature`;
}

test("accepts a recent authentication method timestamp", () => {
  assert.equal(hasRecentAuthentication(token({ amr: [{ method: "password", timestamp: now - 30 }] }), now), true);
});

test("does not treat a freshly refreshed iat as recent authentication", () => {
  assert.equal(hasRecentAuthentication(token({ iat: now, amr: [{ method: "password", timestamp: now - 601 }] }), now), false);
});

test("ignores token refresh and anonymous methods", () => {
  assert.equal(hasRecentAuthentication(token({ amr: [
    { method: "token_refresh", timestamp: now },
    { method: "anonymous", timestamp: now },
  ] }), now), false);
});

test("fails closed for missing, malformed, and too-far-future authentication claims", () => {
  assert.equal(hasRecentAuthentication("not-a-jwt", now), false);
  assert.equal(hasRecentAuthentication(token({ amr: [] }), now), false);
  assert.equal(hasRecentAuthentication(token({ amr: [{ method: "password", timestamp: now + 31 }] }), now), false);
});
