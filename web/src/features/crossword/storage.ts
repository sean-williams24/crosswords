import { emptyProgress } from "./engine";
import type { CrosswordProgress, CrosswordPuzzle, CrosswordSettings } from "./types";

const SETTINGS_KEY = "backword:web:crossword:settings:v1";
const PROGRESS_KEY = "backword:web:crossword:progress:v1";
const PUZZLE_CACHE_KEY = "backword:web:crossword:puzzles:v1";

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

function isProgress(value: unknown): value is CrosswordProgress {
  if (!value || typeof value !== "object") {
    return false;
  }
  const progress = value as Partial<CrosswordProgress>;
  return (
    progress.schemaVersion === 1 &&
    typeof progress.puzzleId === "string" &&
    /^\d{4}-\d{2}-\d{2}$/.test(progress.date ?? "") &&
    Number.isInteger(progress.size) && progress.size === 9 &&
    isEntryGrid(progress.entries, progress.size) &&
    Array.isArray(progress.completedClueIds) && progress.completedClueIds.every(Number.isInteger) &&
    typeof progress.startedAt === "string" &&
    (progress.completedAt === null || typeof progress.completedAt === "string") &&
    typeof progress.releaseDateScore === "number" && progress.releaseDateScore >= 0 && progress.releaseDateScore <= 5
  );
}

function isPuzzle(value: unknown): value is CrosswordPuzzle {
  if (!value || typeof value !== "object") {
    return false;
  }
  const puzzle = value as Partial<CrosswordPuzzle>;
  return (
    typeof puzzle.id === "string" &&
    /^\d{4}-\d{2}-\d{2}$/.test(puzzle.date ?? "") &&
    puzzle.size === 9 &&
    Array.isArray(puzzle.cells) && puzzle.cells.length === 9 &&
    Array.isArray(puzzle.clues) && puzzle.clues.length > 0
  );
}

export type CrosswordStorage = ReturnType<typeof createCrosswordStorage>;

export function createCrosswordStorage(storage: Storage = window.localStorage) {
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
      const saved = readRecord<unknown>(storage, PROGRESS_KEY)[puzzle.id];
      return isProgress(saved) && saved.date === puzzle.date && saved.size === puzzle.size
        ? saved
        : emptyProgress(puzzle);
    },

    loadAllProgress(): CrosswordProgress[] {
      return Object.values(readRecord<unknown>(storage, PROGRESS_KEY)).filter(isProgress);
    },

    loadProgressForDate(date: string): CrosswordProgress | null {
      return this.loadAllProgress().find((progress) => progress.date === date) ?? null;
    },

    saveProgress(progress: CrosswordProgress): void {
      const records = readRecord<CrosswordProgress>(storage, PROGRESS_KEY);
      records[progress.puzzleId] = progress;
      storage.setItem(PROGRESS_KEY, JSON.stringify(records));
    },

    loadCachedPuzzle(date: string): CrosswordPuzzle | null {
      const puzzle = readRecord<unknown>(storage, PUZZLE_CACHE_KEY)[date];
      return isPuzzle(puzzle) ? puzzle : null;
    },

    cachePuzzle(puzzle: CrosswordPuzzle): void {
      const records = readRecord<CrosswordPuzzle>(storage, PUZZLE_CACHE_KEY);
      records[puzzle.date] = puzzle;
      storage.setItem(PUZZLE_CACHE_KEY, JSON.stringify(records));
    }
  };
}
