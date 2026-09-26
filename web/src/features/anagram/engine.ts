import { localDateOffset, localDateString } from "../backword/date";

export type AnagramPuzzle = {
  id: string;
  date: string;
  puzzleNumber: number;
  schemaVersion: 1;
  answer: string;
  acceptedAnswers: string[];
  initialScramble: string;
};

export type AnagramProgress = {
  schemaVersion: 1;
  puzzleID: string;
  date: string;
  startedAt: string;
  trayOrder: number[];
  placedTileIDs: (number | null)[];
  placementHistory: number[];
  hintUsed: boolean;
  hintSource: "time_penalty" | "rewarded_ad" | null;
  penaltySeconds: number;
  lockedCellIndex: number | null;
  lockedTileID: number | null;
  outcome: "solved" | "gave_up" | null;
  completedAt: string | null;
  elapsedSecondsAtCompletion: number | null;
  releaseDateScore: number;
  updatedAt: string;
};

export function reviewAnagramPuzzle(date = localDateString()): AnagramPuzzle {
  return {
    id: "web-anagram-review",
    date,
    puzzleNumber: 0,
    schemaVersion: 1,
    answer: "TRIANGLE",
    acceptedAnswers: ["INTEGRAL"],
    initialScramble: "RAGTLINE"
  };
}

/** Swift's Codable encoder omits nil optionals; web state keeps them explicit. */
export function normalizeAnagramProgress(progress: AnagramProgress): AnagramProgress {
  return {
    ...progress,
    hintSource: progress.hintSource ?? null,
    lockedCellIndex: progress.lockedCellIndex ?? null,
    lockedTileID: progress.lockedTileID ?? null,
    outcome: progress.outcome ?? null,
    completedAt: progress.completedAt ?? null,
    elapsedSecondsAtCompletion: progress.elapsedSecondsAtCompletion ?? null
  };
}

const sortedLetters = (word: string) => [...word].sort().join("");

export function validPuzzle(puzzle: AnagramPuzzle): boolean {
  if (typeof puzzle.answer !== "string" || typeof puzzle.initialScramble !== "string"
    || !Array.isArray(puzzle.acceptedAnswers) || !puzzle.acceptedAnswers.every((answer) => typeof answer === "string")) return false;
  const answers = [puzzle.answer, ...puzzle.acceptedAnswers];
  return puzzle.schemaVersion === 1 && /^\d{4}-\d{2}-\d{2}$/.test(puzzle.date)
    && Number.isInteger(puzzle.puzzleNumber) && puzzle.puzzleNumber > 0
    && /^[A-Z]{7,9}$/.test(puzzle.answer)
    && new Set(answers).size === answers.length
    && answers.every((answer) => /^[A-Z]{7,9}$/.test(answer) && sortedLetters(answer) === sortedLetters(puzzle.answer))
    && sortedLetters(puzzle.initialScramble) === sortedLetters(puzzle.answer)
    && !answers.includes(puzzle.initialScramble);
}

