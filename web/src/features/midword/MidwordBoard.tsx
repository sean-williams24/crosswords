import { type MidwordProgress, type MidwordPuzzle } from "./engine";
import { MidwordLetterRow } from "./MidwordLetterRow";
import { GameInputMessage } from "../../components/GameInputMessage";

export function MidwordBoard({ puzzle, progress, input, inputError = false, message }: {
  puzzle: MidwordPuzzle; progress: MidwordProgress; input: string; inputError?: boolean; message: string;
}) {
  const won = progress.outcome === "won";
  const revealed = won || progress.outcome === "failed";
  return <>
    <p className="midword-explainer">{progress.outcome === "won"
      ? `Solved in ${progress.guesses.length} ${progress.guesses.length === 1 ? "guess" : "guesses"}...`
      : progress.outcome === "failed" && (progress.startedAt != null || progress.guesses.length < 5)
      ? "You gave up, the answer was..."
      : progress.outcome === "failed" ? "Not this time, the answer was..."
      : "Find the link that ends the top word and starts the bottom word to make 2 new words"}</p>
    <section aria-label="Midword board" className="midword-board">
      <p className="midword-prompt midword-prompt--first">{puzzle.firstWord}</p>
      <MidwordLetterRow active={!progress.completedAt} correct={won} failed={progress.outcome === "failed"} inputError={inputError} label={revealed ? `Middle word, ${puzzle.answer}` : `Middle word, ${input.length} of ${puzzle.answer.length} letters entered`}
        length={puzzle.answer.length} word={revealed ? puzzle.answer : input} />
      <p className="midword-prompt midword-prompt--second">{puzzle.secondWord}</p>
    </section>
    <div className="midword-attempt-status">
      <GameInputMessage className="midword-message" message={message} />
    </div>

  </>;
}
