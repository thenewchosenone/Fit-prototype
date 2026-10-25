import { render, screen } from "@testing-library/react";
import { HashRouter } from "react-router-dom";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { AuthProvider } from "../src/auth";
import { seedState } from "../src/data";
import { TrackerProvider } from "../src/store";

describe("focused web launch", () => {
  beforeAll(() => vi.stubEnv("VITE_ENABLE_DEFERRED_FEATURES", "false"));
  afterAll(() => vi.unstubAllEnvs());

  it("removes deferred social navigation and redirects old community routes", async () => {
    const { default: App } = await import("../src/App");
    window.location.hash = "#/community";

    render(
      <HashRouter>
        <AuthProvider>
          <TrackerProvider initialState={structuredClone(seedState)}>
            <App />
          </TrackerProvider>
        </AuthProvider>
      </HashRouter>
    );

    expect(await screen.findByRole("heading", { name: /Welcome back/i })).toBeVisible();
    expect(screen.queryByRole("link", { name: "Community" })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Messages" })).not.toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Community highlight" })).not.toBeInTheDocument();
  });
});
