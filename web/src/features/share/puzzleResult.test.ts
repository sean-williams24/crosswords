import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { puzzleResultCardSvg } from "./PuzzleResultShare";
import { buildBackwordShareResult, buildCrosswordShareResult, formatCompletionTime, shareUrl } from "./puzzleResult";

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

    expect(result).toMatchObject({ game: "backword", issueNumber: 32, outcome: "SOLVED", score: 4, streak: 4, totalGamesSolved: 4, primaryStat: { value: "2 / 5" }, timeStat: { label: "COMPLETED AT" }, ratingTier: "Linguist", ratingPoints: 68 });
    expect(result.url).toBe("https://www.playbackword.com/backword/2026-09-16?utm_source=share&utm_medium=social&utm_campaign=completed_puzzle");
    expect(`${result.caption}${puzzleResultCardSvg(result)}`).not.toContain(answer);
    expect(`${result.caption}${puzzleResultCardSvg(result)}`).not.toContain("BOTTLE");
  });

  it("uses the original vector Backword logo on the share card", () => {
    const card = puzzleResultCardSvg({
      game: "backword", gameName: "Backword", issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 1, totalGamesSolved: 7,
      ratingTier: "Linguist", ratingPoints: 68, ratingMaxPoints: 140,
      primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, url: "https://www.playbackword.com/backword/2026-09-16", caption: ""
    });

    expect(card).toContain('<image href="https://www.playbackword.com/brand/backword-logo-share.svg"');
    expect(card).not.toContain('<g aria-label="Backword logo"');
    expect(card).toContain('width="1080" height="1080"');
    expect(card).toContain('<rect width="1080" height="1080" rx="48" fill="#7888d7"/>');
    expect(card).toContain('fill="#999999" font-family="Outfit, sans-serif" font-size="31" font-weight="700" letter-spacing="3">TODAY\'S SCORE</text>');
    expect(card).toContain('font-size="52" font-weight="400">5 pts</text>');
    expect(card).toContain(">1 day</text>");
    expect(card).not.toContain("DAY STREAK");
    expect(card).toContain(">Linguist</text><text x=\"94\" y=\"695\" fill=\"#ffffff\" font-family=\"Outfit, sans-serif\" font-size=\"44\" font-weight=\"400\">68/140 pts</text>");
    expect(card).toContain("SOLVED");
    expect(card).toContain('font-family="Outfit, sans-serif"');
    expect(card).not.toContain('font-family="Arial, sans-serif"');
    expect(card).toContain('<text x="1016" y="1010" fill="#2a2a2a" font-family="Outfit, sans-serif" font-size="55" font-weight="700" letter-spacing="3" text-anchor="end">playbackword.com</text>');
    expect(card).not.toContain("PLAY →");
    expect(card).not.toContain("<circle");
  });

  it("uses a high-contrast blue for BACK in the shared vector wordmark", () => {
    const logo = readFileSync(resolve(process.cwd(), "public/brand/backword-logo-share.svg"), "utf8");

    expect(logo).toContain('<g fill="#B8E0FF" fill-rule="evenodd">');
    expect(logo).not.toContain('#5B8DC9');
  });

  it("uses the singular score unit for one point", () => {
    const card = puzzleResultCardSvg({
      game: "backword", gameName: "Backword", issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 1, streak: 1, totalGamesSolved: 7,
      ratingTier: "Linguist", ratingPoints: 68, ratingMaxPoints: 140,
      primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, url: "https://www.playbackword.com/backword/2026-09-16", caption: ""
    });

    expect(card).toContain(">1 pt</text>");
    expect(card).not.toContain(">1 pts</text>");
  });

  it("embeds Outfit Bold when creating a shareable SVG", () => {
    const card = puzzleResultCardSvg({
      game: "backword", gameName: "Backword", issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 1, totalGamesSolved: 7,
      ratingTier: "Linguist", ratingPoints: 68, ratingMaxPoints: 140,
      primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, url: "https://www.playbackword.com/backword/2026-09-16", caption: ""
    }, undefined, { bold: "data:font/ttf;base64,OUTFIT" });

    expect(card).toContain('@font-face { font-family: "Outfit"; src: url("data:font/ttf;base64,OUTFIT") format("truetype"); font-weight: 700; }');
  });

  it("embeds Outfit Regular for the smaller result values", () => {
    const card = puzzleResultCardSvg({
      game: "backword", gameName: "Backword", issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 1, totalGamesSolved: 7,
      ratingTier: "Linguist", ratingPoints: 68, ratingMaxPoints: 140,
      primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, url: "https://www.playbackword.com/backword/2026-09-16", caption: ""
    }, undefined, { regular: "data:font/ttf;base64,REGULAR" });

    expect(card).toContain('@font-face { font-family: "Outfit"; src: url("data:font/ttf;base64,REGULAR") format("truetype"); font-weight: 400; }');
    expect(card).toContain('font-size="52" font-weight="400">5 pts</text>');
  });

  it("accepts an embedded logo source for rasterized sharing", () => {
    const card = puzzleResultCardSvg({
      game: "backword", gameName: "Backword", issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 1, totalGamesSolved: 7,
      ratingTier: "Linguist", ratingPoints: 68, ratingMaxPoints: 140,
      primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, url: "https://www.playbackword.com/backword/2026-09-16", caption: ""
    }, "data:image/png;base64,LOGO");

    expect(card).toContain('<image href="data:image/png;base64,LOGO"');
  });

  it("uses the matching iOS share-card palette for every game", () => {
    const base = {
      issueNumber: 7, date: "2026-09-16", outcome: "SOLVED", score: 5, streak: 1, totalGamesSolved: 7,
      ratingTier: "Linguist", ratingPoints: 68, ratingMaxPoints: 140,
      primaryStat: { label: "ATTEMPTS", value: "1 / 5" }, url: "https://www.playbackword.com/backword/2026-09-16", caption: ""
    };

    const backwordCard = puzzleResultCardSvg({ ...base, game: "backword", gameName: "Backword" });
    expect(backwordCard).toContain('fill="#7888d7"');
    expect(backwordCard).toContain('fill="#999999"');
    expect(backwordCard).toContain('fill="#2a2a2a" font-family="Outfit, sans-serif" font-size="55"');
    const dailyCard = puzzleResultCardSvg({ ...base, game: "daily_crossword", gameName: "Quick Crossword" });
    expect(dailyCard).toContain('fill="#43668f"');
    expect(dailyCard).toContain('fill="#e0ddd6" font-family="Outfit, sans-serif" font-size="55"');
    const proCard = puzzleResultCardSvg({ ...base, game: "weekly_crossword", gameName: "Pro Crossword" });
    expect(proCard).toContain('fill="#1e1d1b"');
    expect(proCard).toContain('rx="48" fill="none" stroke="url(#pro-border)"');
    expect(proCard).toContain('fill="#ebb838" font-family="Outfit, sans-serif" font-size="55"');
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

    expect(daily).toMatchObject({ game: "daily_crossword", gameName: "Quick Crossword", score: 5, totalGamesSolved: 1, primaryStat: { label: "SOLVE TIME", value: "00:05:02" }, timeStat: null });
    expect(weekly).toMatchObject({ game: "weekly_crossword", gameName: "Pro Crossword", issueNumber: 3, totalGamesSolved: 1, primaryStat: { label: "SOLVE TIME", value: "00:05:02" }, timeStat: null });
    expect(`${daily.caption}${puzzleResultCardSvg(daily)}`).not.toContain("puzzle-id");
    expect(`${daily.caption}${puzzleResultCardSvg(daily)}`).not.toContain("Test clue");
  });

  it("links each game type to its exact issue with attribution", () => {
    expect(shareUrl("daily_crossword", "2026-09-16", "https://playbackword.com")).toContain("/crossword/2026-09-16?");
    expect(shareUrl("weekly_crossword", "2026-09-14", "https://playbackword.com")).toContain("/weekly-crossword/2026-09-14?");
  });

  it("formats Backword completion times with an AM or PM marker", () => {
    expect(formatCompletionTime("2026-09-16T14:24:00.000Z")).toMatch(/^\d{1,2}:\d{2} (AM|PM)$/);
  });
});
