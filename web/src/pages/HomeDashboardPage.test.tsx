import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { act, render, screen, waitFor, within } from "@testing-library/react";
import { useLayoutEffect } from "react";
import { MemoryRouter } from "react-router-dom";
import { localDateOffset, localDateString, localWeekStartString } from "../features/backword/date";
import { emptyProgress } from "../features/crossword/engine";
import { emptyProgress as emptyBackwordProgress } from "../features/backword/engine";
import { createBackwordStorage } from "../features/backword/storage";
import { emptyProgress as emptyMidwordProgress } from "../features/midword/engine";
import { createMidwordStorage } from "../features/midword/storage";
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
  value: { backword: 121, anagram: 1 as number | null, midword: 11, crossword: 122, weeklyCrossword: 23 }
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
    testIssueNumbers.value = { backword: 121, anagram: 1, midword: 11, crossword: 122, weeklyCrossword: 23 };
    sync.refreshAccountProgress.mockReset();
    sync.refreshAccountProgress.mockResolvedValue(undefined);
  });

  afterEach(() => vi.useRealTimers());

  it.each([false, true])("hides zero streaks on every game card (Pro: %s)", (isPro) => {
    testAuth.value.entitlement = isPro ? { isPro: true, expiresAt: null } : null;
    const { container } = renderDashboard();
    for (const selector of [".home-game-card--backword", ".home-game-card--crossword", ".home-game-card--anagram", ".home-game-card--midword", ".weekly-card"]) {
      const card = container.querySelector(selector)!;
      const streak = card.querySelector(":scope > .home-game-card__streak");
      expect(streak).toBeNull();
      expect(card.querySelector("[class$='__identity'] .home-game-card__streak")).toBeNull();
      expect(card.querySelector("[class$='__details'] .home-game-card__streak")).toBeNull();
    }
  });

  it("uses saved release-day results for Backword and Midword Home streaks", () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date(2026, 9, 12, 12));
    const today = localDateString();
    const backwordStorage = createBackwordStorage();
    const midwordStorage = createMidwordStorage();
    for (const offset of [-1, 0]) {
      const date = localDateOffset(today, offset);
      const completedAt = new Date(`${date}T12:00:00`).toISOString();
      backwordStorage.saveProgress({ ...emptyBackwordProgress(date), guesses: ["CASTLE"], outcome: "won", completedAt });
    }
    midwordStorage.saveProgress({ ...emptyMidwordProgress(today), guesses: ["NOTE"], outcome: "won", completedAt: new Date().toISOString(), releaseDateScore: 5 });
    // An archive win completed today must not extend the Home streak.
    const archiveDate = localDateOffset(today, -1);
    midwordStorage.saveProgress({ ...emptyMidwordProgress(archiveDate), guesses: ["NOTE"], outcome: "won", completedAt: new Date().toISOString(), releaseDateScore: 0 });
    const { container } = renderDashboard();
    expect(container.querySelector(".home-game-card--backword > .home-game-card__streak")).toHaveTextContent("2");
    expect(container.querySelector(".home-game-card--midword > .home-game-card__streak")).toHaveTextContent("1");
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

    await waitFor(() => expect(sync.refreshAccountProgress).toHaveBeenCalledTimes(5));
    expect(sync.refreshAccountProgress.mock.calls.map((call) => [call[0], call[1]])).toEqual([
      ["player-1", "backword"],
      ["player-1", "anagram"],
      ["player-1", "midword"],
      ["player-1", "daily_crossword"],
      ["player-1", "weekly_crossword"]
    ]);
    expect(await screen.findByLabelText("Status: 2 guesses")).toBeInTheDocument();
    const backwordCard = screen.getAllByRole("link").find((link) => link.getAttribute("href") === "/backword")!;
    expect(backwordCard.querySelector(":scope > .home-game-card__streak")).toHaveTextContent("1");
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
    expect(sync.refreshAccountProgress).toHaveBeenCalledTimes(5);
    expect(Array.from({ length: sessionStorage.length }, (_, index) => sessionStorage.key(index)))
      .toContain("backword:web:home-sync:v1:player-1:2026-09-27T20:00:00Z");
    firstVisit.unmount();

    testAuth.value.user = { ...sessionUser };
    renderDashboard();

    expect(screen.getByRole("link", { name: "Overall rating: Novice. View player profile" })).not.toHaveClass("is-syncing");
    expect(sync.refreshAccountProgress).toHaveBeenCalledTimes(5);
  });

  it("reserves six grid positions plus Word of the Day while content loads", () => {
    testWordOfTheDay.state = "loading";
    const { container } = renderDashboard();

    expect(screen.getByRole("status")).toHaveTextContent("Loading daily games");
    expect(container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(7);
    const gridSkeletons = container.querySelectorAll(".home-dashboard__games-grid > .home-dashboard-loading-card");
    expect(gridSkeletons).toHaveLength(6);
    expect(Array.from(gridSkeletons).map((card) => card.className.split(" ")[1])).toEqual([
      "home-dashboard-loading-card--backword", "home-dashboard-loading-card--anagram", "home-dashboard-loading-card--midword",
      "home-dashboard-loading-card--crossword", "home-dashboard-loading-card--archive", "home-dashboard-loading-card--weekly"
    ]);
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

    expect(view.container.querySelectorAll(".home-dashboard-loading-card")).toHaveLength(7);

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
    expect(gamesGrid?.querySelectorAll(":scope > .home-dashboard__game")).toHaveLength(6);
    expect(Array.from(gamesGrid?.querySelectorAll(":scope > .home-dashboard__game") ?? []).map((game) =>
      game.querySelector("a")?.getAttribute("aria-label")
    )).toEqual([
      "Backword, issue #121",
      "Anagram, issue #1",
      "Midword, issue #11",
      "Quick Crossword, issue #122",
      "Archive",
      "Pro Crossword, issue #23"
    ]);
    expect(screen.getByLabelText("Issue #121")).toHaveClass("home-game-card__issue");
    expect(screen.getByLabelText("Issue #122")).toHaveClass("home-game-card__issue");
    expect(screen.getByLabelText("Issue #23")).toHaveClass("weekly-card__issue");
    expect(screen.getAllByLabelText("Status: New")).toHaveLength(4);
    const anagramCard = screen.getByRole("link", { name: "Anagram, issue #1" });
    expect(anagramCard).toHaveAttribute("href", "/anagram");
    expect(within(anagramCard).getByLabelText("Status: New").querySelector(".home-status__icon"))
      .toBeEmptyDOMElement();
    expect(screen.getByRole("link", { name: "Midword, issue #11" })).toHaveAttribute("href", "/midword");
    expect(within(gamesGrid as HTMLElement).getByRole("link", { name: "Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive");
    expect(container.querySelectorAll(".home-game-card--archive")).toHaveLength(1);
    expect(container.querySelectorAll(".home-archive-link")).toHaveLength(0);
    expect(screen.queryByRole("link", { name: /^(Backword|Anagram|Midword|Quick Crossword|Pro Crossword) Archive$/ })).not.toBeInTheDocument();
    expect(screen.getByText("13×13")).toBeInTheDocument();
    expect(screen.queryByText("♛")).not.toBeInTheDocument();
  });

  it("lays out six equal cards in three columns before the full-width Word of the Day panel", () => {
    const { container } = renderDashboard();
    const layout = container.querySelector(".home-dashboard__daily-layout");
    const gamesGrid = layout?.querySelector(":scope > .home-dashboard__games-grid");
    const wordOfTheDay = layout?.querySelector(":scope > .wotd-widget");
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(layout?.children[0]).toBe(gamesGrid);
    expect(layout?.children[1]).toBe(wordOfTheDay);
    expect(gamesGrid?.querySelectorAll(":scope > .home-dashboard__game")).toHaveLength(6);
    expect(styles).toContain(".home-dashboard__content {\n  width: min(100% - 48px, 1440px);");
    expect(styles).toMatch(/\.home-dashboard__games-grid\s*\{[^}]*grid-template-columns:\s*repeat\(3, minmax\(0, 1fr\)\);[^}]*grid-auto-rows:\s*1fr;[^}]*align-items:\s*stretch;/);
    expect(styles).toMatch(/\.home-dashboard__game\s*\{[^}]*display:\s*grid;[^}]*min-width:\s*0;/);
    for (const wrapper of gamesGrid?.children ?? []) expect(wrapper.children).toHaveLength(1);
    expect(styles).not.toContain(".home-archive-link");
    expect(styles).toContain("@media (min-width: 681px) and (max-width: 1200px) {");
    expect(styles).not.toContain(".home-dashboard__games-grid { grid-template-columns: repeat(2,");
    expect(styles).toContain(".home-dashboard__games-grid { grid-template-columns: 1fr; gap: 20px; }");
    expect(styles).not.toMatch(/\.home-dashboard-loading-card--weekly\s*\{[^}]*[;{]\s*height:/);
  });

  it("keeps the Anagram grid position when its issue number has not loaded", () => {
    testIssueNumbers.value.anagram = null;
    const { container } = renderDashboard();
    const cards = container.querySelectorAll(".home-dashboard__games-grid > .home-dashboard__game");
    expect(cards).toHaveLength(6);
    expect(within(cards[1] as HTMLElement).getByRole("link", { name: "Anagram" })).toHaveAttribute("href", "/anagram");
    expect(within(cards[4] as HTMLElement).getByRole("link", { name: "Archive" })).toBeInTheDocument();
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
    expect(backwordCard?.querySelector(".home-game-card__details")?.querySelector(".home-status")).toHaveClass("home-status");
    const proCard = screen.getAllByRole("link", { name: /^Pro Crossword/ })
      .find((link) => link.getAttribute("href") === "/weekly-crossword")!;
    const proScore = proCard.querySelector(".weekly-card__stats .home-game-card__score");
    expect(proScore).toHaveTextContent("3/ 5");
    expect(proScore).toHaveClass("home-game-card__score");
    expect(proCard.querySelector(".weekly-card__details")?.querySelector(".weekly-card__status")).toHaveClass("weekly-card__status");
    expect(proCard.querySelector(".weekly-card__details")?.firstElementChild?.contains(proScore)).toBe(true);
    expect(proCard.querySelector(".weekly-card__details > .weekly-card__issue")).toBeInTheDocument();
    expect(proCard.querySelector(":scope > .home-game-card__streak")).toBeInTheDocument();
    expect(proCard.querySelector(".weekly-card__identity > .weekly-card__description")).toHaveTextContent("13×13");
    expect(proCard.querySelector(".weekly-card__details .home-game-card__streak")).not.toBeInTheDocument();
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

  it("centres every game brand independently of its footer issue number", () => {
    const { container } = renderDashboard();
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const midwordStyles = readFileSync(resolve(process.cwd(), "src/features/midword/midword.css"), "utf8");

    for (const [cardSelector, identitySelector] of [
      [".home-game-card--backword", ".home-game-card__identity"],
      [".home-game-card--crossword", ".home-game-card__identity"],
      [".home-game-card--anagram", ".anagram-home-card__identity"],
      [".home-game-card--midword", ".midword-home-card__identity"],
      [".weekly-card", ".weekly-card__identity"]
    ]) {
      const card = container.querySelector(cardSelector)!;
      expect(card.querySelector(".home-game-card__issue")).toBeInTheDocument();
      expect(card.querySelector(`${identitySelector} .home-game-card__issue`)).not.toBeInTheDocument();
      const identityRule = new RegExp(`${identitySelector.replace(".", "\\.")}\\s*\\{[^}]*align-items:\\s*center;[^}]*justify-content:\\s*center;`);
      expect(styles + midwordStyles).toMatch(identityRule);
    }

    expect(styles).toContain('grid-template-areas: ". . streak" "identity identity identity" "details details details";');
    expect(styles).toMatch(/\.home-game-card__issue\s*\{[^}]*grid-column:\s*3;[^}]*grid-row:\s*1;[^}]*justify-self:\s*end;/);
    expect(styles).toMatch(/\.midword-home-card__details\s*\{[^}]*display:\s*grid;[^}]*grid-template-columns:\s*minmax\(0, 1fr\) auto minmax\(0, 1fr\);[^}]*align-items:\s*end;/);
    expect(styles).not.toContain("transform: translateX(-16.3%)");
    expect(container.querySelector(".weekly-card__identity > .weekly-card__description")).toHaveTextContent("13×13");
    expect(container.querySelector(".weekly-card > .weekly-card__description")).toBeNull();
    expect(container.querySelector(".weekly-card__description")?.previousElementSibling).toHaveClass("weekly-card__title");
    expect(container.querySelector(".home-game-card--crossword .home-game-card__description")).toHaveTextContent("9×9");
  });

  it("centres branding between equal top and bottom spaces within compact cards", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    for (const selector of ["home-game-card", "weekly-card", "home-game-card--anagram"]) {
      const rule = styles.match(new RegExp(`^\\.${selector}\\s*\\{([^}]+)\\}`, "m"))![1];
      expect(rule).toContain("grid-template-rows: minmax(32px, 1fr) auto minmax(32px, 1fr);");
    }
    expect(styles).toMatch(/\.home-game-card__issue\s*\{[^}]*align-self:\s*end;/);
    expect(styles).toMatch(/\.midword-home-card__details\s*\{[^}]*align-self:\s*end;/);
    expect(styles).not.toMatch(/\.home-game-card__description\s*\{[^}]*(?:grid-area|position):/);
    expect(styles).not.toMatch(/\.weekly-card__description\s*\{[^}]*(?:grid-area|position):/);
    expect(styles).toMatch(/\.home-game-card--crossword\s*\{[^}]*row-gap:\s*0;/);
    expect(styles).toMatch(/\.weekly-card\s*\{[^}]*row-gap:\s*0;/);

    for (const selector of ["home-game-card__title", "weekly-card__title", "anagram-home-card__identity strong"]) {
      const rule = styles.match(new RegExp(`^\\.${selector}\\s*\\{([^}]+)\\}`, "m"))![1];
      const letterSpacing = rule.match(/letter-spacing:\s*([\d.]+em)/)![1];
      expect(rule).toContain(`padding-left: ${letterSpacing};`);
    }
  });

  it("keeps scores at the bottom left, status at the centre, and streaks at the top right", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const midwordStyles = readFileSync(resolve(process.cwd(), "src/features/midword/midword.css"), "utf8");
    const nativeTheme = readFileSync(resolve(process.cwd(), "../Backword/Theme/AppTheme.swift"), "utf8");
    const nativeHeight = nativeTheme.match(/cardHeightSmall: CGFloat = (\d+)/)![1];

    for (const selector of ["home-game-card", "weekly-card", "home-dashboard-loading-card"]) {
      expect(styles).toMatch(new RegExp(`\\.${selector}\\s*\\{[^}]*min-height:\\s*${nativeHeight}px;`));
    }
    expect(styles).not.toMatch(/\.home-game-card\s*\{[^}]*min-height:\s*160px;/);
    expect(styles).toMatch(/\.home-game-card__score\s*\{[^}]*grid-column:\s*1;[^}]*grid-row:\s*1;[^}]*justify-self:\s*start;[^}]*align-self:\s*end;/);
    expect(styles).toMatch(/\.home-game-card__streak\s*\{[^}]*grid-area:\s*streak;[^}]*justify-self:\s*end;[^}]*align-self:\s*start;/);
    expect(styles).toMatch(/\.weekly-card__status\s*\{[^}]*grid-column:\s*2;[^}]*grid-row:\s*1;[^}]*justify-self:\s*center;/);
    for (const selector of ["home-game-card__details", "anagram-home-card__details", "midword-home-card__details"]) {
      expect(styles).toContain(`.${selector} > .home-status`);
    }
    expect(styles).toContain(".weekly-card__details:has(.home-game-card__score) > .weekly-card__status");
    expect(styles).toContain("grid-row: 2;");
    const midwordLogoHeight = nativeTheme.match(/midwordHomeCardLogoHeight: CGFloat = (\d+)/)![1];
    expect(styles).toMatch(/\.home-game-card__logo\s*\{[^}]*height:\s*48px;/);
    expect(styles).toMatch(/\.home-game-card--backword\s*\{[^}]*row-gap:\s*4px;/);
    expect(midwordStyles).toMatch(new RegExp(`\\.midword-home-card__identity img\\s*\\{[^}]*height:\\s*${midwordLogoHeight}px;`));
  });

  it("uses smaller iOS-style streak pills with an orange flame and a white Backword flame in light mode", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const streakRule = styles.match(/^\.home-game-card__streak\s*\{([^}]+)\}/m)![1];
    expect(streakRule).toContain("min-height: 26px;");
    expect(streakRule).toContain("padding: 4px 9px;");
    expect(streakRule).toContain("border-radius: 999px;");
    expect(streakRule).toContain("font-size: 11px;");
    expect(streakRule).toContain("background: rgb(99 164 222 / 12%);");
    expect(styles).toMatch(/\.home-game-card__streak-icon\s*\{[^}]*color:\s*#ff9f0a;/);
    expect(styles).toMatch(/html\[data-theme="light"\] \.home-game-card--backword \.home-game-card__streak-icon\s*\{[^}]*color:\s*#fff;/);
    expect(styles).not.toMatch(/html\[data-theme="light"\] \.home-game-card__streak\s*\{[^}]*border:\s*1px/);
  });

  it("matches the iOS light home-card surfaces", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toContain('html[data-theme="light"] .home-game-card--backword {\n  background: color(display-p3 0.670 0.655 0.845);');
    expect(styles).toContain('background: linear-gradient(rgb(255 255 255 / 10%), rgb(255 255 255 / 10%)), color(display-p3 0.289 0.397 0.544);');
    expect(styles).toContain('html[data-theme="light"] .home-game-card--backword .home-game-card__score small,\nhtml[data-theme="light"] .home-game-card--crossword .home-game-card__score small { color: rgb(255 255 255 / 58%); }');
    expect(styles).toContain('html[data-theme="light"] .home-game-card--backword .home-game-card__score.is-perfect strong { color: #c6f6b5; }');
  });

  it.each([false, true])("gives the web Pro card a metallic fill and gradient border (Pro: %s)", (isPro) => {
    testAuth.value.entitlement = isPro ? { isPro: true, expiresAt: null } : null;
    const { container } = renderDashboard();
    expect(container.querySelector(".weekly-card")).toBeInTheDocument();
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const cardRule = styles.match(/^\.weekly-card\s*\{([^}]+)\}/m)![1];
    expect(cardRule).toContain("border: 2px solid transparent;");
    expect(cardRule).toContain("--weekly-card-glow: 4%;");
    expect(cardRule).toContain("rgb(255 193 77 / 3%) 75%) padding-box");
    expect(cardRule).toContain("linear-gradient(135deg, #1c1c1e, #000000) padding-box");
    expect(cardRule).toContain("linear-gradient(135deg, color(srgb 0.85 0.65 0.25), color(srgb 0.78 0.52 0.2), color(srgb 0.85 0.65 0.25)) border-box");
    expect(cardRule).toContain("--app-text-primary: #eeeeee;");
    expect(styles).toMatch(/\.weekly-card:hover,\s*\.weekly-card:focus-visible\s*\{[^}]*--weekly-card-glow:\s*5%;/);
    expect(styles).toMatch(/\.weekly-card:focus-visible\s*\{[^}]*outline:\s*2px solid #ffd27a;/);
    expect(styles).not.toMatch(/html\[data-theme="light"\] \.weekly-card(?:[:\s][^{]*)?\s*\{[^}]*background:/);
  });

  it("matches native Pro title and metadata colours while keeping Pro Only white", () => {
    const { container } = renderDashboard();
    expect(container.querySelector(".weekly-card .home-status--pro-only")).toHaveTextContent("Pro Only");
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const nativeTheme = readFileSync(resolve(process.cwd(), "../Backword/Theme/AppTheme.swift"), "utf8");
    const nativeStops = nativeTheme.match(/enum AppGradient\s*\{[\s\S]*?colors:\s*\[([\s\S]*?)\]/)![1];
    const stops = Array.from(nativeStops.matchAll(/Color\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\)/g),
      (match) => `color(srgb ${Number(match[1])} ${Number(match[2])} ${Number(match[3])})`);
    expect(stops).toHaveLength(3);
    const titleRule = styles.match(/^\.weekly-card__title\s*\{([^}]+)\}/m)![1];
    expect(titleRule).toContain(`linear-gradient(135deg, ${stops.join(", ")})`);
    const cardRule = styles.match(/^\.weekly-card\s*\{([^}]+)\}/m)![1];
    expect(cardRule).toContain(`linear-gradient(135deg, ${stops.join(", ")}) border-box`);
    expect(titleRule).toContain("background-clip: text;");
    expect(styles).toMatch(/\.weekly-card__issue\s*\{[^}]*color:\s*color\(srgb 0\.92 0\.72 0\.22 \/ 0\.58\);/);
    expect(styles).toMatch(/\.weekly-card\s*\{[^}]*--app-text-secondary:\s*#777777;[^}]*--app-accent:\s*color\(srgb 0\.2 0\.467 0\.694\);/);
    expect(styles).toMatch(/\.weekly-card \.home-status--pro-only\s*\{[^}]*color:\s*#fff;/);
    expect(styles).not.toContain('html[data-theme="light"] .weekly-card__title');
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
    expect(styles).toMatch(/\.home-game-card--anagram \.home-game-card__streak\s*\{[^}]*color:\s*var\(--anagram-on-accent\)/);
    expect(styles).toMatch(/\.home-game-card__stats\s*\{[^}]*display:\s*contents;/);
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
