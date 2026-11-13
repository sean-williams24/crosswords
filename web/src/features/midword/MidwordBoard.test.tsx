import { render, screen, within } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { emptyProgress, type MidwordPuzzle } from "./engine";
import { MidwordBoard } from "./MidwordBoard";

const puzzle: MidwordPuzzle = {
  id: "midword-test", date: "2026-10-11", puzzleNumber: 11,
  firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: []
};

describe("Midword prompt alignment", () => {
  it("shares the explainer's responsive width and aligns the bottom prompt to the trailing edge", () => {
    const style = document.createElement("style");
    style.textContent = readFileSync("src/features/midword/midword.css", "utf8");
    document.head.append(style);
    try {
      render(<MidwordBoard input="" message="" puzzle={puzzle} progress={emptyProgress(puzzle.date)} />);
      const explainer = screen.getByText("Find the link that ends the top word and starts the bottom word to make 2 new words");
      const board = screen.getByRole("region", { name: "Midword board" });
      expect(getComputedStyle(explainer).width).toBe("min(100%, 520px)");
      expect(getComputedStyle(board).width).toBe(getComputedStyle(explainer).width);
      expect(getComputedStyle(within(board).getByText("BOOK")).textAlign).toBe("right");
    } finally { style.remove(); }
  });
});

describe("Midword hidden guess history", () => {
  it("keeps the input visible without an attempt counter or previous guesses", () => {
    render(<MidwordBoard input="" message="" puzzle={puzzle} progress={{ ...emptyProgress(puzzle.date), guesses: ["PAGE"] }} />);
    expect(screen.queryByRole("region", { name: "Previous guesses" })).not.toBeInTheDocument();
    expect(screen.queryByLabelText(/attempts remaining/)).not.toBeInTheDocument();
    expect(screen.getByRole("group", { name: "Middle word, 0 of 4 letters entered" })).toBeInTheDocument();
  });
});
