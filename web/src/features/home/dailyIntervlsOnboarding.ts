export type GuideStep = "gameplay" | "scoring";
type OnboardingStage = GuideStep | "complete";

export const dailyIntervlsOnboardingKey = "intervls:daily-onboarding:v1";

export function readDailyIntervlsStage(storage: Storage): OnboardingStage {
  try {
    const saved = storage.getItem(dailyIntervlsOnboardingKey);
    if (saved === "scoring" || saved === "complete") return saved;
  } catch { /* The walkthrough is available when storage is blocked. */ }
  return "gameplay";
}

export function saveDailyIntervlsStage(storage: Storage, stage: OnboardingStage) {
  try {
    const saved = storage.getItem(dailyIntervlsOnboardingKey);
    if (saved === "complete" || (saved === "scoring" && stage !== "complete")) return;
    storage.setItem(dailyIntervlsOnboardingKey, stage);
  } catch { /* Keep the in-memory stage. */ }
}