export function validProgress(progress: AnagramProgress, puzzle: AnagramPuzzle): boolean {
  progress = normalizeAnagramProgress(progress);
  const size = puzzle.answer.length;
  if (progress.schemaVersion !== 1 || progress.puzzleID !== puzzle.id || progress.date !== puzzle.date
    || !Number.isFinite(Date.parse(progress.startedAt)) || !Number.isFinite(Date.parse(progress.updatedAt))
    || ![null, "solved", "gave_up"].includes(progress.outcome)
    || ![null, "rewarded_ad", "time_penalty"].includes(progress.hintSource)
    || progress.trayOrder?.length !== size || progress.placedTileIDs?.length !== size
    || !Array.isArray(progress.placementHistory)
    || progress.trayOrder.slice().sort((a, b) => a - b).some((tile, index) => tile !== index)) return false;
  const placed = progress.placedTileIDs.filter((tile): tile is number => tile !== null);
  const history = progress.placementHistory;
  if (placed.some((tile) => !Number.isInteger(tile) || tile < 0 || tile >= size)
    || new Set(placed).size !== placed.length || new Set(history).size !== history.length
    || history.some((tile) => !placed.includes(tile))
    || history.length !== placed.filter((tile) => tile !== progress.lockedTileID).length
    || history.some((tile) => tile === progress.lockedTileID)
    || progress.hintUsed !== (progress.hintSource !== null)
    || !Number.isInteger(progress.penaltySeconds) || progress.penaltySeconds < 0
    || (progress.hintSource === "time_penalty" && progress.penaltySeconds < 30)
    || (!progress.hintUsed && (progress.penaltySeconds !== 0 || progress.lockedCellIndex !== null || progress.lockedTileID !== null))
    || (progress.hintUsed && progress.outcome === null && (progress.lockedCellIndex === null || progress.lockedTileID === null
      || progress.placedTileIDs[progress.lockedCellIndex] !== progress.lockedTileID))
    || (progress.outcome === null) !== (progress.completedAt === null)
    || !Number.isInteger(progress.releaseDateScore) || progress.releaseDateScore < 0 || progress.releaseDateScore > 5) return false;
  return progress.completedAt === null || Number.isFinite(Date.parse(progress.completedAt));
}

export function startProgress(puzzle: AnagramPuzzle, now = new Date()): AnagramProgress {
  const timestamp = now.toISOString();
  return { schemaVersion: 1, puzzleID: puzzle.id, date: puzzle.date, startedAt: timestamp,
    trayOrder: Array.from({ length: puzzle.answer.length }, (_, index) => index),
    placedTileIDs: Array(puzzle.answer.length).fill(null), placementHistory: [], hintUsed: false,
    hintSource: null, penaltySeconds: 0, lockedCellIndex: null, lockedTileID: null,
    outcome: null, completedAt: null, elapsedSecondsAtCompletion: null, releaseDateScore: 0, updatedAt: timestamp };
}

export function availableTileIDs(progress: AnagramProgress): number[] {
  return progress.trayOrder.filter((tile) => !progress.placedTileIDs.includes(tile));
}

export function answerText(progress: AnagramProgress, puzzle: AnagramPuzzle): string | null {
  if (progress.placedTileIDs.some((tile) => tile === null)) return null;
  return progress.placedTileIDs.map((tile) => puzzle.initialScramble[tile!]).join("");
}

export function elapsedSeconds(progress: AnagramProgress, now = new Date()): number {
  return progress.elapsedSecondsAtCompletion ?? Math.max(0, Math.floor((now.getTime() - Date.parse(progress.startedAt)) / 1000));
}

export function pointsForSeconds(seconds: number): number {
  return seconds < 30 ? 5 : seconds < 60 ? 4 : seconds < 120 ? 3 : seconds < 180 ? 2 : 1;
}

function finish(progress: AnagramProgress, outcome: "solved" | "gave_up", now: Date): AnagramProgress {
  const elapsed = elapsedSeconds(progress, now);
  return { ...progress, outcome, completedAt: now.toISOString(), elapsedSecondsAtCompletion: elapsed,
    releaseDateScore: outcome === "solved" && localDateString(now) === progress.date
      ? pointsForSeconds(elapsed + progress.penaltySeconds) : 0, updatedAt: now.toISOString() };
}

export function placeTile(progress: AnagramProgress, puzzle: AnagramPuzzle, tile: number, now = new Date()): AnagramProgress {
  const cell = progress.placedTileIDs.indexOf(null);
  if (progress.outcome || cell < 0 || !availableTileIDs(progress).includes(tile)) return progress;
  const next = { ...progress, placedTileIDs: [...progress.placedTileIDs], placementHistory: [...progress.placementHistory, tile], updatedAt: now.toISOString() };
  next.placedTileIDs[cell] = tile;
  const answer = answerText(next, puzzle);
  return answer && [puzzle.answer, ...puzzle.acceptedAnswers].includes(answer) ? finish(next, "solved", now) : next;
}

