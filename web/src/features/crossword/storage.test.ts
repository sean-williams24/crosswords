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
});
