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

  it("shows Archive only to Pro subscribers", () => {
    const { rerender } = render(<MemoryRouter><Footer /></MemoryRouter>);
    const footer = screen.getByRole("navigation", { name: "Footer" });

    expect(within(footer).queryByRole("link", { name: "Archive" })).not.toBeInTheDocument();

    auth.entitlement = { isPro: true, expiresAt: null };
    rerender(<MemoryRouter><Footer /></MemoryRouter>);

    expect(within(footer).getByRole("link", { name: "Archive" })).toHaveAttribute("href", "/archive");
  });
});
