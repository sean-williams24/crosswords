import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { localDateString } from "../features/backword/date";
import { giveUp, placeTile, reviewAnagramPuzzle, startProgress } from "../features/anagram/engine";
import { createAnagramStorage } from "../features/anagram/storage";
import { AnagramBoard } from "../features/anagram/components";
import { AnagramPage } from "./AnagramPage";

const repositoryState = vi.hoisted(() => ({ offline: false }));

vi.mock("../features/anagram/repository", () => ({
  createAnagramRepository: () => ({
    getFirstReleaseDate: async () => localDateString(),
    getByDate: async (date: string) => {
      if (repositoryState.offline) throw new Error("Offline");
      return { ...reviewAnagramPuzzle(date), id: "today-anagram", puzzleNumber: 7 };
    }
  })
}));

describe("Anagram browser game", () => {
  it.each([
    { answer: "BUBBLES", initialScramble: "BBBLUES" },
    { answer: "TRIANGLE", initialScramble: "RAGTLINE" },
    { answer: "BLUEBERRY", initialScramble: "RYBBERUEL" }
  ])("keeps every $answer tile in one row", ({ answer, initialScramble }) => {
    const puzzle = { ...reviewAnagramPuzzle(localDateString()), answer, initialScramble, acceptedAnswers: [] };
    const progress = startProgress(puzzle);
    const onPlace = vi.fn();
    render(<AnagramBoard puzzle={puzzle} progress={progress} now={new Date()}
      onPlace={onPlace} onUndo={vi.fn()} onRestart={vi.fn()} onShuffle={vi.fn()} onHint={vi.fn()} onGiveUp={vi.fn()} />);
    const tray = screen.getByLabelText("Scrambled letter tray");
    expect(tray.querySelectorAll(".anagram-letter-row")).toHaveLength(1);
    expect(within(tray).getAllByRole("button")).toHaveLength(answer.length);
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    expect(styles).not.toMatch(/\.anagram-tray\s*\{[^}]*flex-direction:\s*column/);
    expect(styles).toMatch(/\.anagram-tile\s*\{[^}]*min-width:\s*0;[^}]*flex:\s*0 1 var\(--anagram-tray-letter-size\)/);
  });

  beforeEach(() => {
    localStorage.clear();
    repositoryState.offline = false;
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
  });

  it.each([
    { outcome: "solved", offline: false },
    { outcome: "gave_up", offline: false },
    { outcome: "solved", offline: true },
    { outcome: "gave_up", offline: true }
  ] as const)("reopens a saved $outcome result once per visit with offline=$offline", async ({ outcome, offline }) => {
    const user = userEvent.setup();
    const date = localDateString();
    const puzzle = { ...reviewAnagramPuzzle(date), id: "today-anagram", puzzleNumber: 7 };
    const finishedAt = new Date(`${date}T12:00:00`);
    let progress = startProgress(puzzle, new Date(finishedAt.getTime() - 20_000));
    if (outcome === "gave_up") {
      progress = giveUp(progress, finishedAt);
    } else {
      for (const letter of puzzle.answer) {
        const tile = Array.from(puzzle.initialScramble).findIndex((value, index) =>
          value === letter && !progress.placedTileIDs.includes(index));
        progress = placeTile(progress, puzzle, tile, finishedAt);
      }
    }
    const storage = createAnagramStorage();
    storage.cachePuzzle(puzzle);
    storage.saveProgress(progress);
    const saved = storage.loadProgress(puzzle);
    repositoryState.offline = offline;
    const game = <MemoryRouter><AnagramPage /></MemoryRouter>;
    const page = render(game);
    const title = outcome === "solved" ? "Solved!" : "Finished";

    const completion = await screen.findByRole("dialog", { name: title });
    expect(within(completion).getByRole("button", { name: "Share result" })).toBeInTheDocument();
    expect(within(completion).queryByRole("button", { name: /^Close/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    if (offline) expect(screen.getByText("Playing saved game offline")).toBeInTheDocument();

    await user.click(within(completion).getByRole("button", { name: "BACK TO GAME" }));
    page.rerender(game);
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(storage.loadProgress(puzzle)).toEqual(saved);

    page.unmount();
    render(<MemoryRouter><AnagramPage /></MemoryRouter>);
    expect(await screen.findByRole("dialog", { name: title })).toBeInTheDocument();
    expect(storage.loadProgress(puzzle)).toEqual(saved);
  });

  it("hides the footer in the mobile layout while retaining it on the page", async () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    expect(styles).toMatch(/@media \(max-width: 700px\) \{\s*\.anagram-page > \.site-footer \{ display: none; \}/);

    render(<MemoryRouter><AnagramPage /></MemoryRouter>);
    expect(document.querySelector(".anagram-page > .site-footer")).toBeInTheDocument();
    await screen.findByRole("button", { name: "Start" });
  });

  it("aligns the loading message with the stable title column", async () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const main = styles.match(/\.anagram-main\s*\{([^}]*)\}/)?.[1];
    const titleAndLoading = styles.match(/\.anagram-title-block,\s*\.anagram-loading\s*\{([^}]*)\}/)?.[1];

    expect(main).toMatch(/--anagram-max-content-width:\s*calc\(/);
    expect(titleAndLoading).toMatch(/width:\s*min\(100%,\s*var\(--anagram-max-content-width\)\)/);
    expect(titleAndLoading).toMatch(/margin-inline:\s*auto/);
    expect(titleAndLoading).not.toContain("--anagram-content-width");
    expect(styles).toMatch(/\.anagram-loading\s*\{\s*margin-top:\s*24px;/);

    render(<MemoryRouter><AnagramPage /></MemoryRouter>);
    expect(screen.getByRole("status")).toHaveTextContent("Loading Anagram…");
    expect(screen.getByRole("status")).toHaveClass("anagram-loading");
    await screen.findByRole("button", { name: "Start" });
  });

  it("centres the game title and issue number in the same header", async () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const titleBlock = styles.match(/\.anagram-title-block\s*\{([^}]*)\}/)?.[1];
    expect(titleBlock).toMatch(/text-align:\s*center/);

    render(<MemoryRouter><AnagramPage /></MemoryRouter>);
    const title = screen.getByRole("heading", { name: "ANAGRAM", level: 1 });
    const header = title.closest(".anagram-title-block");
    expect(header).toContainElement(screen.getByText("Daily puzzle"));
    await screen.findByRole("button", { name: "Start" });
    expect(header).toContainElement(screen.getByText("Puzzle #7"));
  });

  it("keeps the letter tray and controls at the bottom of the game board", async () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const board = styles.match(/\.anagram-board\s*\{([^}]*)\}/)?.[1];
    const dock = styles.match(/\.anagram-gameplay-dock\s*\{([^}]*)\}/)?.[1];

    expect(board).toMatch(/display:\s*flex/);
    expect(board).toMatch(/flex-direction:\s*column/);
    expect(board).toMatch(/padding:\s*clamp\(24px, 3\.5vh, 40px\) 0 48px/);
    expect(styles).toMatch(/\.anagram-board\s*\{\s*padding-bottom:\s*80px;/);
    expect(dock).toMatch(/margin:\s*auto auto 0/);

    const user = userEvent.setup();
    render(<MemoryRouter><AnagramPage /></MemoryRouter>);
    await user.click(await screen.findByRole("button", { name: "Start" }));
    const boardElement = screen.getByRole("region", { name: "Anagram board" });
    expect(boardElement.querySelector(".anagram-gameplay-dock")).toContainElement(screen.getByLabelText("Scrambled letter tray"));
    expect(boardElement.querySelector(".anagram-gameplay-dock")).toContainElement(screen.getByRole("button", { name: "Give up" }));
  });

  it.each(["solved", "gave_up"])("places the compact share action above the tray after a %s completion closes", async (outcome) => {
    const user = userEvent.setup();
    render(<MemoryRouter><AnagramPage /></MemoryRouter>);

    await user.click(await screen.findByRole("button", { name: "Start" }));
    expect(screen.queryByRole("button", { name: "Share result" })).not.toBeInTheDocument();

    if (outcome === "solved") {
      for (const letter of "TRIANGLE") {
        await user.click(screen.getByRole("button", { name: new RegExp(`^Letter ${letter}, tray position`) }));
      }
    } else {
      await user.click(screen.getByRole("button", { name: "Give up" }));
      await user.click(screen.getByRole("button", { name: "Give up and reveal" }));
    }
    const completion = await screen.findByRole("dialog", { name: outcome === "solved" ? "Solved!" : "Finished" });
    expect(within(completion).getByRole("button", { name: "Share result" })).toBeInTheDocument();
    expect(within(screen.getByRole("main")).queryByRole("button", { name: "Share result" })).not.toBeInTheDocument();

    await user.click(within(completion).getByRole("button", { name: "BACK TO GAME" }));
    const gameShareButton = within(screen.getByRole("main")).getByRole("button", { name: "Share result" });
    expect(gameShareButton).toHaveClass("puzzle-result-share__button--compact");
    const share = gameShareButton.closest(".puzzle-result-share--compact")!;
    expect(share.parentElement).toHaveClass("anagram-gameplay-dock");
    const tray = screen.getByLabelText("Scrambled letter tray");
    expect(share.nextElementSibling).toBe(tray);

    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const mobileSharing = styles.match(/@media \(max-width: 699px\) \{\s*\.puzzle-result-share__fallback[^}]*\}\s*\.anagram-gameplay-dock > \.puzzle-result-share--compact\s*\{([^}]*)\}/)?.[1];
    expect(mobileSharing).toMatch(/position:\s*relative/);
    expect(mobileSharing).toMatch(/top:\s*auto/);
    expect(mobileSharing).toMatch(/margin:\s*0 0 16px auto/);
    expect(styles).not.toContain(".anagram-main > .puzzle-result-share--compact");
  });
});
