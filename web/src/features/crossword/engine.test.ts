import {
  crosswordScore,
  deleteLetter,
  deriveCrosswordStats,
  emptyProgress,
  enterLetter,
  firstWhiteSelection,
  selectCell
} from "./engine";
import type { CrosswordPuzzle } from "./types";

function puzzle(): CrosswordPuzzle {
  const cells: CrosswordPuzzle["cells"] = Array.from({ length: 9 }, () => Array.from({ length: 9 }, () => ({ letter: null, clueNumber: null, acrossClueId: null, downClueId: null })));
  cells[0][0] = { letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: null };
  cells[0][1] = { letter: "B", clueNumber: null, acrossClueId: 0, downClueId: null };
  return { id: "puzzle", puzzleNumber: 1, date: "2026-08-05", size: 9, cells, clues: [{ id: 0, direction: "across", number: 1, text: "Test", answer: "AB", startRow: 0, startCol: 0, length: 2 }] };
}

describe("crossword engine", () => {
  it("completes a clue, locks it by default, and restores editable mode", () => {
    const currentPuzzle = puzzle();
    let progress = emptyProgress(currentPuzzle, new Date("2026-08-05T09:00:00"));
    let selection = firstWhiteSelection(currentPuzzle);
    ({ progress, selection } = enterLetter(progress, currentPuzzle, selection, "a", true, new Date("2026-08-05T09:00:01")));
    ({ progress, selection } = enterLetter(progress, currentPuzzle, selection, "b", true, new Date("2026-08-05T09:00:02")));
    expect(progress.completedClueIds).toEqual([0]);
    expect(progress.completedAt).not.toBeNull();
    const locked = deleteLetter({ ...progress, completedAt: null }, currentPuzzle, selection, true);
    expect(locked.progress.entries[0][1]).toBe("B");
    const editable = deleteLetter({ ...progress, completedAt: null }, currentPuzzle, selection, false);
    expect(editable.progress.entries[0][1]).toBeNull();
  });

  it("selects cells and computes local release-date statistics", () => {
    const currentPuzzle = puzzle();
    expect(selectCell(currentPuzzle, firstWhiteSelection(currentPuzzle), 0, 0).direction).toBe("across");
    expect(crosswordScore(1, 1)).toBe(5);
    expect(crosswordScore(1, 4)).toBe(2);
    const completed = { ...emptyProgress(currentPuzzle, new Date("2026-08-05T09:00:00")), completedAt: "2026-08-05T09:03:00.000Z", completedClueIds: [0], releaseDateScore: 5 };
    expect(deriveCrosswordStats([completed], new Date("2026-08-05T10:00:00")).rollingScore).toBe(5);
  });
});
