import { useNavigate } from "react-router-dom";
import { BackwordModal } from "../backword/components/BackwordModal";
import { countdownText, secondsUntilNextLocalMidnight } from "../backword/date";
import { PuzzleResultShare } from "../share/PuzzleResultShare";
import type { PuzzleShareResult } from "../share/puzzleResult";
import type { MidwordProgress, MidwordPuzzle, MidwordStats } from "./engine";
import { MidwordInstructions } from "./MidwordInstructions";
import { MidwordLetterRow } from "./MidwordLetterRow";
import { MidwordRatingBar, MidwordStatistics } from "./MidwordStatistics";

export function MidwordDialog({ kind, onClose, puzzle, progress, stats, shareResult, now }: {
  kind: "instructions" | "stats" | "completion"; onClose: () => void;
  puzzle: MidwordPuzzle | null; progress: MidwordProgress; stats: MidwordStats;
  shareResult: PuzzleShareResult | null; now: Date;
}) {
  const navigate = useNavigate();
  const title = kind === "instructions" ? "How to Play" : kind === "stats" ? "Midword Stats"
    : progress.outcome === "won" ? "Solved!" : "Finished";
  return <BackwordModal backdropClassName={kind === "instructions" ? "midword-instructions-backdrop" : undefined}
    className={`midword-dialog midword-dialog--${kind}${progress.outcome === "failed" ? " is-failed" : ""}`} onClose={onClose} title={title}>
    <div className="midword-dialog-scroll">
      {kind === "instructions" ? <MidwordInstructions /> : kind === "stats" ? <>
        <MidwordRatingBar score={stats.rollingScore} /><MidwordStatistics stats={stats} />
      </> : puzzle ? <>
        <div className="midword-completion-header"><strong>PUZZLE #{puzzle.puzzleNumber}</strong>
          {progress.outcome === "failed" ? <p>The answer was…</p> : <p>In {progress.guesses.length} {progress.guesses.length === 1 ? "guess" : "guesses"}</p>}</div>
        <div className={`midword-completion-answer${progress.outcome === "won" ? " is-celebrating" : ""}`}>
          <MidwordLetterRow correct={progress.outcome === "won"} label={puzzle.answer} word={puzzle.answer} />
          <p>{puzzle.firstWord + puzzle.answer} · {puzzle.answer + puzzle.secondWord}</p>
        </div>
        <div className="midword-countdown"><span>NEXT MIDWORD IN</span><strong>{countdownText(secondsUntilNextLocalMidnight(now))}</strong></div>
        <div className="midword-completion-details">
          <MidwordRatingBar score={stats.rollingScore} />
          {shareResult ? <PuzzleResultShare result={shareResult} showPreview={false} /> : null}
          <section aria-label="Midword completion statistics" className="midword-summary">
            <div><strong>{progress.guesses.length}/5</strong><small>Guesses</small></div>
            <div><strong>{progress.releaseDateScore}/5</strong><small>Points</small></div>
          </section>
          <MidwordStatistics stats={stats} />
        </div>
      </> : null}
    </div>
    {kind === "completion" ? <div className="midword-completion-actions">
      <button onClick={() => navigate("/")} type="button">HOME</button><button onClick={onClose} type="button">BACK TO GAME</button>
    </div> : null}
  </BackwordModal>;
}
