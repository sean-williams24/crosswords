export type BackwordMode = "normal" | "easy";

export type BackwordOutcome = "inProgress" | "won" | "failed";

export type BackwordWord = {
  id: string;
  date: string;
  word: string;
  clue: string;
};

export type BackwordProgress = {
  schemaVersion: 1;
  date: string;
  guesses: string[];
  completedAt: string | null;
  outcome: BackwordOutcome;
  /** ISO timestamp used only for deterministic cross-device conflict resolution. */
  updatedAt?: string;
};

export type BackwordSettings = {
  schemaVersion: 1;
  mode: BackwordMode;
  hasSeenOnboarding: boolean;
  lastSeenRulesVersion: number;
};

export type BackwordHistoryOutcome =
  | "unplayed"
  | "inProgress"
  | "solved"
  | "failed";

export type BackwordHistoryRow = {
  date: string;
  isToday: boolean;
  score: number;
  guessCount: number | null;
  outcome: BackwordHistoryOutcome;
};

export type BackwordStats = {
  gamesPlayed: number;
  gamesWon: number;
  currentStreak: number;
  longestStreak: number;
  winRate: number;
  guessDistribution: Record<number, number>;
  rollingScore: number;
  history: BackwordHistoryRow[];
};
