import { useLayoutEffect, useRef, type RefObject } from "react";
import { accepts, type MidwordPuzzle } from "./engine";
import { MidwordLetterRow } from "./MidwordLetterRow";

export function MidwordGuessHistory({ guesses, puzzle, input, boardRef }: {
  guesses: string[]; puzzle: MidwordPuzzle; input: string; boardRef: RefObject<HTMLElement | null>;
}) {
  const historyRef = useRef<HTMLElement>(null);
  const snapshot = useRef<{ count: number; input: string; cells: DOMRect[]; rows: Map<string, DOMRect> } | null>(null);
  const animations = useRef<Animation[]>([]);
  const entries = guesses.map((guess, index) => ({ guess, index })).filter(({ guess }) => !accepts(puzzle, guess)).reverse();

  useLayoutEffect(() => () => animations.current.forEach(animation => animation.cancel()), []);
  useLayoutEffect(() => {
    const rows = Array.from(historyRef.current?.querySelectorAll<HTMLElement>("li") ?? []);
    const positions = new Map(rows.map(row => [row.dataset.index!, row.getBoundingClientRect()]));
    const previous = snapshot.current;
    const latest = entries[0];
    const newGuess = previous && guesses.length === previous.count + 1
      && latest?.index === previous.count && latest.guess === previous.input;
    if (newGuess && !window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) {
      animations.current = animations.current.filter(animation => animation.playState !== "finished");
      const move = (element: HTMLElement, from: DOMRect, to: DOMRect) => {
        if (!to.width || !to.height || !element.animate) return;
        animations.current.push(element.animate([
          { transformOrigin: "top left", transform: `translate(${from.left - to.left}px, ${from.top - to.top}px) scale(${from.width / to.width}, ${from.height / to.height})` },
          { transformOrigin: "top left", transform: "translate(0, 0) scale(1)" },
        ], { duration: 450, easing: "cubic-bezier(0.22, 1, 0.36, 1)" }));
      };
      rows.forEach(row => {
        const old = previous.rows.get(row.dataset.index!);
        if (old) move(row, old, positions.get(row.dataset.index!)!);
        else if (Number(row.dataset.index) === latest.index) {
          row.querySelectorAll<HTMLElement>(".midword-letter-row > span").forEach((cell, index) => {
            const source = previous.cells[index];
            if (source) move(cell, source, cell.getBoundingClientRect());
          });
        }
      });
    }
    snapshot.current = {
      count: guesses.length, input,
      cells: Array.from(boardRef.current?.querySelectorAll(".midword-letter-row > span") ?? []).map(cell => cell.getBoundingClientRect()),
      rows: positions,
    };
  });

  return <section ref={historyRef} aria-label="Previous guesses" className="midword-guess-history" hidden={!entries.length}>
    <h2>Previous Guesses</h2>
    <ul>{entries.map(({ guess, index }) => <li key={index} data-index={index}>
      <MidwordLetterRow word={guess} label={`${guess}, incorrect`} />
    </li>)}</ul>
  </section>;
}
