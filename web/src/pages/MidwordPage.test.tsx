import { act, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { localDateOffset, localDateString } from "../features/backword/date";
import { createMidwordStorage } from "../features/midword/storage";
import { emptyProgress, submitGuess, type MidwordPuzzle } from "../features/midword/engine";
import { MidwordPage } from "./MidwordPage";
import { readFileSync } from "node:fs";

const mocks = vi.hoisted(() => ({
  fetch: vi.fn(), track: vi.fn(), queue: vi.fn(), migrate: vi.fn().mockResolvedValue(undefined),
  refresh: vi.fn().mockResolvedValue(undefined),
  auth: { ready: true, entitlementReady: true, user: null as { id: string } | null,
    entitlement: null as { isPro: boolean } | null }
}));
vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => mocks.auth }));
vi.mock("../features/analytics/AnalyticsProvider", () => ({ useAnalytics: () => ({ track: mocks.track }) }));
vi.mock("../features/midword/repository", () => ({ createMidwordRepository: () => ({ getByDate: mocks.fetch }) }));
vi.mock("../features/sync/progressSync", async () => ({
  ...await vi.importActual<typeof import("../features/sync/progressSync")>("../features/sync/progressSync"),
  queueAndDebounce: mocks.queue, migrateProgress: mocks.migrate, refreshAccountProgress: mocks.refresh
}));

function puzzle(date = localDateString()): MidwordPuzzle {
  return { id: `midword-${date}`, date, puzzleNumber: 11, firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: [] };
}
function renderGame(path = "/midword") {
  return render(<MemoryRouter initialEntries={[path]}><Routes>
    <Route element={<MidwordPage />} path="/midword" />
    <Route element={<MidwordPage />} path="/midword/:date" />
    <Route element={<p>Pro destination</p>} path="/pro" />
    <Route element={<p>Home destination</p>} path="/" />
  </Routes></MemoryRouter>);
}
async function typeGuess(user: ReturnType<typeof userEvent.setup>, word: string) {
  await user.keyboard(word); await user.click(screen.getByRole("button", { name: "Submit" }));
}

