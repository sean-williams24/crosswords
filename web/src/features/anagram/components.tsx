import { useEffect, useRef } from "react";
import { localDateString } from "../backword/date";
import type { PuzzleShareResult } from "../share/puzzleResult";
import { answerText, availableTileIDs, elapsedSeconds, type AnagramProgress, type AnagramPuzzle } from "./engine";
import { AnagramCompletion, anagramCompletionTitle } from "./AnagramCompletion";
import { AnagramInstructions } from "./AnagramInstructions";

type Stats = { solved: number; played: number; streak: number; bestStreak: number; rollingScore: number };

function duration(seconds: number) {
  if (seconds >= 3600) return `${Math.floor(seconds / 3600)}:${String(Math.floor((seconds % 3600) / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, "0")}`;
}

function countdownDuration(seconds: number) {
  return `${String(Math.floor(seconds / 3600)).padStart(2, "0")}:${String(Math.floor((seconds % 3600) / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}

function historyDate(dateString: string) {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Intl.DateTimeFormat(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric"
  }).format(new Date(year, month - 1, day, 12));
}

export function AnagramBoard({ puzzle, progress, now, onPlace, onUndo, onRestart, onShuffle, onHint, onGiveUp, onResetReview }: {
  puzzle: AnagramPuzzle; progress: AnagramProgress; now: Date;
  onPlace: (tile: number) => void; onUndo: () => void; onRestart: () => void;
  onShuffle: () => void; onHint: () => void; onGiveUp: () => void;
  onResetReview?: () => void;
}) {
  const ended = progress.outcome !== null;
  const available = new Set(availableTileIDs(progress));
  const letters = [...puzzle.initialScramble];
  const answer = answerText(progress, puzzle);
  const firstRow = puzzle.answer.length === 9 ? 5 : 4;
  const rows = [Array.from({ length: firstRow }, (_, index) => index),
    Array.from({ length: puzzle.answer.length - firstRow }, (_, index) => index + firstRow)];
  return <section aria-label="Anagram board" className="anagram-board">
    <div className="anagram-gameplay-content">
      <div className="anagram-timer">
        <span><svg aria-hidden="true" viewBox="0 0 24 24"><circle cx="12" cy="13" r="8" /><path d="M12 13V8m-3-5h6M7 6 5.5 4.5" /></svg><strong>{duration(elapsedSeconds(progress, now))}</strong></span>
        {progress.penaltySeconds > 0 ? <span className="anagram-penalty">+{duration(progress.penaltySeconds)} hint</span> : null}
      </div>
      <div className="anagram-answer-block">
        <p>YOUR ANSWER</p>
        <div aria-label="Answer cells" className={`anagram-answer anagram-answer--${puzzle.answer.length}`}>
          {Array.from({ length: puzzle.answer.length }, (_, index) => {
            const tile = progress.placedTileIDs[index];
            return <span aria-label={`Cell ${index + 1}: ${tile === null ? "empty" : letters[tile]}${progress.lockedCellIndex === index ? ", locked hint" : ""}`} className={`anagram-cell${tile !== null ? " is-filled" : ""}${progress.lockedCellIndex === index ? " is-locked" : ""}`} key={index}>{tile === null ? "" : letters[tile]}</span>;
          })}
        </div>
      </div>
      {answer && !ended && ![puzzle.answer, ...puzzle.acceptedAnswers].includes(answer) ? <p aria-live="polite" className="anagram-note">Not quite. Undo a letter or restart and try again.</p> : null}
      {onResetReview && ended ? <button className="anagram-review-reset" onClick={onResetReview} type="button">Reset review puzzle</button> : null}
    </div>
    <div className="anagram-gameplay-dock">
      <div aria-label="Scrambled letter tray" className="anagram-tray">
        {rows.map((row, rowIndex) => <div aria-label={`Tray row ${rowIndex + 1}`} className="anagram-letter-row" key={rowIndex}>
          {row.map((position) => { const tile = progress.trayOrder[position]; return available.has(tile)
            ? <button aria-label={`Letter ${letters[tile]}, tray position ${position + 1}`} className="anagram-tile" disabled={ended} key={tile} onClick={() => onPlace(tile)} type="button">{letters[tile]}</button>
            : <span aria-hidden="true" className="anagram-tile anagram-tile--empty" key={tile} />; })}
        </div>)}
      </div>
      <div className="anagram-controls">
        <button disabled={ended || !progress.placementHistory.length} onClick={onUndo} type="button">Undo</button>
        <button disabled={ended || !progress.placementHistory.length} onClick={onRestart} type="button">Restart</button>
        <button disabled={ended || available.size < 2} onClick={onShuffle} type="button">Shuffle</button>
      </div>
      <div className="anagram-secondary-controls"><button disabled={ended || progress.hintUsed} onClick={onHint} type="button">Hint</button><button disabled={ended} onClick={onGiveUp} type="button">Give up</button></div>
    </div>
  </section>;
}

export function AnagramDialog({ kind, onClose, onConfirmHint, onConfirmGiveUp, progress, puzzle, shareResult, stats, history, now }: {
  kind: "instructions" | "hint" | "giveUp" | "stats" | "result";
  onClose: () => void; onConfirmHint: () => void; onConfirmGiveUp: () => void;
  progress: AnagramProgress | null; puzzle: AnagramPuzzle | null;
  shareResult: PuzzleShareResult | null; stats: Stats & { averageSeconds: number | null };
  history: AnagramProgress[]; now: Date;
}) {
  const closeRef = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    closeRef.current?.focus();
    const escape = (event: KeyboardEvent) => { if (event.key === "Escape") onClose(); };
    window.addEventListener("keydown", escape);
    return () => window.removeEventListener("keydown", escape);
  }, [onClose]);
  const historyByDate = new Map(history.map((record) => [record.date, record]));
  const releaseDays = Array.from({ length: 14 }, (_, offset) => {
    const day = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12);
    day.setDate(day.getDate() - offset);
    return localDateString(day);
  });
  const nextRelease = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
  const countdown = countdownDuration(Math.max(0, Math.ceil((nextRelease.getTime() - now.getTime()) / 1000)));
  const historyTable = <section className="anagram-history"><h3>LAST 14 DAYS</h3><div className="anagram-history__table"><div className="anagram-history__row anagram-history__heading"><span>Date</span><span>Score</span><span>Time</span></div>
    {releaseDays.map((date) => {
      const record = historyByDate.get(date);
      const isToday = date === localDateString(now);
      const completedOnRelease = record?.completedAt
        ? localDateString(new Date(record.completedAt)) === date
        : false;
      const result = record?.outcome === "solved"
        ? duration(record.elapsedSecondsAtCompletion ?? 0)
        : "–";
      const outcome = record?.outcome === "solved"
        ? "SOLVED"
        : record?.outcome === "gave_up" && completedOnRelease
          ? "GAVE UP"
          : null;
      const score = record?.releaseDateScore ?? 0;
      return <div className="anagram-history__row" key={date}>
        <span className="anagram-history__date"><time dateTime={date}>{historyDate(date)}</time>{isToday ? <small>TODAY</small> : null}{outcome ? <small>{outcome}</small> : null}</span>
        <strong className={`anagram-score-chip${score > 0 ? " is-earned" : ""}`}>{score}</strong>
        <span className={record?.outcome === "solved" ? "is-solved" : ""}>{result}</span>
      </div>;
    })}
  </div></section>;
  const ratingPercentage = Math.max(0, Math.min(100, (stats.rollingScore / 70) * 100));
  const ratingBar = <section aria-label={`${stats.rollingScore} of 70 Anagram points`} className="anagram-rating-section">
    <div className="anagram-rating"><span className="anagram-rating__fill" style={{ width: `${ratingPercentage}%` }} /><span aria-hidden="true" className="anagram-rating__marker" style={{ left: `${ratingPercentage}%` }} /></div>
    <strong>{stats.rollingScore}/70</strong>
  </section>;
  const statsSummary = <section aria-label="Anagram statistics summary" className="anagram-stats">
    <div className="anagram-stats__primary"><span><strong>{stats.streak}</strong><small>Current<br />Streak</small></span><span><strong>{stats.solved}</strong><small>Total<br />Solved</small></span><span><strong>{stats.bestStreak}</strong><small>Best<br />Streak</small></span></div>
    <span className="anagram-stats__average"><strong>{stats.averageSeconds === null ? "–" : duration(stats.averageSeconds)}</strong><small>Avg Time</small></span>
  </section>;
  const backdropModifier = kind === "giveUp" || kind === "hint"
    ? " anagram-dialog-backdrop--centered"
    : kind === "stats" || kind === "instructions" || kind === "result"
      ? " anagram-dialog-backdrop--stats"
      : "";
  return <div className={`anagram-dialog-backdrop${backdropModifier}`} onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
    <section aria-label={kind === "result" && progress && puzzle ? anagramCompletionTitle(progress, puzzle) : kind === "stats" ? "Anagram stats" : kind === "instructions" ? "How to Play" : kind === "hint" ? "Reveal a letter" : "Give up"} aria-modal="true" className={`anagram-dialog${kind === "stats" ? " anagram-dialog--stats" : kind === "instructions" ? " anagram-dialog--instructions" : kind === "result" ? " anagram-dialog--completion" : ""}`} role="dialog">
      {kind !== "result" ? <button aria-label={kind === "stats" ? "Close Anagram stats" : kind === "instructions" ? "Close How to Play" : "Close"} className="anagram-dialog-close" onClick={onClose} ref={closeRef} type="button">×</button> : null}
      {kind === "instructions" ? <><header className="anagram-instructions-header"><h2>How to Play</h2></header><div className="anagram-instructions-scroll"><AnagramInstructions /></div></> : null}
      {kind === "hint" ? <><h2>Reveal a letter?</h2><p>Your placed letters will return to the tray and Undo history will clear. One correct letter will lock in place. A 30 second scoring penalty applies; the timer keeps running.</p><button className="anagram-primary" onClick={onConfirmHint} type="button">Reveal letter (+30s)</button><button onClick={onClose} type="button">Cancel</button></> : null}
      {kind === "giveUp" ? <><h2>Give up?</h2><p>This ends today’s attempt for zero points and reveals the answer. You cannot replay it for a higher score.</p><button className="anagram-primary" onClick={onConfirmGiveUp} type="button">Give up and reveal</button><button onClick={onClose} type="button">Keep playing</button></> : null}
      {kind === "stats" ? <><header className="anagram-stats-header"><h2>Anagram Stats</h2></header><div className="anagram-stats-scroll">{ratingBar}{statsSummary}{historyTable}</div></> : null}
      {kind === "result" && progress && puzzle ? <AnagramCompletion countdown={countdown} historyTable={historyTable} onClose={onClose} progress={progress} puzzle={puzzle} ratingBar={ratingBar} shareResult={shareResult} statsSummary={statsSummary} /> : null}
    </section>
  </div>;
}
