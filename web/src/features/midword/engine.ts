import { isCompletedOnReleaseDate, isLocalDateString, localDateOffset, localDateString } from "../backword/date";
import type { DashboardStatus } from "../home/backwordStatus";
import { midwordLaunchDate } from "../profile/profileRating";

export type MidwordPuzzle = {
  id: string; date: string; puzzleNumber: number;
  firstWord: string; secondWord: string; answer: string; alternatives: string[];
};

/** Same fields as the native cloud payload, including omitted unfinished timestamps. */
export type MidwordProgress = {
  date: string; guesses: string[]; completedAt: string | null;
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
  if (!isLocalDateString(p.date) || !Array.isArray(p.guesses) || p.guesses.length > 5
    || !p.guesses.every((guess) => typeof guess === "string" && /^[A-Z]{3,6}$/.test(guess))
    || new Set(p.guesses).size !== p.guesses.length || p.schemaVersion !== 1 || !["inProgress", "won", "failed"].includes(p.outcome)
    || !Number.isInteger(p.releaseDateScore) || p.releaseDateScore < 0 || p.releaseDateScore > 5
    || (completedAt !== null && (typeof completedAt !== "string" || !Number.isFinite(Date.parse(completedAt))))
    || typeof p.updatedAt !== "string" || !Number.isFinite(Date.parse(p.updatedAt))
    || (completedAt === null && (p.outcome !== "inProgress" || p.guesses.length === 5))
    || (completedAt !== null && p.outcome === "inProgress")
    || (completedAt !== null && (!p.guesses.length || (p.outcome !== "won" && p.guesses.length !== 5)))) return null;
  return { date: p.date, guesses: [...p.guesses], completedAt, schemaVersion: 1, outcome: p.outcome,
    releaseDateScore: p.releaseDateScore, updatedAt: p.updatedAt };
}

export function emptyProgress(date: string, now = new Date()): MidwordProgress {
  return { date, guesses: [], completedAt: null, schemaVersion: 1, outcome: "inProgress", releaseDateScore: 0, updatedAt: now.toISOString() };
}

export function accepts(puzzle: MidwordPuzzle, guess: string): boolean {
  return guess === puzzle.answer || puzzle.alternatives.includes(guess);
}

export function submitGuess(progress: MidwordProgress, puzzle: MidwordPuzzle, input: string,
  isValidWord: (word: string) => boolean, now = new Date()): { progress: MidwordProgress; message: string | null } {
  const unchanged = (message: string | null) => ({ progress, message });
  const guess = input.toUpperCase();
  if (progress.completedAt || progress.date !== puzzle.date || progress.guesses.length >= 5
    || guess.length !== puzzle.answer.length || !/^[A-Z]+$/.test(guess)) return unchanged(null);
  if (progress.guesses.includes(guess)) return unchanged("Already guessed");
  const won = accepts(puzzle, guess);
  if (!won && (new Set(guess).size === 1 || !isValidWord(guess))) return unchanged("Not a valid word");
  const guesses = [...progress.guesses, guess];
  const completedAt = won || guesses.length === 5 ? now.toISOString() : null;
  return { progress: { ...progress, guesses, outcome: won ? "won" : completedAt ? "failed" : "inProgress", completedAt, updatedAt: now.toISOString(),
    releaseDateScore: won && localDateString(now) === puzzle.date ? 6 - guesses.length : 0 }, message: null };
}

export function midwordStatus(progress: MidwordProgress | null): DashboardStatus {
  if (progress?.completedAt) return progress.outcome === "won"
    ? { label: isCompletedOnReleaseDate(progress.date, progress.completedAt) ? "Solved" : "Finished", tone: "solved" }
    : { label: "Failed", tone: "failed" };
  return progress?.guesses.length ? { label: "In Progress", tone: "progress" } : { label: "New", tone: "new" };
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
        guessCount: eligible(p) ? p!.guesses.length : null };
    });
  return { totalSolved: solved.length, currentStreak, bestStreak, rows,
    rollingScore: rows.reduce((sum, row) => sum + row.score, 0),
    guessDistribution: Array.from({ length: 5 }, (_, index) => solved.filter((p) => p.guesses.length === index + 1).length) };
}

export type MidwordStats = ReturnType<typeof midwordStats>;
