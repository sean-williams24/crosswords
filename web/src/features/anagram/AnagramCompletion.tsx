import type { CSSProperties, ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { PuzzleResultShare } from "../share/PuzzleResultShare";
import type { PuzzleShareResult } from "../share/puzzleResult";
import { answerText, pointsForSeconds, type AnagramProgress, type AnagramPuzzle } from "./engine";

function duration(seconds: number) {
  if (seconds >= 3600) return `${Math.floor(seconds / 3600)}:${String(Math.floor((seconds % 3600) / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

export function anagramCompletionTitle(progress: AnagramProgress, puzzle: AnagramPuzzle) {
  if (progress.outcome === "gave_up") return "Finished";
  return puzzle.puzzleNumber === 0 || progress.releaseDateScore > 0 ? "Solved!" : "Finished";
}

export function AnagramCompletion({
  countdown,
  historyTable,
  onClose,
  progress,
  puzzle,
  ratingBar,
  shareResult,
  statsSummary
}: {
  countdown: string;
  historyTable: ReactNode;
  onClose: () => void;
  progress: AnagramProgress;
  puzzle: AnagramPuzzle;
  ratingBar: ReactNode;
  shareResult: PuzzleShareResult | null;
  statsSummary: ReactNode;
}) {
  const navigate = useNavigate();
  const isReview = puzzle.puzzleNumber === 0;
  const solved = progress.outcome === "solved";
  const celebrates = solved && (isReview || progress.releaseDateScore > 0);
  const title = anagramCompletionTitle(progress, puzzle);
  const answer = solved ? answerText(progress, puzzle) ?? puzzle.answer : puzzle.answer;
  const letters = Array.from(answer);
  const elapsed = progress.elapsedSecondsAtCompletion ?? 0;
  const score = solved
    ? isReview ? pointsForSeconds(elapsed + progress.penaltySeconds) : progress.releaseDateScore
    : 0;
  const countdownDelay = 220 + letters.length * 120 + (celebrates ? 600 : 150);
  const presentationStyle = {
    "--anagram-countdown-delay": `${countdownDelay}ms`,
    "--anagram-details-delay": `${countdownDelay + 180}ms`,
    "--anagram-celebration-delay": `${220 + letters.length * 120 + 280}ms`
  } as CSSProperties;
  const introduction = progress.outcome === "gave_up"
    ? "The answer was..."
    : !celebrates ? "Solved after its release day" : null;

  return <>
    <div className="anagram-completion-scroll" style={presentationStyle}>
      <header className="anagram-completion-header">
        <h2>{title}</h2>
        <strong>{isReview ? "REVIEW PUZZLE" : `PUZZLE #${puzzle.puzzleNumber}`}</strong>
        {introduction ? <p>{introduction}</p> : null}
      </header>

      <div className="anagram-completion-word-stage">
        <div aria-label={answer} className={`anagram-completion-word${celebrates ? " is-celebrating" : ""}`} style={{ "--anagram-letter-count": letters.length } as CSSProperties}>
          {letters.map((letter, index) => <span key={`${letter}-${index}`} style={{ animationDelay: `${340 + index * 120}ms` }}>{letter}</span>)}
        </div>
      </div>

      <div className="anagram-completion-countdown">
        <span>NEXT ANAGRAM IN</span>
        <strong>{countdown}</strong>
      </div>

      <div className="anagram-completion-details">
        {ratingBar}
        {shareResult ? <PuzzleResultShare result={shareResult} showPreview={false} /> : null}
        <section aria-label="Anagram completion statistics" className="anagram-completion-stats">
          <span><strong>{duration(elapsed)}</strong><small>TIME</small></span>
          <span><strong>+{duration(progress.penaltySeconds)}</strong><small>PENALTY</small></span>
          <span><strong>{score}/5</strong><small>POINTS</small></span>
        </section>
        {statsSummary}
        {historyTable}
      </div>
    </div>

    <div className="anagram-completion-actions">
      <button onClick={() => navigate("/")} type="button">HOME</button>
      <button onClick={onClose} type="button">BACK TO GAME</button>
    </div>
  </>;
}
