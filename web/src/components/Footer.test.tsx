import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const auth = vi.hoisted(() => ({
  entitlement: null as { isPro: boolean; expiresAt: string | null } | null
}));

vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => auth }));

import { Footer } from "./Footer";

describe("Footer", () => {
  beforeEach(() => {
    auth.entitlement = null;
  });

  it("sends non-Pro subscribers to Pro and Pro subscribers to the protected destinations", () => {
    const { rerender } = render(<MemoryRouter><Footer /></MemoryRouter>);
    const footer = screen.getByRole("navigation", { name: "Footer" });

    expect(within(footer).getByRole("link", { name: "Pro Crossword" })).toHaveAttribute("href", "/pro?return_to=%2Fweekly-crossword");
    expect(within(footer).getByRole("link", { name: "Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive");

    auth.entitlement = { isPro: true, expiresAt: null };
    rerender(<MemoryRouter><Footer /></MemoryRouter>);

    expect(within(footer).getByRole("link", { name: "Pro Crossword" })).toHaveAttribute("href", "/weekly-crossword");
    expect(within(footer).getByRole("link", { name: "Archive" })).toHaveAttribute("href", "/archive");
  });
});
