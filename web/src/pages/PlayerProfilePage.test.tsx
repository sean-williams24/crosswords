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
    entitlement: { isPro: true, expiresAt: null, provider: "apple" } as { isPro: boolean; expiresAt: string | null; provider?: "apple" | "stripe" } | null,
    entitlementWarning: null as string | null,
    refreshEntitlement: vi.fn().mockResolvedValue(undefined),
    signOut: vi.fn().mockResolvedValue(undefined),
    deleteAccount: vi.fn().mockResolvedValue({ hasApplePurchase: true, hasStripeSubscription: false }),
    finishAccountDeletion: vi.fn().mockResolvedValue(undefined)
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
    <Route path="/" element={<p>Home</p>} />
  </Routes></MemoryRouter>);
}

describe("PlayerProfilePage", () => {
  beforeEach(() => {
    localStorage.clear();
    testAuth.value = {
      ready: true,
      user: { id: "player-1", email: "player@example.com" },
      entitlement: { isPro: true, expiresAt: null, provider: "apple" },
      entitlementWarning: null,
      refreshEntitlement: vi.fn().mockResolvedValue(undefined),
      signOut: vi.fn().mockResolvedValue(undefined),
      deleteAccount: vi.fn().mockResolvedValue({ hasApplePurchase: true, hasStripeSubscription: false }),
      finishAccountDeletion: vi.fn().mockImplementation(async () => { testAuth.value.user = null; })
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
    expect(screen.queryByRole("link", { name: /Manage web subscription through Link/ })).not.toBeInTheDocument();
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
    expect(breakdown).not.toBeNull();
    expect(breakdown!.compareDocumentPosition(mobileSignOut) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(mobileSignOut.compareDocumentPosition(mobileDeleteAccount) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(scoring).not.toHaveTextContent("⌃");
    expect(scoring).toHaveAttribute("aria-haspopup", "dialog");

    await user.click(scoring);
    expect(screen.getByRole("dialog", { name: "How scoring works" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close scoring details" }));
    expect(screen.queryByRole("dialog", { name: "How scoring works" })).not.toBeInTheDocument();
  });

  it("links active Stripe subscribers to Link to manage their web subscription", () => {
    testAuth.value.entitlement = { isPro: true, expiresAt: null, provider: "stripe" };
    renderPage();

    expect(screen.getByRole("link", { name: /Manage web subscription through Link/ })).toHaveAttribute("href", "https://link.com");
    expect(screen.getByRole("link", { name: /Manage web subscription through Link/ })).toHaveAttribute("target", "_blank");
  });

  it("signs out from the profile and returns Home", async () => {
    const user = userEvent.setup();
    renderPage();
    await user.click(screen.getAllByRole("button", { name: "Sign Out" })[0]);

    expect(testAuth.value.signOut).toHaveBeenCalledOnce();
    expect(await screen.findByText("Home")).toBeInTheDocument();
  });

  it("shows Apple-specific deletion information only for an Apple purchase, then returns the player to sign in", async () => {
    const user = userEvent.setup();
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderPage();
    await user.click(screen.getAllByRole("button", { name: "Delete Account" })[0]);

    expect(testAuth.value.deleteAccount).toHaveBeenCalledOnce();
    const confirmation = await screen.findByRole("dialog", { name: "Your Backword account has been deleted" });
    expect(confirmation).toHaveTextContent("Deleted from Backword");
    expect(confirmation).toHaveTextContent("Not deleted");
    expect(confirmation).toHaveTextContent("An Apple subscription was not cancelled");
    expect(confirmation).toHaveTextContent("Your Apple purchase record");
    expect(confirmation).not.toHaveTextContent("Stripe retains legally required billing records");
    expect(testAuth.value.finishAccountDeletion).not.toHaveBeenCalled();

    await user.click(within(confirmation).getByRole("button", { name: "Continue to sign in" }));

    expect(testAuth.value.finishAccountDeletion).toHaveBeenCalledOnce();
    expect(await screen.findByText("Sign in")).toBeInTheDocument();
  });

  it("shows Stripe-specific deletion information without implying an Apple purchase", async () => {
    const user = userEvent.setup();
    vi.spyOn(window, "confirm").mockReturnValue(true);
    testAuth.value.deleteAccount.mockResolvedValue({ hasApplePurchase: false, hasStripeSubscription: true });
    renderPage();

    await user.click(screen.getAllByRole("button", { name: "Delete Account" })[0]);

    const confirmation = await screen.findByRole("dialog", { name: "Your Backword account has been deleted" });
    expect(confirmation).toHaveTextContent("Stripe retains legally required billing records");
    expect(confirmation).not.toHaveTextContent("Apple subscription");
    expect(confirmation).not.toHaveTextContent("Apple purchase record");
  });

  it("redirects guests to sign in with a return destination", () => {
    testAuth.value.user = null;
    renderPage();

    expect(screen.getByText("Sign in")).toBeInTheDocument();
  });

  it("shows safe account refresh copy instead of a server error", async () => {
    sync.fetchCloudProgress.mockRejectedValueOnce(new Error("Cloud unavailable"));
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    renderPage();

    expect(await screen.findByRole("alert")).toHaveTextContent("We couldn't refresh your account right now.");
    expect(screen.getByRole("alert")).not.toHaveTextContent("Cloud unavailable");
  });

  it("shows an entitlement warning only in the signed-in profile", () => {
    testAuth.value.entitlementWarning = "We couldn't check account-linked Pro access right now. Please try again later.";
    renderPage();

    expect(screen.getByRole("alert")).toHaveTextContent("account-linked Pro access");
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
    expect(styles).toMatch(/\.player-profile__pro-logo\s*\{[^}]*\bmargin-left:\s*-14px/);
  });

  it("gives the delete-account control the same rounded corners as sign out", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.player-profile__sign-out\s*\{[^}]*\bborder-radius:\s*9px/);
    expect(styles).toMatch(/\.player-profile__delete-account\s*\{[^}]*\bborder-radius:\s*9px/);
  });

  it("shows bullets in both account-deletion summary lists", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.account-deletion-confirmation ul\s*\{[^}]*\blist-style:\s*disc/);
  });
});
