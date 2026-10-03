import { beforeEach, describe, expect, it } from "vitest";
import { profileMediaStore } from "../src/profileMedia";

describe("browser-local profile media", () => {
  beforeEach(async () => { await profileMediaStore.clear(); localStorage.clear(); });

  it("stores, replaces, removes, and clears photos outside tracker localStorage", async () => {
    const first = new Blob(["first"], { type: "image/webp" });
    const replacement = new Blob(["replacement"], { type: "image/webp" });
    await profileMediaStore.save("user-robert", first);
    expect((await profileMediaStore.get("user-robert"))?.size).toBe(first.size);
    await profileMediaStore.save("user-robert", replacement);
    expect((await profileMediaStore.get("user-robert"))?.size).toBe(replacement.size);
    expect(localStorage.length).toBe(0);
    await profileMediaStore.remove("user-robert");
    expect(await profileMediaStore.get("user-robert")).toBeNull();
    await profileMediaStore.save("user-robert", first);
    await profileMediaStore.clear();
    expect(await profileMediaStore.get("user-robert")).toBeNull();
  });
});
