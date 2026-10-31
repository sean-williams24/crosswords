import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
const settings = vi.hoisted(() => ({ launched: true, legacy: true }));
vi.mock("../brand/brand", () => ({ brand: { get launchEnabled() { return settings.launched; } }, isLegacyOrigin: () => settings.legacy }));
vi.mock("./DomainMigrationPage", () => ({ DomainMigrationPage: () => <div>Save check</div> }));
import { LegacyMigrationGate } from "./LegacyMigrationGate";
function show(path: string) { render(<MemoryRouter initialEntries={[path]}><LegacyMigrationGate><div>Website</div></LegacyMigrationGate></MemoryRouter>); }
beforeEach(() => { settings.launched = true; settings.legacy = true; });
describe("legacy bookmark protection", () => {
  it.each(["/", "/backword/2026-10-29", "/midword", "/anagram", "/crossword", "/weekly-crossword", "/archive", "/player-profile", "/pro?checkout=success"])("checks saves before opening %s", (path) => {
    show(path); expect(screen.getByText("Save check")).toBeInTheDocument(); expect(screen.queryByText("Website")).not.toBeInTheDocument();
  });
  it.each(["/sign-in", "/auth/callback?code=provider-code"])("keeps authentication functional at %s", (path) => {
    show(path); expect(screen.getByText("Website")).toBeInTheDocument();
  });
  it("leaves preparation and the new website usable", () => {
    settings.launched = false; show("/"); expect(screen.getByText("Website")).toBeInTheDocument();
  });
});
