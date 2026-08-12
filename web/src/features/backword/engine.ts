import {
  isCompletedOnReleaseDate,
  localDateOffset,
  localDateString
} from "./date";
import type {
  BackwordHistoryRow,
  BackwordMode,
  BackwordProgress,
  BackwordStats
} from "./types";

export const BACKWORD_LENGTH = 6;
export const MAX_GUESSES = 5;
export const BACKWORD_RULES_VERSION = 2;

export function emptyProgress(date: string): BackwordProgress {
  return {
    schemaVersion: 1,
    date,
    guesses: [],
    completedAt: null,
    outcome: "inProgress",
    updatedAt: new Date().toISOString()
  };
}

export function sanitizeInput(value: string, maximumLength: number): string {
  return value.toUpperCase().replace(/[^A-Z]/g, "").slice(0, maximumLength);
}

export function matchingSuffixLength(guess: string, answer: string): number {
  const normalizedGuess = guess.toUpperCase();
  const normalizedAnswer = answer.toUpperCase();
  if (
    normalizedGuess.length !== BACKWORD_LENGTH ||
    normalizedAnswer.length !== BACKWORD_LENGTH
  ) {
    return 0;
  }

  let length = 0;
  for (let index = BACKWORD_LENGTH - 1; index >= 0; index -= 1) {
    if (normalizedGuess[index] !== normalizedAnswer[index]) {
      break;
    }
    length += 1;
  }
  return length;
}

export function revealedIndices(
  progress: BackwordProgress,
  answer: string,
  mode: BackwordMode
): Set<number> {
  if (progress.outcome === "failed") {
    return new Set(Array.from({ length: BACKWORD_LENGTH }, (_, index) => index));
  }

  const wrongGuesses =
    progress.outcome === "won" ? progress.guesses.slice(0, -1) : progress.guesses;
  let suffixLength = 1;

  if (mode === "easy") {
    suffixLength = Math.min(wrongGuesses.length + 1, BACKWORD_LENGTH - 1);
  } else if (wrongGuesses.length >= 3) {
    suffixLength = 3;
  } else if (wrongGuesses.length >= 2) {
    suffixLength = 2;
  }

  for (const guess of wrongGuesses) {
    suffixLength = Math.max(suffixLength, matchingSuffixLength(guess, answer));
  }

  return new Set(
    Array.from(
      { length: suffixLength },
      (_, offset) => BACKWORD_LENGTH - suffixLength + offset
    )
  );
}

export function unrevealedIndices(revealed: Set<number>): number[] {
  return Array.from({ length: BACKWORD_LENGTH }, (_, index) => index).filter(
    (index) => !revealed.has(index)
  );
}

export function buildGuess(
  typedInput: string,
  answer: string,
  revealed: Set<number>
): string | null {
  const typed = sanitizeInput(typedInput, BACKWORD_LENGTH);
  const target = answer.toUpperCase();
  const hidden = unrevealedIndices(revealed);
  if (target.length !== BACKWORD_LENGTH || typed.length !== hidden.length) {
    return null;
  }

  let typedIndex = 0;
  return Array.from(target)
    .map((letter, index) => {
      if (revealed.has(index)) {
        return letter;
      }
      const value = typed[typedIndex];
      typedIndex += 1;
      return value;
    })
    .join("");
}

export function submitGuess(
  progress: BackwordProgress,
  answer: string,
  typedInput: string,
  mode: BackwordMode,
  completedAt = new Date()
): BackwordProgress | null {
  if (progress.outcome !== "inProgress") {
    return null;
  }

  const guess = buildGuess(typedInput, answer, revealedIndices(progress, answer, mode));
  if (!guess) {
    return null;
  }

  const guesses = [...progress.guesses, guess];
  if (guess === answer.toUpperCase()) {
    return {
      ...progress,
      guesses,
      outcome: "won",
      completedAt: completedAt.toISOString(),
      updatedAt: completedAt.toISOString()
    };
  }

  if (guesses.length >= MAX_GUESSES) {
    return {
      ...progress,
      guesses,
      outcome: "failed",
      completedAt: completedAt.toISOString(),
      updatedAt: completedAt.toISOString()
    };
  }

  return { ...progress, guesses, updatedAt: completedAt.toISOString() };
}

