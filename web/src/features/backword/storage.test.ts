import { BACKWORD_RULES_VERSION, emptyProgress } from "./engine";
import { createBackwordStorage } from "./storage";

describe("Backword browser storage", () => {
  beforeEach(() => localStorage.clear());

  it("uses Normal mode and unseen onboarding defaults", () => {
    const storage = createBackwordStorage(localStorage);
    expect(storage.loadSettings()).toEqual({
      schemaVersion: 1,
      mode: "normal",
      hasSeenOnboarding: false,
      lastSeenRulesVersion: 0
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

    const word = { id: "word-id", date: "2026-08-03", word: "CASTLE", clue: "Fortress" };
    storage.cacheWord(word);
    expect(storage.loadCachedWord(word.date)).toEqual(word);
  });

  it("fails safely when stored records are corrupt", () => {
    localStorage.setItem("backword:web:settings:v1", "not-json");
    localStorage.setItem("backword:web:progress:v1", JSON.stringify({ bad: { guesses: true } }));
    localStorage.setItem("backword:web:puzzles:v1", JSON.stringify({ bad: { word: "TOO-LONG" } }));
    const storage = createBackwordStorage(localStorage);

    expect(storage.loadSettings().mode).toBe("normal");
    expect(storage.loadAllProgress()).toEqual([]);
    expect(storage.loadCachedWord("bad")).toBeNull();
  });
});
