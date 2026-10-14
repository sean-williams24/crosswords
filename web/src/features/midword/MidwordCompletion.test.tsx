import { fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { readFileSync } from "node:fs";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { localDateOffset, localDateString } from "../backword/date";
import { emptyProgress, type MidwordProgress, type MidwordPuzzle, type MidwordStats } from "./engine";
import { MidwordDialog } from "./MidwordDialog";

const today = localDateString();
const puzzle: MidwordPuzzle = {
  id: "midword-1", date: today, puzzleNumber: 1, firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: []
};
const progress: MidwordProgress = {
  ...emptyProgress(today), outcome: "failed", guesses: ["PAGE", "WORD", "READ", "LINE", "BOOK"]
};
const stats: MidwordStats = {
  currentStreak: 0, bestStreak: 0, totalSolved: 0, rollingScore: 0, guessDistribution: [0, 0, 0, 0, 0],
  rows: Array.from({ length: 14 }, (_, index) => ({
    date: localDateOffset(today, -index), outcome: "unplayed", score: 0, guessCount: null
  }))
};

function renderCompletion(value = progress) {
  const onClose = vi.fn();
  render(<MemoryRouter initialEntries={["/midword"]}><Routes>
    <Route path="/midword" element={<MidwordDialog kind="completion" now={new Date(`${today}T23:30:00`)}
      onClose={onClose} progress={value} puzzle={puzzle} shareResult={null} stats={stats} />} />
    <Route path="/" element={<p>Home destination</p>} />
  </Routes></MemoryRouter>);
  return onClose;
}

describe("Midword completion native appearance", () => {
  it("keeps the title, failed answer and all statistics together in the scrolling content", () => {
    renderCompletion();
    const dialog = screen.getByRole("dialog", { name: "Finished" });
    const heading = within(dialog).getByRole("heading", { name: "Finished" });
    const scroll = heading.closest(".midword-completion-scroll")!;
    expect(scroll).toContainElement(screen.getByText("PUZZLE #1"));
    expect(scroll).toContainElement(screen.getByText("The answer was…"));
    expect(scroll).toContainElement(screen.getByText("BANKNOTE · NOTEBOOK"));
    expect(scroll).toContainElement(screen.getByText("00:30:00"));
    expect(screen.getByRole("group", { name: "NOTE" })).toHaveClass("is-incorrect");
    expect(screen.getByRole("group", { name: "NOTE" })).not.toHaveClass("is-correct");
    expect(scroll).toContainElement(screen.getByLabelText("Midword completion statistics"));
    expect(scroll).toContainElement(screen.getByRole("table"));
    expect(within(screen.getByRole("table")).getAllByRole("row")).toHaveLength(15);
    expect(dialog.querySelector(".bw-modal-header")).not.toBeInTheDocument();
  });

  it("shows solved styling, singular guess copy and earned points for a win", () => {
    renderCompletion({ ...progress, outcome: "won", guesses: ["NOTE"], releaseDateScore: 5 });
    expect(screen.getByRole("heading", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByText("In 1 guess")).toBeInTheDocument();
    expect(screen.getByRole("group", { name: "NOTE" })).toHaveClass("is-correct");
    expect(screen.getByRole("group", { name: "NOTE" })).not.toHaveClass("is-incorrect");
    expect(screen.getByLabelText("Midword completion statistics")).toHaveTextContent("1/5Guesses5/5Points");
  });

  it("uses plural guess copy for multiple guesses", () => {
    renderCompletion({ ...progress, outcome: "won", guesses: ["PAGE", "NOTE"], releaseDateScore: 4 });
    expect(screen.getByText("In 2 guesses")).toBeInTheDocument();
  });

  it("keeps a single HOME action outside the scroll area and navigates home", async () => {
    const user = userEvent.setup();
    renderCompletion();
    const home = screen.getByRole("button", { name: "HOME" });
    expect(screen.getAllByRole("button")).toEqual([home]);
    expect(home).toHaveFocus();
    expect(home.closest(".midword-completion-scroll")).toBeNull();
    await user.click(home);
    expect(screen.getByText("Home destination")).toBeInTheDocument();
  });

  it("retains Escape dismissal without a toolbar close button", () => {
    const onClose = renderCompletion();
    fireEvent.keyDown(window, { key: "Escape" });
    expect(onClose).toHaveBeenCalledOnce();
  });

  it("matches native heading and countdown weights, spacing and full-width history", () => {
    const css = readFileSync("src/features/midword/midword.css", "utf8");
    const style = document.createElement("style");
    style.textContent = css;
    document.head.append(style);
    try {
      renderCompletion();
      const heading = getComputedStyle(screen.getByRole("heading", { name: "Finished" }));
      expect(heading.fontSize).toBe("40px");
      expect(heading.fontWeight).toBe("700");
      const issue = getComputedStyle(screen.getByText("PUZZLE #1"));
      expect(issue.fontSize).toBe("14px");
      expect(issue.fontWeight).toBe("900");
      expect(issue.letterSpacing).toBe("3px");
      const countdown = getComputedStyle(screen.getByText("NEXT MIDWORD IN"));
      expect(countdown.fontWeight).toBe("900");
      expect(countdown.letterSpacing).toBe("2px");
      expect(getComputedStyle(screen.getByText("00:30:00")).fontSize).toBe("24px");
      expect(getComputedStyle(screen.getByRole("heading", { name: "Finished" }).closest(".midword-completion-scroll")!).padding).toBe("32px 0px 28px");
      expect(getComputedStyle(screen.getByRole("button", { name: "HOME" }).parentElement!).flexShrink).toBe("0");
      const rule = (selector: string) => css.slice(css.indexOf(`${selector} {`)).split("}")[0];
      for (const outcome of ["is-correct", "is-incorrect"]) {
        expect(rule(`.midword-completion-answer .${outcome} > span`)).toContain("color: var(--midword-text)");
        expect(rule(`.midword-completion-answer .${outcome} > span`)).toContain("15%, var(--midword-background)");
      }
      expect(rule(".midword-completion-header > strong")).toContain("color: var(--midword-accent)");
      expect(rule(".midword-countdown span")).toContain("color: var(--midword-accent)");
      expect(rule(".midword-completion-actions button")).toContain("background: transparent");
      expect(css).toContain(".midword-completion-statistics > .midword-summary, .midword-completion-statistics > .midword-distribution { margin-inline: 20px; }");
      expect(rule(".midword-completion-statistics")).toContain("gap: 28px");
      expect(css).toContain(".midword-completion-backdrop { padding: 30px; align-items: center; }");
      expect(css).toContain(".midword-page *, .midword-dialog * { animation: none !important; transition: none !important; }");
    } finally { style.remove(); }
  });
});
