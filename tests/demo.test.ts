import { describe, expect, it } from "vitest";
import { validatePublicDemoEnvironment } from "../src/demoConfig";

describe("public demo environment", () => {
  it("accepts an isolated seeded demo", () => {
    expect(() => validatePublicDemoEnvironment({ VITE_PUBLIC_DEMO: "true", VITE_AUTH_DEMO_MODE: "true" })).not.toThrow();
  });

  it("rejects Supabase configuration in public-demo mode", () => {
    expect(() => validatePublicDemoEnvironment({ VITE_PUBLIC_DEMO: "true", VITE_AUTH_DEMO_MODE: "true", VITE_SUPABASE_URL: "https://example.supabase.co" })).toThrow("must not include Supabase credentials");
    expect(() => validatePublicDemoEnvironment({ VITE_PUBLIC_DEMO: "true", VITE_AUTH_DEMO_MODE: "true", VITE_SUPABASE_ANON_KEY: "not-a-real-key" })).toThrow("must not include Supabase credentials");
  });

  it("rejects a public demo without seeded authentication", () => {
    expect(() => validatePublicDemoEnvironment({ VITE_PUBLIC_DEMO: "true", VITE_AUTH_DEMO_MODE: "false" })).toThrow("require VITE_AUTH_DEMO_MODE=true");
  });

  it("does not constrain future non-demo environments", () => {
    expect(() => validatePublicDemoEnvironment({ VITE_PUBLIC_DEMO: "false", VITE_SUPABASE_URL: "https://example.supabase.co" })).not.toThrow();
  });
});
