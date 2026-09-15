import { readFileSync } from "node:fs";
import { resolve } from "node:path";
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
  return render(<MemoryRouter initialEntries={["/menu-test"]}><Routes>
    <Route path="*" element={<GameMenu />} />
    <Route path="/" element={<p>Home</p>} />
  </Routes></MemoryRouter>);
}

describe("GameMenu account actions", () => {
  beforeEach(() => {
    testAuth.value = { ready: true, user: { id: "player-1" }, signOut: vi.fn().mockResolvedValue(undefined), deleteAccount: vi.fn().mockResolvedValue(undefined) };
    document.body.removeAttribute("style");
    Object.defineProperty(window, "scrollY", { configurable: true, value: 0 });
  });

  it("uses the primary menu-link treatment for Player Profile without account actions", async () => {
    const user = userEvent.setup();
    renderMenu();
    await user.click(screen.getByRole("button", { name: "Open game menu" }));

    const menu = screen.getByRole("dialog", { name: "Game navigation" });
    const profile = within(menu).getByRole("link", { name: "Player Profile" });
    expect(profile).toHaveAttribute("href", "/player-profile");
    expect(profile).toHaveClass("bw-menu-link", "bw-menu-link--primary", "bw-menu-auth");
    expect(profile.querySelector(".auth-button__wide-label")).toHaveTextContent("Player Profile");
    expect(profile.querySelector(".auth-button__compact-label")).toHaveTextContent("Profile");
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
    const login = screen.getByRole("link", { name: "Login" });
    expect(login).toHaveClass("bw-menu-link--primary");
    expect(login.querySelector(".auth-button__compact-label")).toHaveTextContent("Login");
    const upgrade = screen.getByRole("link", { name: "Get full access" });
    expect(upgrade).toHaveAttribute("href", "/pro");
    expect(upgrade).toHaveClass("bw-menu-upgrade");
    expect(login.compareDocumentPosition(upgrade) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it("locks the page at its current position until the menu closes", async () => {
    const user = userEvent.setup();
    const scrollTo = vi.spyOn(window, "scrollTo").mockImplementation(() => undefined);
    Object.defineProperty(window, "scrollY", { configurable: true, value: 184 });
    document.body.style.overflow = "clip";
    document.body.style.width = "calc(100% - 12px)";
    const { unmount } = renderMenu();

    await user.click(screen.getByRole("button", { name: "Open game menu" }));

    expect(document.body.style).toMatchObject({
      left: "0px",
      overflow: "hidden",
      position: "fixed",
      right: "0px",
      top: "-184px",
      width: "100%"
    });

    await user.click(screen.getByRole("button", { name: "Close game menu" }));

    expect(document.body.style.overflow).toBe("clip");
    expect(document.body.style.width).toBe("calc(100% - 12px)");
    expect(document.body.style.position).toBe("");
    expect(scrollTo).toHaveBeenCalledWith(0, 184);
    unmount();
    scrollTo.mockRestore();
  });

  it("restores page scrolling when an open menu unmounts", async () => {
    const user = userEvent.setup();
    const scrollTo = vi.spyOn(window, "scrollTo").mockImplementation(() => undefined);
    Object.defineProperty(window, "scrollY", { configurable: true, value: 72 });
    const { unmount } = renderMenu();

    await user.click(screen.getByRole("button", { name: "Open game menu" }));
    unmount();

    expect(document.body.style.position).toBe("");
    expect(document.body.style.overflow).toBe("");
    expect(scrollTo).toHaveBeenCalledWith(0, 72);
    scrollTo.mockRestore();
  });

  it("defines the phone menu as a full viewport overlay with a larger close control", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/@media \(max-width: 680px\) \{[\s\S]*?\.bw-menu-panel \{[^}]*width: 100vw[^}]*height: 100svh[^}]*height: 100dvh[^}]*border-radius: 0[^}]*box-shadow: none/);
    expect(styles).toMatch(/@media \(max-width: 680px\) \{[\s\S]*?\.bw-menu-links \{[^}]*overflow-y: auto[^}]*overscroll-behavior: contain/);
    expect(styles).toMatch(/@media \(max-width: 680px\) \{[\s\S]*?\.bw-menu-close \{ width: 48px; height: 48px; font-size: 28px; \}/);
  });
});
