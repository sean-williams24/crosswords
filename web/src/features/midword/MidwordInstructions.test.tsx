import { fireEvent, render, screen, within } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { AnagramInstructions } from "../anagram/AnagramInstructions";
import { emptyProgress, midwordStats } from "./engine";
import { MidwordDialog } from "./MidwordDialog";

function renderInstructions(onClose = vi.fn()) {
  return render(<MemoryRouter><MidwordDialog kind="instructions" now={new Date()}
    onClose={onClose} progress={emptyProgress("2026-10-11")} puzzle={null}
    shareResult={null} stats={midwordStats([])} /></MemoryRouter>);
}

describe("Midword info sheet", () => {
  it("uses Anagram's shared instruction sections and icon rows with native Midword guidance", () => {
    renderInstructions();
    const dialog = screen.getByRole("dialog", { name: "How to Play" });
    expect(dialog.parentElement).toHaveClass("midword-instructions-backdrop");
    for (const name of ["Find the connection", "Example", "Scoring"]) {
      const heading = within(dialog).getByRole("heading", { name });
      expect(heading.parentElement).toHaveClass("game-instructions__section");
      expect(heading.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
    }
    expect(dialog.querySelectorAll(".game-instructions__row")).toHaveLength(4);
    expect(within(dialog).getByText("You have five attempts.")).toBeInTheDocument();
    expect(within(dialog).getByText(/Invalid or repeated words do not use an attempt/)).toBeInTheDocument();
    expect(within(dialog).getByText("BANK + NOTE = BANKNOTE")).toBeInTheDocument();
    expect(within(dialog).getByText("NOTE + BOOK = NOTEBOOK")).toBeInTheDocument();
    expect(within(dialog).getByText("First guess", { selector: "dt" })).toBeInTheDocument();
    expect(within(dialog).getByText("1 pt")).toBeInTheDocument();
    expect(within(dialog).getByText("0 pts")).toBeInTheDocument();
    expect(within(dialog).getByText(/release day adds points to your rolling 14-day rating/)).toBeInTheDocument();
  });

  it("keeps the close control focused and dismisses through the button and Escape", () => {
    const onClose = vi.fn();
    renderInstructions(onClose);
    const close = screen.getByRole("button", { name: "Close How to Play" });
    expect(close).toHaveFocus();
    fireEvent.click(close);
    expect(onClose).toHaveBeenCalledOnce();
    fireEvent.keyDown(window, { key: "Escape" });
    expect(onClose).toHaveBeenCalledTimes(2);
  });

  it("matches Anagram's sentence-case headings, spacing, icons, and scoring typography", () => {
    const style = document.createElement("style");
    style.textContent = readFileSync("src/styles.css", "utf8") + "\n"
      + readFileSync("src/features/midword/midword.css", "utf8");
    document.head.append(style);
    try {
      renderInstructions();
      const anagram = render(<div className="anagram-dialog anagram-dialog--instructions"><AnagramInstructions /></div>);
      const dialog = screen.getByRole("dialog", { name: "How to Play" });
      const midwordHeading = within(dialog).getByRole("heading", { name: "Find the connection" });
      const anagramHeading = within(anagram.container).getByRole("heading", { name: "Gameplay" });
      for (const property of ["fontSize", "fontWeight", "letterSpacing", "textTransform", "gap", "marginBottom"] as const) {
        expect(getComputedStyle(midwordHeading)[property]).toBe(getComputedStyle(anagramHeading)[property]);
      }
      expect(getComputedStyle(midwordHeading).fontSize).toBe("15px");
      expect(getComputedStyle(midwordHeading).textTransform).toBe("none");
      expect(getComputedStyle(midwordHeading.querySelector("svg")!).width).toBe("22px");
      const paragraph = within(dialog).getByText("You have five attempts.");
      expect(getComputedStyle(paragraph).margin).toBe("0px");
      expect(getComputedStyle(paragraph).lineHeight).toBe("1.45");
      expect(getComputedStyle(within(dialog).getByText("5 pts")).fontWeight).toBe("700");
      expect(getComputedStyle(within(dialog).getByRole("heading", { name: "How to Play" })).fontWeight).toBe("400");
      expect(getComputedStyle(dialog.querySelector(".midword-dialog-scroll")!).overflowY).toBe("auto");
      expect(getComputedStyle(screen.getByRole("button", { name: "Close How to Play" })).width).toBe("50px");
    } finally { style.remove(); }
  });

  it("uses green accent tokens and the same mobile/desktop sheet geometry as Anagram", () => {
    const css = readFileSync("src/features/midword/midword.css", "utf8");
    expect(css).toMatch(/\.midword-dialog--instructions\s*\{[^}]*--instructions-accent: var\(--midword-accent\);[^}]*width: min\(100%, 640px\);[^}]*max-height: 91svh;/);
    expect(css).toMatch(/\.midword-dialog--instructions \.bw-modal-header\s*\{[^}]*min-height: 86px;/);
    expect(css).toMatch(/\.midword-dialog--instructions \.bw-modal-close\s*\{[^}]*background: var\(--midword-accent\);/);
    expect(css).toMatch(/@media \(min-width: 700px\)\s*\{\s*\.midword-instructions-backdrop\s*\{[^}]*padding: 30px; align-items: center;/);
    expect(css).toContain(".midword-dialog--instructions { border-bottom: 1px solid var(--app-border); border-radius: 22px;");
  });
});
