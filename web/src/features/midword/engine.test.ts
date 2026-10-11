import { describe, expect, it } from "vitest";
import { localDateOffset } from "../backword/date";
import { accepts, decodeProgress, emptyProgress, midwordStats, midwordStatus, submitGuess, validPuzzle, type MidwordPuzzle } from "./engine";
import { validMidwordGuesses } from "./validGuesses";

const now = new Date(2026, 9, 11, 12);
const date = "2026-10-11";
export const puzzle: MidwordPuzzle = { id: "midword-11", date, puzzleNumber: 11, firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: [] };
const submit = (progress = emptyProgress(date), word = "NOTE", time = now) => submitGuess(progress, puzzle, word, () => true, time).progress;

describe("Midword rules and statistics", () => {
  it("validates answer length, alternatives, ASCII prompts and real calendar dates", () => {
    expect(validPuzzle(puzzle)).toBe(true);
    for (const changes of [{ date: "2026-02-30" }, { answer: "NO" }, { answer: "TOOLONG" }, { firstWord: "BANK-" }, { alternatives: ["NOTES"] }, { alternatives: ["NOTE"] }, { puzzleNumber: 0 }]) {
      expect(validPuzzle({ ...puzzle, ...changes })).toBe(false);
    }
  });
  it.each([1, 2, 3, 4, 5])("scores a release-day win on guess %i", (attempt) => {
    let progress = emptyProgress(date);
    for (let index = 0; index < attempt - 1; index++) progress = submit(progress, ["PAGE", "WORD", "READ", "LINE"][index]);
    progress = submit(progress);
    expect(progress.outcome).toBe("won");
    expect(progress.releaseDateScore).toBe(6 - attempt);
    expect(progress.completedAt).toBe(now.toISOString());
  });
  it("does not consume incomplete, duplicate, invalid or repeated-letter guesses", () => {
    const progress = submit(emptyProgress(date), "PAGE");
    for (const word of ["NO", "NOTEZ", "PAGE", "ZZZZ", "AAAA", "N0TE"]) {
      expect(submitGuess(progress, puzzle, word, () => false, now).progress).toBe(progress);
    }
    expect(submitGuess(progress, puzzle, "PAGE", () => true).message).toBe("Already guessed");
    expect(submitGuess(progress, puzzle, "AAAA", () => true).message).toBe("Not a valid word");
    expect(submitGuess(progress, puzzle, "QWER", () => false).message).toBe("Not a valid word");
  });
  it("always accepts approved answers and alternatives independently of the dictionary", () => {
    const alternativePuzzle = { ...puzzle, alternatives: ["LINK"] };
    expect(accepts(alternativePuzzle, "LINK")).toBe(true);
    expect(submitGuess(emptyProgress(date), alternativePuzzle, "LINK", () => false, now).progress.outcome).toBe("won");
    expect(submitGuess(emptyProgress(date), puzzle, "NOTE", () => false, now).progress.outcome).toBe("won");
  });
  it("fails after five accepted wrong words and never changes terminal progress", () => {
    let progress = emptyProgress(date);
    for (const word of ["PAGE", "WORD", "READ", "LINE", "BOOK"]) progress = submit(progress, word);
    expect(progress.outcome).toBe("failed");
    expect(progress.releaseDateScore).toBe(0);
    expect(submit(progress)).toBe(progress);
  });
  it("gives archive wins no points and labels them Finished", () => {
    const progress = submit(emptyProgress(date), "NOTE", new Date(2026, 9, 12, 12));
    expect(progress.releaseDateScore).toBe(0);
    expect(midwordStatus(progress).label).toBe("Finished");
    expect(midwordStatus(emptyProgress(date)).label).toBe("New");
    expect(midwordStatus(submit(emptyProgress(date), "PAGE")).label).toBe("In Progress");
  });
  it("decodes the native cloud payload with an omitted completedAt", () => {
    const { completedAt: _omitted, ...native } = emptyProgress(date, now);
    expect(decodeProgress({ ...native, guesses: ["PAGE"] })?.completedAt).toBeNull();
    expect(decodeProgress({ ...native, guesses: ["PAGE", "PAGE"] })).toBeNull();
    expect(decodeProgress({ ...native, updatedAt: "invalid" })).toBeNull();
    expect(decodeProgress(null)).toBeNull();
  });
  it("derives streaks and distribution only from release-day solves", () => {
    const win = (day: string) => ({ ...submit(), date: day, completedAt: new Date(`${day}T12:00:00`).toISOString() });
    const records = [win("2026-10-09"), win("2026-10-10"), emptyProgress(date),
      { ...win("2026-10-08"), completedAt: now.toISOString(), releaseDateScore: 0 }];
    const stats = midwordStats(records, now);
    expect(stats.totalSolved).toBe(2);
    expect(stats.currentStreak).toBe(2);
    expect(stats.bestStreak).toBe(2);
    expect(stats.guessDistribution).toEqual([2, 0, 0, 0, 0]);
    expect(stats.rollingScore).toBe(10);
    expect(stats.rows.find((r) => r.date === "2026-10-08")).toMatchObject({ outcome: "unplayed", guessCount: null, score: 0 });
    let failed = emptyProgress(date);
    for (const word of ["PAGE", "WORD", "READ", "LINE", "BOOK"]) failed = submit(failed, word);
    expect(midwordStats([...records.filter((p) => p.date !== date), failed], now).currentStreak).toBe(0);
  });
  it("limits history to fourteen local release dates after launch", () => {
    expect(midwordStats([], new Date(2026, 9, 2, 12)).rows.map((r) => r.date)).toEqual(["2026-10-02", "2026-10-01"]);
    const rows = midwordStats([], new Date(2026, 10, 1, 12)).rows;
    expect(rows).toHaveLength(14);
    expect(rows[13].date).toBe(localDateOffset("2026-11-01", -13));
  });
  it("bundles common 3–6-letter guesses for offline play", () => {
    for (const word of ["CAT", "NOTE", "WORD", "HOUSE", "CASTLE"]) expect(validMidwordGuesses.has(word)).toBe(true);
    for (const word of validMidwordGuesses) expect(word).toMatch(/^[A-Z]{3,6}$/);
    expect(validMidwordGuesses.has("AAAA")).toBe(false);
    expect(validMidwordGuesses.has("ZZQX")).toBe(false);
  });
});
