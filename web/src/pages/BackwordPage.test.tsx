import { act, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parse } from "postcss";
import { localDateString } from "../features/backword/date";
import { BackwordPage } from "./BackwordPage";

const repositoryDates = vi.hoisted(() => ({ values: [] as string[] }));
const wordValidator = vi.hoisted(() => vi.fn());

vi.mock("../features/backword/repository", async () => {
  const actual = await vi.importActual<typeof import("../features/backword/repository")>(
    "../features/backword/repository"
  );
  return {
    ...actual,
    createBackwordRepository: () => ({
      getByDate: async (date: string) => {
        repositoryDates.values.push(date);
        return { id: "today", puzzleNumber: 7, date, word: "CASTLE", clue: "Fortress" };
      }
    })
  };
});

vi.mock("../features/backword/wordValidator", () => ({
  isValidEnglishWord: wordValidator
}));

function renderGame() {
  return render(
    <MemoryRouter initialEntries={["/backword"]}>
      <BackwordPage />
    </MemoryRouter>
  );
}

async function dismissOnboarding(user: ReturnType<typeof userEvent.setup>, remainingSteps = 5) {
  for (let index = 0; index < remainingSteps; index += 1) {
    const button = await screen.findByRole("button", { name: /^OK:/ });
    await user.click(button);
    await waitFor(() => expect(screen.queryByRole("button", { name: button.getAttribute("aria-label") ?? "" })).not.toBeInTheDocument());
  }
}

