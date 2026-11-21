import { dailyIntervlsOnboardingKey, readDailyIntervlsStage, saveDailyIntervlsStage } from "./dailyIntervlsOnboarding";

describe("Daily Intervls onboarding storage", () => {
  beforeEach(() => localStorage.clear());

  it("keeps the first walkthrough available when startup creates a puzzle cache", () => {
    saveDailyIntervlsStage(localStorage, readDailyIntervlsStage(localStorage));
    localStorage.setItem("backword:web:midword:puzzles:v1", "{}");
    expect(readDailyIntervlsStage(localStorage)).toBe("gameplay");
  });

  it.each(["backword:web:progress:v1:user:abc", "sb-project-auth-token", "backword:web:analytics-consent:v1"])(
    "recognises prior use from %s", key => {
      localStorage.setItem(key, "stored");
      expect(readDailyIntervlsStage(localStorage)).toBe("returningTipPending");
    }
  );

  it("keeps completion when a stale tab saves the scoring step", () => {
    saveDailyIntervlsStage(localStorage, "complete");
    saveDailyIntervlsStage(localStorage, "scoring");
    expect(localStorage.getItem(dailyIntervlsOnboardingKey)).toBe("complete");
  });
});
