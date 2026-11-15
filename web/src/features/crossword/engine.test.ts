import {
  crosswordScore,
  deleteLetter,
  deriveCrosswordStats,
  deriveWeeklyCrosswordStats,
  emptyProgress,
  enterLetter,
  firstWhiteSelection,
  giveUp,
  crosswordDashboardStatus,
  weeklyCrosswordDashboardStatus,
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
  it.each(["daily", "weekly"] as const)("giving up a %s crossword reveals and locks it without increasing earned points", kind => {
    const currentPuzzle = puzzle();
    // Four crossing clues leave one genuinely solved answer before reveal.
    currentPuzzle.clues = [currentPuzzle.clues[0],
      { ...currentPuzzle.clues[0], id: 1, answer: "CD", startRow: 1 },
      { ...currentPuzzle.clues[0], id: 2, answer: "AC", direction: "down" },
      { ...currentPuzzle.clues[0], id: 3, answer: "BD", direction: "down", startCol: 1 }];
    currentPuzzle.date = kind === "weekly" ? "2026-08-02" : "2026-08-05";
    currentPuzzle.cells[1][0] = { letter: "C", clueNumber: 2, acrossClueId: 1, downClueId: 2 };
    currentPuzzle.cells[1][1] = { letter: "D", clueNumber: null, acrossClueId: 1, downClueId: 3 };
    let before = emptyProgress(currentPuzzle, new Date("2026-08-05T09:00:00"));
    before = { ...before, completedClueIds: [0], hintsUsed: 3, releaseDateScore: 1 };
    before.entries[0][0] = "A"; before.entries[0][1] = "B";
    const now = new Date("2026-08-05T10:00:00");
    const ended = giveUp(before, currentPuzzle, now, kind);
    expect(ended).toMatchObject({ gaveUpAt: now.toISOString(), gaveUpScore: 1, releaseDateScore: 1,
      completedAt: now.toISOString(), completedClueIds: [0, 1, 2, 3], isWeekly: kind === "weekly" });
    expect(ended.entries[1].slice(0, 3)).toEqual(["C", "D", null]);
    expect(ended.gaveUpRevealedCells).toEqual(["1,0", "1,1"]);
    expect(before.entries[1][0]).toBeNull();
    const selection = firstWhiteSelection(currentPuzzle);
    expect(enterLetter(ended, currentPuzzle, selection, "Z", false).progress).toBe(ended);
    expect(deleteLetter(ended, currentPuzzle, selection, false).progress).toBe(ended);
    expect(toggleHint(ended, currentPuzzle, currentPuzzle.clues[0])).toBe(ended);
    expect(giveUp(ended, currentPuzzle)).toBe(ended);
    const stats = kind === "weekly" ? deriveWeeklyCrosswordStats([ended], now) : deriveCrosswordStats([ended], now);
    expect(stats).toMatchObject({ totalSolved: 0, averageSolveTimeSeconds: null, rollingScore: 1 });
    const status = kind === "weekly" ? weeklyCrosswordDashboardStatus(ended, now, [ended]) : crosswordDashboardStatus(ended, now, [ended]);
    expect(status).toMatchObject({ label: "Gave up", tone: "failed", score: 1 });
    const archive = giveUp(before, currentPuzzle, new Date("2026-08-12T10:00:00"), kind);
    expect(archive.releaseDateScore).toBe(1);
    expect(archive.gaveUpScore).toBe(1);
    const unscoredArchive = giveUp({ ...before, releaseDateScore: 0 }, currentPuzzle, new Date("2026-08-12T10:00:00"), kind);
    expect(unscoredArchive.releaseDateScore).toBe(0);
    expect(giveUp({ ...before, completedAt: now.toISOString() }, currentPuzzle, now, kind).gaveUpAt).toBeUndefined();
  });
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
    const current = { ...emptyProgress({ ...puzzle(), id: "weekly-current", date: "2026-08-09" }, new Date("2026-08-10T09:00:00.000Z")), completedClueIds: [0], completedAt: "2026-08-10T10:00:00.000Z", releaseDateScore: 5, isWeekly: true };
    const previous = { ...current, puzzleId: "weekly-previous", date: "2026-08-02", startedAt: "2026-08-03T09:00:00.000Z", completedAt: "2026-08-03T10:00:00.000Z", releaseDateScore: 4 };
    const older = {
      ...current,
      puzzleId: "weekly-older",
      date: "2026-07-19",
      startedAt: "2026-07-19T01:00:00.000Z",
      completedAt: "2026-07-19T23:00:00.000Z"
    };
    const stats = deriveWeeklyCrosswordStats([current, previous, older], new Date("2026-08-14T12:00:00"));

    expect(stats.rollingScore).toBe(9);
    expect(stats.recentHistory).toHaveLength(2);
    expect(stats.previousHistory).toHaveLength(5);
    expect(stats.currentStreak).toBe(2);
    expect(stats.averageSolveTimeSeconds).toBe(3_600);
  });
});
