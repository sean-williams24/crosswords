import {
  backwordScore,
  buildGuess,
  connectedSuffixIndices,
  deriveStats,
  emptyProgress,
  matchingSuffixLength,
  revealedIndices,
  submitGuess
} from "./engine";
import type { BackwordProgress } from "./types";

function progressWithGuesses(
  guesses: string[],
  outcome: BackwordProgress["outcome"] = "inProgress"
): BackwordProgress {
  return {
    ...emptyProgress("2026-08-03"),
    guesses,
    outcome,
    completedAt: outcome === "inProgress" ? null : new Date(2026, 7, 3, 12).toISOString()
  };
}

describe("Backword engine", () => {
  it("starts with only the last letter revealed", () => {
    expect([...revealedIndices(emptyProgress("2026-08-03"), "CASTLE", "normal")]).toEqual([5]);
  });

  it("uses the Normal automatic reveal schedule", () => {
    expect([...revealedIndices(progressWithGuesses(["XXXXXE"]), "CASTLE", "normal")]).toEqual([5]);
    expect([...revealedIndices(progressWithGuesses(["XXXXXE", "BXXXXE"]), "CASTLE", "normal")]).toEqual([4, 5]);
    expect([...revealedIndices(progressWithGuesses(["XXXXXE", "BXXXXE", "DXXXLE"]), "CASTLE", "normal")]).toEqual([3, 4, 5]);
    expect([...revealedIndices(progressWithGuesses(["XXXXXE", "BXXXXE", "DXXXLE", "PXXTLE"]), "CASTLE", "normal")]).toEqual([3, 4, 5]);
  });

  it("reveals another letter after every Easy mode miss", () => {
    expect([...revealedIndices(progressWithGuesses(["XXXXXE"]), "CASTLE", "easy")]).toEqual([4, 5]);
    expect([...revealedIndices(progressWithGuesses(["XXXXXE", "BXXXXE", "DXXXLE", "PXXTLE"]), "CASTLE", "easy")]).toEqual([1, 2, 3, 4, 5]);
  });

  it("reveals a longer connected suffix immediately and ignores disconnected letters", () => {
    expect(matchingSuffixLength("DREESY", "CHEESY")).toBe(4);
    expect([...connectedSuffixIndices("CXXXXE", "CASTLE")]).toEqual([5]);
    expect([...revealedIndices(progressWithGuesses(["DREESY"]), "CHEESY", "normal")]).toEqual([2, 3, 4, 5]);
  });

  it("assembles a full guess from only the hidden input cells", () => {
    expect(buildGuess("CASTL", "CASTLE", new Set([5]))).toBe("CASTLE");
    expect(buildGuess("CAS", "CASTLE", new Set([3, 4, 5]))).toBe("CASTLE");
    expect(buildGuess("CA", "CASTLE", new Set([3, 4, 5]))).toBeNull();
  });

  it("wins, fails after five guesses, and scores only on the release date", () => {
    const win = submitGuess(emptyProgress("2026-08-03"), "CASTLE", "CASTL", "normal", new Date(2026, 7, 3, 12));
    expect(win?.outcome).toBe("won");
    expect(win && backwordScore(win)).toBe(5);

    let failure = emptyProgress("2026-08-03");
    for (let guess = 0; guess < 5; guess += 1) {
      failure = submitGuess(failure, "CASTLE", "XXXXX".slice(0, 6 - revealedIndices(failure, "CASTLE", "normal").size), "normal", new Date(2026, 7, 3, 12))!;
    }
    expect(failure.outcome).toBe("failed");
    expect(backwordScore(failure)).toBe(0);

    const lateWin = { ...win!, completedAt: new Date(2026, 7, 4, 0, 1).toISOString() };
    expect(backwordScore(lateWin)).toBe(0);
  });

  it("derives aggregate stats and every release in the rolling 14-day history", () => {
    const todayWin = progressWithGuesses(["XXXXXE", "CASTLE"], "won");
    const yesterdayWin = {
      ...progressWithGuesses(["CASTLE"], "won"),
      date: "2026-08-02",
      completedAt: new Date(2026, 7, 2, 12).toISOString()
    };
    const failed = {
      ...progressWithGuesses(["A", "B", "C", "D", "E"], "failed"),
      date: "2026-08-01",
      completedAt: new Date(2026, 7, 1, 12).toISOString()
    };
    const stats = deriveStats([todayWin, yesterdayWin, failed], new Date(2026, 7, 3, 12));

    expect(stats.gamesPlayed).toBe(3);
    expect(stats.gamesWon).toBe(2);
    expect(stats.currentStreak).toBe(2);
    expect(stats.longestStreak).toBe(2);
    expect(stats.winRate).toBe(66);
    expect(stats.guessDistribution[1]).toBe(1);
    expect(stats.guessDistribution[2]).toBe(1);
    expect(stats.rollingScore).toBe(9);
    expect(stats.history).toHaveLength(14);
    expect(stats.history[0]).toMatchObject({ date: "2026-08-03", outcome: "solved", score: 4 });
    expect(stats.history[3]).toMatchObject({ date: "2026-07-31", outcome: "unplayed" });
  });

  it("excludes archive progress from the 14-day stats history", () => {
    const archiveProgress = {
      ...progressWithGuesses(["A", "B"], "inProgress"),
      date: "2026-08-01"
    };

    const stats = deriveStats([archiveProgress], new Date(2026, 7, 12, 12));
    const archiveRow = stats.history.find((row) => row.date === "2026-08-01");

    expect(archiveRow).toMatchObject({ score: 0, guessCount: null, outcome: "unplayed" });
  });

  it("breaks the current streak after today's failed game", () => {
    const failedToday = progressWithGuesses(["A", "B", "C", "D", "E"], "failed");
    const wonYesterday = {
      ...progressWithGuesses(["CASTLE"], "won"),
      date: "2026-08-02",
      completedAt: new Date(2026, 7, 2, 12).toISOString()
    };
    expect(deriveStats([failedToday, wonYesterday], new Date(2026, 7, 3, 12)).currentStreak).toBe(0);
  });
});
