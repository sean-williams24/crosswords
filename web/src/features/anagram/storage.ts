import { normalizeAnagramProgress, validProgress, validPuzzle, type AnagramProgress, type AnagramPuzzle } from "./engine";

const PROGRESS_KEY = "backword:web:anagram:progress:v1";
const PUZZLES_KEY = "backword:web:anagram:puzzles:v1";
const FIRST_RELEASE_KEY = "backword:web:anagram:first-release:v1";
const TIP_KEY = "backword:web:anagram:tip-seen:v1";

function readRecord(storage: Storage, key: string): Record<string, unknown> {
  try {
    const value: unknown = JSON.parse(storage.getItem(key) ?? "{}");
    return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
  } catch { return {}; }
}

export function createAnagramStorage(storage: Storage = window.localStorage, options: { userId?: string | null; onProgressSaved?: (progress: AnagramProgress) => void } = {}) {
  const scoped = options.userId ? `${PROGRESS_KEY}:user:${options.userId}` : PROGRESS_KEY;
  return {
    loadProgress(puzzle: AnagramPuzzle): AnagramProgress | null {
      const value = readRecord(storage, scoped)[puzzle.date] as AnagramProgress | undefined;
      if (!value) return null;
      const normalized = normalizeAnagramProgress(value);
      return validProgress(normalized, puzzle) ? normalized : null;
    },
    loadAllProgress(): AnagramProgress[] {
      return Object.values(readRecord(storage, scoped)).filter((value): value is AnagramProgress => {
        const progress = value as AnagramProgress;
        return progress?.schemaVersion === 1 && typeof progress.date === "string" && typeof progress.puzzleID === "string" && Array.isArray(progress.placementHistory);
      }).map(normalizeAnagramProgress);
    },
    saveProgress(progress: AnagramProgress) {
      const records = readRecord(storage, scoped);
      records[progress.date] = progress;
      storage.setItem(scoped, JSON.stringify(records));
      options.onProgressSaved?.(progress);
    },
    replaceProgress(progress: AnagramProgress) {
      const records = readRecord(storage, scoped);
      records[progress.date] = normalizeAnagramProgress(progress);
      storage.setItem(scoped, JSON.stringify(records));
    },
    deleteProgress(date: string) {
      const records = readRecord(storage, scoped);
      delete records[date]; storage.setItem(scoped, JSON.stringify(records));
    },
    loadCachedPuzzle(date: string): AnagramPuzzle | null {
      const value = readRecord(storage, PUZZLES_KEY)[date] as AnagramPuzzle | undefined;
      return value && validPuzzle(value) ? value : null;
    },
    cachePuzzle(puzzle: AnagramPuzzle) {
      const records = readRecord(storage, PUZZLES_KEY);
      records[puzzle.date] = puzzle; storage.setItem(PUZZLES_KEY, JSON.stringify(records));
    },
    firstReleaseDate(): string | null { return storage.getItem(FIRST_RELEASE_KEY); },
    setFirstReleaseDate(date: string) { if (/^\d{4}-\d{2}-\d{2}$/.test(date)) storage.setItem(FIRST_RELEASE_KEY, date); },
    hasSeenTip(): boolean { return storage.getItem(TIP_KEY) === "yes"; },
    markTipSeen() { storage.setItem(TIP_KEY, "yes"); }
  };
}
