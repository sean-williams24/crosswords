import { describe, expect, it } from "vitest";
import fixtures from "../../../../docs/fixtures/anagram-v1.json";
import { anagramStats, answerText, elapsedSeconds, giveUp, placeTile, pointsForSeconds, reshuffle, restartTiles, revealHint, startProgress, undoTile, validProgress, validPuzzle, type AnagramProgress, type AnagramPuzzle } from "./engine";
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
  it("starts with a different letter from the answer, including repeated first letters", () => {
    const repeated = { ...puzzle, answer: "BUBBLES", acceptedAnswers: [], initialScramble: "BBBLUES" };
    const progress = startProgress(repeated, start);
    expect(repeated.initialScramble[progress.trayOrder[0]]).not.toBe(repeated.answer[0]);
    expect([...progress.trayOrder].sort()).toEqual([0, 1, 2, 3, 4, 5, 6]);
    expect(validProgress(progress, repeated)).toBe(true);
    expect(startProgress(puzzle, start).trayOrder).toEqual([0, 1, 2, 3, 4, 5, 6, 7]);
  });

  it("prevents Shuffle from returning the answer's first letter to the first slot", () => {
    const progress = reshuffle(startProgress(puzzle, start), puzzle, [3, 0, 1, 2, 4, 5, 6, 7], start);
    expect(puzzle.initialScramble[progress.trayOrder[0]]).not.toBe(puzzle.answer[0]);
    expect([...progress.trayOrder].sort()).toEqual([0, 1, 2, 3, 4, 5, 6, 7]);
    expect(validProgress(progress, puzzle)).toBe(true);
  });

  it("does not reveal an accepted answer when correcting the first letter", () => {
    const reactor = { ...puzzle, answer: "REACTOR", acceptedAnswers: ["CREATOR"], initialScramble: "RCEATOR" };
    const progress = startProgress(reactor, start);
    const tray = progress.trayOrder.map((tile) => reactor.initialScramble[tile]).join("");
    expect(tray[0]).not.toBe(reactor.answer[0]);
    expect([reactor.answer, ...reactor.acceptedAnswers]).not.toContain(tray);
    expect(validProgress(progress, reactor)).toBe(true);
  });

  it("keeps placed tray slots fixed and tolerates only matching letters remaining", () => {
    const placed = placeTile(startProgress(puzzle, start), puzzle, 0, start);
    const order = [3, 1, 2, 4, 5, 6, 7];
    const shuffled = reshuffle(placed, puzzle, order, start);
    expect(shuffled.trayOrder).toEqual([0, ...order]);
    expect(shuffled.placedTileIDs).toEqual(placed.placedTileIDs);
    expect(shuffled.placementHistory).toEqual([0]);
    expect(shuffled.startedAt).toBe(placed.startedAt);

    const repeated = { ...puzzle, answer: "BUBBLES", acceptedAnswers: [], initialScramble: "BBBLUES" };
    let remaining = startProgress(repeated, start);
    for (const tile of [3, 4, 5, 6]) remaining = placeTile(remaining, repeated, tile, start);
    const result = reshuffle(remaining, repeated, [2, 1, 0], start);
    expect(result.trayOrder.filter((tile) => !result.placedTileIDs.includes(tile))).toEqual([2, 1, 0]);
    expect(validProgress(result, repeated)).toBe(true);
  });

  it("preserves hint locks, penalties and history when shuffling", () => {
    const hinted = placeTile(revealHint(startProgress(puzzle, start), puzzle, start), puzzle, 1, start);
    const order = hinted.trayOrder.filter((tile) => !hinted.placedTileIDs.includes(tile)).reverse();
    const shuffled = reshuffle(hinted, puzzle, order, start);
    expect(shuffled.placedTileIDs).toEqual(hinted.placedTileIDs);
    expect(shuffled.placementHistory).toEqual(hinted.placementHistory);
    expect(shuffled.lockedTileID).toBe(hinted.lockedTileID);
    expect(shuffled.penaltySeconds).toBe(30);
    expect(shuffled.startedAt).toBe(hinted.startedAt);
    expect(validProgress(shuffled, puzzle)).toBe(true);
  });

  it("decodes shared puzzle fixtures and scoring boundaries", () => {
    expect(puzzle.answer).toBe("TRIANGLE");
    for (const scoreCase of fixtures.scoreCases) expect(pointsForSeconds(scoreCase.elapsedWithPenaltySeconds)).toBe(scoreCase.points);
  });

  it("reads a published hint position and rejects an invalid one", () => {
    const row = { ...fixtures.puzzles[0], puzzle_data: { ...fixtures.puzzles[0].puzzle_data, hintCellIndex: 3 } };
    expect(mapAnagramRow(row).hintCellIndex).toBe(3);
    expect(() => mapAnagramRow({ ...row, puzzle_data: { ...row.puzzle_data, hintCellIndex: -1 } })).toThrow();
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

  it("locks a published non-first hint and still accepts a compatible alternate", () => {
    const shared: AnagramPuzzle = {
      ...puzzle, answer: "GARDENS", acceptedAnswers: ["DANGERS"],
      initialScramble: "SGENDRA", hintCellIndex: 1
    };
    expect(validPuzzle(shared)).toBe(true);
    let progress = revealHint(placeTile(startProgress(shared, start), shared, 0, start), shared, start);
    expect(progress.lockedCellIndex).toBe(1);
    expect(progress.placedTileIDs[0]).toBeNull();
    expect(shared.initialScramble[progress.lockedTileID!]).toBe("A");
    for (const [index, letter] of [..."DANGERS"].entries()) {
      if (index === 1) continue;
      const tile = [...shared.initialScramble].findIndex((value, tileID) =>
        value === letter && !progress.placedTileIDs.includes(tileID));
      progress = placeTile(progress, shared, tile, start);
    }
    expect(progress.outcome).toBe("solved");
    expect(validPuzzle({ ...shared, hintCellIndex: -1 })).toBe(false);
    expect(validPuzzle({ ...shared, hintCellIndex: shared.answer.length })).toBe(false);
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
