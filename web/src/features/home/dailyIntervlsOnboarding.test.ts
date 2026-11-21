import { dailyIntervlsOnboardingKey, readDailyIntervlsStage, saveDailyIntervlsStage } from "./dailyIntervlsOnboarding";

describe("Daily Intervls onboarding storage", () => {
  beforeEach(() => localStorage.clear());

  it("starts the walkthrough on gameplay in a fresh browser", () => {
    expect(readDailyIntervlsStage(localStorage)).toBe("gameplay");
  });

  it.each(["backword:web:progress:v1:user:abc", "sb-project-auth-token", "backword:web:analytics-consent:v1"])(
    "starts the same walkthrough with existing browser data in %s", key => {
      localStorage.setItem(key, "stored");
      expect(readDailyIntervlsStage(localStorage)).toBe("gameplay");
    }
  );

  it("starts the walkthrough when the legacy returning tip was pending", () => {
    localStorage.setItem(dailyIntervlsOnboardingKey, "returningTipPending");
    expect(readDailyIntervlsStage(localStorage)).toBe("gameplay");
  });

  it("keeps completion when a stale tab saves the scoring step", () => {
    saveDailyIntervlsStage(localStorage, "complete");
    saveDailyIntervlsStage(localStorage, "scoring");
    expect(localStorage.getItem(dailyIntervlsOnboardingKey)).toBe("complete");
  });
});