describe("Midword browser gameplay", () => {
  beforeEach(() => {
    localStorage.clear(); vi.clearAllMocks();
    mocks.auth = { ready: true, entitlementReady: true, user: null, entitlement: null };
    mocks.fetch.mockImplementation(async (date: string) => puzzle(date));
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
  });
  it("renders the native prompt arrangement and exact answer length", async () => {
    renderGame();
    const board = await screen.findByRole("region", { name: "Midword board" });
    expect(board.firstElementChild).toHaveTextContent("BANK");
    expect(board.lastElementChild).toHaveTextContent("BOOK");
    expect(within(board).getByRole("group", { name: "Middle word, 0 of 4 letters entered" }).children).toHaveLength(4);
    expect(screen.getByLabelText("5 attempts remaining")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Submit" })).not.toBeInTheDocument();
  });
  it("keeps site navigation after the board and controls before and after the first guess", async () => {
    const user = userEvent.setup(); renderGame();
    const board = await screen.findByRole("region", { name: "Midword board" });
    const main = board.closest("main");
    const shell = main?.parentElement;
    const footer = screen.getByRole("navigation", { name: "Footer" }).closest("footer");
    expect(screen.queryByRole("region", { name: "Previous guesses" })).not.toBeInTheDocument();
    expect(shell?.nextElementSibling).toBe(footer);
    expect(shell?.parentElement).toHaveClass("midword-page");
    expect(footer).toContainElement(screen.getByRole("link", { name: "Midword" }));
    await typeGuess(user, "PAGE");
    expect(main).toContainElement(screen.getByRole("region", { name: "Previous guesses" }));
    expect(shell?.nextElementSibling).toBe(footer);
    expect(main).not.toContainElement(screen.getByRole("group", { name: "Midword keyboard" }));
  });
  it("lets a long guess history and Submit extend the page instead of scrolling behind the keyboard", async () => {
    const style = document.createElement("style");
    style.textContent = readFileSync("src/features/midword/midword.css", "utf8");
    document.head.append(style);
    try {
      createMidwordStorage().saveProgress({ ...emptyProgress(localDateString()), guesses: ["PAGE", "READ", "LINE", "BOOK"] });
      const user = userEvent.setup(); renderGame();
      const history = await screen.findByRole("region", { name: "Previous guesses" });
      await user.keyboard("WORD");
      expect(screen.getByRole("button", { name: "Submit" })).toBeInTheDocument();
      expect(within(history).getAllByRole("group")).toHaveLength(4);
      const main = history.closest("main")!;
      const shell = main.parentElement!;
      expect(getComputedStyle(main).overflow).toBe("visible");
      expect(getComputedStyle(main).flexShrink).toBe("0");
      expect(getComputedStyle(shell).overflow).toBe("visible");
      expect(getComputedStyle(shell.parentElement!).height).toBe("auto");
      expect(shell.lastElementChild).toContainElement(screen.getByRole("group", { name: "Midword keyboard" }));
    } finally {
      style.remove();
    }
  });
  it("uses Backword's centered large logo layout and header action placement", async () => {
    renderGame();
    const logo = await screen.findByRole("img", { name: "Midword" });
    expect(logo).toHaveClass("bw-logo", "bw-logo--large");
    expect(logo.parentElement).toHaveClass("bw-logo-lockup", "bw-logo-lockup--large");
    expect(logo.closest("header")).toHaveClass("bw-game-header", "bw-game-header--offset");
    expect(screen.getByRole("navigation", { name: "Midword actions" })).toHaveClass("bw-game-actions--top", "bw-game-actions--logo-header");
  });
  it("uses the shared keyboard-width rating bar with a visible zero-score fill and no Today label", async () => {
    renderGame();
    const bar = await screen.findByLabelText("0 of 70 Midword points");
    expect(bar).toHaveClass("bw-game-score", "bw-game-score--keyboard-width");
    expect(bar.firstElementChild).toHaveStyle({ clipPath: "inset(0 99% 0 0)" });
    expect(screen.queryByText(/^Today:/)).not.toBeInTheDocument();
    expect(bar.parentElement).toContainElement(screen.getByRole("group", { name: "Midword keyboard" }));
  });
  it("fills the rating bar from earned history without awarding points for today's wrong guesses", async () => {
    const yesterday = localDateOffset(localDateString(), -1);
    createMidwordStorage().saveProgress({ ...emptyProgress(yesterday), guesses: ["PAGE", "WORD", "NOTE"],
      outcome: "won", completedAt: new Date(`${yesterday}T12:00:00`).toISOString(), releaseDateScore: 3 });
    const user = userEvent.setup(); renderGame();
    const bar = await screen.findByLabelText("3 of 70 Midword points");
    expect(bar.firstElementChild).toHaveStyle({ clipPath: `inset(0 ${100 - 3 / 70 * 100}% 0 0)` });
    await typeGuess(user, "PAGE");
    expect(screen.queryByText(/^Today:/)).not.toBeInTheDocument();
    expect(bar).toHaveAttribute("aria-label", "3 of 70 Midword points");
  });
  it("places the rating bar directly above the keyboard or Submit as input is filled and cleared", async () => {
    const user = userEvent.setup(); renderGame();
    const bar = await screen.findByLabelText("0 of 70 Midword points");
    await typeGuess(user, "PAGE");
    const history = screen.getByRole("region", { name: "Previous guesses" });
    const keyboard = screen.getByRole("group", { name: "Midword keyboard" });
    const transition = bar.nextElementSibling;
    expect(transition).toHaveClass("game-submit");
    expect(transition).not.toHaveClass("game-submit--visible");
    expect(transition?.nextElementSibling).toBe(keyboard);
    await user.keyboard("WORD");
    const submit = screen.getByRole("button", { name: "Submit" });
    expect(bar.nextElementSibling).toBe(transition);
    expect(transition).toHaveClass("game-submit--visible");
    expect(transition).toContainElement(submit);
    expect(transition?.nextElementSibling).toBe(keyboard);
    expect(history).toBeInTheDocument();
    expect(bar.closest("footer")?.previousElementSibling).toContainElement(history);
    expect(screen.queryByText(/^Today:/)).not.toBeInTheDocument();
    await user.keyboard("{Backspace}");
    expect(screen.queryByRole("button", { name: "Submit" })).not.toBeInTheDocument();
    expect(bar.nextElementSibling).toBe(transition);
    expect(transition).not.toHaveClass("game-submit--visible");
    expect(submit).toBeDisabled();
  });
  it("accepts the on-screen keyboard, reveals completion and saves a release-day score", async () => {
    const user = userEvent.setup(); renderGame();
    const keyboard = await screen.findByRole("group", { name: "Midword keyboard" });
    for (const letter of "NOTE") await user.click(within(keyboard).getByRole("button", { name: letter }));
    await user.click(screen.getByRole("button", { name: "Submit" }));
    const result = await screen.findByRole("dialog", { name: "Solved!" });
    expect(within(result).getByText("BANKNOTE · NOTEBOOK")).toBeInTheDocument();
    expect(within(result).getByLabelText("Midword completion statistics")).toHaveTextContent("5/5");
    expect(createMidwordStorage().loadProgress(localDateString()).releaseDateScore).toBe(5);
    expect(screen.queryByRole("group", { name: "Midword keyboard" })).not.toBeInTheDocument();
    expect(mocks.track.mock.calls.map((args) => args[0].name)).toEqual(["game_started", "game_completed"]);
    await user.click(within(result).getByRole("button", { name: "BACK TO GAME" }));
    expect(screen.getByRole("button", { name: "Share result" })).toBeInTheDocument();
  });
  it("retains invalid and duplicate input without consuming an attempt", async () => {
    const user = userEvent.setup(); renderGame(); await screen.findByRole("region", { name: "Midword board" });
    await typeGuess(user, "ZZZZ");
    const label = screen.getByRole("alert");
    expect(label).toHaveTextContent("Not a valid word");
    expect(screen.getByLabelText("Middle word, 4 of 4 letters entered")).toHaveClass("is-shaking");
    const transition = label.closest(".game-input-message");
    expect(transition).toHaveClass("game-input-message--visible");
    expect(transition?.parentElement).toContainElement(screen.getByLabelText("5 attempts remaining"));
    expect(screen.getByLabelText("5 attempts remaining")).toBeInTheDocument();
    await user.keyboard("{Backspace}");
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(transition).not.toHaveClass("game-input-message--visible");
    expect(label).toHaveTextContent("Not a valid word");
    expect(screen.getByLabelText("Middle word, 3 of 4 letters entered")).not.toHaveClass("is-shaking");
    await user.keyboard("{Backspace}{Backspace}{Backspace}");
    await typeGuess(user, "PAGE");
    const history = screen.getByRole("region", { name: "Previous guesses" });
    const previousGuess = within(history).getByRole("group", { name: "PAGE, incorrect" });
    expect(previousGuess.children).toHaveLength(4);
    expect(history).toHaveClass("midword-guesses");
    const answerInput = screen.getByRole("group", { name: "Middle word, 0 of 4 letters entered" });
    expect(answerInput.children).toHaveLength(4);
    expect(history).not.toContainElement(answerInput);
    await typeGuess(user, "PAGE");
    expect(screen.getByRole("alert")).toHaveTextContent("Already guessed");
    expect(screen.getByRole("alert")).toBe(label);
    expect(transition).toHaveClass("game-input-message--visible");
    expect(screen.getByLabelText("4 attempts remaining")).toBeInTheDocument();
    expect(within(history).getAllByRole("group")).toHaveLength(1);
    expect(createMidwordStorage().loadProgress(localDateString()).guesses).toEqual(["PAGE"]);
  });
  it("matches Backword's shake and red invalid-word label, hiding it after two seconds without consuming a guess", async () => {
    renderGame(); await screen.findByRole("region", { name: "Midword board" });
    vi.useFakeTimers();
    try {
      for (const key of ["Q", "W", "E", "R", "Enter"]) fireEvent.keyDown(window, { key });
      const input = screen.getByLabelText("Middle word, 4 of 4 letters entered");
      const label = screen.getByRole("alert");
      expect(input).toHaveClass("is-shaking");
      expect(label).toHaveTextContent("Not a valid word");
      expect(screen.getByLabelText("5 attempts remaining")).toBeInTheDocument();
      expect(createMidwordStorage().loadProgress(localDateString()).guesses).toEqual([]);
      expect(screen.queryByRole("region", { name: "Previous guesses" })).not.toBeInTheDocument();

      act(() => vi.advanceTimersByTime(500));
      expect(input).not.toHaveClass("is-shaking");
      expect(screen.getByRole("alert")).toBe(label);
      act(() => vi.advanceTimersByTime(1499));
      expect(screen.getByRole("alert")).toBe(label);
      act(() => vi.advanceTimersByTime(1));
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
      expect(label.closest(".game-input-message")).not.toHaveClass("game-input-message--visible");
      expect(input).toHaveTextContent("QWER");
      expect(screen.getByRole("button", { name: "Submit" })).toBeEnabled();

      const styles = readFileSync("src/styles.css", "utf8");
      expect(styles).toMatch(/\.bw-letter-row\.is-shaking,\s*\.midword-letter-row\.is-shaking\s*\{\s*animation: bw-shake 420ms ease-in-out;/);
      const midwordStyles = readFileSync("src/features/midword/midword.css", "utf8");
      expect(midwordStyles).toMatch(/\.midword-message\s*\{[^}]*color: var\(--bw-error, #ff6b6b\);[^}]*font-weight: 700;/);
      expect(midwordStyles).toMatch(/@media \(prefers-reduced-motion: reduce\)\s*\{\s*\.midword-page \*, \.midword-dialog \*\s*\{[^}]*animation: none !important;/);
    } finally {
      vi.useRealTimers();
    }
  });
  it("restarts invalid-word feedback timers on repeated submission", async () => {
    renderGame(); await screen.findByRole("region", { name: "Midword board" });
    vi.useFakeTimers();
    try {
      for (const key of ["Z", "Z", "Z", "Z", "Enter"]) fireEvent.keyDown(window, { key });
      act(() => vi.advanceTimersByTime(1000));
      const input = screen.getByLabelText("Middle word, 4 of 4 letters entered");
      expect(input).not.toHaveClass("is-shaking");
      fireEvent.keyDown(window, { key: "Enter" });
      expect(input).toHaveClass("is-shaking");
      act(() => vi.advanceTimersByTime(1000));
      expect(screen.getByRole("alert")).toHaveTextContent("Not a valid word");
      expect(input).not.toHaveClass("is-shaking");
      act(() => vi.advanceTimersByTime(999));
      expect(screen.getByRole("alert")).toBeInTheDocument();
      act(() => vi.advanceTimersByTime(1));
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
      expect(screen.getByLabelText("5 attempts remaining")).toBeInTheDocument();
    } finally {
      vi.useRealTimers();
    }
  });
  it("cancels feedback timers when input is edited or the game is unmounted", async () => {
    const view = renderGame(); await screen.findByRole("region", { name: "Midword board" });
    vi.useFakeTimers();
    try {
      for (const key of ["Z", "Z", "Z", "Z", "Enter"]) fireEvent.keyDown(window, { key });
      expect(vi.getTimerCount()).toBe(2);
      fireEvent.keyDown(window, { key: "Backspace" });
      expect(vi.getTimerCount()).toBe(0);
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
      expect(screen.getByLabelText("Middle word, 3 of 4 letters entered")).not.toHaveClass("is-shaking");
      for (const key of ["Z", "Enter"]) fireEvent.keyDown(window, { key });
      expect(vi.getTimerCount()).toBe(2);
      view.unmount();
      expect(vi.getTimerCount()).toBe(0);
    } finally {
      vi.useRealTimers();
    }
  });
  it("fails on the fifth wrong word and restores that terminal result on reload", async () => {
    const user = userEvent.setup(); const view = renderGame(); await screen.findByRole("region", { name: "Midword board" });
    for (const word of ["PAGE", "WORD", "READ", "LINE", "BOOK"]) await typeGuess(user, word);
    expect(await screen.findByRole("dialog", { name: "Finished" })).toHaveTextContent("The answer was…");
    const progress = createMidwordStorage().loadProgress(localDateString());
    expect(progress.outcome).toBe("failed"); expect(progress.releaseDateScore).toBe(0);
    view.unmount(); renderGame();
    expect(await screen.findByRole("dialog", { name: "Finished" })).toBeInTheDocument();
  });
  it("blocks physical game input while instructions or navigation are open", async () => {
    const user = userEvent.setup(); renderGame(); await screen.findByRole("region", { name: "Midword board" });
    await user.click(screen.getByRole("button", { name: "How to play Midword" }));
    expect(screen.getByRole("dialog", { name: "How to Play" })).toHaveTextContent("five attempts");
    await user.keyboard("NOTE");
    expect(screen.getByLabelText("Middle word, 0 of 4 letters entered")).toBeInTheDocument();
    await user.keyboard("{Escape}");
    await user.click(screen.getByRole("button", { name: "Open game menu" }));
    await user.keyboard("NOTE");
    expect(screen.getByLabelText("Middle word, 0 of 4 letters entered")).toBeInTheDocument();
    expect(within(screen.getByRole("dialog", { name: "Game navigation" })).getByRole("link", { name: "Midword" })).toHaveAttribute("href", "/midword");
  });
  it("uses cached content offline and supports retry when no cache exists", async () => {
    createMidwordStorage().cachePuzzle(puzzle()); mocks.fetch.mockRejectedValue(new Error("offline"));
    const view = renderGame();
    expect(await screen.findByText("Playing saved game offline")).toBeInTheDocument();
    view.unmount(); localStorage.clear(); renderGame();
    expect(await screen.findByRole("alert")).toHaveTextContent("could not be loaded");
    mocks.fetch.mockImplementation(async (date: string) => puzzle(date));
    await userEvent.setup().click(screen.getByRole("button", { name: "Try again" }));
    expect(await screen.findByRole("region", { name: "Midword board" })).toBeInTheDocument();
  });
  it("redirects archive visitors before fetching and rejects invalid and future routes", async () => {
    const yesterday = localDateOffset(localDateString(), -1);
    const view = renderGame(`/midword/${yesterday}`);
    expect(screen.getByText("Pro destination")).toBeInTheDocument();
    expect(mocks.fetch).not.toHaveBeenCalled(); view.unmount();
    const invalid = renderGame("/midword/2026-02-30");
    expect(screen.getByText("Invalid Midword date.")).toBeInTheDocument(); invalid.unmount();
    renderGame(`/midword/${localDateOffset(localDateString(), 1)}`);
    expect(screen.getByText("This Midword has not been released yet.")).toBeInTheDocument();
    expect(mocks.fetch).not.toHaveBeenCalled();
  });
  it("allows Pro archive completion without adding rating points", async () => {
    mocks.auth.user = { id: "alice" }; mocks.auth.entitlement = { isPro: true };
    const user = userEvent.setup(); const yesterday = localDateOffset(localDateString(), -1);
    renderGame(`/midword/${yesterday}`); await screen.findByRole("region", { name: "Midword board" });
    await typeGuess(user, "NOTE");
    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(createMidwordStorage(localStorage, { userId: "alice" }).loadProgress(yesterday).releaseDateScore).toBe(0);
    expect(mocks.queue).toHaveBeenCalledWith("alice", expect.objectContaining({ game_type: "midword", release_score: 0 }));
  });
  it("refreshes native account progress on focus and presents a remote win", async () => {
    mocks.auth.user = { id: "alice" };
    const native = submitGuess(emptyProgress(localDateString()), puzzle(), "NOTE", () => false).progress;
    mocks.refresh.mockImplementationOnce(async (_id, _game, _records, apply) => apply({ payload: native }));
    renderGame(); await screen.findByRole("region", { name: "Midword board" });
    fireEvent(window, new Event("focus"));
    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    await waitFor(() => expect(mocks.refresh).toHaveBeenCalledWith("alice", "midword", expect.any(Array), expect.any(Function)));
  });
  it("resets displayed progress and typed input when the account changes", async () => {
    mocks.auth.user = { id: "alice" };
    createMidwordStorage(localStorage, { userId: "alice" }).saveProgress({ ...emptyProgress(localDateString()), guesses: ["PAGE"] });
    const view = render(<MemoryRouter><MidwordPage /></MemoryRouter>);
    await screen.findByRole("region", { name: "Midword board" });
    await userEvent.setup().keyboard("NO");
    expect(screen.getByLabelText("Middle word, 2 of 4 letters entered")).toBeInTheDocument();
    mocks.auth.user = { id: "bob" };
    view.rerender(<MemoryRouter><MidwordPage /></MemoryRouter>);
    await screen.findByRole("region", { name: "Midword board" });
    expect(screen.getByLabelText("5 attempts remaining")).toBeInTheDocument();
    expect(screen.getByLabelText("Middle word, 0 of 4 letters entered")).toBeInTheDocument();
    expect(createMidwordStorage(localStorage, { userId: "alice" }).loadProgress(localDateString()).guesses).toEqual(["PAGE"]);
  });
  it("refreshes an undated game at local midnight without carrying typed letters over", async () => {
    vi.useFakeTimers(); vi.setSystemTime(new Date(2026, 9, 11, 23, 59, 59));
    try {
      await act(async () => { renderGame(); });
      fireEvent.keyDown(window, { key: "N" });
      expect(screen.getByLabelText("Middle word, 1 of 4 letters entered")).toBeInTheDocument();
      await act(async () => { vi.advanceTimersByTime(1000); });
      expect(mocks.fetch).toHaveBeenLastCalledWith("2026-10-12");
      expect(screen.getByLabelText("Middle word, 0 of 4 letters entered")).toBeInTheDocument();
      expect(screen.getByLabelText("5 attempts remaining")).toBeInTheDocument();
    } finally { vi.useRealTimers(); }
  });
});
