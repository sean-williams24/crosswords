import { useEffect, useState } from "react";
import type { CSSProperties } from "react";
import { useNavigate } from "react-router-dom";
import { BackwordModal } from "../../backword/components/BackwordModal";
import {
  countdownText,
  secondsUntilNextLocalMidnight,
  secondsUntilNextLocalSunday,
  weeklyCountdownText
} from "../../backword/date";
import { completedInReleaseWindow, formatDuration } from "../engine";
import type { WeeklyCrosswordStats } from "../engine";
import type { CrosswordKind, CrosswordProgress, CrosswordPuzzle, CrosswordStats } from "../types";
import { CrosswordStatsContent } from "./CrosswordStats";

type CrosswordCompletionProps = {
  onClose: () => void;
  progress: CrosswordProgress;
  puzzle: CrosswordPuzzle;
  stats: CrosswordStats | WeeklyCrosswordStats;
  kind?: CrosswordKind;
};

export function CrosswordCompletion({ onClose, progress, puzzle, stats, kind = "daily" }: CrosswordCompletionProps) {
  const navigate = useNavigate();
  const [seconds, setSeconds] = useState(() => kind === "weekly" ? secondsUntilNextLocalSunday() : secondsUntilNextLocalMidnight());
  const onTime = completedInReleaseWindow(kind, progress.date, progress.completedAt);
  const completedAt = new Date(progress.completedAt ?? "").getTime();
  const startedAt = new Date(progress.startedAt).getTime();
  const solveTime = Number.isFinite(completedAt - startedAt) ? Math.max(0, Math.floor((completedAt - startedAt) / 1000)) : null;

  useEffect(() => {
    const timer = window.setInterval(() => setSeconds(kind === "weekly" ? secondsUntilNextLocalSunday() : secondsUntilNextLocalMidnight()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <BackwordModal className="bw-completion-modal cw-completion-modal" onClose={onClose} showCloseButton={false} title={onTime ? "Solved!" : "Finished"}>
      <div className="bw-modal-scroll bw-completion-scroll">
        <h2 className={onTime ? "" : "is-finished"}>{onTime ? "Solved!" : "Finished"}</h2>
        <p className="bw-completion-summary">PUZZLE #{puzzle.puzzleNumber}</p>
        <div aria-label="Completed crossword grid" className={`cw-completion-grid ${kind === "weekly" ? "cw-completion-grid--weekly" : ""}`} style={{ "--cw-grid-size": puzzle.size } as CSSProperties}>
          {puzzle.cells.flatMap((row, rowIndex) => row.map((cell, colIndex) => cell.letter === null
            ? <span className="is-black" key={`${rowIndex}:${colIndex}`} />
            : <span key={`${rowIndex}:${colIndex}`} style={{ animationDelay: `${(rowIndex + colIndex) * 40}ms` }}>{cell.letter}</span>
          ))}
        </div>
        <div className="bw-countdown"><span>NEXT {kind === "weekly" ? "WEEKLY" : "DAILY"} CROSSWORD IN</span><strong>{kind === "weekly" ? weeklyCountdownText(seconds) : countdownText(seconds)}</strong></div>
        {!onTime ? <p className="bw-late-message">Complete the crossword on its release date to earn points.</p> : null}
        <section className="cw-completion-summary-card">
          <div><strong>{progress.releaseDateScore}/5</strong><span>SCORE</span></div>
          <div><strong>{stats.currentStreak}</strong><span>STREAK</span></div>
          <div><strong>{formatDuration(solveTime)}</strong><span>TIME</span></div>
        </section>
        <CrosswordStatsContent stats={stats} kind={kind} />
      </div>
      <div className="bw-completion-actions"><button onClick={() => navigate("/")} type="button">HOME</button><button onClick={onClose} type="button">BACK TO GAME</button></div>
    </BackwordModal>
  );
}
