import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { localDateString } from "../features/backword/date";

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
  backwordCloudRecord: (progress: { date: string }) => ({ release_date: progress.date, release_score: 0, payload: progress }),
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

  it("shows signed-in account controls beneath the inline scoring and 14-day breakdown", async () => {
    renderPage();

    expect(screen.getByRole("heading", { name: "Player Profile" })).toBeInTheDocument();
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
    const rollingWindow = screen.getByText("Rolling 14-day window");
    const dailyScoring = screen.getByText("Quick & Weekly Crossword");
    const signOut = screen.getByRole("button", { name: "Sign Out" });
    const deleteAccount = screen.getByRole("button", { name: "Delete Account" });
    const breakdown = screen.getByRole("heading", { name: "LAST 14 DAYS" }).closest("section");
    expect(rating.compareDocumentPosition(rollingWindow) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(rollingWindow.compareDocumentPosition(dailyScoring) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(dailyScoring.compareDocumentPosition(account) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(breakdown).not.toBeNull();
    expect(breakdown!.compareDocumentPosition(signOut) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(signOut.compareDocumentPosition(deleteAccount) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(screen.queryByRole("button", { name: "HOW SCORING WORKS" })).not.toBeInTheDocument();
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

  it("shows guests this browser's local stats and permanent scoring details without account controls", () => {
    testAuth.value.user = null;
    sync.fetchCloudProgress.mockClear();
    localStorage.setItem("backword:web:progress:v1", JSON.stringify({
      [localDateString()]: {
        schemaVersion: 1,
        date: localDateString(),
        guesses: ["CASTLE", "CASTLE", "CASTLE"],
        completedAt: new Date().toISOString(),
        outcome: "won"
      }
    }));
    renderPage();

    expect(screen.getByRole("heading", { name: "Player Profile" })).toBeInTheDocument();
    expect(screen.getByText("3 / 140 pts")).toBeInTheDocument();
    expect(screen.queryByText("YOUR BACKWORD ACCOUNT")).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Account summary")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "HOW SCORING WORKS" })).not.toBeInTheDocument();
    expect(screen.queryByRole("dialog", { name: "How scoring works" })).not.toBeInTheDocument();
    const rollingWindow = screen.getByText("Rolling 14-day window");
    const dailyScoring = screen.getByText("Quick & Weekly Crossword");
    expect(rollingWindow.compareDocumentPosition(dailyScoring) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(dailyScoring).toBeInTheDocument();
    expect(screen.getByText("− 1 point deducted for every 3 hints used")).toBeInTheDocument();
    expect(within(screen.getByLabelText("Player summary")).getByText("Backword")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Sign Out" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Delete Account" })).not.toBeInTheDocument();
    expect(sync.fetchCloudProgress).not.toHaveBeenCalled();
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

  it("shows account-scoped cached stats while the profile refresh is pending", async () => {
    let resolveFetch: (records: []) => void = () => undefined;
    const pendingFetch = new Promise<[]>(resolve => {
      resolveFetch = resolve;
    });
    sync.fetchCloudProgress.mockReturnValue(pendingFetch);
    const fetchCallsBeforeRender = sync.fetchCloudProgress.mock.calls.length;
    localStorage.setItem("backword:web:progress:v1:user:player-1", JSON.stringify({
      [localDateString()]: {
        schemaVersion: 1,
        date: localDateString(),
        guesses: ["CASTLE", "CASTLE", "CASTLE"],
        completedAt: new Date().toISOString(),
        outcome: "won"
      }
    }));
    renderPage();

    expect(screen.getByText("3 / 150 pts")).toBeInTheDocument();
    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    resolveFetch([]);

    await waitFor(() => expect(sync.fetchCloudProgress).toHaveBeenCalledTimes(fetchCallsBeforeRender + 3));
  });

  it("compensates for transparent padding around the Pro logo", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.player-profile__pro-logo\s*\{[^}]*\bmargin-right:\s*-14px/);
    expect(styles).toMatch(/\.player-profile__pro-logo\s*\{[^}]*\bmargin-left:\s*-14px/);
  });

  it("pins the profile footer to the viewport bottom when content is short", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.player-profile > footer\s*\{[^}]*\bmargin-top:\s*auto/);
  });

  it("gives the delete-account control the same rounded corners as sign out", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.player-profile__sign-out\s*\{[^}]*\bborder-radius:\s*9px/);
    expect(styles).toMatch(/\.player-profile__delete-account\s*\{[^}]*\bborder-radius:\s*9px/);
  });

  it("tightens the mobile profile header beneath its title", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/@media \(max-width: 680px\)\s*\{[\s\S]*?\.home-dashboard__header\.player-profile__header\s*\{[^}]*\bmin-height:\s*92px/);
  });

  it("uses Archive typography for the profile title and account eyebrow", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.player-profile__header-title\s*\{[^}]*\bfont-size:\s*clamp\(28px, 4vw, 42px\)[^}]*\bletter-spacing:\s*-.045em/);
    expect(styles).toMatch(/\.player-profile__heading > p\s*\{[^}]*\bcolor:\s*#d6be87[^}]*\bfont-size:\s*11px[^}]*\bletter-spacing:\s*\.22em/);
  });

  it("shows bullets in both account-deletion summary lists", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.account-deletion-confirmation ul\s*\{[^}]*\blist-style:\s*disc/);
  });
});
