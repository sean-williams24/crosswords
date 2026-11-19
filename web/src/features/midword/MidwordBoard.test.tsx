import { render, screen, within } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import { emptyProgress, giveUp, startProgress, type MidwordPuzzle } from "./engine";
import { MidwordBoard } from "./MidwordBoard";

const puzzle: MidwordPuzzle = {
  id: "midword-test", date: "2026-10-11", puzzleNumber: 11,
  firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: []
};

describe("Midword prompt alignment", () => {
  it("uses the board gap without adding extra margin above validation feedback", () => {
    const style = document.createElement("style");
    style.textContent = readFileSync("src/features/midword/midword.css", "utf8");
    document.head.append(style);
    try {
      render(<MidwordBoard input="ZZZZ" message="Not a valid word" puzzle={puzzle}
        progress={{ ...emptyProgress(puzzle.date), guesses: ["PAGE"] }} />);
      expect(getComputedStyle(screen.getByRole("alert")).marginTop).toBe("0px");
    } finally { style.remove(); }
  });
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

describe("Midword guess history", () => {
  it.each(["Not a valid word", "Already guessed"])("places %s between the board and previous guesses", message => {
    render(<MidwordBoard input="ZZZZ" inputError message={message} puzzle={puzzle}
      progress={{ ...emptyProgress(puzzle.date), guesses: ["PAGE"] }} />);
    const board = screen.getByRole("region", { name: "Midword board" });
    const feedback = screen.getByRole("alert");
    const history = screen.getByRole("region", { name: "Previous guesses" });
    expect(feedback).toHaveTextContent(message);
    expect(board.compareDocumentPosition(feedback) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(feedback.compareDocumentPosition(history) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(within(history).getAllByRole("listitem")).toHaveLength(1);
  });
  it.each([[1, "guess"], [2, "guesses"]] as const)("shows the solved message for %s guesses", (count, noun) => {
    const progress = { ...emptyProgress(puzzle.date), outcome: "won" as const, completedAt: new Date().toISOString(), guesses: count === 1 ? ["NOTE"] : ["PAGE", "NOTE"] };
    render(<MidwordBoard input="" message="" puzzle={puzzle} progress={progress} />);
    expect(document.querySelector(".midword-explainer")).toHaveTextContent(`Solved in ${count} ${noun}...`);
  });
  it("shows the failure message for a legacy exhausted attempt", () => {
    const progress = { ...emptyProgress(puzzle.date), outcome: "failed" as const, completedAt: new Date().toISOString(), guesses: ["PAGE", "WORD", "READ", "LINE", "BOOK"] };
    render(<MidwordBoard input="" message="" puzzle={puzzle} progress={progress} />);
    expect(document.querySelector(".midword-explainer")).toHaveTextContent("Not this time, the answer was...");
  });
  it("reveals the answer on the board after giving up", () => {
    const progress = giveUp(startProgress(emptyProgress(puzzle.date)));
    render(<MidwordBoard input="PA" message="" puzzle={puzzle} progress={progress} />);
    expect(document.querySelector(".midword-explainer")).toHaveTextContent("You gave up, the answer was...");
    expect(document.querySelector(".midword-explainer br")).toBeNull();
    expect(screen.getByRole("group", { name: "Middle word, NOTE" })).toHaveTextContent("NOTE");
  });
  it("shows saved guesses below the board without an attempt counter", () => {
    render(<MidwordBoard input="" message="" puzzle={puzzle} progress={{ ...emptyProgress(puzzle.date), guesses: ["PAGE"] }} />);
    expect(screen.getByRole("region", { name: "Previous guesses" })).toHaveTextContent("PAGE");
    expect(screen.queryByLabelText(/attempts remaining/)).not.toBeInTheDocument();
    expect(screen.getByRole("group", { name: "Middle word, 0 of 4 letters entered" })).toBeInTheDocument();
  });
});


describe("Midword previous guess movement", () => {
  it.each(["NOTE", "LINK"])("orders wrong guesses newest first and excludes solved answer %s", answer => {
    render(<MidwordBoard input="" message="" puzzle={{ ...puzzle, alternatives: ["LINK"] }}
      progress={{ ...emptyProgress(puzzle.date), outcome: "won", guesses: ["PAGE", "WORD", answer] }} />);
    const history = screen.getByRole("region", { name: "Previous guesses" });
    expect(within(history).getAllByRole("group").map(row => row.getAttribute("aria-label"))).toEqual(["WORD, incorrect", "PAGE, incorrect"]);
    expect(within(history).queryByText("LINK")).not.toBeInTheDocument();
  });

  it.each([false, true])("moves new cells from the input and pushes saved rows down; reduce motion = %s", (reduced) => {
    const originalAnimate = HTMLElement.prototype.animate;
    const animate = vi.fn((_keyframes: Keyframe[], _options: KeyframeAnimationOptions) => ({ cancel: vi.fn(), playState: "finished" } as unknown as Animation));
    HTMLElement.prototype.animate = animate;
    vi.stubGlobal("matchMedia", vi.fn(() => ({ matches: reduced })));
    const bounds = vi.spyOn(HTMLElement.prototype, "getBoundingClientRect").mockImplementation(function (this: HTMLElement) {
      const history = !!this.closest(".midword-guess-history");
      const row = this.closest("li");
      const rowIndex = row?.dataset.index;
      return { left: 0, top: history ? (rowIndex === "0" && row?.parentElement?.children.length === 2 ? 250 : 200) : 100,
        width: history ? 38 : 56, height: history ? 38 : 56 } as DOMRect;
    });
    try {
      const progress = { ...emptyProgress(puzzle.date), guesses: ["PAGE"] };
      const { rerender, unmount } = render(<MidwordBoard input="WORD" message="" puzzle={puzzle} progress={progress} />);
      // Hydrating a saved game does not replay old submissions.
      expect(animate).not.toHaveBeenCalled();
      rerender(<MidwordBoard input="" message="" puzzle={puzzle} progress={{ ...progress, guesses: ["PAGE", "WORD"] }} />);
      if (reduced) expect(animate).not.toHaveBeenCalled();
      else {
        expect(animate).toHaveBeenCalledTimes(5); // Four new letters and one existing row.
        expect(animate.mock.calls[1][0][0].transform).toContain("-100px");
        expect(animate.mock.calls[1][0][0].transform).toContain("1.473");
        expect(animate.mock.calls[4][0][0].transform).toContain("-50px");
      }
      unmount();
    } finally {
      HTMLElement.prototype.animate = originalAnimate;
      bounds.mockRestore(); vi.unstubAllGlobals();
    }
  });
});
