import { decodeProgress, emptyProgress, validPuzzle, type MidwordProgress, type MidwordPuzzle } from "./engine";

const progressKey = "backword:web:midword:progress:v1";
const puzzlesKey = "backword:web:midword:puzzles:v1";

function read(storage: Storage, key: string): Record<string, unknown> {
  try {
    const value: unknown = JSON.parse(storage.getItem(key) ?? "{}");
    return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
  } catch { return {}; }
}

export function createMidwordStorage(storage: Storage = window.localStorage,
  options: { userId?: string | null; onProgressSaved?: (progress: MidwordProgress) => void } = {}) {
  const scoped = options.userId ? `${progressKey}:user:${options.userId}` : progressKey;
  const replace = (value: unknown) => {
    const progress = decodeProgress(value);
    if (!progress) return;
    storage.setItem(scoped, JSON.stringify({ ...read(storage, scoped), [progress.date]: progress }));
  };
  return {
    loadProgress(date: string): MidwordProgress {
      const progress = decodeProgress(read(storage, scoped)[date]);
      return progress?.date === date ? progress : emptyProgress(date);
    },
    loadAllProgress(): MidwordProgress[] {
      return Object.entries(read(storage, scoped)).flatMap(([date, value]) => {
        const progress = decodeProgress(value);
        return progress?.date === date ? [progress] : [];
      });
    },
    saveProgress(progress: MidwordProgress) { replace(progress); options.onProgressSaved?.(progress); },
    replaceProgress: replace,
    deleteProgress(date: string) {
      const records = read(storage, scoped); delete records[date]; storage.setItem(scoped, JSON.stringify(records));
    },
    loadCachedPuzzle(date: string): MidwordPuzzle | null {
      const value = read(storage, puzzlesKey)[date];
      return validPuzzle(value) && value.date === date ? value : null;
    },
    cachePuzzle(puzzle: MidwordPuzzle) {
      if (validPuzzle(puzzle)) storage.setItem(puzzlesKey, JSON.stringify({ ...read(storage, puzzlesKey), [puzzle.date]: puzzle }));
    }
  };
}
