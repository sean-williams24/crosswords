import { isCompletedOnReleaseDate, isLocalDateString, localDateOffset, localDateString } from "../backword/date";
import type { DashboardStatus } from "../home/backwordStatus";
import { midwordLaunchDate } from "../profile/profileRating";

export type MidwordPuzzle = {
  id: string; date: string; puzzleNumber: number;
  firstWord: string; secondWord: string; answer: string; alternatives: string[];
};

/** Same fields as the native cloud payload, including omitted unfinished timestamps. */
export type MidwordProgress = {
  date: string; guesses: string[]; startedAt?: string | null; elapsedSecondsAtCompletion?: number | null; completedAt: string | null;
  schemaVersion: 1; outcome: "inProgress" | "won" | "failed"; releaseDateScore: number; updatedAt: string;
};

export function validPuzzle(value: unknown): value is MidwordPuzzle {
  if (!value || typeof value !== "object") return false;
  const p = value as MidwordPuzzle;
  return typeof p.id === "string" && p.id.length > 0 && isLocalDateString(p.date)
    && Number.isInteger(p.puzzleNumber) && p.puzzleNumber > 0
    && typeof p.answer === "string" && /^[A-Z]{3,6}$/.test(p.answer)
    && [p.firstWord, p.secondWord].every((word) => typeof word === "string" && /^[A-Z]+$/.test(word))
    && Array.isArray(p.alternatives) && p.alternatives.every((word) => typeof word === "string"
      && /^[A-Z]+$/.test(word) && word.length === p.answer.length && word !== p.answer);
}

export function decodeProgress(value: unknown): MidwordProgress | null {
  if (!value || typeof value !== "object") return null;
  const p = value as MidwordProgress;
  const completedAt = p.completedAt ?? null;
  if (!isLocalDateString(p.date) || !Array.isArray(p.guesses)
    || !p.guesses.every((guess) => typeof guess === "string" && /^[A-Z]{3,6}$/.test(guess))
    || new Set(p.guesses).size !== p.guesses.length || p.schemaVersion !== 1 || !["inProgress", "won", "failed"].includes(p.outcome)
    || !Number.isInteger(p.releaseDateScore) || p.releaseDateScore < 0 || p.releaseDateScore > 5
    || (completedAt !== null && (typeof completedAt !== "string" || !Number.isFinite(Date.parse(completedAt))))
    || typeof p.updatedAt !== "string" || !Number.isFinite(Date.parse(p.updatedAt))
    || (completedAt === null && (p.outcome !== "inProgress"))
    || (completedAt !== null && p.outcome === "inProgress")
    || (completedAt !== null && p.outcome === "won" && !p.guesses.length)
    || (p.startedAt != null && (typeof p.startedAt !== "string" || !Number.isFinite(Date.parse(p.startedAt))))
    || (p.elapsedSecondsAtCompletion != null && (!Number.isInteger(p.elapsedSecondsAtCompletion) || p.elapsedSecondsAtCompletion < 0))) return null;
  return { date: p.date, guesses: [...p.guesses], completedAt, schemaVersion: 1, outcome: p.outcome,
    startedAt: p.startedAt ?? null, elapsedSecondsAtCompletion: p.elapsedSecondsAtCompletion ?? null,
    releaseDateScore: p.releaseDateScore, updatedAt: p.updatedAt };
}

export function emptyProgress(date: string, now = new Date()): MidwordProgress {
  return { date, guesses: [], completedAt: null, schemaVersion: 1, outcome: "inProgress", releaseDateScore: 0, updatedAt: now.toISOString() };
}

export const timeBands = ["Under 30 seconds", "Under 60 seconds", "Under 120 seconds", "Under 180 seconds", "180 seconds or more"];
export function pointsForSeconds(seconds: number): number {
  return seconds < 30 ? 5 : seconds < 60 ? 4 : seconds < 120 ? 3 : seconds < 180 ? 2 : 1;
}
export function elapsedSeconds(progress: MidwordProgress, now = new Date()): number {
  return progress.elapsedSecondsAtCompletion ?? (progress.startedAt ? Math.max(0, Math.floor((now.getTime() - Date.parse(progress.startedAt)) / 1000)) : 0);
}
export function formatTime(seconds: number | null | undefined): string {
  if (seconds == null) return "–";
  return [Math.floor(seconds / 3600), Math.floor(seconds / 60) % 60, seconds % 60].map(n => String(n).padStart(2, "0")).join(":");
}
export function startProgress(progress: MidwordProgress, now = new Date()): MidwordProgress {
  return progress.completedAt || progress.startedAt ? progress : { ...progress, startedAt: now.toISOString(), updatedAt: now.toISOString() };
}
export function giveUp(progress: MidwordProgress, now = new Date()): MidwordProgress {
  return progress.completedAt || !progress.startedAt ? progress : { ...progress, outcome: "failed", completedAt: now.toISOString(),
    elapsedSecondsAtCompletion: elapsedSeconds(progress, now), updatedAt: now.toISOString(), releaseDateScore: 0 };
}
export function mergeProgress(a: MidwordProgress, b: MidwordProgress): MidwordProgress {
  const starts = [a.startedAt, b.startedAt].filter((s): s is string => !!s).sort((x, y) => Date.parse(x) - Date.parse(y));
  const legacy = [a, b].filter(p => p.completedAt && !p.startedAt && (!starts.length || Date.parse(p.completedAt) <= Date.parse(starts[0]))).sort((x, y) => y.releaseDateScore - x.releaseDateScore);
  if (legacy.length) return legacy[0];
  const candidates = [a, b].filter(p => !starts.length || p.startedAt);
  const terminal = candidates.filter(p => p.completedAt).sort((x, y) => Date.parse(x.completedAt!) - Date.parse(y.completedAt!));
  const chosen = terminal[0] ?? candidates.sort((x, y) => Number(!!y.startedAt) - Number(!!x.startedAt)
    || y.guesses.length - x.guesses.length || Date.parse(y.updatedAt) - Date.parse(x.updatedAt))[0];
  const result = { ...chosen, startedAt: starts[0] ?? null };
  if (result.completedAt && result.startedAt) {
    result.elapsedSecondsAtCompletion = Math.max(0, Math.floor((Date.parse(result.completedAt) - Date.parse(result.startedAt)) / 1000));
    result.releaseDateScore = result.outcome === "won" && result.releaseDateScore > 0 ? pointsForSeconds(result.elapsedSecondsAtCompletion) : 0;
  }
  return result;
}

