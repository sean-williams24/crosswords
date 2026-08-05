import { render, screen } from "@testing-library/react";
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

  it("renders the daily cards, word of the day, and playable Backword link", () => {
    renderDashboard();

    expect(screen.getByRole("heading", { level: 1, name: "Daily Games" })).toBeInTheDocument();
    const backwordLink = screen.getAllByRole("link").find((link) => link.getAttribute("href") === "/");
    expect(backwordLink).toBeDefined();
    expect(screen.getByRole("link", { name: /Quick Crossword/i })).toHaveAttribute("href", "/crossword");
    expect(screen.getByText("Sycophant")).toBeInTheDocument();
    expect(screen.getAllByLabelText("Status: New")).toHaveLength(2);
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
    expect(screen.getByRole("dialog", { name: "The full game experience" })).toBeInTheDocument();
    expect(screen.getByText("Weekly challenging puzzles")).toBeInTheDocument();
    const appStoreBadge = screen.getByLabelText("Download Backword on the App Store");
    expect(appStoreBadge).toHaveAttribute(
      "href",
      "https://apps.apple.com/app/backword/id6773428497"
    );
    expect(appStoreBadge.parentElement).toHaveClass("weekly-modal__store-badge");

    await user.click(screen.getByRole("button", { name: "Close weekly crossword details" }));
    expect(screen.queryByRole("dialog", { name: "The full game experience" })).not.toBeInTheDocument();
  });
});
