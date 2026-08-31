import { createCrosswordStorage } from "./storage";
import { emptyProgress } from "./engine";

const puzzle = { id: "puzzle", date: "2026-08-05", size: 9 };

describe("crossword storage", () => {
  beforeEach(() => localStorage.clear());

  it("persists valid per-puzzle progress and ignores corrupt records", () => {
    const storage = createCrosswordStorage();
    const progress = emptyProgress(puzzle, new Date("2026-08-05T09:00:00"));
    storage.saveProgress(progress);
    expect(storage.loadProgress(puzzle)).toEqual(progress);
    localStorage.setItem("backword:web:crossword:progress:v1", "not json");
    expect(storage.loadProgress(puzzle).puzzleId).toBe("puzzle");
  });

  it("accepts an unfinished iOS cloud payload that omits completedAt", () => {
    const storage = createCrosswordStorage();
    const progress = emptyProgress(puzzle, new Date("2026-08-05T09:00:00"));
    const iosPayload = { ...progress } as Record<string, unknown>;
    delete iosPayload.completedAt;

    storage.replaceProgress(iosPayload as typeof progress);

    expect(storage.loadProgress(puzzle)).toMatchObject({
      puzzleId: "puzzle",
      completedAt: null
    });
  });

  it("keeps 13×13 weekly progress isolated while preserving iOS hint metadata", () => {
    const weeklyPuzzle = { id: "weekly-puzzle", date: "2026-08-02", size: 13 } as const;
    const weeklyStorage = createCrosswordStorage(undefined, { kind: "weekly" });
    const weekly = {
      ...emptyProgress(weeklyPuzzle, new Date("2026-08-02T09:00:00")),
      hintedClueIds: [4],
      hintsUsed: 1,
      isWeekly: true
    };

    weeklyStorage.saveProgress(weekly);

    expect(weeklyStorage.loadProgress(weeklyPuzzle)).toMatchObject({ size: 13, hintedClueIds: [4], hintsUsed: 1, isWeekly: true });
    expect(createCrosswordStorage().loadAllProgress()).toHaveLength(0);
  });
});
