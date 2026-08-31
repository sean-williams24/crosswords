import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { CrosswordPage } from "./CrosswordPage";

vi.mock("../features/crossword/repository", async () => {
  const actual = await vi.importActual<typeof import("../features/crossword/repository")>("../features/crossword/repository");
  const cells: import("../features/crossword/types").CrosswordPuzzle["cells"] = Array.from({ length: 9 }, () => Array.from({ length: 9 }, () => ({ letter: null, clueNumber: null, acrossClueId: null, downClueId: null })));
  cells[0][0] = { letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: null };
  cells[0][1] = { letter: "B", clueNumber: null, acrossClueId: 0, downClueId: null };
  return {
    ...actual,
    createCrosswordRepository: () => ({
      getByDate: async (date: string) => ({
        id: "today-crossword", puzzleNumber: 1, date, size: 9, cells,
        clues: [{ id: 0, direction: "across", number: 1, text: "Test answer", hint: "Test hint", answer: "AB", startRow: 0, startCol: 0, length: 2 }]
      })
    })
  };
});

describe("CrosswordPage", () => {
  beforeEach(() => localStorage.clear());

  it("loads the daily grid, supports keyboard play, and opens completion", async () => {
    const user = userEvent.setup();
    render(<MemoryRouter><CrosswordPage /></MemoryRouter>);

    expect(screen.getByRole("heading", { name: "QUICK CROSSWORD" })).toBeInTheDocument();
    const actions = screen.getByRole("navigation", { name: "Crossword actions" });
    const [cluesAction, statsAction] = Array.from(actions.querySelectorAll("button"));
    expect(cluesAction).toHaveAccessibleName("Show clue list");
    expect(cluesAction).toHaveClass("cw-clues-action");
    expect(cluesAction).toHaveTextContent("Clues");
    expect(statsAction).toHaveAccessibleName("Crossword stats");
    expect(await screen.findByRole("dialog", { name: "How to Play" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close How to Play" }));
    expect(await screen.findByRole("grid", { name: "Crossword grid" })).toBeInTheDocument();
    expect(screen.getByRole("group", { name: "Crossword keyboard" })).toBeInTheDocument();

    await user.keyboard("AB");
    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByText("NEXT DAILY CROSSWORD IN")).toBeInTheDocument();
  });
});
