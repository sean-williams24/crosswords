export type CrosswordDirection = "across" | "down";

export type CrosswordCell = {
  letter: string | null;
  clueNumber: number | null;
  acrossClueId: number | null;
  downClueId: number | null;
};

export type CrosswordClue = {
  id: number;
  direction: CrosswordDirection;
  number: number;
  text: string;
  answer: string;
  startRow: number;
  startCol: number;
  length: number;
};

export type CrosswordPuzzle = {
  id: string;
  puzzleNumber: number;
  date: string;
  size: number;
  cells: CrosswordCell[][];
  clues: CrosswordClue[];
};

export type CrosswordProgress = {
  schemaVersion: 1;
  puzzleId: string;
  date: string;
  size: number;
  entries: (string | null)[][];
  completedClueIds: number[];
  startedAt: string;
  completedAt: string | null;
  releaseDateScore: number;
};

export type CrosswordSettings = {
  schemaVersion: 1;
  hasSeenOnboarding: boolean;
  correctHighlight: boolean;
};

export type CrosswordSelection = {
  row: number;
  col: number;
  direction: CrosswordDirection;
};

export type CrosswordDashboardStatus = {
  label: string;
  tone: "new" | "progress" | "solved";
  score: number | null;
  streak: number;
};

export type CrosswordHistoryRow = {
  date: string;
  isToday: boolean;
  score: number;
  solveTimeSeconds: number | null;
  outcome: "unplayed" | "inProgress" | "solved";
};

export type CrosswordStats = {
  totalSolved: number;
  currentStreak: number;
  longestStreak: number;
  averageSolveTimeSeconds: number | null;
  rollingScore: number;
  history: CrosswordHistoryRow[];
};
