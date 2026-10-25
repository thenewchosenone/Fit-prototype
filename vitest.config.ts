import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    setupFiles: "./tests/setup.ts",
    css: true,
    testTimeout: 30_000,
    exclude: ["e2e/**", "node_modules/**", "dist/**"]
  }
});
