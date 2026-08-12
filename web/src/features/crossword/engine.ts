import { isCompletedOnReleaseDate, localDateOffset, localDateString } from "../backword/date";
import type {
  CrosswordClue,
  CrosswordDashboardStatus,
  CrosswordDirection,
  CrosswordProgress,
  CrosswordPuzzle,
  CrosswordSelection,
  CrosswordStats
} from "./types";

export function emptyProgress(
  puzzle: Pick<CrosswordPuzzle, "id" | "date" | "size">,
  startedAt = new Date()
): CrosswordProgress {
  return {
    schemaVersion: 1,
    puzzleId: puzzle.id,
    date: puzzle.date,
    size: puzzle.size,
    entries: Array.from({ length: puzzle.size }, () => Array<string | null>(puzzle.size).fill(null)),
    completedClueIds: [],
    startedAt: startedAt.toISOString(),
    completedAt: null,
    releaseDateScore: 0,
    updatedAt: startedAt.toISOString()
  };
}

export function clueCells(clue: CrosswordClue): Array<{ row: number; col: number }> {
  return Array.from({ length: clue.length }, (_, offset) => ({
    row: clue.startRow + (clue.direction === "down" ? offset : 0),
    col: clue.startCol + (clue.direction === "across" ? offset : 0)
  }));
}

export function cluesAt(puzzle: CrosswordPuzzle, row: number, col: number): {
  across: CrosswordClue | null;
  down: CrosswordClue | null;
} {
  const cell = puzzle.cells[row]?.[col];
  if (!cell || cell.letter === null) {
    return { across: null, down: null };
  }
  return {
    across: puzzle.clues.find((clue) => clue.id === cell.acrossClueId) ?? null,
    down: puzzle.clues.find((clue) => clue.id === cell.downClueId) ?? null
  };
}

export function activeClue(
  puzzle: CrosswordPuzzle,
  selection: CrosswordSelection
): CrosswordClue | null {
  const choices = cluesAt(puzzle, selection.row, selection.col);
  return selection.direction === "across"
    ? choices.across ?? choices.down
    : choices.down ?? choices.across;
}

export function firstWhiteSelection(puzzle: CrosswordPuzzle): CrosswordSelection {
  for (let row = 0; row < puzzle.size; row += 1) {
    for (let col = 0; col < puzzle.size; col += 1) {
      if (puzzle.cells[row][col].letter !== null) {
        return { row, col, direction: "across" };
      }
    }
  }
  return { row: 0, col: 0, direction: "across" };
}

function selectDirection(
  puzzle: CrosswordPuzzle,
  selection: CrosswordSelection,
  row: number,
  col: number
): CrosswordDirection {
  const cell = puzzle.cells[row][col];
  const choices = cluesAt(puzzle, row, col);
  const startsAcross = cell.clueNumber !== null && choices.across?.number === cell.clueNumber;
  const startsDown = cell.clueNumber !== null && choices.down?.number === cell.clueNumber;
  if (startsAcross && !startsDown) return "across";
  if (startsDown && !startsAcross) return "down";
  if (choices.across && !choices.down) return "across";
  if (!choices.across && choices.down) return "down";
  return selection.direction;
}

export function selectCell(
  puzzle: CrosswordPuzzle,
  selection: CrosswordSelection,
  row: number,
  col: number
): CrosswordSelection {
  const cell = puzzle.cells[row]?.[col];
  if (!cell || cell.letter === null) return selection;
  if (selection.row === row && selection.col === col) {
    return toggleDirection(puzzle, selection);
  }
  return { row, col, direction: selectDirection(puzzle, selection, row, col) };
}

export function toggleDirection(
  puzzle: CrosswordPuzzle,
  selection: CrosswordSelection
): CrosswordSelection {
  const choices = cluesAt(puzzle, selection.row, selection.col);
  if (selection.direction === "across" && choices.down) {
    return { ...selection, direction: "down" };
  }
  if (selection.direction === "down" && choices.across) {
    return { ...selection, direction: "across" };
  }
  return selection;
}

export function navigateToClue(
  progress: CrosswordProgress,
  clue: CrosswordClue
): CrosswordSelection {
  const firstEmpty = clueCells(clue).find(({ row, col }) => progress.entries[row][col] === null);
  return {
    row: firstEmpty?.row ?? clue.startRow,
    col: firstEmpty?.col ?? clue.startCol,
    direction: clue.direction
  };
}

