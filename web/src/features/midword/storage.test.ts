import { beforeEach, describe, expect, it, vi } from "vitest";
import { emptyProgress, type MidwordPuzzle } from "./engine";
import { createMidwordStorage } from "./storage";

const puzzle: MidwordPuzzle = { id: "midword", date: "2026-10-11", puzzleNumber: 11, firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: [] };
beforeEach(() => localStorage.clear());

describe("Midword persistence", () => {
  it("isolates guest and account progress while keeping puzzle caches shared", () => {
    const guest = createMidwordStorage();
    const account = createMidwordStorage(localStorage, { userId: "alice" });
    const progress = { ...emptyProgress(puzzle.date), guesses: ["PAGE"] };
    guest.saveProgress(progress); guest.cachePuzzle(puzzle);
    expect(account.loadProgress(puzzle.date).guesses).toEqual([]);
    expect(account.loadCachedPuzzle(puzzle.date)).toEqual(puzzle);
    account.saveProgress({ ...progress, guesses: ["WORD"] });
    expect(guest.loadProgress(puzzle.date).guesses).toEqual(["PAGE"]);
    expect(createMidwordStorage(localStorage, { userId: "bob" }).loadAllProgress()).toEqual([]);
  });
  it("notifies only after a local save, never when applying remote progress", () => {
    const callback = vi.fn();
    const storage = createMidwordStorage(localStorage, { onProgressSaved: callback });
    storage.saveProgress(emptyProgress(puzzle.date));
    expect(callback).toHaveBeenCalledOnce();
    storage.replaceProgress({ ...emptyProgress(puzzle.date), guesses: ["WORD"] });
    expect(callback).toHaveBeenCalledOnce();
    expect(storage.loadProgress(puzzle.date).guesses).toEqual(["WORD"]);
    storage.deleteProgress(puzzle.date);
    expect(storage.loadAllProgress()).toEqual([]);
  });
  it("ignores corrupt saves and cache payloads", () => {
    localStorage.setItem("backword:web:midword:progress:v1", "broken");
    const storage = createMidwordStorage();
    expect(storage.loadAllProgress()).toEqual([]);
    storage.replaceProgress({ date: puzzle.date, guesses: 123 });
    expect(storage.loadAllProgress()).toEqual([]);
    localStorage.setItem("backword:web:midword:progress:v1", JSON.stringify({ [puzzle.date]: { ...emptyProgress("2026-10-10"), guesses: ["PAGE"] } }));
    expect(storage.loadProgress(puzzle.date).guesses).toEqual([]);
    localStorage.setItem("backword:web:midword:puzzles:v1", JSON.stringify({ [puzzle.date]: { ...puzzle, answer: "??" } }));
    expect(storage.loadCachedPuzzle(puzzle.date)).toBeNull();
  });
});
