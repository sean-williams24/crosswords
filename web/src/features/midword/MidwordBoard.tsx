import { accepts, type MidwordProgress, type MidwordPuzzle } from "./engine";
import { MidwordLetterRow } from "./MidwordLetterRow";

export function MidwordBoard({ puzzle, progress, input, message }: {
  puzzle: MidwordPuzzle; progress: MidwordProgress; input: string; message: string;
}) {
  const won = progress.outcome === "won";
  return <>
    <p className="midword-explainer">Find the link that ends the top word and starts the bottom word to make 2 new words</p>
    <section aria-label="Midword board" className="midword-board">
      <p className="midword-prompt midword-prompt--first">{puzzle.firstWord}</p>
      <MidwordLetterRow active={!progress.completedAt} correct={won} label={`Middle word, ${won ? puzzle.answer.length : input.length} of ${puzzle.answer.length} letters entered`}
        length={puzzle.answer.length} word={won ? puzzle.answer : input} />
      <p className="midword-prompt midword-prompt--second">{puzzle.secondWord}</p>
    </section>
    <div aria-label={`${Math.max(0, 5 - progress.guesses.length)} attempts remaining`} className="bw-guess-counter midword-attempts">
      {Array.from({ length: 5 }, (_, index) => <span key={index} className={progress.outcome === "failed" ? "is-failed"
        : won && index === progress.guesses.length - 1 ? "is-won" : index < progress.guesses.length ? "is-used" : ""} />)}
    </div>
    {message ? <p className="midword-message" role="alert">{message}</p> : null}
    {progress.guesses.length ? <section aria-label="Previous guesses" className="midword-guesses">
      <h2>Previous guesses</h2>
      {progress.guesses.map((guess, index) => <MidwordLetterRow correct={accepts(puzzle, guess)} failed={!accepts(puzzle, guess)}
        key={index} label={`${guess}, ${accepts(puzzle, guess) ? "correct" : "incorrect"}`} word={guess} />)}
    </section> : null}
  </>;
}