describe("Backword browser game", () => {
  beforeEach(() => {
    localStorage.clear();
    repositoryDates.values = [];
    wordValidator.mockReturnValue(true);
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
    Object.defineProperty(navigator, "vibrate", { configurable: true, value: vi.fn() });
  });

  it("uses the iOS logo asset and provides the game navigation menu", async () => {
    renderGame();

    const logo = await screen.findByRole("img", { name: "Backword" });
    expect(logo).toHaveAttribute("src", "/brand/backword-logo.png");
    expect(logo).toHaveClass("bw-logo--large");
    expect(logo.closest("header")).toHaveClass("bw-game-header--offset");
    expect(screen.getByRole("navigation", { name: "Backword actions" })).toHaveClass(
      "bw-game-actions--top",
      "bw-game-actions--logo-header"
    );
    expect(screen.queryByRole("link", { name: "Back to home" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
  });

  it("explains the game below the logo and above the clue", async () => {
    renderGame();

    const clue = await screen.findByText("FORTRESS");
    const explainer = screen.getByText("Spell it forwards - letters reveal backwards.");
    const logo = screen.getByRole("img", { name: "Backword" });
    const prompt = screen.getByText("Guess the six letter word.");

    expect(prompt.parentElement).toBe(explainer);
    expect(prompt.nextElementSibling?.tagName).toBe("BR");
    expect(explainer.closest("main")).toHaveClass("bw-game-main");
    expect(logo.compareDocumentPosition(explainer) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(explainer.compareDocumentPosition(clue) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it("centres the clue above the answer tiles with extra space before the guess counter", async () => {
    renderGame();

    const clue = await screen.findByText("FORTRESS");
    expect(clue).toHaveTextContent("Clue: FORTRESS");
    expect(clue.nextElementSibling).toHaveClass("bw-guess-counter");
    const answer = clue.closest("main")!.querySelector(".bw-answer-input");
    expect(answer).toBeInTheDocument();
    expect(clue.compareDocumentPosition(answer!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();

    // JSDOM has no layout engine; verify the rendered clue's alignment and spacing.
    const styles = parse(readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8"));
    const style = document.createElement("style");
    styles.walkRules((rule) => {
      if (rule.parent?.type === "root" && rule.selector === ".bw-clue") {
        style.textContent += rule.toString();
      }
    });
    document.head.append(style);
    try {
      expect(getComputedStyle(clue).textAlign).toBe("center");
      expect(getComputedStyle(clue).marginBottom).toBe("24px");
    } finally {
      style.remove();
    }
  });

  it("loads a dated archive route without replacing it with today", async () => {
    render(
      <MemoryRouter initialEntries={["/backword/2026-08-03"]}>
        <Routes><Route element={<BackwordPage />} path="/backword/:date" /></Routes>
      </MemoryRouter>
    );

    await screen.findByText("FORTRESS");
    expect(repositoryDates.values).toContain("2026-08-03");
    expect(repositoryDates.values).not.toContain(localDateString());
  });

  it("reopens a completed game with results and sharing available", async () => {
    const date = localDateString();
    localStorage.setItem("backword:web:progress:v1", JSON.stringify({
      [date]: {
        schemaVersion: 1,
        date,
        guesses: ["CASTLE"],
        completedAt: new Date().toISOString(),
        outcome: "won"
      }
    }));

    renderGame();

    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Share result" })).toBeInTheDocument();
  });

  it("opens and closes a menu with game and legal routes", async () => {
    const user = userEvent.setup();
    renderGame();

    await user.click(screen.getByRole("button", { name: "Open game menu" }));

    const menu = screen.getByRole("dialog", { name: "Game navigation" });
    expect(menu).toBeInTheDocument();
    expect(within(menu).queryByText("MENU")).not.toBeInTheDocument();
    expect(within(menu).getByRole("link", { name: "Home" })).toHaveAttribute("href", "/");
    expect(within(menu).getByRole("link", { name: "Backword" })).toHaveAttribute("href", "/backword");
    expect(within(menu).getByRole("link", { name: "Quick Crossword" })).toHaveAttribute("href", "/crossword");
    expect(within(menu).getByRole("link", { name: "Pro Crossword" })).toHaveAttribute("href", "/pro?return_to=%2Fweekly-crossword");
    expect(within(menu).getByRole("link", { name: "Archive" })).toHaveAttribute("href", "/pro?return_to=%2Farchive");
    expect(within(menu).getByRole("link", { name: "Info" })).toHaveAttribute("href", "/info");
    expect(within(menu).getByRole("link", { name: "Contact" })).toHaveAttribute("href", "/contact");
    expect(within(menu).getByLabelText("Download intervls on the App Store").parentElement).toHaveClass(
      "bw-menu-store-badge"
    );
    expect(within(menu).getByRole("link", { name: "Privacy" })).toHaveAttribute("href", "/privacy");
    expect(within(menu).getByRole("link", { name: "Terms" })).toHaveAttribute("href", "/terms");

    await user.click(screen.getByRole("button", { name: "Close game menu" }));
    expect(screen.queryByRole("dialog", { name: "Game navigation" })).not.toBeInTheDocument();
  });

  it("renders the score progress and keyboard within the game controls", async () => {
    const { container } = renderGame();

    expect(await screen.findByText("FORTRESS")).toHaveClass("bw-clue");
    expect(container.querySelector(".bw-onboarding-deck")).toBeInTheDocument();
    expect(container.querySelector(".bw-explainer-card")).not.toBeInTheDocument();
    await screen.findByRole("group", { name: "Backword keyboard" });
    const controls = container.querySelector(".bw-game-controls");
    expect(controls?.querySelector(".bw-game-score")).toHaveClass("bw-game-score--keyboard-width");
    expect(controls?.querySelector(".bw-keyboard")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Share result" })).not.toBeInTheDocument();
  });

  it.each([
    ["two guesses", ["STACKS", "STANCE"]],
    ["four guesses", ["STACKS", "STANCE", "PLANET", "MASTER"]]
  ])("keeps the game at least a full viewport above the site footer with %s", async (_label, guesses) => {
    const date = localDateString();
    localStorage.setItem("backword:web:progress:v1", JSON.stringify({
      [date]: {
        schemaVersion: 1,
        date,
        guesses,
        completedAt: null,
        outcome: "inProgress"
      }
    }));
    renderGame();

    const history = await screen.findByRole("heading", { name: "Previous Guesses" });
    const main = history.closest("main");
    const shell = main!.parentElement!;
    expect(shell).toHaveClass("bw-shell--backword");
    expect(main?.nextElementSibling).toContainElement(screen.getByLabelText("0 of 70 Backword points"));
    expect(shell.nextElementSibling).toBe(screen.getByRole("navigation", { name: "Footer" }).closest("footer"));

    // JSDOM has no layout engine; check the effective flex sizing rules instead.
    const styles = parse(readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8"));
    const style = document.createElement("style");
    styles.walkRules((rule) => {
      if (rule.parent?.type === "root" && [".bw-shell", ".bw-shell--backword", ".bw-game-main"].includes(rule.selector)) {
        style.textContent += rule.toString();
      }
    });
    document.head.append(style);
    try {
      expect(getComputedStyle(shell).minHeight).toBe("100svh");
      expect(getComputedStyle(shell).flexShrink).toBe("0");
      expect(getComputedStyle(shell).height).toBe("");
      expect(getComputedStyle(main!).flexGrow).toBe("1");
    } finally {
      style.remove();
    }
  });

  it("expands and collapses the shared Submit control above the keyboard as input changes", async () => {
    const user = userEvent.setup();
    renderGame();
    const bar = await screen.findByLabelText("0 of 70 Backword points");
    const transition = bar.nextElementSibling;
    const keyboard = screen.getByRole("group", { name: "Backword keyboard" });
    expect(transition).toHaveClass("game-submit");
    expect(transition?.nextElementSibling).toBe(keyboard);
    expect(screen.queryByRole("button", { name: "Submit" })).not.toBeInTheDocument();

    await user.keyboard("CASTLE");
    const submit = screen.getByRole("button", { name: "Submit" });
    expect(transition).toHaveClass("game-submit--visible");
    expect(transition).toContainElement(submit);
    await user.keyboard("{Backspace}");
    expect(transition).not.toHaveClass("game-submit--visible");
    expect(submit).toBeDisabled();
    expect(screen.queryByRole("button", { name: "Submit" })).not.toBeInTheDocument();

    await user.keyboard("E");
    expect(screen.getByRole("button", { name: "Submit" })).toBe(submit);
    await user.click(submit);
    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
  });

  it("uses the iOS semantic treatment for Backword letter cells", async () => {
    const { container } = renderGame();

    await screen.findByText("FORTRESS");
    const cells = container.querySelectorAll(".bw-letter-row > span");
    expect(cells).toHaveLength(6);
    expect(cells[0]).toHaveClass("is-empty", "is-cursor");

    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    expect(styles).toContain("--bw-cell-accent: #2979ff;");
    expect(styles).toContain("background: rgb(var(--app-surface-rgb) / 50%);");
    expect(styles).toContain("color: rgb(var(--app-text-secondary-rgb) / 40%);");
    expect(styles).toContain(".bw-letter-row > .is-revealed { border-color: rgb(var(--bw-cell-accent-rgb) / 50%); }");
    expect(styles).toMatch(/\.puzzle-result-share__button--compact\s*\{[^}]*min-height:\s*44px;[^}]*border-radius:\s*6px;/);
    expect(styles).toMatch(/\.puzzle-result-share--compact\s*\{[^}]*z-index:\s*4;[^}]*pointer-events:\s*auto;/);
    expect(styles).toMatch(/@media \(min-width: 700px\)\s*\{[\s\S]*?\.puzzle-result-share--compact\s*\{[^}]*position:\s*fixed;[^}]*top:\s*calc\(max\(8px, env\(safe-area-inset-top\)\) \+ 54px\);[^}]*bottom:\s*auto;/);
  });

  it("shows a persisted staggered onboarding deck without an immediate explainer after dismissal", async () => {
    const user = userEvent.setup();
    const first = renderGame();

    expect(await screen.findByRole("region", { name: "How to play Backword" })).toBeInTheDocument();
    expect(screen.queryByText("Guess the 6 letter word...")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: /^OK: The clue is a word/ })).toBeInTheDocument();
    const clueExplanation = screen.getByText("The clue is a word associated with the answer, or something connected to it");
    expect(clueExplanation.closest(".bw-onboarding-card")).toHaveClass("is-top");
    expect(document.querySelector(".bw-game-controls")).not.toHaveTextContent("The clue is a word");
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    expect(document.querySelectorAll(".bw-onboarding-card")).toHaveLength(5);
    expect(document.querySelectorAll(".bw-onboarding-card[aria-hidden='true']")).toHaveLength(4);

    const firstButton = screen.getByRole("button", { name: /^OK: The clue is a word/ });
    await user.click(firstButton);
    await waitFor(() => expect(firstButton).not.toBeInTheDocument());
    expect(screen.getByRole("button", { name: /^OK: Correctly placed letters/ })).toBeInTheDocument();
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    expect(JSON.parse(localStorage.getItem("backword:web:settings:v1") ?? "{}").hasSeenInstructionsTip).toBe(false);
    first.unmount();

    renderGame();
    expect(await screen.findByRole("button", { name: /^OK: Correctly placed letters/ })).toBeInTheDocument();
    expect(screen.queryByText("The clue is a word associated with the answer, or something connected to it")).not.toBeInTheDocument();
    await dismissOnboarding(user, 4);
    expect(screen.queryByText("Guess the 6 letter word...")).not.toBeInTheDocument();
    expect(document.querySelector(".bw-explainer-card")).not.toBeInTheDocument();
    expect(screen.queryByRole("region", { name: "How to play Backword" })).not.toBeInTheDocument();
    expect(await screen.findByRole("tooltip")).toHaveTextContent("Tap the info icon at any time to view game information and toggle difficulty");
  });

  it("shows the info tooltip after the final card and does not replay it after dismissal", async () => {
    const user = userEvent.setup();
    const first = renderGame();

    expect(await screen.findByRole("region", { name: "How to play Backword" })).toBeInTheDocument();
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    await dismissOnboarding(user);

    expect(screen.queryByText("Guess the 6 letter word...")).not.toBeInTheDocument();
    expect(document.querySelector(".bw-explainer-card")).not.toBeInTheDocument();
    expect(await screen.findByRole("tooltip")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close tooltip" }));
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    first.unmount();

    renderGame();
    await screen.findByText("FORTRESS");
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it.each([false, true])("shows the stuck hint only after 30 seconds when onboarding is complete: %s", async (hasSeenOnboarding) => {
    localStorage.setItem("backword:web:settings:v1", JSON.stringify({
      schemaVersion: 1,
      mode: "easy",
      hasSeenOnboarding,
      lastSeenRulesVersion: 4,
      hasSeenInstructionsTip: true
    }));
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    let game: ReturnType<typeof renderGame> | undefined;
    try {
      await act(async () => { game = renderGame(); });
      expect(screen.getByText("FORTRESS")).toBeInTheDocument();
      expect(document.querySelector(".bw-explainer-card")).not.toBeInTheDocument();
      expect(screen.queryByText("Guess the 6 letter word...")).not.toBeInTheDocument();

      await act(async () => { vi.advanceTimersByTime(29_999); });
      expect(document.querySelector(".bw-explainer-card")).not.toBeInTheDocument();
      await act(async () => { vi.advanceTimersByTime(1); });

      const hint = screen.queryByText("If you’re stuck, guess any word to reveal letters");
      if (hasSeenOnboarding) {
        expect(hint).toBeInTheDocument();
        expect(hint?.previousElementSibling).toHaveTextContent("💡");
        for (const key of "XXXXXX") fireEvent.keyDown(window, { key });
        fireEvent.keyDown(window, { key: "Enter" });
        expect(document.querySelector(".bw-explainer-card")).not.toBeInTheDocument();
        await act(async () => { vi.advanceTimersByTime(30_000); });
        expect(document.querySelector(".bw-explainer-card")).not.toBeInTheDocument();
      } else {
        expect(hint).not.toBeInTheDocument();
        expect(screen.getByRole("region", { name: "How to play Backword" })).toBeInTheDocument();
      }
    } finally {
      game?.unmount();
      vi.useRealTimers();
    }
  });

  it("keeps the full instructions sheet manual during inline onboarding and persists mode changes", async () => {
    const user = userEvent.setup();
    const { container } = renderGame();

    expect(await screen.findByRole("region", { name: "How to play Backword" })).toBeInTheDocument();
    expect(screen.queryByRole("dialog", { name: "How to Play" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "How to Play" }));
    expect(await screen.findByRole("dialog", { name: "How to Play" })).toBeInTheDocument();
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    expect(screen.getByRole("switch", { name: "Hard Mode" })).not.toBeChecked();
    await user.click(screen.getByRole("button", { name: "Close How to Play" }));
    expect(await screen.findByText("FORTRESS")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "C" }));
    expect(container.querySelector(".bw-letter-row")?.textContent).toContain("C");

    await user.click(screen.getByRole("button", { name: "How to Play" }));
    await user.click(screen.getByRole("switch", { name: "Hard Mode" }));
    expect(screen.getByRole("switch", { name: "Hard Mode" })).toBeChecked();
    await user.click(screen.getByRole("button", { name: "Close How to Play" }));

    expect(container.querySelector(".bw-letter-row")?.textContent).not.toContain("C");
    expect(JSON.parse(localStorage.getItem("backword:web:settings:v1") ?? "{}").mode).toBe("normal");
  });

  it("supports keyboard play, saves a win, and opens the completion stats", async () => {
    const user = userEvent.setup();
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: { writeText }
    });
    renderGame();

    wordValidator.mockReturnValue(false);
    await user.keyboard("CASTLE{Enter}");

    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByText("... in 1 guess")).toBeInTheDocument();
    expect(screen.getByText("5/70")).toBeInTheDocument();
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    const shareButton = within(screen.getByRole("dialog", { name: "Solved!" })).getByRole("button", { name: "Share result" });
    expect(shareButton).toBeInTheDocument();
    expect(document.querySelector(".puzzle-result-share__preview")).not.toBeInTheDocument();
    expect(shareButton.compareDocumentPosition(document.querySelector(".bw-distribution") as Node) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    await user.click(shareButton);
    expect(writeText).toHaveBeenCalledWith(expect.stringContaining("I solved Backword #7"));
    expect(writeText).toHaveBeenCalledWith(expect.not.stringContaining("CASTLE"));
    expect(screen.getByText("Result copied to clipboard")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "BACK TO GAME" }));
    const gameShareButton = screen.getByRole("button", { name: "Share result" });
    expect(gameShareButton).toHaveClass("puzzle-result-share__button--compact");
    expect(gameShareButton.closest(".puzzle-result-share--compact")?.parentElement).toHaveClass("bw-game-main");

    const stored = JSON.parse(localStorage.getItem("backword:web:progress:v1") ?? "{}");
    expect(stored[localDateString()]).toMatchObject({ outcome: "won", guesses: ["CASTLE"] });
  });

  it("restores an unfinished game after remounting", async () => {
    const user = userEvent.setup();
    const first = renderGame();
    await user.keyboard("XXXXXX{Enter}");
    const previousGuesses = await screen.findByText("Previous Guesses");
    const onboardingDeck = document.querySelector(".bw-onboarding-deck");
    expect(onboardingDeck).toBeInTheDocument();
    expect(previousGuesses.compareDocumentPosition(onboardingDeck as Node) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    first.unmount();

    renderGame();
    await waitFor(() => expect(screen.getByLabelText("XXXXXX")).toBeInTheDocument());
    expect(document.querySelector(".bw-onboarding-deck")).toBeInTheDocument();
    expect(screen.queryByRole("dialog", { name: "How to Play" })).not.toBeInTheDocument();
  });

  it("rejects a non-word without using a guess and gives negative haptic feedback", async () => {
    const user = userEvent.setup();
    wordValidator.mockReturnValue(false);
    renderGame();

    await user.keyboard("XXXXXX{Enter}");

    const label = await screen.findByRole("alert");
    expect(label).toHaveTextContent("Not a valid word");
    const transition = label.closest(".game-input-message");
    expect(transition).toHaveClass("game-input-message--visible");
    expect(transition?.parentElement).toHaveClass("bw-answer-input");
    expect(screen.queryByText("Previous Guesses")).not.toBeInTheDocument();
    expect(screen.getByLabelText("0 of 5 guesses used")).toBeInTheDocument();
    expect(navigator.vibrate).toHaveBeenCalledWith([30, 50, 80]);
    await waitFor(() => expect(screen.queryByRole("alert")).not.toBeInTheDocument(), { timeout: 2500 });
    expect(transition).not.toHaveClass("game-input-message--visible");
    expect(label).toBeInTheDocument();
    expect(label).toHaveTextContent("Not a valid word");
  });

  it("shows returning players the version 4 rules update and records its dismissal", async () => {
    const user = userEvent.setup();
    localStorage.setItem("backword:web:settings:v1", JSON.stringify({
      schemaVersion: 1,
      mode: "easy",
      hasSeenOnboarding: true,
      lastSeenRulesVersion: 3
    }));
    renderGame();

    expect(await screen.findByText("The final letter is no longer shown at the start. Your first wrong guess reveals it.")).toBeInTheDocument();
    expect(screen.getByText("Guesses must be real English words.")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close How to Play" }));

    expect(JSON.parse(localStorage.getItem("backword:web:settings:v1") ?? "{}")).toMatchObject({
      lastSeenRulesVersion: 4
    });
  });
});
