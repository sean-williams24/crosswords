import { describe, expect, it } from "vitest";
import { puzzleResultCardSvg } from "./PuzzleResultShare";
import { buildBackwordShareResult, buildCrosswordShareResult, shareUrl } from "./puzzleResult";

const rating = {
  days: [],
  maxPoints: 140,
  totalPoints: 68,
  fraction: 68 / 140,
  tier: "Linguist" as const
};

describe("puzzle share results", () => {
  it("builds a scored Backword result without including the answer or guesses", () => {
    const answer = "CASTLE";
    const result = buildBackwordShareResult({
      progress: {
        schemaVersion: 1,
        date: "2026-09-16",
        guesses: ["BOTTLE", answer],
        outcome: "won",
        completedAt: "2026-09-16T14:24:00.000Z"
      },
      stats: { gamesPlayed: 4, gamesWon: 4, currentStreak: 4, longestStreak: 4, winRate: 100, guessDistribution: { 1: 0, 2: 1, 3: 0, 4: 0, 5: 0 }, rollingScore: 18, history: [] },
      word: { puzzleNumber: 32 },
      rating,
      origin: "https://www.playbackword.com"
    });

    expect(result).toMatchObject({ game: "backword", issueNumber: 32, outcome: "SOLVED", score: 4, streak: 4, primaryStat: { value: "2 / 5" }, ratingTier: "Linguist", ratingPoints: 68 });
    expect(result.url).toBe("https://www.playbackword.com/backword/2026-09-16?utm_source=share&utm_medium=social&utm_campaign=completed_puzzle");
    expect(`${result.caption}${puzzleResultCardSvg(result)}`).not.toContain(answer);
    expect(`${result.caption}${puzzleResultCardSvg(result)}`).not.toContain("BOTTLE");
  });

  it("uses the Backword logo instead of a text-only wordmark on the share card", () => {
    const card = puzzleResultCardSvg({
      game: "backword", gameName: "Backword", issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 1,
      ratingTier: "Linguist", ratingPoints: 68, ratingMaxPoints: 140,
      primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, url: "https://www.playbackword.com/backword/2026-09-16", caption: ""
    });

    expect(card).toContain('<image href="https://www.playbackword.com/brand/backword-logo.png"');
    expect(card).not.toContain('letter-spacing="5">BACKWORD</text>');
    expect(card).toContain('width="1080" height="1080"');
    expect(card).toContain("1 DAY STREAK");
    expect(card).toContain("SOLVED");
    expect(card).not.toContain("<circle");
  });

  it("uses the matching dark Home-card palette for every game", () => {
    const base = {
      issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 1,
      ratingTier: "Linguist", ratingPoints: 68, ratingMaxPoints: 140,
      primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, url: "https://www.playbackword.com/backword/2026-09-16", caption: ""
    };

    expect(puzzleResultCardSvg({ ...base, game: "backword", gameName: "Backword" })).toContain('stop-color="#34417c"');
    expect(puzzleResultCardSvg({ ...base, game: "daily_crossword", gameName: "Quick Crossword" })).toContain('stop-color="#30445e"');
    expect(puzzleResultCardSvg({ ...base, game: "weekly_crossword", gameName: "Pro Crossword" })).toContain('stop-color="#211e19"');
  });

  it("makes a failed Backword result neutral and spoiler-safe", () => {
    const answer = "CASTLE";
    const result = buildBackwordShareResult({
      progress: { schemaVersion: 1, date: "2026-09-16", guesses: ["BOTTLE", "BANGLE", "BUNGLE", "BUNDLE", "JUNGLE"], outcome: "failed", completedAt: "2026-09-16T14:24:00.000Z" },
      stats: { gamesPlayed: 4, gamesWon: 3, currentStreak: 0, longestStreak: 3, winRate: 75, guessDistribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }, rollingScore: 12, history: [] },
      word: { puzzleNumber: 32 }, rating, origin: "https://www.playbackword.com"
    });

    expect(result).toMatchObject({ outcome: "COMPLETED", score: 0, primaryStat: { value: "5 / 5" } });
    expect(result.caption).not.toMatch(/failed|lost|castle|bottle/i);
  });

  it("builds daily and weekly crossword results without grid or clue content", () => {
    const progress = {
      schemaVersion: 1 as const, puzzleId: "puzzle-id", date: "2026-09-16", size: 9, entries: [["A"]], completedClueIds: [1], hintedClueIds: [], hintsUsed: 0,
      startedAt: "2026-09-16T14:00:00.000Z", completedAt: "2026-09-16T14:05:02.000Z", releaseDateScore: 5
    };
    const daily = buildCrosswordShareResult({ progress, puzzle: { puzzleNumber: 8 }, stats: { totalSolved: 1, currentStreak: 2, longestStreak: 2, averageSolveTimeSeconds: null, rollingScore: 5, history: [] }, kind: "daily", rating, origin: "https://www.playbackword.com" });
    const weekly = buildCrosswordShareResult({ progress: { ...progress, size: 13, isWeekly: true }, puzzle: { puzzleNumber: 3 }, stats: { totalSolved: 1, currentStreak: 1, longestStreak: 1, averageSolveTimeSeconds: null, rollingScore: 5, recentHistory: [], previousHistory: [] }, kind: "weekly", rating, origin: "https://www.playbackword.com" });

    expect(daily).toMatchObject({ game: "daily_crossword", gameName: "Quick Crossword", score: 5, timeStat: { value: "00:05:02" } });
    expect(weekly).toMatchObject({ game: "weekly_crossword", gameName: "Pro Crossword", issueNumber: 3 });
    expect(`${daily.caption}${puzzleResultCardSvg(daily)}`).not.toContain("puzzle-id");
    expect(`${daily.caption}${puzzleResultCardSvg(daily)}`).not.toContain("Test clue");
  });

  it("links each game type to its exact issue with attribution", () => {
    expect(shareUrl("daily_crossword", "2026-09-16", "https://playbackword.com")).toContain("/crossword/2026-09-16?");
    expect(shareUrl("weekly_crossword", "2026-09-14", "https://playbackword.com")).toContain("/weekly-crossword/2026-09-14?");
  });
});
