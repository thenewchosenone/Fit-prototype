import { describe, expect, it } from "vitest";
import { isGymCatalogStale } from "../src/platform";

describe("gym directory freshness", () => {
  it("warns only after the 14-day freshness window expires", () => {
    const generatedAt = Date.parse("2026-01-01T00:00:00.000Z");
    const fourteenDays = 14 * 24 * 60 * 60 * 1000;

    expect(isGymCatalogStale(new Date(generatedAt).toISOString(), generatedAt + fourteenDays)).toBe(false);
    expect(isGymCatalogStale(new Date(generatedAt).toISOString(), generatedAt + fourteenDays + 1)).toBe(true);
  });

  it("flags an invalid catalog timestamp so malformed freshness metadata is visible", () => {
    expect(isGymCatalogStale("not-a-date", Date.now())).toBe(true);
  });
});
