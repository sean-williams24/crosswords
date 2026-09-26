import { useEffect, useRef } from "react";
import { PuzzleResultShare } from "../share/PuzzleResultShare";
import { localDateString } from "../backword/date";
import type { PuzzleShareResult } from "../share/puzzleResult";
import { answerText, availableTileIDs, elapsedSeconds, type AnagramProgress, type AnagramPuzzle } from "./engine";

type Stats = { solved: number; played: number; streak: number; bestStreak: number; rollingScore: number };

function duration(seconds: number) {
  if (seconds >= 3600) return `${Math.floor(seconds / 3600)}:${String(Math.floor((seconds % 3600) / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, "0")}`;
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

export function AnagramDialog({ kind, onClose, onStart, onConfirmHint, onConfirmGiveUp, progress, puzzle, shareResult, stats, history, now }: {
  kind: "instructions" | "hint" | "giveUp" | "stats" | "result";
  onClose: () => void; onStart: () => void; onConfirmHint: () => void; onConfirmGiveUp: () => void;
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
  const countdown = duration(Math.max(0, Math.ceil((nextRelease.getTime() - now.getTime()) / 1000)));
  const historyTable = <div className="anagram-history"><h3>Last 14 days</h3><div className="anagram-history__row anagram-history__heading"><span>Date</span><span>Score</span><span>Time</span></div>
    {releaseDays.map((date) => {
      const record = historyByDate.get(date);
      const completedOnRelease = record?.completedAt
        ? localDateString(new Date(record.completedAt)) === date
        : false;
      const result = record?.outcome === "solved" && record.releaseDateScore > 0
        ? duration(record.elapsedSecondsAtCompletion ?? 0)
        : record?.outcome === "gave_up" && completedOnRelease
          ? "Gave up"
          : record?.outcome === null && date === localDateString(now)
            ? "In progress"
            : "—";
      return <div className="anagram-history__row" key={date}><time dateTime={date}>{date}</time><strong>{record?.releaseDateScore ?? 0}/5</strong><span>{result}</span></div>;
    })}
  </div>;
  const ratingBar = <div aria-label={`${stats.rollingScore} of 70 Anagram points`} className="anagram-rating"><span style={{ width: `${(stats.rollingScore / 70) * 100}%` }} /></div>;
  const statsSummary = <div className="anagram-stats"><span>Current streak <strong>{stats.streak}</strong></span><span>Total solved <strong>{stats.solved}</strong></span><span>Best streak <strong>{stats.bestStreak}</strong></span><span>Average solve <strong>{stats.averageSeconds === null ? "—" : duration(stats.averageSeconds)}</strong></span></div>;
  return <div className={`anagram-dialog-backdrop${kind === "giveUp" ? " anagram-dialog-backdrop--centered" : ""}`} onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
    <section aria-label={kind === "result" ? "Anagram result" : kind === "stats" ? "Anagram stats" : kind === "instructions" ? "How to play Anagram" : kind === "hint" ? "Reveal a letter" : "Give up"} aria-modal="true" className="anagram-dialog" role="dialog">
      <button aria-label="Close" className="anagram-dialog-close" onClick={onClose} ref={closeRef} type="button">×</button>
      {kind === "instructions" ? <><h2>How to play Anagram</h2><p>Tap the scrambled letters to make a 7–9 letter word. They fill the first empty answer cell from left to right.</p><p>Undo removes your most recent letter. Restart returns all letters you placed. Shuffle rearranges the tray. Your timer continues throughout.</p><p>You can reveal one letter. It clears your placed letters, locks the revealed letter, and adds 30 seconds to your scoring time.</p><p>Finish with an accepted answer before 30 seconds for 5 points. You can keep playing for as long as you like.</p>{!progress ? <button className="anagram-primary" onClick={onStart} type="button">Start</button> : null}</> : null}
      {kind === "hint" ? <><h2>Reveal a letter?</h2><p>Your placed letters will return to the tray and Undo history will clear. One correct letter will lock in place. A 30 second scoring penalty applies; the timer keeps running.</p><button className="anagram-primary" onClick={onConfirmHint} type="button">Reveal letter (+30s)</button><button onClick={onClose} type="button">Cancel</button></> : null}
      {kind === "giveUp" ? <><h2>Give up?</h2><p>This ends today’s attempt for zero points and reveals the answer. You cannot replay it for a higher score.</p><button className="anagram-primary" onClick={onConfirmGiveUp} type="button">Give up and reveal</button><button onClick={onClose} type="button">Keep playing</button></> : null}
      {kind === "stats" ? <><h2>Anagram stats</h2>{statsSummary}
        <p className="anagram-stats-total">Last 14 days: <strong>{stats.rollingScore} / 70</strong> points</p>
        {ratingBar}{historyTable}</> : null}
      {kind === "result" && progress && puzzle ? <><h2>{progress.outcome === "solved" ? "Anagram solved" : "Anagram complete"}</h2>
        <p className="anagram-result-answer">{progress.outcome === "solved" ? answerText(progress, puzzle) : puzzle.answer}</p>
        <div className="anagram-stats anagram-completion-stats"><span>Elapsed <strong>{duration(progress.elapsedSecondsAtCompletion ?? 0)}</strong></span><span>Penalty <strong>+{progress.penaltySeconds}s</strong></span><span>Points <strong>{progress.releaseDateScore}/5</strong></span></div>
        <p className="anagram-stats-total">Next Anagram in {countdown}</p>{ratingBar}
        {shareResult ? <PuzzleResultShare result={shareResult} showPreview={false} /> : null}{statsSummary}{historyTable}</> : null}
    </section>
  </div>;
}
