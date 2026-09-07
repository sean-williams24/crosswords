import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { CrosswordPage } from "./CrosswordPage";

const repositoryDates = vi.hoisted(() => ({ values: [] as string[] }));

vi.mock("../features/crossword/repository", async () => {
  const actual = await vi.importActual<typeof import("../features/crossword/repository")>("../features/crossword/repository");
  const cells: import("../features/crossword/types").CrosswordPuzzle["cells"] = Array.from({ length: 9 }, () => Array.from({ length: 9 }, () => ({ letter: null, clueNumber: null, acrossClueId: null, downClueId: null })));
  cells[0][0] = { letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: null };
  cells[0][1] = { letter: "B", clueNumber: null, acrossClueId: 0, downClueId: null };
  return {
    ...actual,
    createCrosswordRepository: () => ({
      getByDate: async (date: string) => {
        repositoryDates.values.push(date);
        return {
        id: "today-crossword", puzzleNumber: 1, date, size: 9, cells,
        clues: [{ id: 0, direction: "across", number: 1, text: "Test answer", hint: "Test hint", answer: "AB", startRow: 0, startCol: 0, length: 2 }]
        };
      }
    })
  };
});

describe("CrosswordPage", () => {
  beforeEach(() => {
    localStorage.clear();
    repositoryDates.values = [];
  });

  it("loads the daily grid, supports keyboard play, and opens completion", async () => {
    const user = userEvent.setup();
    render(<MemoryRouter><CrosswordPage /></MemoryRouter>);

    expect(screen.getByRole("heading", { name: "QUICK CROSSWORD" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "QUICK CROSSWORD" })).toHaveClass("cw-header-title");
    const actions = screen.getByRole("navigation", { name: "Crossword actions" });
    const hintAction = screen.getByRole("button", { name: "Show hint" });
    const cluesAction = screen.getByRole("button", { name: "Show clue list" });
    const statsAction = screen.getByRole("button", { name: "Crossword stats" });
    expect(actions).toContainElement(hintAction);
    expect(cluesAction).toHaveAccessibleName("Show clue list");
    expect(cluesAction).toHaveClass("cw-clues-action");
    expect(cluesAction).toHaveTextContent("Clues");
    expect(statsAction).toHaveAccessibleName("Crossword stats");
    expect(await screen.findByRole("dialog", { name: "How to Play" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close How to Play" }));
    expect(await screen.findByRole("grid", { name: "Crossword grid" })).toBeInTheDocument();
    expect(screen.getByRole("group", { name: "Crossword keyboard" })).toBeInTheDocument();
    await user.click(hintAction);
    expect(screen.getByText("Test hint")).toBeInTheDocument();

    await user.keyboard("AB");
    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByText("NEXT DAILY CROSSWORD IN")).toBeInTheDocument();
  });

  it("loads a dated archive route without replacing it with today", async () => {
    render(
      <MemoryRouter initialEntries={["/crossword/2026-08-05"]}>
        <Routes><Route element={<CrosswordPage />} path="/crossword/:date" /></Routes>
      </MemoryRouter>
    );

    await screen.findByRole("grid", { name: "Crossword grid" });
    expect(repositoryDates.values).toContain("2026-08-05");
  });

  it("uses iOS-aligned compact spacing for the mobile puzzle", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.cw-clue-bar\s*\{[^}]*grid-template-columns:\s*30px 1fr;[^}]*gap:\s*12px;[^}]*padding:\s*10px 16px;/);
    expect(styles).toMatch(/\.cw-page:not\(\.cw-page--weekly\) \.cw-header-title\s*\{\s*display:\s*none;/);
    expect(styles).toMatch(/\.cw-page:not\(\.cw-page--weekly\) \.cw-game-main\s*\{\s*padding-top:\s*4px;\s*padding-inline:\s*8px;/);
    expect(styles).toMatch(/\.cw-page:not\(\.cw-page--weekly\) \.cw-grid\s*\{\s*width:\s*min\(100%, clamp\(245px, calc\(100svh - 320px\), 430px\)\);/);
  });
});
