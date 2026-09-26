import { describe, expect, it } from "vitest";
import fixtures from "../../../../docs/fixtures/anagram-v1.json";
import { mapAnagramRow } from "./repository";
import { placeTile, startProgress, type AnagramProgress } from "./engine";
import { createAnagramStorage } from "./storage";

const puzzle = mapAnagramRow(fixtures.puzzles[0]);

describe("Anagram storage", () => {
  it("restores one whole arrangement with its Undo history and isolates accounts", () => {
    const storage = createAnagramStorage(localStorage, { userId: "account-a" });
    const guest = createAnagramStorage(localStorage);
    const progress = placeTile(startProgress(puzzle), puzzle, 0);
    storage.saveProgress(progress);
    expect(storage.loadProgress(puzzle)?.placementHistory).toEqual([0]);
    expect(guest.loadProgress(puzzle)).toBeNull();
    expect(createAnagramStorage(localStorage, { userId: "account-b" }).loadProgress(puzzle)).toBeNull();
    storage.deleteProgress(puzzle.date);
  });

  it("normalizes optional fields omitted by Swift Codable", () => {
    const storage = createAnagramStorage(localStorage);
    const encoded = { ...startProgress(puzzle) } as Partial<AnagramProgress>;
    delete encoded.hintSource;
    delete encoded.lockedCellIndex;
    delete encoded.lockedTileID;
    delete encoded.outcome;
    delete encoded.completedAt;
    delete encoded.elapsedSecondsAtCompletion;
    localStorage.setItem("backword:web:anagram:progress:v1", JSON.stringify({ [puzzle.date]: encoded }));

    expect(storage.loadProgress(puzzle)).toMatchObject({
      hintSource: null,
      lockedCellIndex: null,
      lockedTileID: null,
      outcome: null,
      completedAt: null,
      elapsedSecondsAtCompletion: null
    });
    storage.deleteProgress(puzzle.date);
  });
});