export function backwordScore(progress: BackwordProgress): number {
  if (
    progress.outcome !== "won" ||
    !isCompletedOnReleaseDate(progress.date, progress.completedAt)
  ) {
    return 0;
  }
  return Math.max(0, 6 - progress.guesses.length);
}

export function connectedSuffixIndices(guess: string, answer: string): Set<number> {
  const suffixLength = matchingSuffixLength(guess, answer);
  return new Set(
    Array.from(
      { length: suffixLength },
      (_, offset) => BACKWORD_LENGTH - suffixLength + offset
    )
  );
}

function eligibleProgress(progress: BackwordProgress): boolean {
  return (
    progress.outcome !== "inProgress" &&
    isCompletedOnReleaseDate(progress.date, progress.completedAt)
  );
}

function calculateLongestStreak(progressRecords: BackwordProgress[]): number {
  const winningDates = progressRecords
    .filter((progress) => eligibleProgress(progress) && progress.outcome === "won")
    .map((progress) => progress.date)
    .sort();

  let longest = 0;
  let current = 0;
  let previous: string | null = null;
  for (const date of winningDates) {
    current = previous && localDateOffset(previous, 1) === date ? current + 1 : 1;
    longest = Math.max(longest, current);
    previous = date;
  }
  return longest;
}

function calculateCurrentStreak(
  progressRecords: BackwordProgress[],
  today: string
): number {
  const outcomes = new Map(
    progressRecords
      .filter(eligibleProgress)
      .map((progress) => [progress.date, progress.outcome] as const)
  );
  if (outcomes.get(today) === "failed") {
    return 0;
  }
  let cursor = outcomes.get(today) === "won" ? today : localDateOffset(today, -1);
  if (outcomes.get(cursor) !== "won") {
    return 0;
  }

  let streak = 0;
  while (outcomes.get(cursor) === "won") {
    streak += 1;
    cursor = localDateOffset(cursor, -1);
  }
  return streak;
}

export function deriveStats(
  progressRecords: BackwordProgress[],
  now = new Date()
): BackwordStats {
  const today = localDateString(now);
  const byDate = new Map(progressRecords.map((progress) => [progress.date, progress]));
  const eligible = progressRecords.filter(eligibleProgress);
  const wins = eligible.filter((progress) => progress.outcome === "won");
  const guessDistribution: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  for (const progress of wins) {
    guessDistribution[progress.guesses.length] =
      (guessDistribution[progress.guesses.length] ?? 0) + 1;
  }

  const history: BackwordHistoryRow[] = Array.from({ length: 14 }, (_, offset) => {
    const date = localDateOffset(today, -offset);
    const progress = byDate.get(date);
    return {
      date,
      isToday: offset === 0,
      score: progress ? backwordScore(progress) : 0,
      guessCount: progress ? progress.guesses.length : null,
      outcome: progress
        ? progress.outcome === "won"
          ? "solved"
          : progress.outcome
        : "unplayed"
    };
  });

  return {
    gamesPlayed: eligible.length,
    gamesWon: wins.length,
    currentStreak: calculateCurrentStreak(progressRecords, today),
    longestStreak: calculateLongestStreak(progressRecords),
    winRate: eligible.length === 0 ? 0 : Math.floor((wins.length / eligible.length) * 100),
    guessDistribution,
    rollingScore: history.reduce((total, row) => total + row.score, 0),
    history
  };
}

export function shareText(progress: BackwordProgress, answer: string): string {
  const result =
    progress.outcome === "won"
      ? `Got it in ${progress.guesses.length}/${MAX_GUESSES}!`
      : `Failed (${answer.toUpperCase()})`;
  const blocks = progress.guesses
    .map((_, index) =>
      progress.outcome === "won" && index === progress.guesses.length - 1
        ? "🟩".repeat(BACKWORD_LENGTH)
        : "⬛".repeat(BACKWORD_LENGTH)
    )
    .join("\n");
  return `Backword ${progress.date}\n${result}\n${blocks}`;
}
