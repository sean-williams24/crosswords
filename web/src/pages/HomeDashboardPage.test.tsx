import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { act, render, screen, waitFor, within } from "@testing-library/react";
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

const testIssueNumbers = vi.hoisted(() => ({
  value: { backword: 121, anagram: 1, crossword: 122, weeklyCrossword: 23 }
}));

const sync = vi.hoisted(() => ({
  refreshAccountProgress: vi.fn().mockResolvedValue(undefined)
}));

vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => testAuth.value }));
vi.mock("../features/home/useHomeGameIssueNumbers", () => ({ useHomeGameIssueNumbers: () => testIssueNumbers.value }));
vi.mock("../features/sync/progressSync", async () => {
  const actual = await vi.importActual<typeof import("../features/sync/progressSync")>("../features/sync/progressSync");
  return { ...actual, refreshAccountProgress: sync.refreshAccountProgress };
});
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
    sessionStorage.clear();
    testAuth.value = { entitlement: null, ready: true, user: null };
    testWordOfTheDay.notify = null;
    testWordOfTheDay.state = "loaded";
    testIssueNumbers.value = { backword: 121, anagram: 1, crossword: 122, weeklyCrossword: 23 };
    sync.refreshAccountProgress.mockReset();
    sync.refreshAccountProgress.mockResolvedValue(undefined);
  });

  it("syncs every account game after sign-in and refreshes the home cards", async () => {
    const today = localDateString();
    sync.refreshAccountProgress.mockImplementation(async (_userId, gameType, _records, applyWinner) => {
      if (gameType !== "backword") return;
      applyWinner({
        game_type: "backword",
        content_key: today,
        release_date: today,
        schema_version: 1,
        status: "solved",
        progress_rank: 2,
        release_score: 4,
        client_updated_at: new Date().toISOString(),
        payload: {
          schemaVersion: 1,
          date: today,
          guesses: ["CASTLE", "CASTLE"],
          completedAt: new Date().toISOString(),
          outcome: "won"
        }
      });
    });
    const view = renderDashboard();

    expect(sync.refreshAccountProgress).not.toHaveBeenCalled();
    testAuth.value.user = { id: "player-1" };
    view.rerender(<MemoryRouter><HomeDashboardPage /></MemoryRouter>);

    await waitFor(() => expect(sync.refreshAccountProgress).toHaveBeenCalledTimes(4));
    expect(sync.refreshAccountProgress.mock.calls.map((call) => [call[0], call[1]])).toEqual([
      ["player-1", "backword"],
      ["player-1", "anagram"],
      ["player-1", "daily_crossword"],
      ["player-1", "weekly_crossword"]
    ]);
    expect(await screen.findByLabelText("Status: 2 guesses")).toBeInTheDocument();
  });

  it("animates the rating bar as a sync indicator until Home progress is refreshed", async () => {
    let finishSync: (() => void) | undefined;
    const pendingSync = new Promise<void>((resolve) => { finishSync = resolve; });
    sync.refreshAccountProgress.mockReturnValue(pendingSync);
    testAuth.value.user = { id: "player-1" };

    renderDashboard();

    const syncingRating = screen.getByRole("link", { name: "Syncing player progress. View player profile" });
    expect(syncingRating).toHaveClass("is-syncing");
    expect(syncingRating.querySelector(".home-profile-rating-link__label")).toHaveTextContent("SYNCING");
    expect(syncingRating.querySelector(".home-profile-rating-link__marker")).not.toBeInTheDocument();

    await act(async () => finishSync?.());

    const rating = await screen.findByRole("link", { name: "Overall rating: Novice. View player profile" });
    expect(rating).not.toHaveClass("is-syncing");
    expect(rating.querySelector(".home-profile-rating-link__label")).toHaveTextContent("NOVICE");
    expect(rating.querySelector(".home-profile-rating-link__marker")).toBeInTheDocument();
  });

  it("reuses a recent account sync when the same signed-in session returns Home", async () => {
    const sessionUser = { id: "player-1", last_sign_in_at: "2026-09-27T20:00:00Z" };
    testAuth.value.user = sessionUser;
    const firstVisit = renderDashboard();

    await screen.findByRole("link", { name: "Overall rating: Novice. View player profile" });
    expect(sync.refreshAccountProgress).toHaveBeenCalledTimes(4);
    expect(Array.from({ length: sessionStorage.length }, (_, index) => sessionStorage.key(index)))
      .toContain("backword:web:home-sync:v1:player-1:2026-09-27T20:00:00Z");
    firstVisit.unmount();

    testAuth.value.user = { ...sessionUser };
    renderDashboard();

    expect(screen.getByRole("link", { name: "Overall rating: Novice. View player profile" })).not.toHaveClass("is-syncing");
    expect(sync.refreshAccountProgress).toHaveBeenCalledTimes(4);
  });

  it("keeps five non-interactive skeleton cards visible until Word of the Day loads", () => {
    testWordOfTheDay.state = "loading";
    const { container } = renderDashboard();

    expect(screen.getByRole("status")).toHaveTextContent("Loading daily games");
    expect(container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(5);
    expect(screen.queryByRole("link", { name: "Quick Crossword" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Pro Crossword/i })).not.toBeInTheDocument();

    testWordOfTheDay.state = "loaded";
    act(() => testWordOfTheDay.notify?.("loaded"));

    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    expect(container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(0);
    expect(screen.getByRole("link", { name: "Quick Crossword, issue #122" })).toBeInTheDocument();
  });

  it("keeps the skeleton visible until account startup has completed", () => {
    testAuth.value.ready = false;
    const view = renderDashboard();

    expect(view.container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(5);

    testAuth.value.ready = true;
    view.rerender(
      <MemoryRouter>
        <HomeDashboardPage />
      </MemoryRouter>
    );

    expect(view.container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(0);
    expect(screen.getByRole("link", { name: "Quick Crossword, issue #122" })).toBeInTheDocument();
  });

  it("shows an informational Word of the Day error card when the row is unavailable", () => {
    testWordOfTheDay.state = "unavailable";
    renderDashboard();

    expect(screen.getByLabelText("Word of the Day unavailable")).toHaveTextContent("Unavailable today");
    expect(screen.getByRole("link", { name: "Quick Crossword, issue #122" })).toBeInTheDocument();
    expect(screen.getAllByRole("link", { name: /^Pro Crossword/i }).find((link) => link.getAttribute("href") === "/pro?return_to=%2Fweekly-crossword"))
      .toBeDefined();
  });

  it("renders the daily cards and playable Backword link", () => {
    const { container } = renderDashboard();

    expect(screen.queryByRole("heading", { name: "Daily Games" })).not.toBeInTheDocument();
    expect(container.querySelector(".home-dashboard__heading")).not.toBeInTheDocument();
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
    const crosswordCard = screen.getByRole("link", { name: "Quick Crossword, issue #122" });
    expect(crosswordCard).toHaveAttribute("href", "/crossword");
    const crosswordStats = crosswordCard.querySelector(".home-game-card__stats");
    expect(crosswordStats).not.toBeNull();
    expect(crosswordStats?.parentElement).toHaveClass("home-game-card__details");
    expect(crosswordStats?.querySelector(".home-game-card__streak")).toBeNull();
    const gamesGrid = crosswordCard.closest(".home-dashboard__games-grid");
    expect(gamesGrid).not.toBeNull();
    expect(gamesGrid?.querySelectorAll(":scope > .home-dashboard__game")).toHaveLength(4);
    expect(Array.from(gamesGrid?.querySelectorAll(":scope > .home-dashboard__game") ?? []).map((game) =>
      game.querySelector("a")?.getAttribute("aria-label")
    )).toEqual([
      "Backword, issue #121",
      "Quick Crossword, issue #122",
      "Anagram, issue #1",
      "Pro Crossword, issue #23"
    ]);
    expect(screen.getByLabelText("Issue #121")).toHaveClass("home-game-card__issue");
    expect(screen.getByLabelText("Issue #122")).toHaveClass("home-game-card__issue");
    expect(screen.getByLabelText("Issue #23")).toHaveClass("weekly-card__issue");
    expect(screen.getAllByLabelText("Status: New")).toHaveLength(3);
    const anagramCard = screen.getByRole("link", { name: "Anagram, issue #1" });
    expect(anagramCard).toHaveAttribute("href", "/anagram");
    expect(within(anagramCard).getByLabelText("Status: New").querySelector(".home-status__icon"))
      .toBeEmptyDOMElement();
    expect(screen.getByRole("link", { name: "Backword Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive%3Fgame%3Dbackword");
    expect(screen.getByRole("link", { name: "Anagram Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive%3Fgame%3Danagram");
    expect(screen.getByRole("link", { name: "Quick Crossword Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive%3Fgame%3Ddaily");
    expect(screen.getByRole("link", { name: "Pro Crossword Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive%3Fgame%3Dweekly");
    expect(screen.getAllByText("Archive", { selector: ".home-archive-link > span" })).toHaveLength(4);
    expect(container.querySelectorAll(".home-archive-link > svg")).toHaveLength(4);
    expect(screen.getByText("13×13")).toBeInTheDocument();
    expect(screen.queryByText("♛")).not.toBeInTheDocument();
  });

  it("lays out all four games before the full-width Word of the Day panel", () => {
    const { container } = renderDashboard();
    const layout = container.querySelector(".home-dashboard__daily-layout");
    const gamesGrid = layout?.querySelector(":scope > .home-dashboard__games-grid");
    const wordOfTheDay = layout?.querySelector(":scope > .wotd-widget");
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(layout?.children[0]).toBe(gamesGrid);
    expect(layout?.children[1]).toBe(wordOfTheDay);
    expect(gamesGrid?.querySelectorAll(":scope > .home-dashboard__game")).toHaveLength(4);
    expect(styles).toContain(".home-dashboard__content {\n  width: min(100% - 48px, 1440px);");
    expect(styles).toContain(".home-dashboard__games-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr));");
    expect(styles).toMatch(/\.home-archive-link\s*\{[^}]*display:\s*flex;[^}]*align-items:\s*center;[^}]*justify-content:\s*center;[^}]*gap:\s*8px;/);
    expect(styles).not.toMatch(/\.home-archive-link\s*\{[^}]*flex-direction:\s*column;/);
    expect(styles).toContain("@media (min-width: 681px) and (max-width: 1200px) {");
    expect(styles).toContain(".home-dashboard__games-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px; }");
    expect(styles).toContain(".home-dashboard__games-grid { grid-template-columns: 1fr; gap: 20px; }");
    expect(styles).toMatch(/\.home-dashboard-loading-card--weekly\s*\{[^}]*height:\s*150px(?![^}]*margin-top)/);
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
    const proCard = screen.getAllByRole("link", { name: /^Pro Crossword/ })
      .find((link) => link.getAttribute("href") === "/weekly-crossword")!;
    const proScore = proCard.querySelector(".weekly-card__stats .home-game-card__score");
    expect(proScore).toHaveTextContent("3/ 5");
    expect(proScore).toHaveClass("home-game-card__score");
  });

  it("uses the menu upgrade treatment for the account link", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.bw-menu-upgrade,\s*\.auth-button\.auth-button--menu-upgrade\s*\{[^}]*\bborder:\s*1px solid rgb\(var\(--app-primary-rgb\) \/ 35%\)[^}]*\bborder-radius:\s*7px[^}]*\bfont-weight:\s*400[^}]*\bbackground:\s*transparent/);
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
    expect(styles).toContain(".home-dashboard__header > .home-profile-rating-link { top: 118px; right: auto; left: 50%; transform: translateX(-50%); }");
    expect(styles).toContain("@media (max-width: 1100px) {\n  .home-dashboard__header > a[aria-label=\"Backword home\"] { align-self: start; margin-top: 25px; }");
    expect(styles).toContain(".home-profile-rating-link__track { position: relative; display: block; height: 18px; }");
    expect(styles).toContain("animation: home-profile-rating-sync 2.5s ease-in-out infinite;");
    expect(styles).toContain("@keyframes home-profile-rating-sync { from { clip-path: inset(0 100% 0 0); } to { clip-path: inset(0 0 0 0); } }");
    expect(styles).toMatch(/@media \(prefers-reduced-motion: reduce\)\s*\{\s*\.home-profile-rating-link\.is-syncing \.home-profile-rating-link__fill\s*\{[^}]*animation:\s*none;/);
  });

  it("uses one grey surface for the weekly crossword dialog", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toContain(".weekly-modal { position: relative; width: min(100%, 520px); max-height: calc(100svh - 40px); overflow-y: auto; border: 1px solid var(--app-control); border-radius: 26px; background: var(--app-surface);");
    expect(styles).toMatch(/\.weekly-modal__hero\s*\{[^}]*display:\s*grid[^}]*height:\s*210px[^}]*place-items:\s*center[^}]*\}/);
    expect(styles).not.toMatch(/\.weekly-modal__hero\s*\{[^}]*\bbackground\s*:/);
  });

  it("uses the Anagram identity and details layout across all game cards", () => {
    const { container } = renderDashboard();
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    const backwordCard = container.querySelector(".home-game-card--backword");
    const crosswordCard = container.querySelector(".home-game-card--crossword");
    const weeklyCard = container.querySelector(".weekly-card");

    expect(backwordCard?.querySelector(".home-game-card__identity .home-game-card__logo")).toBeInTheDocument();
    expect(backwordCard?.querySelector(".home-game-card__identity .home-game-card__issue")).toBeInTheDocument();
    expect(backwordCard?.querySelector(".home-game-card__details .home-status")).toBeInTheDocument();
    expect(crosswordCard?.querySelector(".home-game-card__identity .home-game-card__title")).toHaveTextContent("Quick Crossword");
    expect(crosswordCard?.querySelector(".home-game-card__identity .home-game-card__description")).toHaveTextContent("9×9");
    expect(crosswordCard?.querySelector(".home-game-card__details .home-status")).toBeInTheDocument();
    expect(weeklyCard?.querySelector(".weekly-card__identity .weekly-card__title")).toHaveTextContent("PRO CROSSWORD");
    expect(weeklyCard?.querySelector(".weekly-card__identity small")).toHaveTextContent("13×13");
    expect(weeklyCard?.querySelector(".weekly-card__crown")).not.toBeInTheDocument();
    expect(Array.from(weeklyCard?.querySelector(".weekly-card__identity")?.children ?? []).map((child) => child.className)).toEqual([
      "weekly-card__title",
      "",
      "home-game-card__issue weekly-card__issue"
    ]);
    expect(styles).toMatch(/\.home-game-card\s*\{[^}]*display:\s*grid;[^}]*grid-template-columns:\s*1fr 1fr;/);
    expect(styles).toMatch(/\.home-game-card__identity\s*\{[^}]*align-items:\s*flex-start;[^}]*justify-content:\s*flex-start;/);
    expect(styles).toMatch(/\.home-game-card__details\s*\{[^}]*align-items:\s*flex-end;[^}]*justify-content:\s*flex-end;/);
    expect(styles).toMatch(/\.home-game-card__stats\s*\{[^}]*flex-direction:\s*row;[^}]*align-items:\s*center;[^}]*gap:\s*8px;/);
    expect(styles).toContain(".home-game-card__stats--streak-only { margin-top: 4px; }");
    expect(styles).toMatch(/\.home-game-card__title\s*\{[^}]*font-size:\s*clamp\(16px, 2vw, 16px\)/);
    expect(styles).toMatch(/\.weekly-card__title\s*\{[^}]*font-size:\s*clamp\(16px, 2vw, 16px\)/);
    expect(styles).toContain(".home-game-card--crossword .home-game-card__identity { padding-top: 4px; }");
    expect(styles).toMatch(/\.weekly-card__identity\s*\{[^}]*padding-top:\s*4px;/);
    expect(styles).toContain(".home-game-card--backword .home-game-card__logo { margin-bottom: -16px; transform: translateX(-16.3%); }");
    expect(styles).toContain(".weekly-card__issue { color: rgb(214 190 135 / 70%); }");
  });

  it("matches the iOS light home-card surfaces", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toContain('html[data-theme="light"] .home-game-card--backword {\n  background: color(display-p3 0.670 0.655 0.845);');
    expect(styles).toContain('background: linear-gradient(rgb(255 255 255 / 10%), rgb(255 255 255 / 10%)), color(display-p3 0.289 0.397 0.544);');
    expect(styles).toContain('html[data-theme="light"] .home-game-card--backword .home-game-card__score small,\nhtml[data-theme="light"] .home-game-card--crossword .home-game-card__score small { color: rgb(255 255 255 / 58%); }');
    expect(styles).toContain('html[data-theme="light"] .home-game-card--backword .home-game-card__score.is-perfect strong { color: #c6f6b5; }');
    expect(styles).toContain('html[data-theme="light"] .weekly-card {\n  border-color: #d9a640;\n  color: #d9a640;\n  background: var(--app-surface);');
  });

  it("keeps the Backword home card borderless at rest in both themes", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).not.toContain(".home-game-card--backword::after");
    expect(styles).toContain("border: 1px solid transparent;");
    expect(styles).toContain(".home-game-card:focus-visible::after { border-color: var(--app-text-primary); }");
  });

  it("matches the iOS Anagram home-card colours in light and dark mode", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toContain('src: url("/fonts/Outfit-Black.ttf") format("truetype");');
    expect(styles).toContain('--anagram-home-card-accent: color(srgb 0.967 0.434 0.040);');
    expect(styles).toContain('--anagram-home-card-accent: color(display-p3 1 0.604 0.331);');
    expect(styles).toMatch(/\.home-game-card--anagram\s*\{[^}]*padding:\s*12px 18px[^}]*border-radius:\s*12px[^}]*color:\s*var\(--anagram-on-accent\)[^}]*background:\s*var\(--anagram-home-card-accent\)/);
    expect(styles).toMatch(/\.home-game-card--anagram \.home-status\s*\{[^}]*border:\s*0[^}]*color:\s*var\(--anagram-on-accent\)[^}]*background:\s*color-mix\(in srgb, var\(--anagram-on-accent\) 12%, transparent\)/);
    expect(styles).toMatch(/\.home-game-card--anagram \.home-game-card__streak\s*\{[^}]*border-radius:\s*12px[^}]*color:\s*var\(--anagram-on-accent\)/);
    expect(styles).toMatch(/\.home-game-card__stats\s*\{[^}]*flex-direction:\s*row;[^}]*align-items:\s*center;[^}]*gap:\s*8px;/);
    expect(styles).toMatch(/\.anagram-home-card__identity strong\s*\{[^}]*font-size:\s*clamp\(17px, 2vw, 24px\)[^}]*font-weight:\s*900/);
    expect(styles).toMatch(/@media \(max-width: 430px\)\s*\{\s*\.anagram-home-card__identity strong\s*\{[^}]*font-size:\s*24px;/);
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

    expect(screen.getAllByRole("link", { name: /^Pro Crossword/ }).find((link) => link.getAttribute("href") === "/pro?return_to=%2Fweekly-crossword"))
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

    expect(screen.getAllByRole("link", { name: /^Pro Crossword/ }).find((link) => link.getAttribute("href") === "/weekly-crossword"))
      .toBeDefined();
  });
});
