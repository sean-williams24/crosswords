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
  it("redirects non-Pro accounts to the web Pro subscription path", () => {
    render(<MemoryRouter><Routes>
      <Route element={<WeeklyCrosswordPage />} path="/" />
      <Route element={<ProDestination />} path="/pro" />
    </Routes></MemoryRouter>);

    expect(screen.getByText("/weekly-crossword")).toBeInTheDocument();
  });

  it("keeps a dated archive destination through the Pro gate", () => {
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
          <Route element={<ProDestination />} path="/pro" />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByText("/weekly-crossword/2026-08-02")).toBeInTheDocument();
  });
});

function ProDestination() {
  const { search } = useLocation();
  return <p>{new URLSearchParams(search).get("return_to")}</p>;
}
