import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { countdownText, secondsUntilNextLocalMidnight } from "../date";
import { isCompletedOnReleaseDate } from "../date";
import { shareText } from "../engine";
import type { BackwordProgress, BackwordStats, BackwordWord } from "../types";
import { BackwordModal } from "./BackwordModal";
import { StatsContent } from "./BackwordStats";

type BackwordCompletionProps = {
  progress: BackwordProgress;
  stats: BackwordStats;
  word: BackwordWord;
  onClose: () => void;
};

export function BackwordCompletion({
  progress,
  stats,
  word,
  onClose
}: BackwordCompletionProps) {
  const navigate = useNavigate();
  const [seconds, setSeconds] = useState(() => secondsUntilNextLocalMidnight());
  const [shareStatus, setShareStatus] = useState("");
  const failed = progress.outcome === "failed";
  const onTime = isCompletedOnReleaseDate(progress.date, progress.completedAt);
  const title = failed ? "Failed" : onTime ? "Solved!" : "Finished";
  const summary = failed
    ? "The answer was..."
    : `... in ${progress.guesses.length} ${progress.guesses.length === 1 ? "guess" : "guesses"}`;
  const letters = useMemo(() => Array.from(word.word), [word.word]);

  useEffect(() => {
    const timer = window.setInterval(
      () => setSeconds(secondsUntilNextLocalMidnight()),
      1000
    );
    return () => window.clearInterval(timer);
  }, []);

  async function shareResult() {
    const text = shareText(progress, word.word);
    try {
      if (navigator.share) {
        await navigator.share({ text, title: `Backword ${progress.date}` });
        setShareStatus("Shared");
      } else {
        await navigator.clipboard.writeText(text);
        setShareStatus("Copied to clipboard");
      }
    } catch (error) {
      if ((error as DOMException).name !== "AbortError") {
        setShareStatus("Sharing is unavailable");
      }
    }
  }

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

        <StatsContent
          highlightGuessCount={progress.outcome === "won" ? progress.guesses.length : undefined}
          stats={stats}
        />

        <button className="bw-secondary-button" onClick={shareResult} type="button">
          Share result
        </button>
        <span aria-live="polite" className="bw-share-status">{shareStatus}</span>
      </div>
      <div className="bw-completion-actions">
        <button onClick={() => navigate("/")} type="button">HOME</button>
        <button onClick={onClose} type="button">BACK TO GAME</button>
      </div>
    </BackwordModal>
  );
}
