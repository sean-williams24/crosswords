import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { act, render, screen, within } from "@testing-library/react";
import { useLayoutEffect } from "react";
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
    expect(screen.getAllByRole("link", { name: /Pro Crossword/i }).find((link) => link.getAttribute("href") === "/pro?return_to=%2Fweekly-crossword"))
      .toBeDefined();
  });

  it("renders the daily cards and playable Backword link", () => {
    renderDashboard();

    expect(screen.getByRole("heading", { level: 1, name: "Daily Games" })).toBeInTheDocument();
    const loginButton = screen.getByRole("link", { name: "Login" });
    const profileRating = screen.getByRole("link", { name: "Overall rating: Novice. View player profile" });
    expect(loginButton.parentElement).toHaveClass("home-dashboard__actions");
    expect(screen.queryByLabelText("Download Backword on the App Store")).not.toBeInTheDocument();
    expect(loginButton).toHaveAttribute("href", "/sign-in");
    expect(profileRating).toHaveAttribute("href", "/player-profile");
    expect(profileRating.querySelector(".home-profile-rating-link__marker")).toBeInTheDocument();
    expect(profileRating.querySelector(".home-profile-rating-link__label")).toHaveTextContent("NOVICE");
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
    expect(screen.getByRole("link", { name: "Backword Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive%3Fgame%3Dbackword");
    expect(screen.getByRole("link", { name: "Quick Crossword Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive%3Fgame%3Ddaily");
    expect(screen.getByRole("link", { name: "Pro Crossword Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive%3Fgame%3Dweekly");
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

  it("uses the menu upgrade treatment for the account link", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.bw-menu-upgrade,\s*\.auth-button\.auth-button--menu-upgrade\s*\{[^}]*\bborder:\s*1px solid rgb\(255 255 255 \/ 35%\)[^}]*\bborder-radius:\s*7px[^}]*\bfont-weight:\s*400[^}]*\bbackground:\s*transparent/);
    expect(styles).toContain(".home-dashboard__actions .auth-button { width: 120px; min-height: 40px; height: 40px;");
    expect(styles).toContain(".home-dashboard__actions .auth-button { width: 93px; min-height: 31px; height: 31px;");
    expect(styles).toContain(".home-dashboard__actions .auth-button__wide-label { display: none; }");
    expect(styles).toContain(".home-dashboard__actions .auth-button__compact-label { display: inline; }");
  });

  it("places the profile rating bar below Profile on wide screens and below the logo on smaller screens", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toContain(".home-profile-rating-link {\n  display: grid;\n  width: min(340px, calc(100vw - 40px));\n  margin: 0;");
    expect(styles).toContain(".home-dashboard__header > .home-profile-rating-link { position: absolute; top: calc(max(20px, env(safe-area-inset-top)) + 54px); right: clamp(20px, 4vw, 60px); }");
    expect(styles).toContain("@media (min-width: 681px) and (max-width: 1100px) {");
    expect(styles).toContain(".home-dashboard__header > .home-profile-rating-link { top: 138px; right: auto; left: 50%; transform: translateX(-50%); }");
    expect(styles).toContain("@media (max-width: 1100px) {\n  .home-dashboard__header > a[aria-label=\"Backword home\"] { align-self: start; margin-top: 25px; }");
    expect(styles).toContain(".home-profile-rating-link__track { position: relative; display: block; height: 18px; }");
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

  it("sends non-Pro players directly to the web Pro page from the weekly crossword", () => {
    renderDashboard();

    expect(screen.getAllByRole("link", { name: "Pro Crossword" }).find((link) => link.getAttribute("href") === "/pro?return_to=%2Fweekly-crossword"))
      .toHaveAttribute(
      "href",
      "/pro?return_to=%2Fweekly-crossword"
    );
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