export function adjacentClue(
  puzzle: CrosswordPuzzle,
  selection: CrosswordSelection,
  step: 1 | -1
): CrosswordClue | null {
  const current = activeClue(puzzle, selection);
  if (!current) return null;
  const clues = puzzle.clues
    .filter((clue) => clue.direction === current.direction)
    .sort((first, second) => first.number - second.number);
  const index = clues.findIndex((clue) => clue.id === current.id);
  return index < 0 ? null : clues[(index + step + clues.length) % clues.length];
}

export function isCompletedCell(progress: CrosswordProgress, puzzle: CrosswordPuzzle, row: number, col: number): boolean {
  const cell = puzzle.cells[row]?.[col];
  return Boolean(
    cell && (progress.completedClueIds.includes(cell.acrossClueId ?? -1) || progress.completedClueIds.includes(cell.downClueId ?? -1))
  );
}

function advanceSelection(
  progress: CrosswordProgress,
  clue: CrosswordClue,
  selection: CrosswordSelection
): CrosswordSelection {
  const cells = clueCells(clue);
  const index = cells.findIndex((cell) => cell.row === selection.row && cell.col === selection.col);
  if (index < 0) return selection;
  const nextEmpty = cells.slice(index + 1).find(({ row, col }) => progress.entries[row][col] === null);
  const next = nextEmpty ?? cells[index + 1];
  return next ? { row: next.row, col: next.col, direction: selection.direction } : selection;
}

function previousSelection(clue: CrosswordClue, selection: CrosswordSelection): CrosswordSelection {
  const cells = clueCells(clue);
  const index = cells.findIndex((cell) => cell.row === selection.row && cell.col === selection.col);
  const previous = index > 0 ? cells[index - 1] : null;
  return previous ? { row: previous.row, col: previous.col, direction: selection.direction } : selection;
}

function completedClueIds(
  progress: CrosswordProgress,
  candidates: CrosswordClue[]
): number[] {
  const completed = new Set(progress.completedClueIds);
  for (const clue of candidates) {
    if (!completed.has(clue.id) && clueCells(clue).map(({ row, col }) => progress.entries[row][col] ?? "").join("") === clue.answer) {
      completed.add(clue.id);
    }
  }
  return [...completed];
}

export function crosswordScore(completedClueCount: number, totalClues: number): number {
  if (totalClues <= 0 || completedClueCount <= 0) return 0;
  const percent = Math.floor((completedClueCount / totalClues) * 100);
  if (percent === 100) return 5;
  if (percent >= 75) return 4;
  if (percent >= 50) return 3;
  if (percent >= 25) return 2;
  return 1;
}

function saveReleaseDateScore(progress: CrosswordProgress, puzzle: CrosswordPuzzle, now: Date): CrosswordProgress {
  if (localDateString(now) !== progress.date) return progress;
  return { ...progress, releaseDateScore: crosswordScore(progress.completedClueIds.length, puzzle.clues.length) };
}

export function enterLetter(
  progress: CrosswordProgress,
  puzzle: CrosswordPuzzle,
  selection: CrosswordSelection,
  value: string,
  correctHighlight: boolean,
  now = new Date()
): { progress: CrosswordProgress; selection: CrosswordSelection } {
  const letter = value.toUpperCase();
  const clue = activeClue(puzzle, selection);
  if (!clue || progress.completedAt || !/^[A-Z]$/.test(letter)) return { progress, selection };
  if (correctHighlight && isCompletedCell(progress, puzzle, selection.row, selection.col)) {
    return progress.entries[selection.row][selection.col] === letter
      ? { progress, selection: advanceSelection(progress, clue, selection) }
      : { progress, selection };
  }

  const entries = progress.entries.map((row) => [...row]);
  entries[selection.row][selection.col] = letter;
  let updated = { ...progress, entries };
  const crossing = cluesAt(puzzle, selection.row, selection.col);
  updated = { ...updated, completedClueIds: completedClueIds(updated, [clue, crossing.across, crossing.down].filter((candidate): candidate is CrosswordClue => candidate !== null)) };
  if (updated.completedClueIds.length === puzzle.clues.length) {
    updated = { ...updated, completedAt: now.toISOString() };
  }
  updated = { ...saveReleaseDateScore(updated, puzzle, now), updatedAt: now.toISOString() };
  return { progress: updated, selection: advanceSelection(updated, clue, selection) };
}

