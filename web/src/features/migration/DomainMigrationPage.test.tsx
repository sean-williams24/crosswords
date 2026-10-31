import { beforeEach, describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
const context = vi.hoisted(() => ({ user: null as { id: string; email: string } | null, ready: true, signOut: vi.fn() }));
const sync = vi.hoisted(() => ({ run: vi.fn() }));
vi.mock("../auth/AuthProvider", () => ({ useAuth: () => context }));
vi.mock("../brand/brand", async () => {
  const actual = await vi.importActual<typeof import("../brand/brand")>("../brand/brand");
  return { ...actual, brand: { ...actual.brand, launchEnabled: true } };
});
vi.mock("./migrationCoordinator", () => ({ runDomainMigration: sync.run }));
import { DomainMigrationPage } from "./DomainMigrationPage";
import { migrationGames } from "./migrationStorage";

beforeEach(() => { localStorage.clear(); context.user = null; vi.clearAllMocks(); });
function show() { return render(<MemoryRouter initialEntries={["/backword/2026-10-29"]}><DomainMigrationPage /></MemoryRouter>); }
describe("old-domain save recovery", () => {
  it("requires an explicit choice before continuing without existing history", () => {
    localStorage.setItem(migrationGames[0].key, '{"legacy":{"schemaVersion":99}}');
    show();
    expect(screen.getByRole("link", { name: "Sign in to keep my progress" })).toHaveAttribute("href", "/sign-in");
    expect(screen.getByRole("button", { name: "Continue without moving history" })).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox"));
    expect(screen.getByRole("button", { name: "Continue without moving history" })).toBeEnabled();
    expect(localStorage.getItem(migrationGames[0].key)).toContain("legacy");
  });
  it("does not offer verified continuation after an incomplete sync", async () => {
    context.user = { id: "alice", email: "alice@example.com" };
    sync.run.mockResolvedValue({ ready: false, games: [] });
    show(); fireEvent.click(screen.getByRole("button", { name: "Sync and check my saves" }));
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("Some saves have not been confirmed"));
    expect(screen.queryByRole("button", { name: "Continue to intervls" })).not.toBeInTheDocument();
  });
  it("invalidates a successful check when another tab changes storage", async () => {
    context.user = { id: "alice", email: "alice@example.com" };
    sync.run.mockResolvedValue({ ready: true, games: [] });
    show(); fireEvent.click(screen.getByRole("button", { name: "Sync and check my saves" }));
    await screen.findByRole("button", { name: "Continue to intervls" });
    fireEvent(window, new StorageEvent("storage", { key: migrationGames[0].key }));
    expect(screen.queryByRole("button", { name: "Continue to intervls" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sync and check my saves" })).toBeInTheDocument();
  });
});
