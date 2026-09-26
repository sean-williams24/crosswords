import { afterEach, describe, expect, it } from "vitest";
import fixtures from "../../../../docs/fixtures/anagram-v1.json";
import { buildPlayerProfileRating } from "../profile/profileRating";
import { chooseBestProgress, anagramCloudRecord } from "../sync/progressSync";
import { mapAnagramRow } from "./repository";
import { placeTile, revealHint, startProgress, type AnagramProgress } from "./engine";

const puzzle = mapAnagramRow(fixtures.puzzles[0]);
const initial = new Date("2026-10-01T10:00:00Z");

afterEach(() => localStorage.removeItem("backword:web:anagram:first-release:v1"));

describe("Anagram account and rating integration", () => {
  it("keeps the arrangement and Undo history together while preserving the earliest start", () => {
    const a = placeTile(startProgress(puzzle, initial), puzzle, 0, new Date(initial.getTime() + 1_000));
    const b = placeTile(placeTile(startProgress(puzzle, new Date(initial.getTime() - 10_000)), puzzle, 1), puzzle, 2);
    const merged = chooseBestProgress(anagramCloudRecord(a), anagramCloudRecord(b)).payload;
    expect(merged.placedTileIDs).toEqual(b.placedTileIDs);
    expect(merged.placementHistory).toEqual(b.placementHistory);
    expect(merged.startedAt).toBe(new Date(initial.getTime() - 10_000).toISOString());
  });

  it("treats omitted Swift optionals as an unfinished branch during conflict resolution", () => {
    const plain = anagramCloudRecord(placeTile(startProgress(puzzle, initial), puzzle, 0));
    const swiftPayload = { ...plain.payload } as Partial<AnagramProgress>;
    delete swiftPayload.hintSource;
    delete swiftPayload.lockedCellIndex;
    delete swiftPayload.lockedTileID;
    delete swiftPayload.outcome;
    delete swiftPayload.completedAt;
    delete swiftPayload.elapsedSecondsAtCompletion;
    plain.payload = swiftPayload as AnagramProgress;
    const hinted = anagramCloudRecord(revealHint(startProgress(puzzle, initial), puzzle, initial));

    const merged = chooseBestProgress(plain, hinted).payload;
    expect(merged.outcome).toBeNull();
    expect(merged.hintUsed).toBe(true);
    expect(merged.lockedTileID).not.toBeNull();
  });

  it("adds possible points only after the first release and decodes older profile records as zero", () => {
    localStorage.setItem("backword:web:anagram:first-release:v1", "2026-10-01");
    const rating = buildPlayerProfileRating({ backword: [], dailyCrossword: [], weeklyCrossword: [], anagram: [
      { release_date: "2026-10-01", release_score: 4 }
    ] }, false, new Date("2026-10-02T12:00:00Z"));
    expect(rating.maxPoints).toBe(150);
    expect(rating.totalPoints).toBe(4);
    expect(rating.days[0].anagram).toBe(0);
    expect(rating.days[1].anagram).toBe(4);
    localStorage.setItem("backword:web:anagram:first-release:v1", "2026-09-01");
    expect(buildPlayerProfileRating({ backword: [], dailyCrossword: [], weeklyCrossword: [] }, false, new Date("2026-10-02T12:00:00Z")).maxPoints).toBe(210);
  });
});
