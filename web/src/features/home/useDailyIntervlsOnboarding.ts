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
    finishOnboarding: () => {
      saveDailyIntervlsStage(window.localStorage, "complete");
      setStage("complete");
    }
  };
}
