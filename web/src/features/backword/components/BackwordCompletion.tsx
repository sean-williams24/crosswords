import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { countdownText, secondsUntilNextLocalMidnight } from "../date";
import { isCompletedOnReleaseDate } from "../date";
import type { BackwordProgress, BackwordStats, BackwordWord } from "../types";
import type { PlayerProfileRating } from "../../profile/profileRating";
import { PuzzleResultShare } from "../../share/PuzzleResultShare";
import { buildBackwordShareResult } from "../../share/puzzleResult";
import { BackwordModal } from "./BackwordModal";
import { StatsContent } from "./BackwordStats";

type BackwordCompletionProps = {
  progress: BackwordProgress;
  stats: BackwordStats;
  word: BackwordWord;
  rating: PlayerProfileRating;
  onClose: () => void;
};

export function BackwordCompletion({
  progress,
  stats,
  word,
  rating,
  onClose
}: BackwordCompletionProps) {
  const navigate = useNavigate();
  const [seconds, setSeconds] = useState(() => secondsUntilNextLocalMidnight());
  const failed = progress.outcome === "failed";
  const onTime = isCompletedOnReleaseDate(progress.date, progress.completedAt);
  const title = failed ? "Failed" : onTime ? "Solved!" : "Finished";
  const summary = failed
    ? "The answer was..."
    : `... in ${progress.guesses.length} ${progress.guesses.length === 1 ? "guess" : "guesses"}`;
  const letters = useMemo(() => Array.from(word.word), [word.word]);
  const shareResult = useMemo(
    () => buildBackwordShareResult({ progress, stats, word, rating }),
    [progress, rating, stats, word]
  );

  useEffect(() => {
    const timer = window.setInterval(
      () => setSeconds(secondsUntilNextLocalMidnight()),
      1000
    );
    return () => window.clearInterval(timer);
  }, []);

  return (
    <BackwordModal
      className="bw-completion-modal"
      onClose={onClose}
      showCloseButton={false}
      title={title}
    >
      <div className="bw-modal-scroll bw-completion-scroll">
        <h2 className={failed ? "is-failed" : onTime ? "" : "is-finished"}>{title}</h2>
        <p className="bw-completion-summary">{summary}</p>
        <div
          aria-label={`The answer was ${word.word}`}
          className={`bw-completion-word ${failed ? "is-failed" : ""}`}
        >
          {letters.map((letter, index) => (
            <span key={`${letter}-${index}`} style={{ animationDelay: `${(letters.length - index) * 90}ms` }}>
              {letter}
            </span>
          ))}
        </div>
        <div className="bw-countdown">
          <span>NEXT BACKWORD IN</span>
          <strong>{countdownText(seconds)}</strong>
        </div>

        {!failed && !onTime ? (
          <p className="bw-late-message">Complete Backword on its release date to earn points.</p>
        ) : null}

        <PuzzleResultShare result={shareResult} showPreview={false} />

        <StatsContent
          highlightGuessCount={progress.outcome === "won" ? progress.guesses.length : undefined}
          stats={stats}
        />
      </div>
      <div className="bw-completion-actions">
        <button onClick={() => navigate("/")} type="button">HOME</button>
        <button onClick={onClose} type="button">BACK TO GAME</button>
      </div>
    </BackwordModal>
  );
}
