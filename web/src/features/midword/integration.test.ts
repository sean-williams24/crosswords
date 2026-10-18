import { beforeEach, describe, expect, it } from "vitest";
import { buildPlayerProfileRating } from "../profile/profileRating";
import { loadLocalProfileRecords } from "../profile/profileRecords";
import { chooseBestProgress, midwordCloudRecord } from "../sync/progressSync";
import { canMigrateGuestProgress, clearGuestMigrationOwnerIfEmpty } from "../sync/guestMigration";
import { buildMidwordShareResult } from "../share/puzzleResult";
import { puzzleResultCardSvg } from "../share/PuzzleResultShare";
import { emptyProgress, midwordStats, submitGuess, type MidwordPuzzle } from "./engine";
import { createMidwordStorage } from "./storage";

const now = new Date(2026, 9, 11, 12);
const puzzle: MidwordPuzzle = { id: "puzzle", date: "2026-10-11", puzzleNumber: 11, firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: [] };
const won = submitGuess(emptyProgress(puzzle.date), puzzle, "NOTE", () => false, now).progress;
beforeEach(() => localStorage.clear());

describe("Midword account, rating and sharing integration", () => {
  it("emits the native payload and whole-record sync metadata", () => {
    const record = midwordCloudRecord(won);
    expect(record).toMatchObject({ game_type: "midword", content_key: puzzle.date, schema_version: 1,
      status: "solved", progress_rank: 1, release_score: 5, payload: { schemaVersion: 1, outcome: "won" } });
    expect(record.payload).not.toHaveProperty("won");
  });
  it("keeps one whole guess list and preserves the greater release score", () => {
    const archiveWin = { ...won, guesses: ["PAGE", "NOTE"], completedAt: new Date(2026, 9, 12, 12).toISOString(), updatedAt: new Date(2026, 9, 12, 12).toISOString(), releaseDateScore: 0 };
    const merged = chooseBestProgress(midwordCloudRecord(won), midwordCloudRecord(archiveWin));
    expect(merged.payload.guesses).toEqual(["NOTE"]);
    expect(merged.release_score).toBe(5);
    expect(merged.payload.releaseDateScore).toBe(5);
    const partial = midwordCloudRecord({ ...emptyProgress(puzzle.date), guesses: ["PAGE"] });
    expect(chooseBestProgress(partial, midwordCloudRecord(won)).status).toBe("solved");
  });
  it("claims a Midword-only guest batch for one account until migration completes", () => {
    const storage = createMidwordStorage(); storage.saveProgress(won);
    expect(canMigrateGuestProgress(localStorage, "alice")).toBe(true);
    clearGuestMigrationOwnerIfEmpty(localStorage);
    expect(canMigrateGuestProgress(localStorage, "bob")).toBe(false);
    storage.deleteProgress(won.date); clearGuestMigrationOwnerIfEmpty(localStorage);
    expect(localStorage.getItem("backword:web:sync:guest-migration-owner:v1")).toBeNull();
  });
  it("prefers the native shorter solved guess list while preserving release-day points", () => {
    const onTime = { ...won, guesses: ["PAGE", "NOTE"], releaseDateScore: 4 };
    const archive = { ...won, completedAt: new Date(2026, 9, 12, 12).toISOString(), releaseDateScore: 0 };
    const merged = chooseBestProgress(midwordCloudRecord(onTime), midwordCloudRecord(archive));
    expect(merged.payload.guesses).toEqual(["NOTE"]);
    expect(merged.payload.completedAt).toBe(archive.completedAt);
    expect(merged.release_score).toBe(4);
    expect(merged.payload.releaseDateScore).toBe(4);
  });
  it("includes local Midword points immediately in the shared player rating", () => {
    localStorage.setItem("backword:web:anagram:first-release:v1", "2026-09-01");
    createMidwordStorage(localStorage, { userId: "alice" }).saveProgress(won);
    const records = loadLocalProfileRecords("alice");
    const rating = buildPlayerProfileRating(records, false, now);
    expect(rating.totalPoints).toBe(5);
    expect(rating.days[0].midword).toBe(5);
    expect(buildPlayerProfileRating(records, false, new Date(2026, 9, 14, 12)).maxPoints).toBe(280);
    expect(buildPlayerProfileRating(records, true, new Date(2026, 9, 14, 12)).maxPoints).toBe(290);
    expect(loadLocalProfileRecords().midword).toEqual([]);
  });
  it("exports only result metadata and a dated link, never puzzle words or guesses", () => {
    const result = buildMidwordShareResult({ puzzle, progress: won, stats: midwordStats([won], now),
      rating: buildPlayerProfileRating(loadLocalProfileRecords(), false, now), origin: "https://playbackword.com" });
    expect(result.url).toContain("/midword/2026-10-11?utm_source=share");
    expect(result.primaryStat).toEqual({ label: "GUESSES", value: "1/5" });
    const shared = JSON.stringify(result) + puzzleResultCardSvg(result);
    for (const word of ["BANK", "BOOK", "NOTE", "BANKNOTE", "NOTEBOOK"]) expect(shared).not.toContain(word);
    expect(puzzleResultCardSvg(result)).toContain('fill="#1f1f1f"');
  });
});
