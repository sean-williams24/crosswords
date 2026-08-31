import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { WeeklyCrosswordPage } from "./WeeklyCrosswordPage";

const auth = vi.hoisted(() => ({
  value: {
    ready: true,
    entitlementReady: true,
    entitlement: { isPro: false, expiresAt: null } as { isPro: boolean; expiresAt: string | null } | null,
    user: { id: "standard-player" } as { id: string } | null
  }
}));

vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => auth.value }));

describe("WeeklyCrosswordPage access", () => {
  it("keeps non-Pro accounts at the iOS subscription path", () => {
    render(<MemoryRouter><WeeklyCrosswordPage /></MemoryRouter>);

    expect(screen.getByRole("dialog", { name: "The full game experience" })).toBeInTheDocument();
    expect(screen.getByText("Available with a Backword Pro subscription on iOS.")).toBeInTheDocument();
  });
});