export function deleteLetter(
  progress: CrosswordProgress,
  puzzle: CrosswordPuzzle,
  selection: CrosswordSelection,
  correctHighlight: boolean,
  now = new Date()
): { progress: CrosswordProgress; selection: CrosswordSelection } {
  const clue = activeClue(puzzle, selection);
  if (!clue || progress.completedAt) return { progress, selection };
  if (correctHighlight && isCompletedCell(progress, puzzle, selection.row, selection.col)) {
    return { progress, selection: previousSelection(clue, selection) };
  }
  let target = selection;
  const entries = progress.entries.map((row) => [...row]);
  if (entries[target.row][target.col] === null) {
    target = previousSelection(clue, target);
  }
  if (!(correctHighlight && isCompletedCell(progress, puzzle, target.row, target.col))) {
    entries[target.row][target.col] = null;
  }
  return { progress: { ...saveReleaseDateScore({ ...progress, entries }, puzzle, now), updatedAt: now.toISOString() }, selection: target };
}

function solvedProgress(progress: CrosswordProgress): boolean {
  return progress.completedAt !== null && !progress.gaveUpAt;
}

function longestConsecutive(dates: string[]): number {
  let current = 0;
  let longest = 0;
  let previous: string | null = null;
  for (const date of [...new Set(dates)].sort()) {
    current = previous && localDateOffset(previous, 1) === date ? current + 1 : 1;
    longest = Math.max(longest, current);
    previous = date;
  }
  return longest;
}

function currentStreak(dates: string[], today: string): number {
  const completed = new Set(dates);
  let cursor = completed.has(today) ? today : localDateOffset(today, -1);
  let streak = 0;
  while (completed.has(cursor)) {
    streak += 1;
    cursor = localDateOffset(cursor, -1);
  }
  return streak;
}

/** iOS exposes solve times only for a successful completion on its release day. */
function onTimeSolveTime(progress: CrosswordProgress): number | null {
  if (!solvedProgress(progress) || !isCompletedOnReleaseDate(progress.date, progress.completedAt)) {
    return null;
  }
  const end = new Date(progress.completedAt ?? "").getTime();
  const start = new Date(progress.startedAt).getTime();
  return Number.isFinite(end - start) ? Math.max(0, Math.floor((end - start) / 1000)) : null;
}

export function deriveCrosswordStats(progressRecords: CrosswordProgress[], now = new Date()): CrosswordStats {
  const today = localDateString(now);
  const byDate = new Map(progressRecords.map((progress) => [progress.date, progress]));
  const solved = progressRecords.filter(solvedProgress);
  const onTimeSolved = solved.filter((progress) => isCompletedOnReleaseDate(progress.date, progress.completedAt));
  const completionDates = onTimeSolved.map((progress) => progress.date);
  const history = Array.from({ length: 14 }, (_, offset) => {
    const date = localDateOffset(today, -offset);
    const progress = byDate.get(date);
    const solveTimeSeconds = progress ? onTimeSolveTime(progress) : null;
    return {
      date,
      isToday: offset === 0,
      score: progress?.releaseDateScore ?? 0,
      solveTimeSeconds,
      outcome: progress ? solveTimeSeconds !== null ? "solved" : "inProgress" : "unplayed"
    } as const;
  });
  const visibleSolveTimes = history
    .map((row) => row.solveTimeSeconds)
    .filter((seconds): seconds is number => seconds !== null);
  return {
    totalSolved: solved.length,
    currentStreak: currentStreak(completionDates, today),
    longestStreak: longestConsecutive(completionDates),
    averageSolveTimeSeconds: visibleSolveTimes.length ? Math.floor(visibleSolveTimes.reduce((total, seconds) => total + seconds, 0) / visibleSolveTimes.length) : null,
    rollingScore: history.reduce((total, row) => total + row.score, 0),
    history
  };
}

export function crosswordDashboardStatus(
  progress: CrosswordProgress | null,
  now = new Date(),
  allProgress: CrosswordProgress[] = []
): CrosswordDashboardStatus {
  const stats = deriveCrosswordStats(allProgress, now);
  if (!progress) return { label: "New", tone: "new", score: null, streak: stats.currentStreak };
  if (progress.completedAt) {
    return {
      label: isCompletedOnReleaseDate(progress.date, progress.completedAt) ? "Solved" : "Finished",
      tone: "solved",
      score: progress.releaseDateScore,
      streak: stats.currentStreak
    };
  }
  if (progress.completedClueIds.length) {
    return { label: "In Progress", tone: "progress", score: progress.releaseDateScore, streak: stats.currentStreak };
  }
  return { label: "New", tone: "new", score: null, streak: stats.currentStreak };
}

export function formatDuration(seconds: number | null): string {
  if (seconds === null) return "–";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainder = seconds % 60;
  return [hours, minutes, remainder].map((value) => String(value).padStart(2, "0")).join(":");
}

export function directionLabel(direction: CrosswordDirection): string {
  return direction === "across" ? "Across" : "Down";
}