export function undoTile(progress: AnagramProgress, now = new Date()): AnagramProgress {
  if (progress.outcome || !progress.placementHistory.length) return progress;
  const tile = progress.placementHistory.at(-1)!;
  return { ...progress, placedTileIDs: progress.placedTileIDs.map((value) => value === tile ? null : value),
    placementHistory: progress.placementHistory.slice(0, -1), updatedAt: now.toISOString() };
}

export function restartTiles(progress: AnagramProgress, now = new Date()): AnagramProgress {
  if (progress.outcome || !progress.placementHistory.length) return progress;
  const placements = new Set(progress.placementHistory);
  return { ...progress, placedTileIDs: progress.placedTileIDs.map((tile) => tile !== null && placements.has(tile) ? null : tile),
    placementHistory: [], updatedAt: now.toISOString() };
}

export function reshuffle(progress: AnagramProgress, order: number[], now = new Date()): AnagramProgress {
  const available = availableTileIDs(progress);
  if (progress.outcome || order.length !== available.length || order.slice().sort().join() !== available.slice().sort().join()) return progress;
  let index = 0;
  const set = new Set(available);
  return { ...progress, trayOrder: progress.trayOrder.map((tile) => set.has(tile) ? order[index++] : tile), updatedAt: now.toISOString() };
}

export function revealHint(progress: AnagramProgress, puzzle: AnagramPuzzle, now = new Date()): AnagramProgress {
  if (progress.outcome || progress.hintUsed) return progress;
  const cleared = restartTiles(progress, now);
  const tile = availableTileIDs(cleared).find((id) => puzzle.initialScramble[id] === puzzle.answer[0]);
  if (tile === undefined) return progress;
  return { ...cleared, placedTileIDs: [tile, ...cleared.placedTileIDs.slice(1)], placementHistory: [],
    hintUsed: true, hintSource: "time_penalty", penaltySeconds: 30,
    lockedCellIndex: 0, lockedTileID: tile, updatedAt: now.toISOString() };
}

export function giveUp(progress: AnagramProgress, now = new Date()): AnagramProgress {
  return progress.outcome ? progress : finish(progress, "gave_up", now);
}

export function anagramStats(records: AnagramProgress[], now = new Date()) {
  const released = records.filter((record) => record.date !== "review");
  const solved = released.filter((record) => record.outcome === "solved" && record.releaseDateScore > 0);
  const byDate = new Map(released.map((record) => [record.date, record]));
  const today = localDateString(now);
  const yesterday = new Date(now); yesterday.setDate(yesterday.getDate() - 1);
  const todayRecord = byDate.get(today);
  let cursor = todayRecord?.releaseDateScore ? new Date(now) : yesterday;
  let streak = 0;
  while (!(todayRecord?.outcome && todayRecord.releaseDateScore === 0)) {
    const record = byDate.get(localDateString(cursor));
    if (!record || record.outcome !== "solved" || record.releaseDateScore <= 0) break;
    streak++; cursor = new Date(cursor); cursor.setDate(cursor.getDate() - 1);
  }
  let bestStreak = 0;
  let candidateStreak = 0;
  let previousSolvedDate: string | null = null;
  for (const record of [...solved].sort((a, b) => a.date.localeCompare(b.date))) {
    candidateStreak = previousSolvedDate && localDateOffset(previousSolvedDate, 1) === record.date
      ? candidateStreak + 1
      : 1;
    bestStreak = Math.max(bestStreak, candidateStreak);
    previousSolvedDate = record.date;
  }
  const recentSolves = solved.filter((record) => record.date <= today && (now.getTime() - Date.parse(`${record.date}T12:00:00`)) / 86400000 < 14);
  const averageSeconds = recentSolves.length
    ? Math.round(recentSolves.reduce((total, record) => total + (record.elapsedSecondsAtCompletion ?? 0), 0) / recentSolves.length) : null;
  return { solved: solved.length, played: released.filter((record) => record.outcome).length, streak, bestStreak, averageSeconds,
    rollingScore: released.filter((record) => record.date <= today && (now.getTime() - Date.parse(`${record.date}T12:00:00`)) / 86400000 < 14)
      .reduce((total, record) => total + record.releaseDateScore, 0) };
}
