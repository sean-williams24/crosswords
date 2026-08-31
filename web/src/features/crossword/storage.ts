import { emptyProgress } from "./engine";
import type { CrosswordKind, CrosswordProgress, CrosswordPuzzle, CrosswordSettings } from "./types";

const SETTINGS_KEY = "backword:web:crossword:settings:v1";
const DAILY_PROGRESS_KEY = "backword:web:crossword:progress:v1";
const DAILY_PUZZLE_CACHE_KEY = "backword:web:crossword:puzzles:v1";
const WEEKLY_PROGRESS_KEY = "backword:web:weekly-crossword:progress:v1";
const WEEKLY_PUZZLE_CACHE_KEY = "backword:web:weekly-crossword:puzzles:v1";

const defaultSettings: CrosswordSettings = {
  schemaVersion: 1,
  hasSeenOnboarding: false,
  correctHighlight: true
};

function readRecord<T>(storage: Storage, key: string): Record<string, T> {
  try {
    const parsed: unknown = JSON.parse(storage.getItem(key) ?? "{}");
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as Record<string, T>
      : {};
  } catch {
    return {};
  }
}

function isEntryGrid(value: unknown, size: number): value is (string | null)[][] {
  return Array.isArray(value) && value.length === size && value.every((row) =>
    Array.isArray(row) && row.length === size && row.every((entry) =>
      entry === null || (typeof entry === "string" && /^[A-Z]$/.test(entry))
    )
  );
}

function isProgress(value: unknown, size: 9 | 13, isWeekly: boolean): value is CrosswordProgress {
  if (!value || typeof value !== "object") {
    return false;
  }
  const progress = value as Partial<CrosswordProgress>;
  return (
    progress.schemaVersion === 1 &&
    typeof progress.puzzleId === "string" &&
    /^\d{4}-\d{2}-\d{2}$/.test(progress.date ?? "") &&
    Number.isInteger(progress.size) && progress.size === size &&
    isEntryGrid(progress.entries, progress.size) &&
    Array.isArray(progress.completedClueIds) && progress.completedClueIds.every(Number.isInteger) &&
    (progress.hintedClueIds === undefined || (Array.isArray(progress.hintedClueIds) && progress.hintedClueIds.every(Number.isInteger))) &&
    (progress.hintsUsed === undefined || (Number.isInteger(progress.hintsUsed) && progress.hintsUsed >= 0)) &&
    typeof progress.startedAt === "string" &&
    // Swift's JSONEncoder omits nil optionals, while browser saves use an
    // explicit null. Both represent an unfinished shared crossword.
    (progress.completedAt === undefined || progress.completedAt === null || typeof progress.completedAt === "string") &&
    typeof progress.releaseDateScore === "number" && progress.releaseDateScore >= 0 && progress.releaseDateScore <= 5 &&
    (progress.isWeekly === undefined || progress.isWeekly === isWeekly)
  );
}

/** Normalise the shared iOS payload to the browser's explicit-null shape. */
function normalizedProgress(progress: CrosswordProgress): CrosswordProgress {
  return {
    ...progress,
    completedAt: progress.completedAt ?? null,
    hintedClueIds: progress.hintedClueIds ?? [],
    hintsUsed: progress.hintsUsed ?? 0
  };
}

function isPuzzle(value: unknown, size: 9 | 13): value is CrosswordPuzzle {
  if (!value || typeof value !== "object") {
    return false;
  }
  const puzzle = value as Partial<CrosswordPuzzle>;
  return (
    typeof puzzle.id === "string" &&
    /^\d{4}-\d{2}-\d{2}$/.test(puzzle.date ?? "") &&
    puzzle.size === size &&
    Array.isArray(puzzle.cells) && puzzle.cells.length === size &&
    Array.isArray(puzzle.clues) && puzzle.clues.length > 0
  );
}

export type CrosswordStorage = ReturnType<typeof createCrosswordStorage>;

type CrosswordStorageOptions = {
  kind?: CrosswordKind;
  userId?: string | null;
  onProgressSaved?: (progress: CrosswordProgress) => void;
};

export function createCrosswordStorage(
  storage: Storage = window.localStorage,
  options: CrosswordStorageOptions = {}
) {
  const kind = options.kind ?? "daily";
  const size = kind === "weekly" ? 13 : 9;
  const isWeekly = kind === "weekly";
  const progressKey = isWeekly ? WEEKLY_PROGRESS_KEY : DAILY_PROGRESS_KEY;
  const puzzleCacheKey = isWeekly ? WEEKLY_PUZZLE_CACHE_KEY : DAILY_PUZZLE_CACHE_KEY;
  const scopedKey = (key: string) => options.userId ? `${key}:user:${options.userId}` : key;

  return {
    loadSettings(): CrosswordSettings {
      try {
        const parsed: unknown = JSON.parse(storage.getItem(SETTINGS_KEY) ?? "null");
        if (!parsed || typeof parsed !== "object") {
          return { ...defaultSettings };
        }
        const settings = parsed as Partial<CrosswordSettings>;
        return settings.schemaVersion === 1 &&
          typeof settings.hasSeenOnboarding === "boolean" &&
          typeof settings.correctHighlight === "boolean"
          ? settings as CrosswordSettings
          : { ...defaultSettings };
      } catch {
        return { ...defaultSettings };
      }
    },

    saveSettings(settings: CrosswordSettings): void {
      storage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    },

    loadProgress(puzzle: Pick<CrosswordPuzzle, "id" | "date" | "size">): CrosswordProgress {
      const saved = readRecord<unknown>(storage, scopedKey(progressKey))[puzzle.id];
      return isProgress(saved, size, isWeekly) && saved.date === puzzle.date && saved.size === puzzle.size
        ? normalizedProgress(saved)
        : emptyProgress(puzzle);
    },

    loadAllProgress(): CrosswordProgress[] {
      return Object.values(readRecord<unknown>(storage, scopedKey(progressKey)))
        .filter((progress): progress is CrosswordProgress => isProgress(progress, size, isWeekly))
        .map(normalizedProgress);
    },

    loadProgressForDate(date: string): CrosswordProgress | null {
      return this.loadAllProgress().find((progress) => progress.date === date) ?? null;
    },

    saveProgress(progress: CrosswordProgress): void {
      progress.updatedAt = new Date().toISOString();
      const records = readRecord<CrosswordProgress>(storage, scopedKey(progressKey));
      records[progress.puzzleId] = progress;
      storage.setItem(scopedKey(progressKey), JSON.stringify(records));
      options.onProgressSaved?.(progress);
    },

    replaceProgress(progress: CrosswordProgress): void {
      const records = readRecord<CrosswordProgress>(storage, scopedKey(progressKey));
      records[progress.puzzleId] = normalizedProgress(progress);
      storage.setItem(scopedKey(progressKey), JSON.stringify(records));
    },

    deleteProgress(puzzleId: string): void {
      const records = readRecord<CrosswordProgress>(storage, scopedKey(progressKey));
      delete records[puzzleId];
      storage.setItem(scopedKey(progressKey), JSON.stringify(records));
    },

    loadCachedPuzzle(date: string): CrosswordPuzzle | null {
      const puzzle = readRecord<unknown>(storage, puzzleCacheKey)[date];
      return isPuzzle(puzzle, size) ? puzzle : null;
    },

    cachePuzzle(puzzle: CrosswordPuzzle): void {
      const records = readRecord<CrosswordPuzzle>(storage, puzzleCacheKey);
      records[puzzle.date] = puzzle;
      storage.setItem(puzzleCacheKey, JSON.stringify(records));
    }
  };
}
