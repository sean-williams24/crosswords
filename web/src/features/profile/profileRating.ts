import { localDateOffset, localDateString } from "../backword/date";
import { backwordScore } from "../backword/engine";
import type { BackwordProgress } from "../backword/types";
import type { CloudRecord } from "../sync/progressSync";

const windowDays = 14;
const tierThresholds = [
  ["Novice", 0],
  ["Scribe", 0.2],
  ["Linguist", 0.5],
  ["Grandmaster", 0.75],
  ["Virtuoso", 0.9]
] as const;

export type RatingTierName = (typeof tierThresholds)[number][0];

export type PlayerProfileDay = {
  date: string;
  dailyCrossword: number;
  weeklyCrossword: number | null;
  backword: number;
  total: number;
};

export type PlayerProfileRating = {
  days: PlayerProfileDay[];
  maxPoints: number;
  totalPoints: number;
  fraction: number;
  tier: RatingTierName;
};

type ProfileProgress = Pick<CloudRecord<unknown>, "release_date" | "release_score">;
type BackwordProfileProgress = ProfileProgress & { payload?: unknown };

function validScore(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 5;
}

function scoreMap(records: ProfileProgress[], dates: Set<string>) {
  return records.reduce((scores, record) => {
    if (!dates.has(record.release_date) || !validScore(record.release_score)) return scores;
    scores.set(record.release_date, Math.max(scores.get(record.release_date) ?? 0, record.release_score));
    return scores;
  }, new Map<string, number>());
}

function isBackwordProgress(value: unknown): value is BackwordProgress {
  if (!value || typeof value !== "object") return false;
  const progress = value as Partial<BackwordProgress>;
  return (
    progress.schemaVersion === 1 &&
    typeof progress.date === "string" &&
    Array.isArray(progress.guesses) &&
    progress.guesses.every((guess) => typeof guess === "string") &&
    (progress.outcome === "inProgress" || progress.outcome === "won" || progress.outcome === "failed") &&
    (progress.completedAt === null || typeof progress.completedAt === "string")
  );
}

/**
 * Backword payloads retain the completion time needed to distinguish a daily
 * result from Archive play. Treat that canonical game state as authoritative
 * over older rows whose stored release_score was calculated incorrectly.
 */
function backwordScoreMap(records: BackwordProfileProgress[], dates: Set<string>) {
  return records.reduce((scores, record) => {
    if (!dates.has(record.release_date)) return scores;
    const score = isBackwordProgress(record.payload)
      ? backwordScore(record.payload)
      : record.release_score;
    if (!validScore(score)) return scores;
    scores.set(record.release_date, Math.max(scores.get(record.release_date) ?? 0, score));
    return scores;
  }, new Map<string, number>());
}

export function buildPlayerProfileRating(
  records: {
    backword: ProfileProgress[];
    dailyCrossword: ProfileProgress[];
    weeklyCrossword: ProfileProgress[];
  },
  isPro: boolean,
  now = new Date()
): PlayerProfileRating {
  const today = localDateString(now);
  const dates = Array.from({ length: windowDays }, (_, offset) => localDateOffset(today, -offset));
  const visibleDates = new Set(dates);
  const dailyScores = scoreMap(records.dailyCrossword, visibleDates);
  const backwordScores = backwordScoreMap(records.backword, visibleDates);
  const weeklyScores = scoreMap(records.weeklyCrossword, visibleDates);
  const days = dates.map((date) => {
    const dailyCrossword = dailyScores.get(date) ?? 0;
    const backword = backwordScores.get(date) ?? 0;
    const weeklyCrossword = isPro ? weeklyScores.get(date) ?? null : null;
    return {
      date,
      dailyCrossword,
      weeklyCrossword,
      backword,
      total: dailyCrossword + backword + (weeklyCrossword ?? 0)
    };
  });
  const maxPoints = 140 + (isPro ? 10 : 0);
  const totalPoints = days.reduce((total, day) => total + day.total, 0);
  const fraction = Math.min(totalPoints / maxPoints, 1);
  const tier = [...tierThresholds].reverse().find(([, threshold]) => fraction >= threshold)?.[0] ?? "Novice";

  return { days, maxPoints, totalPoints, fraction, tier };
}

export function formatProfileDate(dateString: string) {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Intl.DateTimeFormat(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric"
  }).format(new Date(year, month - 1, day, 12));
}
