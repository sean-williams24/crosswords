import { useState } from "react";
import { readDailyIntervlsStage, saveDailyIntervlsStage } from "./dailyIntervlsOnboarding";

export function useDailyIntervlsOnboarding() {
  const [stage, setStage] = useState(() => readDailyIntervlsStage(window.localStorage));

  function acknowledgeGameplay() {
    saveDailyIntervlsStage(window.localStorage, "scoring");
    setStage("scoring");
  }

  return {
    pendingStep: stage === "complete" ? null : stage,
    acknowledgeGameplay,
    recordCompletion: () => saveDailyIntervlsStage(window.localStorage, "complete"),
    closeOnboarding: () => setStage("complete")
  };
}
