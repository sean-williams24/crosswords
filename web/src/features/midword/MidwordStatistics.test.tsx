import { render, screen, within } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { localDateOffset, localDateString } from "../backword/date";
import { emptyProgress, type MidwordStats } from "./engine";
import { MidwordDialog } from "./MidwordDialog";

const today = localDateString();
const stats: MidwordStats = {
  currentStreak: 1, bestStreak: 3, totalSolved: 4, rollingScore: 5,
  timeDistribution: [1, 2, 0, 1, 0],
  rows: [
    { date: today, outcome: "solved", score: 5, elapsedSeconds: 12 },
    { date: localDateOffset(today, -1), outcome: "unplayed", score: 0, elapsedSeconds: null }
  ]
};

function renderStats(values = stats) {
  return render(<MemoryRouter><MidwordDialog kind="stats" now={new Date()}
    onClose={vi.fn()} progress={emptyProgress(today)} puzzle={null}
    shareResult={null} stats={values} /></MemoryRouter>);
}

describe("Midword statistics native appearance", () => {
  it("shows the native summary and Date / Score / Time history", () => {
    renderStats();
    const summary = screen.getByLabelText("Midword statistics summary");
    expect(within(summary).getByText("Current streak")).toContainHTML("<br>");
    expect(within(summary).getByText("Total solved")).toContainHTML("<br>");
    expect(within(summary).getByText("Best streak")).toContainHTML("<br>");
    const table = screen.getByRole("table");
    expect(within(table).getAllByRole("columnheader").map((cell) => cell.textContent))
      .toEqual(["Date", "Score", "Time"]);
    const [, solved, unplayed] = within(table).getAllByRole("row");
    expect(solved.querySelector("time")).toHaveClass("is-today");
    expect(within(solved).getByText("TODAY")).toBeInTheDocument();
    expect(within(solved).getByText("SOLVED")).toBeInTheDocument();
    expect(within(solved).getAllByRole("cell").slice(1).map((cell) => cell.textContent)).toEqual(["5", "00:00:12"]);
    expect(within(solved).getByText("5")).toHaveClass("is-earned");
    expect(within(unplayed).getByText("0")).not.toHaveClass("is-earned");
    expect(within(unplayed).getByText("–")).toHaveClass("is-unplayed");
    expect(screen.getByLabelText("Under 60 seconds: 2 solves").querySelector("i")).toHaveStyle({ width: "100%" });
    expect(screen.getByLabelText("Under 120 seconds: 0 solves").querySelector("i")).toHaveStyle({ width: "0%" });
  });

  it("keeps zero statistics and empty distribution tracks visible", () => {
    renderStats({ ...stats, currentStreak: 0, totalSolved: 0, bestStreak: 0,
      rollingScore: 0, timeDistribution: [0, 0, 0, 0, 0], rows: [] });
    expect(screen.getByText("0/70")).toBeInTheDocument();
    const bar = screen.getByLabelText("0 of 70 Midword points");
    expect(bar.querySelector("i")).toHaveStyle({ left: "0%" });
    for (let guesses = 1; guesses <= 5; guesses++) {
      expect(screen.getByLabelText(`${["Under 30 seconds", "Under 60 seconds", "Under 120 seconds", "Under 180 seconds", "180 seconds or more"][guesses - 1]}: 0 solves`).querySelector("i"))
        .toHaveStyle({ width: "0%" });
    }
  });

  it("uses native Outfit weights and sizes rather than browser defaults", () => {
    const style = document.createElement("style");
    style.textContent = readFileSync("src/features/midword/midword.css", "utf8");
    document.head.append(style);
    try {
      renderStats();
      const summary = screen.getByLabelText("Midword statistics summary");
      const value = getComputedStyle(summary.querySelector("strong")!);
      const label = getComputedStyle(summary.querySelector("small")!);
      expect(value.fontWeight).toBe("700");
      expect(value.fontSize).toBe("24px");
      expect(label.fontWeight).toBe("900");
      expect(label.fontSize).toBe("10px");
      expect(label.letterSpacing).toBe("1px");
      const heading = getComputedStyle(screen.getByRole("heading", { name: "Solve time distribution" }));
      expect(heading.fontWeight).toBe("900");
      expect(heading.letterSpacing).toBe("2px");
      expect(getComputedStyle(screen.getByText("5/70")).fontWeight).toBe("900");
      expect(getComputedStyle(screen.getByRole("columnheader", { name: "Score" })).fontWeight).toBe("900");
      expect(getComputedStyle(screen.getByRole("heading", { name: "Midword Stats" })).fontFamily).toBe("system-ui, sans-serif");
      expect(style.textContent).toContain('--midword-font: "Outfit", ui-sans-serif, system-ui, sans-serif;');
      expect(style.textContent).toMatch(/\.midword-summary, \.midword-rating-section, \.midword-distribution, \.midword-history\s*\{[^}]*font-family: var\(--midword-font\)/);
      const fonts = readFileSync("src/styles.css", "utf8");
      for (const [name, weight] of [["Regular", 400], ["Bold", 700], ["Black", 900]]) {
        expect(fonts).toMatch(new RegExp(`@font-face\\s*\\{[^}]*Outfit-${name}\\.ttf[^}]*font-weight: ${weight};`));
      }
    } finally { style.remove(); }
  });

  it("uses native semantic accent and opacity treatments in both appearances", () => {
    const css = readFileSync("src/features/midword/midword.css", "utf8");
    const rule = (selector: string) => css.slice(css.indexOf(`${selector} {`)).split("}")[0];
    expect(rule(".midword-summary small")).toContain("color: var(--midword-accent)");
    expect(rule(".midword-summary strong")).toContain("color: var(--midword-text)");
    expect(rule(".midword-rating-section > strong")).toContain("color: var(--midword-accent)");
    expect(rule(".midword-history th")).toContain("color: var(--midword-accent)");
    expect(rule(".midword-score-chip")).toContain("var(--midword-accent) 65%, transparent");
    expect(rule(".midword-score-chip")).toContain("var(--midword-accent) 15%, transparent");
    expect(rule(".midword-score-chip.is-earned")).toContain("color: var(--midword-on-accent)");
    expect(rule(".midword-rating")).toContain("var(--midword-text) 12%");
    expect(css).toContain("--midword-surface: color-mix(in srgb, var(--midword-text) 8%, var(--midword-background));");
    expect(css).toMatch(/html\[data-theme="light"\]\s*\{[^}]*--midword-background: #f5f2eb;[^}]*--midword-text: #1a1a1a;/);
    const nativeAccent = JSON.parse(readFileSync("../Backword/Resources/Assets.xcassets/MidwordAccent.colorset/Contents.json", "utf8"));
    const { red, green, blue } = nativeAccent.colors[0].color.components;
    const hex = `#${[red, green, blue].map((value: string) => value.slice(2).toLowerCase()).join("")}`;
    expect(css).toContain(`--midword-accent: ${hex};`);
    expect(css).toContain("--midword-accent: color(display-p3 0.412 0.612 0.424);");
  });
});
