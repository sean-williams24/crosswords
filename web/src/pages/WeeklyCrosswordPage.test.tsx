import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { WeeklyCrosswordPage } from "./WeeklyCrosswordPage";

vi.mock("../features/auth/AuthProvider", () => ({
  useAuth: () => ({
    ready: true,
    entitlementReady: true,
    entitlement: { isPro: true, expiresAt: null },
    user: { id: "pro-player" }
  })
}));

vi.mock("../features/crossword/repository", async () => {
  const actual = await vi.importActual<typeof import("../features/crossword/repository")>("../features/crossword/repository");
  const cells: import("../features/crossword/types").CrosswordPuzzle["cells"] = Array.from({ length: 13 }, () => Array.from({ length: 13 }, () => ({ letter: null, clueNumber: null, acrossClueId: null, downClueId: null })));
  cells[0][0] = { letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: null };
  cells[0][1] = { letter: "B", clueNumber: null, acrossClueId: 0, downClueId: null };
  return {
    ...actual,
    createCrosswordRepository: () => ({
      getCurrentWeekly: async (date: string) => ({
        id: "weekly-crossword",
        puzzleNumber: 7,
        date,
        size: 13,
        cells,
        clues: [{ id: 0, direction: "across", number: 1, text: "Test clue", hint: "Test hint", answer: "AB", startRow: 0, startCol: 0, length: 2 }]
      })
    })
  };
});

describe("WeeklyCrosswordPage", () => {
  beforeEach(() => localStorage.clear());

  it("loads the Pro 13×13 grid, offers hints, and uses weekly completion copy", async () => {
    const user = userEvent.setup();
    render(<MemoryRouter><WeeklyCrosswordPage /></MemoryRouter>);

    expect(screen.getByRole("heading", { name: "PRO CROSSWORD" })).toBeInTheDocument();
    expect(await screen.findByRole("grid", { name: "Crossword grid" })).toHaveClass("cw-grid--weekly");
    await user.click(screen.getByRole("button", { name: "Show hint" }));
    expect(screen.getByText("Test hint")).toBeInTheDocument();
    await user.keyboard("AB");

    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByText("NEXT WEEKLY CROSSWORD IN")).toBeInTheDocument();
  });
});
