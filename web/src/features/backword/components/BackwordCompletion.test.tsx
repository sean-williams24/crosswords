import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { BackwordCompletion } from "./BackwordCompletion";

vi.mock("../../share/PuzzleResultShare", () => ({
  PuzzleResultShare: () => null
}));

vi.mock("./BackwordStats", () => ({
  StatsContent: () => null
}));

describe("BackwordCompletion", () => {
  it("uses encouraging wording after an unsuccessful game", () => {
    render(
      <MemoryRouter>
        <BackwordCompletion
          progress={{
            schemaVersion: 1,
            date: "2026-09-23",
            guesses: ["PLANET", "STREAM", "CANDLE", "MARKET", "FLOWER"],
            completedAt: "2026-09-23T10:00:00.000Z",
            outcome: "failed"
          }}
          stats={{
            gamesPlayed: 1,
            gamesWon: 0,
            currentStreak: 0,
            longestStreak: 0,
            winRate: 0,
            guessDistribution: {},
            rollingScore: 0,
            history: []
          }}
          word={{
            id: "today",
            puzzleNumber: 1,
            date: "2026-09-23",
            word: "CASTLE",
            clue: "Fortress"
          }}
          rating={{
            days: [],
            maxPoints: 140,
            totalPoints: 0,
            fraction: 0,
            tier: "Novice"
          }}
          onClose={vi.fn()}
        />
      </MemoryRouter>
    );

    expect(screen.getByRole("dialog", { name: "Not this time" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Not this time" })).toHaveClass("is-failed");
  });
});
