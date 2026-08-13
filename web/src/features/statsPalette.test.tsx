import { render } from "@testing-library/react";
import { BackwordStats } from "./backword/components/BackwordStats";
import { CrosswordStats } from "./crossword/components/CrosswordStats";

const baseBackwordStats = {
  gamesPlayed: 1,
  gamesWon: 1,
  currentStreak: 1,
  longestStreak: 1,
  winRate: 100,
  guessDistribution: { 1: 1 },
  rollingScore: 5,
  history: [
    { date: "2026-08-12", isToday: true, score: 5, guessCount: 1, outcome: "solved" as const },
    { date: "2026-08-11", isToday: false, score: 3, guessCount: null, outcome: "unplayed" as const },
    { date: "2026-08-10", isToday: false, score: 0, guessCount: null, outcome: "unplayed" as const }
  ]
};

const baseCrosswordStats = {
  totalSolved: 1,
  currentStreak: 1,
  longestStreak: 1,
  averageSolveTimeSeconds: 60,
  rollingScore: 5,
  history: [
    { date: "2026-08-12", isToday: true, score: 5, solveTimeSeconds: 60, outcome: "solved" as const },
    { date: "2026-08-11", isToday: false, score: 3, solveTimeSeconds: null, outcome: "unplayed" as const },
    { date: "2026-08-10", isToday: false, score: 0, solveTimeSeconds: null, outcome: "unplayed" as const }
  ]
};

describe("iOS stats palette", () => {
  it("uses the iOS solid score-chip tones for Backword and crosswords", () => {
    const backword = render(<BackwordStats onClose={() => undefined} stats={baseBackwordStats} />);
    expect(backword.container.querySelectorAll(".bw-score-chip")[0]).toHaveClass("is-perfect");
    expect(backword.container.querySelectorAll(".bw-score-chip")[1]).not.toHaveClass("is-perfect", "is-zero");
    expect(backword.container.querySelectorAll(".bw-score-chip")[2]).toHaveClass("is-zero");

    const crossword = render(<CrosswordStats onClose={() => undefined} stats={baseCrosswordStats} />);
    expect(crossword.container.querySelectorAll(".bw-score-chip")[0]).toHaveClass("is-perfect");
    expect(crossword.container.querySelectorAll(".bw-score-chip")[2]).toHaveClass("is-zero");
  });

  it("shows today above a solved status, using separate iOS semantic tones", () => {
    const backword = render(<BackwordStats onClose={() => undefined} stats={baseBackwordStats} />);
    const backwordToday = backword.container.querySelector(".bw-history-row span");
    expect(backwordToday).toHaveTextContent("TODAYSOLVED");
    expect(backwordToday?.querySelector(".is-today")).toHaveTextContent("TODAY");
    expect(backwordToday?.querySelector(".is-solved")).toHaveTextContent("SOLVED");

    const crossword = render(<CrosswordStats onClose={() => undefined} stats={baseCrosswordStats} />);
    const crosswordToday = crossword.container.querySelector(".bw-history-row span");
    expect(crosswordToday).toHaveTextContent("TODAYSOLVED");
    expect(crosswordToday?.querySelector(".is-today")).toHaveTextContent("TODAY");
    expect(crosswordToday?.querySelector(".is-solved")).toHaveTextContent("SOLVED");
  });

  it("clips a partial rating fill from the whole 70-point gradient", () => {
    const stats = { ...baseBackwordStats, rollingScore: 27 };
    const view = render(<BackwordStats onClose={() => undefined} stats={stats} />);
    const fill = view.container.querySelector<HTMLElement>(".bw-rating-fill");
    expect(fill).toHaveStyle({ clipPath: `inset(0 ${100 - (27 / 70) * 100}% 0 0)` });
  });

  it("adds the animated iOS rating marker to stats bars only", () => {
    const stats = { ...baseBackwordStats, rollingScore: 27 };
    const view = render(<BackwordStats onClose={() => undefined} stats={stats} />);
    const marker = view.container.querySelector<HTMLElement>(".bw-rating-marker");
    expect(marker).toBeInTheDocument();
    expect(marker).toHaveStyle({ left: `${(27 / 70) * 100}%` });
  });

});
