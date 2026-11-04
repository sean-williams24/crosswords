import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
const settings = vi.hoisted(() => ({ launched: false, notice: true, legacy: true }));
vi.mock("./brand", () => ({ brand: { get launchEnabled() { return settings.launched; }, get noticeEnabled() { return settings.notice; } }, isLegacyOrigin: () => settings.legacy }));
import { RebrandNotice } from "./RebrandNotice";
function show(path: string) { render(<MemoryRouter initialEntries={[path]}><RebrandNotice /></MemoryRouter>); }
beforeEach(() => { settings.launched = false; settings.notice = true; settings.legacy = true; });
describe("advance rebrand notice", () => {
  it("explains the guest-history reset and offers normal account sign-in", () => {
    show("/backword/2026-10-29");
    expect(screen.getByText(/Browser-only history will start fresh on Intervls/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Sign in to sync" })).toHaveAttribute("href", "/sign-in");
  });
  it("keeps the notice out of authentication callbacks", () => {
    show("/auth/callback?code=secret"); expect(screen.queryByRole("complementary")).not.toBeInTheDocument();
  });
  it("hides the advance notice after launch", () => {
    settings.launched = true; show("/"); expect(screen.queryByRole("complementary")).not.toBeInTheDocument();
  });
});