export function accepts(puzzle: MidwordPuzzle, guess: string): boolean {
  return guess === puzzle.answer || puzzle.alternatives.includes(guess);
}

export function submitGuess(progress: MidwordProgress, puzzle: MidwordPuzzle, input: string,
  isValidWord: (word: string) => boolean, now = new Date()): { progress: MidwordProgress; message: string | null } {
  const unchanged = (message: string | null) => ({ progress, message });
  const guess = input.toUpperCase();
  if (progress.completedAt || progress.date !== puzzle.date || !progress.startedAt
    || guess.length !== puzzle.answer.length || !/^[A-Z]+$/.test(guess)) return unchanged(null);
  if (progress.guesses.includes(guess)) return unchanged("Already guessed");
  const won = accepts(puzzle, guess);
  if (!won && (new Set(guess).size === 1 || !isValidWord(guess))) return unchanged("Not a valid word");
  const guesses = [...progress.guesses, guess];
  const completedAt = won ? now.toISOString() : null;
  return { progress: { ...progress, guesses, outcome: won ? "won" : completedAt ? "failed" : "inProgress", completedAt, updatedAt: now.toISOString(),
    elapsedSecondsAtCompletion: won ? elapsedSeconds(progress, now) : null,
    releaseDateScore: won && localDateString(now) === puzzle.date ? pointsForSeconds(elapsedSeconds(progress, now)) : 0 }, message: null };
}

export function midwordStatus(progress: MidwordProgress | null): DashboardStatus {
  if (progress?.completedAt) return progress.outcome === "won"
    ? { label: isCompletedOnReleaseDate(progress.date, progress.completedAt) ? "Solved" : "Finished", tone: "solved" }
    : { label: "Failed", tone: "failed" };
  return progress?.startedAt || progress?.guesses.length ? { label: "In Progress", tone: "progress" } : { label: "New", tone: "new" };
}

export function midwordStats(records: MidwordProgress[], now = new Date()) {
  const today = localDateString(now);
  const byDate = new Map<string, MidwordProgress>();
  for (const record of records) {
    if (record.date < midwordLaunchDate || record.date > today) continue;
    const previous = byDate.get(record.date);
    if (!previous || Date.parse(record.updatedAt) > Date.parse(previous.updatedAt)) byDate.set(record.date, record);
  }
  // The snapshot records release-day eligibility at play time and survives
  // timezone changes and whole-record merges with a later archive attempt.
  const eligible = (p?: MidwordProgress) => p?.outcome === "won" && !!p.completedAt && p.releaseDateScore > 0;
  const solved = [...byDate.values()].filter(eligible).sort((a, b) => a.date.localeCompare(b.date));
  const solvedDates = new Set(solved.map((p) => p.date));
  let bestStreak = 0, run = 0;
  solved.forEach((p, index) => {
    run = index > 0 && solved[index - 1].date === localDateOffset(p.date, -1) ? run + 1 : 1;
    bestStreak = Math.max(bestStreak, run);
  });
  let currentStreak = 0;
  if (!(byDate.get(today)?.completedAt && byDate.get(today)?.outcome === "failed")) {
    let date = solvedDates.has(today) ? today : localDateOffset(today, -1);
    while (solvedDates.has(date)) { currentStreak++; date = localDateOffset(date, -1); }
  }
  const rows = Array.from({ length: 14 }, (_, offset) => localDateOffset(today, -offset))
    .filter((date) => date >= midwordLaunchDate).map((date) => {
      const p = byDate.get(date);
      const onTime = p && isCompletedOnReleaseDate(date, p.completedAt);
      const outcome = eligible(p) ? "solved" : onTime && p?.outcome === "failed" ? "failed"
        : date === today && p && !p.completedAt ? "inProgress" : "unplayed";
      return { date, outcome, score: eligible(p) ? p!.releaseDateScore : 0,
        elapsedSeconds: eligible(p) ? p!.elapsedSecondsAtCompletion ?? null : null };
    });
  return { totalSolved: solved.length, currentStreak, bestStreak, rows,
    rollingScore: rows.reduce((sum, row) => sum + row.score, 0),
    timeDistribution: Array.from({ length: 5 }, (_, index) => solved.filter((p) => p.elapsedSecondsAtCompletion != null && pointsForSeconds(p.elapsedSecondsAtCompletion) === 5 - index).length) };
}

export type MidwordStats = ReturnType<typeof midwordStats>;
