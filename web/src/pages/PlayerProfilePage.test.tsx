import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const testAuth = vi.hoisted(() => ({
  value: {
    ready: true,
    user: { id: "player-1", email: "player@example.com" } as { id: string; email: string } | null,
    entitlement: { isPro: true, expiresAt: null } as { isPro: boolean; expiresAt: string | null } | null,
    error: null as string | null,
    refreshEntitlement: vi.fn().mockResolvedValue(undefined),
    signOut: vi.fn().mockResolvedValue(undefined),
    deleteAccount: vi.fn().mockResolvedValue(undefined)
  }
}));
const sync = vi.hoisted(() => ({
  fetchCloudProgress: vi.fn(),
  refreshAccountProgress: vi.fn().mockResolvedValue(undefined)
}));

vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => testAuth.value }));
vi.mock("../features/sync/progressSync", () => ({
  backwordCloudRecord: (progress: unknown) => progress,
  crosswordCloudRecord: (progress: unknown) => progress,
  fetchCloudProgress: sync.fetchCloudProgress,
  refreshAccountProgress: sync.refreshAccountProgress
}));

import { PlayerProfilePage } from "./PlayerProfilePage";

function renderPage() {
  return render(<MemoryRouter initialEntries={["/player-profile"]}><Routes>
    <Route path="/player-profile" element={<PlayerProfilePage />} />
    <Route path="/sign-in" element={<p>Sign in</p>} />
    <Route path="/home" element={<p>Home</p>} />
  </Routes></MemoryRouter>);
}

describe("PlayerProfilePage", () => {
  beforeEach(() => {
    localStorage.clear();
    testAuth.value = {
      ready: true,
      user: { id: "player-1", email: "player@example.com" },
      entitlement: { isPro: true, expiresAt: null },
      error: null,
      refreshEntitlement: vi.fn().mockResolvedValue(undefined),
      signOut: vi.fn().mockResolvedValue(undefined),
      deleteAccount: vi.fn().mockResolvedValue(undefined)
    };
    sync.fetchCloudProgress.mockResolvedValue([]);
    sync.refreshAccountProgress.mockResolvedValue(undefined);
  });

  it("shows the signed-in account and keeps scoring details out of the dashboard", async () => {
    const user = userEvent.setup();
    renderPage();

    expect(screen.getByRole("heading", { name: "PLAYER PROFILE" })).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Backword home" })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Download Backword on the App Store" })).not.toBeInTheDocument();
    const footer = screen.getByRole("navigation", { name: "Footer" });
    expect(within(footer).getByRole("link", { name: "Player Profile" })).toHaveAttribute("href", "/player-profile");
    expect(screen.getByText("player@example.com")).toBeInTheDocument();
    const proStatus = screen.getByText("is active for this account").closest("p");
    expect(proStatus?.querySelector(".player-profile__pro-logo")).toHaveAttribute("src", "/brand/backword-pro.png");
    expect(screen.getByText("0 / 150 pts")).toBeInTheDocument();
    await waitFor(() => expect(sync.fetchCloudProgress).toHaveBeenCalledTimes(3));
    expect(screen.getByText("Weekly")).toBeInTheDocument();

    const rating = screen.getByLabelText("Overall rating");
    const account = screen.getByLabelText("Account summary");
    const scoring = screen.getByRole("button", { name: "HOW SCORING WORKS" });
    const rollingWindow = screen.getByText("Rolling 14-day window");
    const [desktopSignOut, mobileSignOut] = screen.getAllByRole("button", { name: "Sign Out" });
    const [desktopDeleteAccount, mobileDeleteAccount] = screen.getAllByRole("button", { name: "Delete Account" });
    const breakdown = screen.getByRole("heading", { name: "LAST 14 DAYS" }).closest("section");
    expect(rating.compareDocumentPosition(scoring) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(scoring.compareDocumentPosition(rollingWindow) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(rollingWindow.compareDocumentPosition(account) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(scoring.compareDocumentPosition(account) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(account.compareDocumentPosition(desktopSignOut) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(desktopSignOut.compareDocumentPosition(desktopDeleteAccount) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(breakdown?.compareDocumentPosition(mobileSignOut) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(mobileSignOut.compareDocumentPosition(mobileDeleteAccount) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(scoring).not.toHaveTextContent("⌃");
    expect(scoring).toHaveAttribute("aria-haspopup", "dialog");

    await user.click(scoring);
    expect(screen.getByRole("dialog", { name: "How scoring works" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close scoring details" }));
    expect(screen.queryByRole("dialog", { name: "How scoring works" })).not.toBeInTheDocument();
  });

  it("signs out from the profile and returns Home", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.click(screen.getAllByRole("button", { name: "Sign Out" })[0]);

    expect(testAuth.value.signOut).toHaveBeenCalledOnce();
    expect(await screen.findByText("Home")).toBeInTheDocument();
  });

  it("confirms account deletion from the profile and returns Home", async () => {
    const user = userEvent.setup();
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderPage();
    await user.click(screen.getAllByRole("button", { name: "Delete Account" })[0]);

    expect(testAuth.value.deleteAccount).toHaveBeenCalledOnce();
    expect(await screen.findByText("Home")).toBeInTheDocument();
  });

  it("redirects guests to sign in with a return destination", () => {
    testAuth.value.user = null;
    renderPage();

    expect(screen.getByText("Sign in")).toBeInTheDocument();
  });

  it("shows an account refresh error", async () => {
    sync.fetchCloudProgress.mockRejectedValueOnce(new Error("Cloud unavailable"));
    renderPage();

    expect(await screen.findByRole("alert")).toHaveTextContent("Cloud unavailable");
  });

  it("shows a rolling-window loading indicator until profile stats are available", async () => {
    let resolveFetch: (records: []) => void = () => undefined;
    const pendingFetch = new Promise<[]>(resolve => {
      resolveFetch = resolve;
    });
    sync.fetchCloudProgress.mockReturnValue(pendingFetch);
    renderPage();

    expect(await screen.findByRole("status")).toHaveTextContent("Loading your 14-day stats…");
    resolveFetch([]);

    await waitFor(() => expect(screen.queryByRole("status")).not.toBeInTheDocument());
  });

  it("compensates for transparent padding around the Pro logo", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.player-profile__pro-logo\s*\{[^}]*\bmargin-right:\s*-14px/);
  });
});
