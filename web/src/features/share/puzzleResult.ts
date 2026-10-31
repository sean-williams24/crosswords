import { brand } from "../brand/brand";
import { backwordScore } from "../backword/engine";
import { elapsedSeconds, type AnagramProgress, type AnagramPuzzle } from "../anagram/engine";
import type { BackwordProgress, BackwordStats, BackwordWord } from "../backword/types";
import { completedInReleaseWindow, formatDuration, type WeeklyCrosswordStats } from "../crossword/engine";
import type { CrosswordKind, CrosswordProgress, CrosswordPuzzle, CrosswordStats } from "../crossword/types";
import type { PlayerProfileRating } from "../profile/profileRating";
import type { MidwordProgress, MidwordPuzzle, MidwordStats } from "../midword/engine";

export type ShareGame = "backword" | "daily_crossword" | "weekly_crossword" | "anagram" | "midword";

export type PuzzleShareResult = {
  game: ShareGame;
  gameName: string;
  issueNumber: number;
  date: string;
  outcome: "SOLVED" | "COMPLETED";
  score: number;
  streak: number;
  totalGamesSolved: number;
  ratingTier: string;
  ratingPoints: number;
  ratingMaxPoints: number;
  primaryStat: { label: string; value: string };
  timeStat: { label: string; value: string } | null;
  url: string;
  caption: string;
};

function gamePath(game: ShareGame, date: string) {
  switch (game) {
    case "backword": return `/backword/${date}`;
    case "daily_crossword": return `/crossword/${date}`;
    case "weekly_crossword": return `/weekly-crossword/${date}`;
    case "anagram": return `/anagram/${date}`;
    case "midword": return `/midword/${date}`;
  }
}

export function buildMidwordShareResult({ puzzle, progress, stats, rating, origin }: {
  puzzle: MidwordPuzzle; progress: MidwordProgress; stats: MidwordStats;
  rating: PlayerProfileRating; origin?: string;
}): PuzzleShareResult {
  return withCaption({
    game: "midword", gameName: "Midword", issueNumber: puzzle.puzzleNumber, date: progress.date,
    outcome: progress.outcome === "won" ? "SOLVED" : "COMPLETED", score: progress.releaseDateScore,
    streak: stats.currentStreak, totalGamesSolved: stats.totalSolved,
    ratingTier: rating.tier, ratingPoints: rating.totalPoints, ratingMaxPoints: rating.maxPoints,
    primaryStat: { label: "GUESSES", value: `${progress.guesses.length}/5` }, timeStat: null,
    url: shareUrl("midword", progress.date, origin)
  });
}

export function buildAnagramShareResult({ puzzle, progress, stats, rating, origin }: {
  puzzle: Pick<AnagramPuzzle, "puzzleNumber">;
  progress: AnagramProgress;
  stats: { solved: number; streak: number };
  rating: PlayerProfileRating;
  origin?: string;
}): PuzzleShareResult {
  return withCaption({
    game: "anagram", gameName: "Anagram", issueNumber: puzzle.puzzleNumber,
    date: progress.date, outcome: progress.outcome === "solved" ? "SOLVED" : "COMPLETED",
    score: progress.releaseDateScore, streak: stats.streak, totalGamesSolved: stats.solved,
    ratingTier: rating.tier, ratingPoints: rating.totalPoints, ratingMaxPoints: rating.maxPoints,
    primaryStat: { label: "SOLVE TIME", value: formatDuration(elapsedSeconds(progress)) },
    timeStat: { label: "PENALTY", value: `+${formatDuration(progress.penaltySeconds)}` },
    url: shareUrl("anagram", progress.date, origin)
  });
}

export function shareUrl(game: ShareGame, date: string, origin: string = brand.origin): string {
  const url = new URL(gamePath(game, date), origin);
  url.searchParams.set("utm_source", "share");
  url.searchParams.set("utm_medium", "social");
  url.searchParams.set("utm_campaign", "completed_puzzle");
  return url.toString();
}

export function formatCompletionTime(completedAt: string | null): string {
  if (!completedAt || Number.isNaN(new Date(completedAt).getTime())) return "—";
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23" }).format(new Date(completedAt));
}

function resultCaption(result: Omit<PuzzleShareResult, "caption">): string {
  const stats = [
    `${result.score} ${result.score === 1 ? "pt" : "pts"}`,
    result.primaryStat.value,
    `${result.ratingTier} · ${result.ratingPoints}/${result.ratingMaxPoints} pts`
  ];
  if (result.timeStat) stats.splice(2, 0, result.timeStat.value);
  return `${result.outcome === "SOLVED" ? "I solved" : "I completed"} ${result.gameName} #${result.issueNumber}\n${stats.join(" · ")}\nPlay: ${result.url}`;
}

function withCaption(result: Omit<PuzzleShareResult, "caption">): PuzzleShareResult {
  return { ...result, caption: resultCaption(result) };
}

export function buildBackwordShareResult({
  progress,
  stats,
  word,
  rating,
  origin
}: {
  progress: BackwordProgress;
  stats: BackwordStats;
  word: Pick<BackwordWord, "puzzleNumber">;
  rating: PlayerProfileRating;
  origin?: string;
}): PuzzleShareResult {
  return withCaption({
    game: "backword",
    gameName: "Backword",
    issueNumber: word.puzzleNumber,
    date: progress.date,
    outcome: progress.outcome === "won" ? "SOLVED" : "COMPLETED",
    score: backwordScore(progress),
    streak: stats.currentStreak,
    totalGamesSolved: stats.gamesWon,
    ratingTier: rating.tier,
    ratingPoints: rating.totalPoints,
    ratingMaxPoints: rating.maxPoints,
    primaryStat: { label: "ATTEMPTS", value: `${progress.guesses.length} / 5` },
    timeStat: { label: "COMPLETED AT", value: formatCompletionTime(progress.completedAt) },
    url: shareUrl("backword", progress.date, origin)
  });
}

export function buildCrosswordShareResult({
  progress,
  puzzle,
  stats,
  kind,
  rating,
  origin
}: {
  progress: CrosswordProgress;
  puzzle: Pick<CrosswordPuzzle, "puzzleNumber">;
  stats: CrosswordStats | WeeklyCrosswordStats;
  kind: CrosswordKind;
  rating: PlayerProfileRating;
  origin?: string;
}): PuzzleShareResult {
  const completedAt = new Date(progress.completedAt ?? "").getTime();
  const startedAt = new Date(progress.startedAt).getTime();
  const solveSeconds = Number.isFinite(completedAt - startedAt)
    ? Math.max(0, Math.floor((completedAt - startedAt) / 1_000))
    : null;
  const game = kind === "weekly" ? "weekly_crossword" : "daily_crossword";
  const onTime = completedInReleaseWindow(kind, progress.date, progress.completedAt);
  return withCaption({
    game,
    gameName: kind === "weekly" ? "Pro Crossword" : "Quick Crossword",
    issueNumber: puzzle.puzzleNumber,
    date: progress.date,
    outcome: "SOLVED",
    score: onTime ? progress.releaseDateScore : 0,
    streak: stats.currentStreak,
    totalGamesSolved: stats.totalSolved,
    ratingTier: rating.tier,
    ratingPoints: rating.totalPoints,
    ratingMaxPoints: rating.maxPoints,
    primaryStat: { label: "SOLVE TIME", value: formatDuration(solveSeconds) },
    timeStat: null,
    url: shareUrl(game, progress.date, origin)
  });
}
