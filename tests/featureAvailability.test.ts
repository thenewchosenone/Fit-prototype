import { describe, expect, it } from "vitest";
import { resolveWebFeatureAvailability } from "../src/featureAvailability";

describe("web feature availability", () => {
  it("keeps community and messaging deferred by default", () => {
    expect(resolveWebFeatureAvailability(undefined, "development")).toEqual({
      community: false,
      messaging: false
    });
  });

  it("allows an explicit internal override", () => {
    expect(resolveWebFeatureAvailability("true", "development")).toEqual({
      community: true,
      messaging: true
    });
  });
});
