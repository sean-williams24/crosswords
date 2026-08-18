import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const testAuth = vi.hoisted(() => ({
  value: {
    ready: true,
    user: { id: "player-1" } as { id: string } | null,
    signOut: vi.fn().mockResolvedValue(undefined),
    deleteAccount: vi.fn().mockResolvedValue(undefined)
  }
}));

vi.mock("../../auth/AuthProvider", () => ({ useAuth: () => testAuth.value }));

import { GameMenu } from "./GameMenu";

function renderMenu() {
  return render(<MemoryRouter><Routes>
    <Route path="*" element={<GameMenu />} />
    <Route path="/home" element={<p>Home</p>} />
  </Routes></MemoryRouter>);
}

describe("GameMenu account actions", () => {
  beforeEach(() => {
    testAuth.value = { ready: true, user: { id: "player-1" }, signOut: vi.fn().mockResolvedValue(undefined), deleteAccount: vi.fn().mockResolvedValue(undefined) };
  });

  it("uses the primary menu-link treatment for Player Profile without account actions", async () => {
    const user = userEvent.setup();
    renderMenu();
    await user.click(screen.getByRole("button", { name: "Open game menu" }));

    const menu = screen.getByRole("dialog", { name: "Game navigation" });
    const profile = within(menu).getByRole("link", { name: "Player Profile" });
    expect(profile).toHaveAttribute("href", "/player-profile");
    expect(profile).toHaveClass("bw-menu-link", "bw-menu-link--primary", "bw-menu-auth");
    expect(within(menu).queryByRole("button", { name: "Sign Out" })).not.toBeInTheDocument();
    expect(within(menu).queryByRole("button", { name: "Delete Account" })).not.toBeInTheDocument();
  });

  it("does not expose account deletion to guests", async () => {
    const user = userEvent.setup();
    testAuth.value.user = null;
    renderMenu();
    await user.click(screen.getByRole("button", { name: "Open game menu" }));

    expect(screen.queryByRole("button", { name: "Sign Out" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Delete Account" })).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Login" })).toHaveClass("bw-menu-link--primary");
  });
});
