export type GuideStep = "gameplay" | "scoring";
type OnboardingStage = GuideStep | "returningTipPending" | "complete";

export const dailyIntervlsOnboardingKey = "intervls:daily-onboarding:v1";
export const dailyIntervlsTipKey = "intervls:daily-onboarding-tip:v1";

export function readDailyIntervlsStage(storage: Storage): OnboardingStage {
  try {
    const saved = storage.getItem(dailyIntervlsOnboardingKey);
    if (saved === "gameplay" || saved === "scoring" || saved === "returningTipPending" || saved === "complete") {
      return saved;
    }

    for (let index = 0; index < storage.length; index++) {
      const key = storage.key(index) ?? "";
      if (key.startsWith("backword:web:") || key.startsWith("intervls:daily-celebrated:") || /^sb-.+-auth-token$/.test(key)) {
        return "returningTipPending";
      }
    }
  } catch { /* A fresh walkthrough is available when storage is blocked. */ }
  return "gameplay";
}

export function saveDailyIntervlsStage(storage: Storage, stage: OnboardingStage) {
  try {
    const saved = storage.getItem(dailyIntervlsOnboardingKey);
    if (saved === "complete" || (saved === "scoring" && stage !== "complete")) return;
    storage.setItem(dailyIntervlsOnboardingKey, stage);
  } catch { /* Keep the in-memory stage. */ }
}
