import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { localWeekStartString } from "../features/backword/date";
import { emptyProgress } from "../features/crossword/engine";
import { createCrosswordStorage } from "../features/crossword/storage";
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

  it("offers a navigation flag, confirms give-up, and restores a revealed Pro game without a solved score", async () => {
    const user = userEvent.setup();
    const page = render(<MemoryRouter><WeeklyCrosswordPage /></MemoryRouter>);
    const button = await screen.findByRole("button", { name: "Give up" });
    expect(screen.getByRole("navigation", { name: "Crossword actions" })).toContainElement(button);
    await user.keyboard("A");
    const storage = createCrosswordStorage(undefined, { kind: "weekly", userId: "pro-player" });
    const before = storage.loadProgressForDate(localWeekStartString());
    await user.click(button);
    await user.keyboard("B{Backspace}");
    expect(storage.loadProgressForDate(localWeekStartString())).toEqual(before);
    await user.click(screen.getByRole("button", { name: "Keep playing" }));
    expect(storage.loadProgressForDate(localWeekStartString())).toEqual(before);
    await user.click(button);
    await user.click(screen.getByRole("button", { name: "Give up and reveal" }));
    expect(await screen.findByRole("dialog", { name: "Gave up" })).toHaveTextContent("0/5");
    expect(screen.getByText("This week: 0/5")).toBeInTheDocument();
    expect(storage.loadProgressForDate(localWeekStartString())).toMatchObject({ releaseDateScore: 0, gaveUpScore: 0 });
    expect(screen.queryByRole("button", { name: "Give up" })).not.toBeInTheDocument();
    expect(within(screen.getByRole("group", { name: "Crossword keyboard" })).getByRole("button", { name: "A" })).toBeDisabled();
    page.unmount();
    render(<MemoryRouter><WeeklyCrosswordPage /></MemoryRouter>);
    expect(await screen.findByRole("dialog", { name: "Gave up" })).toBeInTheDocument();
  });

  it("loads the Pro 13×13 grid, opens the same instructions modal, offers hints, and uses weekly completion copy", async () => {
    const user = userEvent.setup();
    render(<MemoryRouter><WeeklyCrosswordPage /></MemoryRouter>);

    expect(screen.getByRole("heading", { name: "PRO CROSSWORD" })).toBeInTheDocument();
    expect(await screen.findByRole("grid", { name: "Crossword grid" })).toHaveClass("cw-grid--weekly");
    expect(screen.getByText("#7")).toHaveClass("cw-puzzle-issue");
    await user.click(screen.getByRole("button", { name: "How to play" }));
    expect(screen.getByRole("dialog", { name: "How to Play" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close How to Play" }));
    await user.click(screen.getByRole("button", { name: "Show hint" }));
    expect(screen.getByText("Test hint")).toBeInTheDocument();
    await user.keyboard("AB");

    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByText("NEXT WEEKLY CROSSWORD IN")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "BACK TO GAME" }));
    const gameShareButton = screen.getByRole("button", { name: "Share result" });
    expect(gameShareButton).toHaveClass("puzzle-result-share__button--compact");
    expect(gameShareButton.closest(".puzzle-result-share--compact")?.parentElement).toHaveClass("cw-game-main");
  });

  it("reopens a completed game with results and sharing available", async () => {
    const date = localWeekStartString();
    const progress = emptyProgress({ id: "weekly-crossword", date, size: 13 });
    progress.entries[0][0] = "A";
    progress.entries[0][1] = "B";
    progress.completedClueIds = [0];
    progress.completedAt = new Date().toISOString();
    progress.releaseDateScore = 5;
    createCrosswordStorage(undefined, { kind: "weekly", userId: "pro-player" }).saveProgress(progress);

    render(<MemoryRouter><WeeklyCrosswordPage /></MemoryRouter>);

    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Share result" })).toBeInTheDocument();
  });
});
