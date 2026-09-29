import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { localDateString } from "../features/backword/date";
import { reviewAnagramPuzzle } from "../features/anagram/engine";
import { AnagramPage } from "./AnagramPage";

vi.mock("../features/anagram/repository", () => ({
  createAnagramRepository: () => ({
    getFirstReleaseDate: async () => localDateString(),
    getByDate: async (date: string) => ({ ...reviewAnagramPuzzle(date), id: "today-anagram", puzzleNumber: 7 })
  })
}));

describe("Anagram browser game", () => {
  beforeEach(() => {
    localStorage.clear();
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
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

  it("shows the compact share action on the game after completion closes", async () => {
    const user = userEvent.setup();
    render(<MemoryRouter><AnagramPage /></MemoryRouter>);

    await user.click(await screen.findByRole("button", { name: "Start" }));
    expect(screen.queryByRole("button", { name: "Share result" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Give up" }));
    await user.click(screen.getByRole("button", { name: "Give up and reveal" }));
    const completion = await screen.findByRole("dialog", { name: "Finished" });
    expect(within(completion).getByRole("button", { name: "Share result" })).toBeInTheDocument();
    expect(within(screen.getByRole("main")).queryByRole("button", { name: "Share result" })).not.toBeInTheDocument();

    await user.click(within(completion).getByRole("button", { name: "BACK TO GAME" }));
    const gameShareButton = within(screen.getByRole("main")).getByRole("button", { name: "Share result" });
    expect(gameShareButton).toHaveClass("puzzle-result-share__button--compact");
    expect(gameShareButton.closest(".puzzle-result-share--compact")?.parentElement).toHaveClass("anagram-main");
  });
});
