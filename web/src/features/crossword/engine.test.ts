import {
  crosswordScore,
  deleteLetter,
  deriveCrosswordStats,
  deriveWeeklyCrosswordStats,
  emptyProgress,
  enterLetter,
  firstWhiteSelection,
  selectCell,
  toggleHint
} from "./engine";
import type { CrosswordPuzzle } from "./types";

function puzzle(): CrosswordPuzzle {
  const cells: CrosswordPuzzle["cells"] = Array.from({ length: 9 }, () => Array.from({ length: 9 }, () => ({ letter: null, clueNumber: null, acrossClueId: null, downClueId: null })));
  cells[0][0] = { letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: null };
  cells[0][1] = { letter: "B", clueNumber: null, acrossClueId: 0, downClueId: null };
  return { id: "puzzle", puzzleNumber: 1, date: "2026-08-05", size: 9, cells, clues: [{ id: 0, direction: "across", number: 1, text: "Test", hint: "Hint", answer: "AB", startRow: 0, startCol: 0, length: 2 }] };
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

  it("excludes archive completions from streaks and on-release average-time statistics", () => {
    const currentPuzzle = puzzle();
    const completed = (date: string, completedAt: string, durationSeconds: number, suffix: string) => ({
      ...emptyProgress({ ...currentPuzzle, id: `puzzle-${suffix}` }, new Date(new Date(completedAt).getTime() - durationSeconds * 1_000)),
      date,
      completedAt,
      releaseDateScore: 5
    });
    const records = [
      // Archive completions remain total solves but never extend a streak or
      // enter the release-day average.
      completed("2026-07-01", "2026-08-01T10:00:00.000Z", 1, "1"),
      completed("2026-07-02", "2026-08-02T10:00:00.000Z", 1, "2"),
      completed("2026-07-03", "2026-08-03T10:00:00.000Z", 1, "3"),
      completed("2026-07-04", "2026-08-04T10:00:00.000Z", 1, "4"),
      completed("2026-08-05", "2026-08-05T10:00:00.000Z", 3_600, "5"),
      completed("2026-08-06", "2026-08-06T10:00:00.000Z", 7_200, "6"),
      completed("2026-08-07", "2026-08-07T10:00:00.000Z", 10_800, "7"),
      completed("2026-08-08", "2026-08-08T10:00:00.000Z", 14_068, "8")
    ];

    const stats = deriveCrosswordStats(records, new Date("2026-08-12T12:00:00.000Z"));

    expect(stats.totalSolved).toBe(8);
    expect(stats.longestStreak).toBe(4);
    expect(stats.averageSolveTimeSeconds).toBe(8_917);
  });

  it("deducts weekly hint penalties and keeps scores inside the Sunday release window", () => {
    const weekly = { ...puzzle(), id: "weekly", date: "2026-08-02", size: 9 };
    const progress = { ...emptyProgress(weekly, new Date("2026-08-02T09:00:00")), completedClueIds: [0] };
    const onceHinted = toggleHint(progress, weekly, weekly.clues[0], new Date("2026-08-02T10:00:00"), "weekly");
    const thriceHinted = { ...onceHinted, hintsUsed: 3, hintedClueIds: [0, 1, 2] };

    expect(onceHinted.releaseDateScore).toBe(5);
    expect(crosswordScore(1, 1, thriceHinted.hintsUsed)).toBe(4);
  });

  it("builds the iOS weekly two-week rating and seven-game history", () => {
    const current = { ...emptyProgress({ ...puzzle(), id: "weekly-current", date: "2026-08-09" }, new Date("2026-08-09T09:00:00")), completedClueIds: [0], completedAt: "2026-08-10T10:00:00.000Z", releaseDateScore: 5, isWeekly: true };
    const previous = { ...current, puzzleId: "weekly-previous", date: "2026-08-02", completedAt: "2026-08-03T10:00:00.000Z", releaseDateScore: 4 };
    const stats = deriveWeeklyCrosswordStats([current, previous], new Date("2026-08-14T12:00:00"));

    expect(stats.rollingScore).toBe(9);
    expect(stats.recentHistory).toHaveLength(2);
    expect(stats.previousHistory).toHaveLength(5);
    expect(stats.currentStreak).toBe(2);
  });
});
