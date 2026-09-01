import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { act, render, screen, within } from "@testing-library/react";
import { useLayoutEffect } from "react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { localDateString, localWeekStartString } from "../features/backword/date";
import { emptyProgress } from "../features/crossword/engine";
import { createCrosswordStorage } from "../features/crossword/storage";
import { HomeDashboardPage } from "./HomeDashboardPage";

const testAuth = vi.hoisted(() => ({
  value: {
    entitlement: null as { isPro: boolean; expiresAt: string | null } | null,
    ready: true,
    user: null as { id: string } | null
  }
}));

const testWordOfTheDay = vi.hoisted(() => ({
  notify: null as ((state: "loading" | "loaded" | "unavailable") => void) | null,
  state: "loaded" as "loading" | "loaded" | "unavailable"
}));

vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => testAuth.value }));
vi.mock("../features/wotd/components/WordOfTheDayCard", () => ({
  WordOfTheDayCard: ({
    className = "",
    onLoadStateChange
  }: {
    className?: string;
    onLoadStateChange?: (state: "loading" | "loaded" | "unavailable") => void;
  }) => {
    useLayoutEffect(() => {
      testWordOfTheDay.notify = onLoadStateChange ?? null;
      onLoadStateChange?.(testWordOfTheDay.state);
    }, [onLoadStateChange]);

    return testWordOfTheDay.state === "loaded"
      ? <section aria-label="Word of the Day" className={`wotd-widget ${className}`.trim()} />
      : null;
  }
}));

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
    testAuth.value = { entitlement: null, ready: true, user: null };
    testWordOfTheDay.notify = null;
    testWordOfTheDay.state = "loaded";
  });

  it("keeps four non-interactive skeleton cards visible until Word of the Day loads", () => {
    testWordOfTheDay.state = "loading";
    const { container } = renderDashboard();

    expect(screen.getByRole("status")).toHaveTextContent("Loading daily games");
    expect(container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(4);
    expect(screen.queryByRole("link", { name: "Quick Crossword" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Pro Crossword/i })).not.toBeInTheDocument();

    testWordOfTheDay.state = "loaded";
    act(() => testWordOfTheDay.notify?.("loaded"));

    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    expect(container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(0);
    expect(screen.getByRole("link", { name: "Quick Crossword" })).toBeInTheDocument();
  });

  it("keeps the skeleton visible until account startup has completed", () => {
    testAuth.value.ready = false;
    const view = renderDashboard();

    expect(view.container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(4);

    testAuth.value.ready = true;
    view.rerender(
      <MemoryRouter>
        <HomeDashboardPage />
      </MemoryRouter>
    );

    expect(view.container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(0);
    expect(screen.getByRole("link", { name: "Quick Crossword" })).toBeInTheDocument();
  });

  it("shows an informational Word of the Day error card when the row is unavailable", () => {
    testWordOfTheDay.state = "unavailable";
    renderDashboard();

    expect(screen.getByLabelText("Word of the Day unavailable")).toHaveTextContent("Unavailable today");
    expect(screen.getByRole("link", { name: "Quick Crossword" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Pro Crossword/i })).toBeInTheDocument();
  });

  it("renders the daily cards and playable Backword link", () => {
    renderDashboard();

    expect(screen.getByRole("heading", { level: 1, name: "Daily Games" })).toBeInTheDocument();
    const appStoreBadge = screen.getByLabelText("Download Backword on the App Store");
    const loginButton = screen.getByRole("link", { name: "Login" });
    expect(appStoreBadge.parentElement).toHaveClass("home-dashboard__actions");
    expect(loginButton.parentElement).toBe(appStoreBadge.parentElement);
    expect(loginButton).toHaveAttribute("href", "/sign-in");
    const backwordLink = screen.getAllByRole("link").find((link) => link.getAttribute("href") === "/backword");
    expect(backwordLink).toBeDefined();
    const crosswordCard = screen.getByRole("link", { name: "Quick Crossword" });
    expect(crosswordCard).toHaveAttribute("href", "/crossword");
    const crosswordStats = crosswordCard.querySelector(".home-game-card__stats");
    expect(crosswordStats).not.toBeNull();
    expect(crosswordStats?.parentElement).toBe(crosswordCard);
    expect(crosswordStats?.querySelector(".home-game-card__streak")).toBeNull();
    const dailyLayout = crosswordCard.closest(".home-dashboard__daily-layout");
    expect(dailyLayout).not.toBeNull();
    expect(crosswordCard.closest(".home-dashboard__daily-cards")?.parentElement).toBe(dailyLayout);
    expect(screen.getAllByLabelText("Status: New")).toHaveLength(2);
    expect(screen.getByRole("link", { name: "Backword Archive" })).toHaveAttribute("href", "/archive?game=backword");
    expect(screen.getByRole("link", { name: "Quick Crossword Archive" })).toHaveAttribute("href", "/archive?game=daily");
    expect(screen.getByRole("link", { name: "Pro Crossword Archive" })).toHaveAttribute("href", "/archive?game=weekly");
  });

  it("uses the Quick Crossword score treatment for earned Backword and Pro points", () => {
    testAuth.value = {
      entitlement: { isPro: true, expiresAt: null },
      ready: true,
      user: null
    };
    saveProgress({
      schemaVersion: 1,
      date: localDateString(),
      guesses: ["CASTLE", "CASTLE", "CASTLE"],
      completedAt: new Date().toISOString(),
      outcome: "won"
    });
    const weeklyPuzzle = { id: "current-weekly", date: localWeekStartString(), size: 13 } as const;
    const weeklyProgress = {
      ...emptyProgress(weeklyPuzzle),
      completedAt: new Date().toISOString(),
      completedClueIds: [1],
      isWeekly: true,
      releaseDateScore: 3
    };
    createCrosswordStorage(undefined, { kind: "weekly" }).saveProgress(weeklyProgress);

    renderDashboard();

    const backwordCard = screen.getAllByRole("link").find((link) => link.getAttribute("href") === "/backword");
    expect(backwordCard?.querySelector(".home-game-card__score")).toHaveTextContent("3/ 5");
    const proCard = screen.getAllByRole("link", { name: "Pro Crossword" })
      .find((link) => link.getAttribute("href") === "/weekly-crossword")!;
    const proScore = proCard.querySelector(".weekly-card__stats .home-game-card__score");
    expect(proScore).toHaveTextContent("3/ 5");
    expect(proScore).toHaveClass("home-game-card__score");
  });

  it("uses a menu-style outlined account link", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.home-dashboard__actions \.auth-button\s*\{[^}]*\bborder:\s*1px solid #eee[^}]*\bbackground:\s*transparent[^}]*\bfont-size:\s*14px[^}]*\bfont-weight:\s*400/);
    expect(styles).toContain(".home-dashboard__actions .auth-button { width: 120px; min-height: 40px; height: 40px;");
    expect(styles).toContain(".home-dashboard__actions .auth-button { width: 93px; min-height: 31px; height: 31px;");
    expect(styles).toContain(".home-dashboard__actions .auth-button__wide-label { display: none; }");
    expect(styles).toContain(".home-dashboard__actions .auth-button__compact-label { display: inline; }");
  });

  it("uses one grey surface for the weekly crossword dialog", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toContain(".weekly-modal { position: relative; width: min(100%, 520px); max-height: calc(100svh - 40px); overflow-y: auto; border: 1px solid #303030; border-radius: 26px; background: #1a1a1a;");
    expect(styles).toMatch(/\.weekly-modal__hero\s*\{[^}]*display:\s*grid[^}]*height:\s*210px[^}]*place-items:\s*center[^}]*\}/);
    expect(styles).not.toMatch(/\.weekly-modal__hero\s*\{[^}]*\bbackground\s*:/);
  });

  it("adds the Pro mark to the header logo for an active Pro account", () => {
    testAuth.value = {
      entitlement: { isPro: true, expiresAt: null },
      ready: true,
      user: { id: "pro-player" }
    };
    renderDashboard();

    expect(within(screen.getByRole("link", { name: "Backword home" })).getByRole("img", { name: "Pro" }))
      .toHaveAttribute("src", "/brand/backword-pro.png");
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

  it("opens and closes the iOS subscription path for the weekly crossword", async () => {
    const user = userEvent.setup();
    renderDashboard();

    await user.click(screen.getByRole("button", { name: /Pro Crossword/i }));
    const modal = screen.getByRole("dialog", { name: "The full game experience" });
    expect(modal).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "The full game experience" })).toHaveClass(
      "weekly-modal__title"
    );
    const featureList = modal.querySelector(".weekly-modal__features");
    const intro = screen.getByText("Available with a Backword Pro subscription on iOS.");
    expect(featureList).not.toBeNull();
    expect(
      screen.getByRole("heading", { name: "The full game experience" }).compareDocumentPosition(
        featureList!
      ) & Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy();
    expect(featureList!.compareDocumentPosition(intro) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(screen.getByText("Weekly challenging puzzles")).toBeInTheDocument();
    expect(within(modal).getByRole("link", { name: "Already Pro? Sign in" })).toHaveAttribute("href", "/sign-in");
    const appStoreBadge = within(modal).getByLabelText("Download Backword on the App Store");
    expect(appStoreBadge).toHaveAttribute(
      "href",
      "https://apps.apple.com/app/backword/id6773428497"
    );
    expect(appStoreBadge.parentElement).toHaveClass("weekly-modal__store-badge");

    await user.click(screen.getByRole("button", { name: "Close weekly crossword details" }));
    expect(screen.queryByRole("dialog", { name: "The full game experience" })).not.toBeInTheDocument();
  });

  it("links an active Pro account to the playable weekly crossword", () => {
    testAuth.value = {
      entitlement: { isPro: true, expiresAt: null },
      ready: true,
      user: { id: "pro-player" }
    };
    renderDashboard();

    expect(screen.getAllByRole("link", { name: "Pro Crossword" }).find((link) => link.getAttribute("href") === "/weekly-crossword"))
      .toBeDefined();
  });
});
