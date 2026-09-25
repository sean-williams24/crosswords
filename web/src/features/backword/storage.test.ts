import { BACKWORD_RULES_VERSION, emptyProgress } from "./engine";
import { createBackwordStorage } from "./storage";

describe("Backword browser storage", () => {
  beforeEach(() => localStorage.clear());

  it("uses Easy mode and unseen onboarding defaults", () => {
    const storage = createBackwordStorage(localStorage);
    expect(storage.loadSettings()).toEqual({
      schemaVersion: 1,
      mode: "easy",
      hasSeenOnboarding: false,
      lastSeenRulesVersion: 0,
      dismissedOnboardingSteps: [],
      hasSeenInstructionsTip: false
    });
  });

  it("persists settings, progress, and cached content", () => {
    const storage = createBackwordStorage(localStorage);
    const settings = storage.markInstructionsSeen(storage.loadSettings());
    expect(settings.lastSeenRulesVersion).toBe(BACKWORD_RULES_VERSION);

    const progress = { ...emptyProgress("2026-08-03"), guesses: ["XXXXXE"] };
    storage.saveProgress(progress);
    expect(storage.loadProgress("2026-08-03")).toEqual(progress);
    expect(storage.loadAllProgress()).toEqual([progress]);

    const word = { id: "word-id", puzzleNumber: 7, date: "2026-08-03", word: "CASTLE", clue: "Fortress" };
    storage.cacheWord(word);
    expect(storage.loadCachedWord(word.date)).toEqual(word);
  });

  it("fails safely when stored records are corrupt", () => {
    localStorage.setItem("backword:web:settings:v1", "not-json");
    localStorage.setItem("backword:web:progress:v1", JSON.stringify({ bad: { guesses: true } }));
    localStorage.setItem("backword:web:puzzles:v1", JSON.stringify({ bad: { word: "TOO-LONG" } }));
    const storage = createBackwordStorage(localStorage);

    expect(storage.loadSettings().mode).toBe("easy");
    expect(storage.loadAllProgress()).toEqual([]);
    expect(storage.loadCachedWord("bad")).toBeNull();
  });

  it("persists each onboarding acknowledgement before completing onboarding", () => {
    const storage = createBackwordStorage(localStorage);
    let settings = storage.loadSettings();

    settings = storage.dismissOnboardingStep(settings, "guessWord");
    expect(settings).toMatchObject({
      hasSeenOnboarding: false,
      dismissedOnboardingSteps: ["guessWord"]
    });

    for (const step of ["connectedLetters", "freeReveals", "scoring", "stuckHint"] as const) {
      settings = storage.dismissOnboardingStep(settings, step);
    }
    expect(settings.hasSeenOnboarding).toBe(true);
    expect(settings.lastSeenRulesVersion).toBe(BACKWORD_RULES_VERSION);
  });

  it("accepts iOS in-progress payloads that omit optional completedAt", () => {
    const storage = createBackwordStorage(localStorage);
    localStorage.setItem("backword:web:progress:v1", JSON.stringify({
      "2026-08-06": {
        schemaVersion: 1,
        date: "2026-08-06",
        guesses: ["PLANET", "CASTLE"],
        outcome: "inProgress",
        updatedAt: "2026-08-12T12:00:00.000Z"
      }
    }));

    expect(storage.loadProgress("2026-08-06")).toMatchObject({
      date: "2026-08-06",
      guesses: ["PLANET", "CASTLE"],
      completedAt: null,
      outcome: "inProgress"
    });
    expect(storage.loadAllProgress()).toHaveLength(1);
  });
});
