import { Link } from "react-router-dom";
import { backwordDashboardStatus } from "../home/backwordStatus";
import { crosswordDashboardStatus, weeklyCrosswordDashboardStatus } from "../crossword/engine";
import { createCrosswordStorage } from "../crossword/storage";
import type { CrosswordPuzzle } from "../crossword/types";
import type { BackwordWord } from "../backword/types";

export type ArchiveGameType = "backword" | "daily" | "weekly";

type ArchiveEntryCardProps = {
  gameType: ArchiveGameType;
  item: BackwordWord | CrosswordPuzzle;
  userId?: string;
};

function formattedDate(date: string) {
  return new Intl.DateTimeFormat("en-US", {
    weekday: "long",
    month: "short",
    day: "numeric"
  }).format(new Date(`${date}T12:00:00`));
}

function destination(gameType: ArchiveGameType, date: string) {
  switch (gameType) {
    case "backword": return `/backword/${date}`;
    case "daily": return `/crossword/${date}`;
    case "weekly": return `/weekly-crossword/${date}`;
  }
}

export function ArchiveEntryCard({ gameType, item, userId }: ArchiveEntryCardProps) {
  const isBackword = gameType === "backword";
  const word = isBackword ? item as BackwordWord : null;
  const puzzle = isBackword ? null : item as CrosswordPuzzle;
  const storage = puzzle ? createCrosswordStorage(window.localStorage, { kind: gameType === "weekly" ? "weekly" : "daily", userId }) : null;
  const progress = puzzle && storage ? storage.loadProgress(puzzle) : null;
  const status = word
    ? backwordDashboardStatus(window.localStorage, word.date, userId)
    : gameType === "weekly"
      ? weeklyCrosswordDashboardStatus(progress, new Date(), storage?.loadAllProgress())
      : crosswordDashboardStatus(progress, new Date(), storage?.loadAllProgress());
  const progressFraction = puzzle && progress
    ? progress.entries.flat().filter((entry) => entry !== null).length /
      Math.max(1, puzzle.cells.flat().filter((cell) => cell.letter !== null).length)
    : 0;

  return (
    <Link aria-label={`${formattedDate(item.date)}, ${status.label}`} className={`archive-entry-card archive-entry-card--${gameType}`} to={destination(gameType, item.date)}>
      <div className="archive-entry-card__main">
        <p>{isBackword ? "BACKWORD" : gameType === "weekly" ? "PRO CROSSWORD" : "QUICK CROSSWORD"}</p>
        <h3>{word ? word.clue.toUpperCase() : `#${puzzle?.puzzleNumber}`}</h3>
        <time dateTime={item.date}>{formattedDate(item.date)}</time>
      </div>
      <div className="archive-entry-card__status">
        <span className={`home-status home-status--${status.tone}`}>{status.label}</span>
        {"score" in status && status.score !== null ? <strong>{status.score}/5</strong> : null}
      </div>
      {progressFraction > 0 && progressFraction < 1 ? (
        <span aria-label={`${Math.round(progressFraction * 100)}% complete`} className="archive-entry-card__progress"><i style={{ width: `${progressFraction * 100}%` }} /></span>
      ) : null}
    </Link>
  );
}
