import { StatsSheetActions } from "../../components/StatsSheetActions";
import { BackwordModal } from "../backword/components/BackwordModal";
import type { PuzzleShareResult } from "../share/puzzleResult";
import type { MidwordProgress, MidwordPuzzle, MidwordStats } from "./engine";
import { MidwordInstructions } from "./MidwordInstructions";
import { MidwordCompletion } from "./MidwordCompletion";
import { MidwordRatingBar, MidwordStatistics } from "./MidwordStatistics";

export function MidwordDialog({ kind, onClose, puzzle, progress, stats, shareResult, now }: {
  kind: "instructions" | "stats" | "completion"; onClose: () => void;
  puzzle: MidwordPuzzle | null; progress: MidwordProgress; stats: MidwordStats;
  shareResult: PuzzleShareResult | null; now: Date;
}) {
  const title = kind === "instructions" ? "How to Play" : kind === "stats" ? "Midword Stats"
    : progress.outcome === "won" ? "Solved!" : "Finished";
  return <BackwordModal backdropClassName={kind === "instructions" ? "midword-instructions-backdrop" : kind === "completion" ? "midword-completion-backdrop" : undefined}
    showCloseButton={kind === "instructions"}
    showHeader={kind !== "completion"}
    className={`midword-dialog midword-dialog--${kind}${progress.outcome === "failed" ? " is-failed" : ""}`} onClose={onClose} title={title}>
    {kind === "completion" ? puzzle ? <MidwordCompletion onClose={onClose} now={now} progress={progress} puzzle={puzzle}
      shareResult={shareResult} stats={stats} /> : null : <div className={`midword-dialog-scroll${kind === "stats" ? " stats-sheet-scroll" : ""}`}>
      {kind === "instructions" ? <MidwordInstructions /> : kind === "stats" ? <>
        <MidwordRatingBar score={stats.rollingScore} /><MidwordStatistics stats={stats} />
      </> : null}
    </div>}
    {kind === "stats" ? <StatsSheetActions onClose={onClose} showHome={false} /> : null}
  </BackwordModal>;
}
