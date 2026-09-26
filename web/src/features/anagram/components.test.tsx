import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import fixtures from "../../../../docs/fixtures/anagram-v1.json";
import { AnagramBoard, AnagramDialog } from "./components";
import { mapAnagramRow } from "./repository";
import { placeTile, revealHint, startProgress } from "./engine";

const puzzle = mapAnagramRow(fixtures.puzzles[0]);
const now = new Date("2026-10-01T10:00:00Z");

describe("Anagram accessible controls", () => {
  it("exposes duplicate tile identities and disables unavailable actions", () => {
    const progress = startProgress(puzzle, now);
    const onPlace = vi.fn();
    render(<AnagramBoard now={now} onGiveUp={vi.fn()} onHint={vi.fn()} onPlace={onPlace} onRestart={vi.fn()} onShuffle={vi.fn()} onUndo={vi.fn()} progress={progress} puzzle={puzzle} />);
    expect(screen.getByRole("button", { name: "Undo" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Restart" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "Letter R, tray position 1" }));
    expect(onPlace).toHaveBeenCalledWith(0);
  });

  it("keeps a revealed letter labelled and blocks a second hint", () => {
    const progress = revealHint(placeTile(startProgress(puzzle, now), puzzle, 0, now), puzzle, now);
    render(<AnagramBoard now={now} onGiveUp={vi.fn()} onHint={vi.fn()} onPlace={vi.fn()} onRestart={vi.fn()} onShuffle={vi.fn()} onUndo={vi.fn()} progress={progress} puzzle={puzzle} />);
    expect(screen.getByLabelText("Cell 1: T, locked hint")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Hint" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Letter R, tray position 1" })).toBeEnabled();
  });

  it("matches the iOS active-game information hierarchy", () => {
    const progress = startProgress(puzzle, now);
    const { container } = render(<AnagramBoard now={now} onGiveUp={vi.fn()} onHint={vi.fn()} onPlace={vi.fn()} onRestart={vi.fn()} onShuffle={vi.fn()} onUndo={vi.fn()} progress={progress} puzzle={puzzle} />);

    expect(screen.getByText("YOUR ANSWER")).toBeInTheDocument();
    expect(screen.queryByText("TAP LETTERS IN ORDER")).not.toBeInTheDocument();
    expect(screen.queryByText("POINTS")).not.toBeInTheDocument();
    expect(container.querySelector(".anagram-gameplay-dock .anagram-tray")).not.toBeNull();
    expect(screen.getByLabelText("Scrambled letter tray").children).toHaveLength(2);
    expect(screen.getByLabelText("Answer cells")).toHaveClass(`anagram-answer--${puzzle.answer.length}`);
    expect(screen.getByLabelText("Answer cells").children).toHaveLength(puzzle.answer.length);
  });

  it("uses the fixed 70-point Anagram rating scale", () => {
    const { container } = render(<AnagramDialog history={[]} kind="stats" now={now}
      onClose={vi.fn()} onConfirmGiveUp={vi.fn()} onConfirmHint={vi.fn()}
      progress={null} puzzle={null} shareResult={null}
      stats={{ averageSeconds: null, bestStreak: 0, played: 0, rollingScore: 0, solved: 0, streak: 0 }} />);

    expect(screen.getByLabelText("0 of 70 Anagram points")).toBeInTheDocument();
    expect(screen.getByText("0/70")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Anagram Stats" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "LAST 14 DAYS" })).toBeInTheDocument();
    expect(screen.getByLabelText("Anagram statistics summary")).toBeInTheDocument();
    expect(container.querySelectorAll(".anagram-stats__primary > span")).toHaveLength(3);
    expect(container.querySelectorAll(".anagram-history__row")).toHaveLength(15);
    expect(screen.getByText("TODAY")).toBeInTheDocument();
    expect(screen.getByRole("dialog", { name: "Anagram stats" })).toHaveClass("anagram-dialog--stats");
    expect(screen.getByRole("dialog", { name: "Anagram stats" }).parentElement).toHaveClass("anagram-dialog-backdrop--stats");
  });

  it("centers the hint and give-up confirmations in the viewport", () => {
    const props = {
      history: [], now, onClose: vi.fn(), onConfirmGiveUp: vi.fn(), onConfirmHint: vi.fn(),
      progress: startProgress(puzzle, now), puzzle, shareResult: null,
      stats: { averageSeconds: null, bestStreak: 0, played: 0, rollingScore: 0, solved: 0, streak: 0 }
    };
    const { rerender } = render(<AnagramDialog {...props} kind="giveUp" />);

    expect(screen.getByRole("dialog", { name: "Give up" }).parentElement).toHaveClass("anagram-dialog-backdrop--centered");

    rerender(<AnagramDialog {...props} kind="hint" />);

    expect(screen.getByRole("dialog", { name: "Reveal a letter" }).parentElement).toHaveClass("anagram-dialog-backdrop--centered");
  });

  it("matches the iOS How to Play information hierarchy", () => {
    render(<AnagramDialog history={[]} kind="instructions" now={now}
      onClose={vi.fn()} onConfirmGiveUp={vi.fn()} onConfirmHint={vi.fn()}
      progress={startProgress(puzzle, now)} puzzle={puzzle} shareResult={null}
      stats={{ averageSeconds: null, bestStreak: 0, played: 0, rollingScore: 0, solved: 0, streak: 0 }} />);

    const dialog = screen.getByRole("dialog", { name: "How to Play" });
    expect(dialog).toHaveClass("anagram-dialog--instructions");
    expect(dialog.parentElement).toHaveClass("anagram-dialog-backdrop--stats");
    expect(screen.getByRole("button", { name: "Close How to Play" })).toBeInTheDocument();
    for (const heading of ["Gameplay", "Timer", "Hint", "Scoring"]) {
      expect(screen.getByRole("heading", { name: heading })).toBeInTheDocument();
    }
    expect(screen.getByText("Under 30 seconds")).toBeInTheDocument();
    expect(screen.getByText("5 pts")).toBeInTheDocument();
    expect(screen.getByText("Give up", { selector: "dt" })).toBeInTheDocument();
    expect(screen.getByText("0 pts")).toBeInTheDocument();
    expect(screen.getByText(/rolling 14-day rating and streak/)).toBeInTheDocument();
  });
});
