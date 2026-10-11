import { render, screen, within } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { emptyProgress, type MidwordPuzzle } from "./engine";
import { MidwordBoard } from "./MidwordBoard";

const puzzle: MidwordPuzzle = {
  id: "midword-test", date: "2026-10-11", puzzleNumber: 11,
  firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: []
};

describe("Midword previous guess appearance", () => {
  it("uses thin borders for correct and incorrect history without changing the active cells", () => {
    const style = document.createElement("style");
    // jsdom cannot resolve custom properties inside the base border shorthand.
    style.textContent = readFileSync("src/features/midword/midword.css", "utf8")
      .replaceAll("var(--midword-border)", "#525252");
    document.head.append(style);
    try {
      render(<MidwordBoard input="" message="" puzzle={puzzle}
        progress={{ ...emptyProgress(puzzle.date), guesses: ["PAGE", "NOTE"] }} />);
      const history = screen.getByRole("region", { name: "Previous guesses" });
      const incorrect = within(history).getByRole("group", { name: "PAGE, incorrect" });
      const correct = within(history).getByRole("group", { name: "NOTE, correct" });
      expect(incorrect).toHaveClass("is-incorrect");
      expect(correct).toHaveClass("is-correct");
      for (const row of [incorrect, correct]) {
        for (const cell of row.children) {
          expect(getComputedStyle(cell).borderTopWidth).toBe("1px");
        }
      }
      const input = screen.getByRole("group", { name: "Middle word, 0 of 4 letters entered" });
      expect(getComputedStyle(input.children[0]).borderTopWidth).toBe("1.5px");
    } finally { style.remove(); }
  });

  it("uses white dark-mode text and subtle outcome borders within guess history", () => {
    const css = readFileSync("src/features/midword/midword.css", "utf8");
    expect(css).toContain("--midword-text: #ffffff;");
    expect(css).toMatch(/\.midword-guesses \.midword-letter-row > span\s*\{[^}]*color: var\(--midword-text\);/);
    expect(css).toMatch(/\.midword-guesses \.midword-letter-row\.is-incorrect > span\s*\{[^}]*border-color: color-mix\(in srgb, var\(--bw-failed\) 45%, transparent\);/);
    expect(css).toMatch(/\.midword-guesses \.midword-letter-row\.is-correct > span\s*\{[^}]*border-color: color-mix\(in srgb, var\(--midword-accent\) 45%, transparent\);/);
  });
});
