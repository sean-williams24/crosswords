import { describe, expect, it } from "vitest";
import fixtures from "../../../../docs/fixtures/anagram-v1.json";
import { anagramStats, answerText, elapsedSeconds, giveUp, placeTile, pointsForSeconds, restartTiles, revealHint, startProgress, undoTile, validProgress, type AnagramProgress, type AnagramPuzzle } from "./engine";
import { mapAnagramRow } from "./repository";

const puzzle = mapAnagramRow(fixtures.puzzles[0]) as AnagramPuzzle;
const start = new Date("2026-10-01T10:00:00Z");

function placeWord(word: string, progress = startProgress(puzzle, start), time = start) {
  const used = new Set<number>(progress.placedTileIDs.filter((tile) => tile !== null) as number[]);
  for (const letter of word) {
    const tile = [...puzzle.initialScramble].findIndex((value, index) => value === letter && !used.has(index));
    expect(tile).toBeGreaterThanOrEqual(0);
    used.add(tile);
    progress = placeTile(progress, puzzle, tile, time);
  }
  return progress;
}

describe("Anagram v1 parity", () => {
  it("decodes shared puzzle fixtures and scoring boundaries", () => {
    expect(puzzle.answer).toBe("TRIANGLE");
    for (const scoreCase of fixtures.scoreCases) expect(pointsForSeconds(scoreCase.elapsedWithPenaltySeconds)).toBe(scoreCase.points);
  });

  it("uses tile identities for duplicate letters and restores repeatable Undo history", () => {
    const second = mapAnagramRow(fixtures.puzzles[1]);
    let progress = startProgress(second, start);
    const firstE = second.initialScramble.indexOf("E");
    const secondE = second.initialScramble.lastIndexOf("E");
    progress = placeTile(progress, second, firstE, start);
    progress = placeTile(progress, second, secondE, start);
    expect(progress.placementHistory).toEqual([firstE, secondE]);
    expect(validProgress(JSON.parse(JSON.stringify(progress)), second)).toBe(true);
    progress = undoTile(progress);
    expect(progress.placedTileIDs[1]).toBeNull();
    progress = undoTile(progress);
    expect(progress.placedTileIDs[0]).toBeNull();
  });

  it("keeps timer and hint penalty through Restart and reload", () => {
    let progress = placeTile(startProgress(puzzle, start), puzzle, 0, new Date(start.getTime() + 20000));
    progress = revealHint(progress, puzzle, new Date(start.getTime() + 25000));
    expect(progress.placementHistory).toEqual([]);
    expect(progress.lockedCellIndex).toBe(0);
    progress = placeTile(progress, puzzle, 0, new Date(start.getTime() + 35000));
    progress = restartTiles(progress, new Date(start.getTime() + 40000));
    expect(progress.placedTileIDs[0]).toBe(progress.lockedTileID);
    expect(progress.penaltySeconds).toBe(30);
    expect(elapsedSeconds(progress, new Date(start.getTime() + 45000))).toBe(45);
    expect(validProgress(JSON.parse(JSON.stringify(progress)), puzzle)).toBe(true);
  });

  it("accepts alternate answers and awards release-day scores only", () => {
    const solved = placeWord("INTEGRAL", startProgress(puzzle, start), new Date(start.getTime() + 59_000));
    expect(answerText(solved, puzzle)).toBe("INTEGRAL");
    expect(solved.outcome).toBe("solved");
    expect(solved.releaseDateScore).toBe(4);
    expect(placeTile(solved, puzzle, 0)).toBe(solved);
    const late = placeWord("TRIANGLE", startProgress(puzzle, start), new Date("2026-10-02T00:00:00Z"));
    expect(late.releaseDateScore).toBe(0);
    expect(giveUp(startProgress(puzzle, start)).releaseDateScore).toBe(0);
  });

  it("derives current and best release-day streaks independently", () => {
    const solved = (date: string): AnagramProgress => ({
      ...startProgress({ ...puzzle, id: `puzzle-${date}`, date }),
      outcome: "solved",
      completedAt: `${date}T12:00:20Z`,
      elapsedSecondsAtCompletion: 20,
      releaseDateScore: 5
    });
    const stats = anagramStats(
      [solved("2026-10-01"), solved("2026-10-02"), solved("2026-10-04")],
      new Date("2026-10-04T18:00:00Z")
    );

    expect(stats.streak).toBe(1);
    expect(stats.bestStreak).toBe(2);
  });
});
