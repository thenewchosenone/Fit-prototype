import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  testMatch: "release-routes.spec.ts",
  workers: 1,
  webServer: {
    command: "pnpm preview --host 127.0.0.1 --port 4173",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: false,
    timeout: 120_000
  },
  use: {
    baseURL: "http://127.0.0.1:4173",
    trace: "retain-on-failure"
  },
  expect: {
    timeout: 10_000
  },
  projects: [
    {
      name: "release-desktop",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1440, height: 900 }
      }
    },
    {
      name: "release-mobile",
      use: {
        ...devices["Pixel 7"],
        viewport: { width: 390, height: 844 }
      }
    }
  ]
});
