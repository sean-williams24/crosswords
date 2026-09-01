import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes, useLocation } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const auth = vi.hoisted(() => ({
  value: {
    ready: true,
    entitlementReady: true,
    user: { id: "player-1", email: "player@example.com" } as { id: string; email: string } | null,
    entitlement: { isPro: false, expiresAt: null, provider: null, cancelAtPeriodEnd: false } as { isPro: boolean; expiresAt: string | null; provider: "apple" | "stripe" | null; cancelAtPeriodEnd: boolean } | null,
    refreshEntitlement: vi.fn().mockResolvedValue(undefined)
  }
}));
const billing = vi.hoisted(() => ({
  startStripeCheckout: vi.fn().mockResolvedValue(undefined),
  openStripeBillingPortal: vi.fn().mockResolvedValue(undefined)
}));

vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => auth.value }));
vi.mock("../features/pro/billing", () => billing);
vi.mock("../features/backword/components/GameMenu", () => ({ GameMenu: () => <span /> }));
vi.mock("../components/Footer", () => ({ Footer: () => <footer /> }));

import { ProPage } from "./ProPage";

function renderPage(entry = "/pro") {
  return render(<MemoryRouter initialEntries={[entry]}><Routes>
    <Route element={<ProPage />} path="/pro" />
    <Route element={<SignInDestination />} path="/sign-in" />
  </Routes></MemoryRouter>);
}

function SignInDestination() {
  const { state } = useLocation();
  return <p>Sign in: {(state as { returnTo?: string } | null)?.returnTo}</p>;
}

describe("ProPage", () => {
  beforeEach(() => {
    auth.value = {
      ready: true,
      entitlementReady: true,
      user: { id: "player-1", email: "player@example.com" },
      entitlement: { isPro: false, expiresAt: null, provider: null, cancelAtPeriodEnd: false },
      refreshEntitlement: vi.fn().mockResolvedValue(undefined)
    };
    billing.startStripeCheckout.mockClear();
    billing.openStripeBillingPortal.mockClear();
  });

  it("shows plans to guests and sends the trial action through account sign-in", async () => {
    const user = userEvent.setup();
    auth.value.user = null;
    renderPage("/pro?return_to=%2Fweekly-crossword");

    expect(screen.getByRole("button", { name: "Start 7-day free trial" })).toBeInTheDocument();
    expect(screen.getByText("Or")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Login" })).toHaveAttribute("href", "/sign-in");
    expect(screen.getByRole("heading", { name: "The 13 x 13 crossword" })).toBeInTheDocument();
    expect(screen.getByText(/complete Backword and crossword archive/i)).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Start 7-day free trial" }));

    expect(screen.getByText("Sign in: /pro?return_to=%2Fweekly-crossword")).toBeInTheDocument();
  });

  it("starts the selected secure Stripe Checkout plan", async () => {
    const user = userEvent.setup();
    renderPage("/pro?return_to=%2Fweekly-crossword");

    expect(screen.getByRole("button", { name: "Start 7-day free trial" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /Monthly/i }));
    await user.click(screen.getByRole("button", { name: "Start 7-day free trial" }));

    expect(billing.startStripeCheckout).toHaveBeenCalledWith("monthly", "/weekly-crossword");
  });

  it("routes active Stripe subscribers to billing management instead of checkout", async () => {
    const user = userEvent.setup();
    auth.value.entitlement = { isPro: true, expiresAt: "2026-10-01T00:00:00.000Z", provider: "stripe", cancelAtPeriodEnd: false };
    renderPage();

    expect(screen.queryByRole("button", { name: "Start 7-day free trial" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Manage web subscription" }));
    expect(billing.openStripeBillingPortal).toHaveBeenCalledOnce();
  });
});
