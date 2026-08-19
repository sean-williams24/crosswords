import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { localDateString } from "../features/backword/date";
import { HomeDashboardPage } from "./HomeDashboardPage";

function renderDashboard() {
  return render(
    <MemoryRouter>
      <HomeDashboardPage />
    </MemoryRouter>
  );
}

function saveProgress(progress: Record<string, unknown>) {
  localStorage.setItem("backword:web:progress:v1", JSON.stringify({ [localDateString()]: progress }));
}

describe("web home dashboard", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("renders the daily cards and playable Backword link", () => {
    renderDashboard();

    expect(screen.getByRole("heading", { level: 1, name: "Daily Games" })).toBeInTheDocument();
    const appStoreBadge = screen.getByLabelText("Download Backword on the App Store");
    const loginButton = screen.getByRole("link", { name: "Login" });
    expect(appStoreBadge.parentElement).toHaveClass("home-dashboard__actions");
    expect(loginButton.parentElement).toBe(appStoreBadge.parentElement);
    expect(loginButton).toHaveAttribute("href", "/sign-in");
    const backwordLink = screen.getAllByRole("link").find((link) => link.getAttribute("href") === "/");
    expect(backwordLink).toBeDefined();
    const crosswordCard = screen.getByRole("link", { name: /Quick Crossword/i });
    expect(crosswordCard).toHaveAttribute("href", "/crossword");
    const crosswordStats = crosswordCard.querySelector(".home-game-card__stats");
    expect(crosswordStats).not.toBeNull();
    expect(crosswordStats?.parentElement).toBe(crosswordCard);
    expect(crosswordStats?.querySelector(".home-game-card__streak")).toBeNull();
    const dailyLayout = crosswordCard.closest(".home-dashboard__daily-layout");
    expect(dailyLayout).not.toBeNull();
    expect(crosswordCard.closest(".home-dashboard__daily-cards")?.parentElement).toBe(dailyLayout);
    expect(screen.getAllByLabelText("Status: New")).toHaveLength(2);
  });

  it("uses a menu-style outlined account link", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.home-dashboard__actions \.auth-button\s*\{[^}]*\bborder:\s*1px solid #eee[^}]*\bbackground:\s*transparent[^}]*\bfont-size:\s*14px[^}]*\bfont-weight:\s*400/);
    expect(styles).toContain(".home-dashboard__actions .auth-button { width: 120px; min-height: 40px; height: 40px;");
    expect(styles).toContain(".home-dashboard__actions .auth-button { width: 93px; min-height: 31px; height: 31px;");
    expect(styles).toContain(".home-dashboard__actions .auth-button__wide-label { display: none; }");
    expect(styles).toContain(".home-dashboard__actions .auth-button__compact-label { display: inline; }");
  });

  it.each([
    [
      "In Progress",
      { schemaVersion: 1, date: localDateString(), guesses: ["CASTLE"], completedAt: null, outcome: "inProgress" }
    ],
    [
      "2 guesses",
      { schemaVersion: 1, date: localDateString(), guesses: ["CASTLE", "CASTLE"], completedAt: new Date().toISOString(), outcome: "won" }
    ],
    [
      "Failed",
      { schemaVersion: 1, date: localDateString(), guesses: ["CASTLE"], completedAt: new Date().toISOString(), outcome: "failed" }
    ]
  ])("derives the Backword %s status from saved progress", (label, progress) => {
    saveProgress(progress);
    renderDashboard();

    expect(screen.getByLabelText(`Status: ${label}`)).toBeInTheDocument();
  });

  it("opens and closes the iOS weekly crossword dialog", async () => {
    const user = userEvent.setup();
    renderDashboard();

    await user.click(screen.getByRole("button", { name: /Pro Crossword/i }));
    const modal = screen.getByRole("dialog", { name: "The full game experience" });
    expect(modal).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "The full game experience" })).toHaveClass(
      "weekly-modal__title"
    );
    const featureList = modal.querySelector(".weekly-modal__features");
    const intro = screen.getByText("Available on the Backword iOS app...");
    expect(featureList).not.toBeNull();
    expect(
      screen.getByRole("heading", { name: "The full game experience" }).compareDocumentPosition(
        featureList!
      ) & Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy();
    expect(featureList!.compareDocumentPosition(intro) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(screen.getByText("Weekly challenging puzzles")).toBeInTheDocument();
    const appStoreBadge = within(modal).getByLabelText("Download Backword on the App Store");
    expect(appStoreBadge).toHaveAttribute(
      "href",
      "https://apps.apple.com/app/backword/id6773428497"
    );
    expect(appStoreBadge.parentElement).toHaveClass("weekly-modal__store-badge");

    await user.click(screen.getByRole("button", { name: "Close weekly crossword details" }));
    expect(screen.queryByRole("dialog", { name: "The full game experience" })).not.toBeInTheDocument();
  });
});
