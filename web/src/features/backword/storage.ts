import { BACKWORD_RULES_VERSION, emptyProgress } from "./engine";
import { BACKWORD_ONBOARDING_STEPS } from "./onboarding";
import type { BackwordOnboardingStep, BackwordProgress, BackwordSettings, BackwordWord } from "./types";

const SETTINGS_KEY = "backword:web:settings:v1";
const PROGRESS_KEY = "backword:web:progress:v1";
const PUZZLE_CACHE_KEY = "backword:web:puzzles:v1";

const defaultSettings: BackwordSettings = {
  schemaVersion: 1,
  mode: "easy",
  hasSeenOnboarding: false,
  lastSeenRulesVersion: 0,
  dismissedOnboardingSteps: [],
  hasSeenInstructionsTip: false
};

function readRecord<T>(storage: Storage, key: string): Record<string, T> {
  try {
    const parsed: unknown = JSON.parse(storage.getItem(key) ?? "{}");
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? (parsed as Record<string, T>)
      : {};
  } catch {
    return {};
  }
}

function isProgress(value: unknown): value is BackwordProgress {
  if (!value || typeof value !== "object") {
    return false;
  }
  const progress = value as Partial<BackwordProgress>;
  return (
    progress.schemaVersion === 1 &&
    typeof progress.date === "string" &&
    Array.isArray(progress.guesses) &&
    progress.guesses.every((guess) => typeof guess === "string") &&
    ["inProgress", "won", "failed"].includes(progress.outcome ?? "") &&
    // Swift's Codable omits optional fields whose value is nil. Treat the
    // absent native field as the browser's explicit null representation.
    (progress.completedAt === undefined || progress.completedAt === null || typeof progress.completedAt === "string")
  );
}

function normalizeProgress(progress: BackwordProgress): BackwordProgress {
  return {
    ...progress,
    completedAt: progress.completedAt ?? null
  };
}

function isOnboardingStep(value: unknown): value is BackwordOnboardingStep {
  return typeof value === "string" && BACKWORD_ONBOARDING_STEPS.includes(value as BackwordOnboardingStep);
}

function isWord(value: unknown): value is BackwordWord {
  if (!value || typeof value !== "object") {
    return false;
  }
  const word = value as Partial<BackwordWord>;
  return (
    typeof word.id === "string" &&
    typeof word.puzzleNumber === "number" && Number.isInteger(word.puzzleNumber) && word.puzzleNumber > 0 &&
    /^\d{4}-\d{2}-\d{2}$/.test(word.date ?? "") &&
    /^[A-Z]{6}$/.test(word.word ?? "") &&
    typeof word.clue === "string" &&
    word.clue.trim().length > 0
  );
}

export type BackwordStorage = ReturnType<typeof createBackwordStorage>;

type BackwordStorageOptions = {
  userId?: string | null;
  onProgressSaved?: (progress: BackwordProgress) => void;
};

export function createBackwordStorage(
  storage: Storage = window.localStorage,
  options: BackwordStorageOptions = {}
) {
  const scopedKey = (key: string) => options.userId ? `${key}:user:${options.userId}` : key;

  return {
    loadSettings(): BackwordSettings {
      try {
        const parsed: unknown = JSON.parse(storage.getItem(SETTINGS_KEY) ?? "null");
        if (!parsed || typeof parsed !== "object") {
          return { ...defaultSettings };
        }
        const value = parsed as Partial<BackwordSettings>;
        if (
          value.schemaVersion !== 1 ||
          (value.mode !== "normal" && value.mode !== "easy") ||
          typeof value.hasSeenOnboarding !== "boolean" ||
          typeof value.lastSeenRulesVersion !== "number" ||
          (value.dismissedOnboardingSteps !== undefined &&
            (!Array.isArray(value.dismissedOnboardingSteps) || !value.dismissedOnboardingSteps.every(isOnboardingStep))) ||
          (value.hasSeenInstructionsTip !== undefined && typeof value.hasSeenInstructionsTip !== "boolean")
        ) {
          return { ...defaultSettings };
        }
        return {
          ...value,
          dismissedOnboardingSteps: value.dismissedOnboardingSteps ?? [],
          hasSeenInstructionsTip: value.hasSeenInstructionsTip ?? false
        } as BackwordSettings;
      } catch {
        return { ...defaultSettings };
      }
    },

    saveSettings(settings: BackwordSettings): void {
      storage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    },

    markInstructionsSeen(settings: BackwordSettings): BackwordSettings {
      const updated = {
        ...settings,
        hasSeenOnboarding: true,
        lastSeenRulesVersion: BACKWORD_RULES_VERSION,
        dismissedOnboardingSteps: [...BACKWORD_ONBOARDING_STEPS]
      };
      this.saveSettings(updated);
      return updated;
    },

    dismissOnboardingStep(settings: BackwordSettings, step: BackwordOnboardingStep): BackwordSettings {
      const dismissedOnboardingSteps = settings.dismissedOnboardingSteps.includes(step)
        ? settings.dismissedOnboardingSteps
        : [...settings.dismissedOnboardingSteps, step];
      const hasSeenOnboarding = BACKWORD_ONBOARDING_STEPS.every((item) => dismissedOnboardingSteps.includes(item));
      const updated = {
        ...settings,
        dismissedOnboardingSteps,
        hasSeenOnboarding,
        lastSeenRulesVersion: hasSeenOnboarding ? BACKWORD_RULES_VERSION : settings.lastSeenRulesVersion
      };
      this.saveSettings(updated);
      return updated;
    },

    markInstructionsTipSeen(settings: BackwordSettings): BackwordSettings {
      const updated = { ...settings, hasSeenInstructionsTip: true };
      this.saveSettings(updated);
      return updated;
    },

    loadProgress(date: string): BackwordProgress {
      const progress = readRecord<unknown>(storage, scopedKey(PROGRESS_KEY))[date];
      return isProgress(progress) ? normalizeProgress(progress) : emptyProgress(date);
    },

    loadAllProgress(): BackwordProgress[] {
      return Object.values(readRecord<unknown>(storage, scopedKey(PROGRESS_KEY)))
        .filter(isProgress)
        .map(normalizeProgress);
    },

    saveProgress(progress: BackwordProgress): void {
      progress.updatedAt = new Date().toISOString();
      const records = readRecord<BackwordProgress>(storage, scopedKey(PROGRESS_KEY));
      records[progress.date] = progress;
      storage.setItem(scopedKey(PROGRESS_KEY), JSON.stringify(records));
      options.onProgressSaved?.(progress);
    },

    replaceProgress(progress: BackwordProgress): void {
      const records = readRecord<BackwordProgress>(storage, scopedKey(PROGRESS_KEY));
      records[progress.date] = progress;
      storage.setItem(scopedKey(PROGRESS_KEY), JSON.stringify(records));
    },

    deleteProgress(date: string): void {
      const records = readRecord<BackwordProgress>(storage, scopedKey(PROGRESS_KEY));
      delete records[date];
      storage.setItem(scopedKey(PROGRESS_KEY), JSON.stringify(records));
    },

    loadCachedWord(date: string): BackwordWord | null {
      const word = readRecord<unknown>(storage, PUZZLE_CACHE_KEY)[date];
      return isWord(word) ? word : null;
    },

    cacheWord(word: BackwordWord): void {
      const records = readRecord<BackwordWord>(storage, PUZZLE_CACHE_KEY);
      records[word.date] = word;
      storage.setItem(PUZZLE_CACHE_KEY, JSON.stringify(records));
    }
  };
}
