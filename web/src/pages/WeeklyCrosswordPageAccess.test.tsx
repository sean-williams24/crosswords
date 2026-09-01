import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes, useLocation } from "react-router-dom";
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

  it("keeps a dated archive destination through the sign-in gate", () => {
    auth.value = {
      ready: true,
      entitlementReady: true,
      entitlement: null,
      user: null
    };
    render(
      <MemoryRouter initialEntries={["/weekly-crossword/2026-08-02"]}>
        <Routes>
          <Route element={<WeeklyCrosswordPage />} path="/weekly-crossword/:date" />
          <Route element={<SignInDestination />} path="/sign-in" />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText("/weekly-crossword/2026-08-02")).toBeInTheDocument();
  });
});

function SignInDestination() {
  const { state } = useLocation();
  return <p>{(state as { returnTo?: string } | null)?.returnTo}</p>;
}
