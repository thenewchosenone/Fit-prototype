import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AuthChangeEvent, Session } from "@supabase/supabase-js";

const mock = vi.hoisted(() => ({
  listeners: [] as Array<(event: AuthChangeEvent, session: Session | null) => void>,
  listener(event: AuthChangeEvent, session: Session | null) { for (const fn of this.listeners) fn(event, session); },
  getSession: vi.fn(), signInWithPassword: vi.fn(), updateUser: vi.fn(), signOut: vi.fn(), resetPasswordForEmail: vi.fn()
}));
vi.mock("@supabase/supabase-js", () => ({
  createClient: () => ({ auth: { ...mock, onAuthStateChange: (listener: typeof mock.listener) => {
    mock.listeners.push(listener);
    return { data: { subscription: { unsubscribe() { mock.listeners = mock.listeners.filter(fn => fn !== listener); } } } };
  } } })
}));
vi.stubEnv("VITE_SUPABASE_URL", "https://example.supabase.co");
vi.stubEnv("VITE_SUPABASE_ANON_KEY", "test-public-key");
const { AuthProvider } = await import("../src/auth");
const { AuthPage } = await import("../src/AuthPages");
const session = { user: { id: "recovery-user", email: "recover@example.test" } } as Session;

function show(mode: "reset" | "login" | "forgot" = "reset") {
  render(<MemoryRouter initialEntries={[`/${mode}`]}><AuthProvider><Routes>
    <Route path="/reset" element={<AuthPage mode="reset" />} />
    <Route path="/login" element={<AuthPage mode="login" />} />
    <Route path="/forgot" element={<AuthPage mode="forgot" />} />
    <Route path="/leaderboards" element={<p>Signed in</p>} />
  </Routes></AuthProvider></MemoryRouter>);
}

beforeEach(() => {
  vi.clearAllMocks();
  mock.listener("SIGNED_OUT", null);
  mock.getSession.mockResolvedValue({ data: { session: null }, error: null });
  mock.signInWithPassword.mockResolvedValue({ error: null });
  mock.updateUser.mockResolvedValue({ error: null });
  mock.resetPasswordForEmail.mockResolvedValue({ error: null });
  mock.signOut.mockImplementation(async () => { mock.listener?.("SIGNED_OUT", null); return { error: null }; });
});

describe("password recovery", () => {
  it("does not accept an existing login session as verified recovery", async () => {
    mock.getSession.mockResolvedValue({ data: { session }, error: null });
    show();
    expect(await screen.findByRole("heading", { name: "Request a new reset link" })).toBeVisible();
    expect(screen.queryByLabelText("New password")).not.toBeInTheDocument();
    expect(mock.updateUser).not.toHaveBeenCalled();
  });

  it("rejects an expired callback even if a prior session remains", async () => {
    mock.getSession.mockResolvedValue({ data: { session }, error: new Error("Expired link") });
    show();
    expect(await screen.findByRole("heading", { name: "Request a new reset link" })).toBeVisible();
  });

  it("checks confirmation, updates the verified account, and returns to sign-in", async () => {
    show();
    await screen.findByRole("heading", { name: "Request a new reset link" });
    mock.getSession.mockResolvedValue({ data: { session }, error: null });
    act(() => mock.listener?.("PASSWORD_RECOVERY", session));
    expect(screen.getByText(/Updating the password for recover@example.test/)).toBeVisible();
    const user = userEvent.setup();
    await user.type(screen.getByLabelText(/^New password/), "new-password-123");
    await user.type(screen.getByLabelText("Confirm new password"), "other-password-123");
    await user.click(screen.getByRole("button", { name: "Update password" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("passwords do not match");
    expect(mock.updateUser).not.toHaveBeenCalled();
    await user.clear(screen.getByLabelText("Confirm new password"));
    await user.type(screen.getByLabelText("Confirm new password"), "new-password-123");
    await user.click(screen.getByRole("button", { name: "Update password" }));
    expect(await screen.findByRole("heading", { name: "Welcome back" })).toBeVisible();
    expect(screen.getByRole("status")).toHaveTextContent("Your password has been updated");
    expect(mock.updateUser).toHaveBeenCalledWith({ password: "new-password-123" });
    expect(mock.signOut).toHaveBeenCalledWith({ scope: "local" });
  });

  it("captures recovery before React mounts", async () => {
    mock.getSession.mockResolvedValue({ data: { session }, error: null });
    mock.listener("PASSWORD_RECOVERY", session);
    show();
    expect(await screen.findByRole("heading", { name: "Choose a new password" })).toBeVisible();
  });

  it("revokes the reset form when the active account changes", async () => {
    show();
    await screen.findByRole("heading", { name: "Request a new reset link" });
    mock.getSession.mockResolvedValue({ data: { session }, error: null });
    act(() => mock.listener?.("PASSWORD_RECOVERY", session));
    act(() => mock.listener?.("SIGNED_IN", { user: { id: "another-user" } } as Session));
    expect(screen.queryByLabelText("New password")).not.toBeInTheDocument();
  });

  it("allows existing eight-character passwords at sign-in", async () => {
    show("login");
    const user = userEvent.setup();
    await user.type(screen.getByLabelText("Email"), "recover@example.test");
    await user.type(screen.getByLabelText("Password"), "eight123");
    expect(screen.getByLabelText("Password")).not.toHaveAttribute("minlength");
    await user.click(screen.getByRole("button", { name: "Sign in" }));
    await waitFor(() => expect(mock.signInWithPassword).toHaveBeenCalledWith({ email: "recover@example.test", password: "eight123" }));
  });

  it("keeps request errors retryable", async () => {
    mock.resetPasswordForEmail.mockRejectedValue(new Error("offline"));
    show("forgot");
    const user = userEvent.setup();
    await user.type(screen.getByLabelText("Email"), "recover@example.test");
    await user.click(screen.getByRole("button", { name: "Send reset link" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Check your connection");
    expect(screen.getByRole("button", { name: "Send reset link" })).toBeEnabled();
  });
});
