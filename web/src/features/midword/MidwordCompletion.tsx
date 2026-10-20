import { StatsSheetActions } from "../../components/StatsSheetActions";
import { countdownText, secondsUntilNextLocalMidnight } from "../backword/date";
import { PuzzleResultShare } from "../share/PuzzleResultShare";
import type { PuzzleShareResult } from "../share/puzzleResult";
import type { MidwordProgress, MidwordPuzzle, MidwordStats } from "./engine";
import { MidwordLetterRow } from "./MidwordLetterRow";
import { MidwordRatingBar, MidwordStatistics } from "./MidwordStatistics";

export function MidwordCompletion({ puzzle, progress, stats, shareResult, now, onClose }: {
  puzzle: MidwordPuzzle; progress: MidwordProgress; stats: MidwordStats;
  shareResult: PuzzleShareResult | null; now: Date; onClose: () => void;
}) {
  const won = progress.outcome === "won";

  return <>
    <div className="midword-dialog-scroll midword-completion-scroll stats-sheet-scroll">
      <header className="midword-completion-header">
        <h2>{won ? "Solved!" : "Finished"}</h2>
        <strong>PUZZLE #{puzzle.puzzleNumber}</strong>
        <p>{won ? `In ${progress.guesses.length} ${progress.guesses.length === 1 ? "guess" : "guesses"}` : "The answer was…"}</p>
      </header>
      <div className={`midword-completion-answer${won ? " is-celebrating" : ""}`}>
        <MidwordLetterRow correct={won} failed={progress.outcome === "failed"} label={puzzle.answer} word={puzzle.answer} />
        <p>{puzzle.firstWord + puzzle.answer} · {puzzle.answer + puzzle.secondWord}</p>
      </div>
      <div className="midword-countdown">
        <span>NEXT MIDWORD IN</span>
        <strong>{countdownText(secondsUntilNextLocalMidnight(now))}</strong>
      </div>
      <div className="midword-completion-details">
        <MidwordRatingBar score={stats.rollingScore} />
        {shareResult ? <PuzzleResultShare result={shareResult} showIcon showPreview={false} /> : null}
        <section aria-label="Midword completion statistics" className="midword-summary">
          <div><strong>{progress.guesses.length}/5</strong><small>Guesses</small></div>
          <div><strong>{progress.releaseDateScore}/5</strong><small>Points</small></div>
        </section>
        <div className="midword-completion-statistics"><MidwordStatistics stats={stats} /></div>
      </div>
    </div>
    <StatsSheetActions onClose={onClose} autoFocusHome />
  </>;
}
