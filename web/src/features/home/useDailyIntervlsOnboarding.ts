import { useEffect, useState } from "react";
import { dailyIntervlsTipKey, readDailyIntervlsStage, saveDailyIntervlsStage } from "./dailyIntervlsOnboarding";

export function useDailyIntervlsOnboarding(canOfferTip: boolean) {
  const [stage, setStage] = useState(() => readDailyIntervlsStage(window.localStorage));
  const [showsTip, setShowsTip] = useState(() => {
    try { return window.sessionStorage.getItem(dailyIntervlsTipKey) === "1"; }
    catch { return false; }
  });

  useEffect(() => {
    if (!canOfferTip || stage !== "returningTipPending") return;
    const current = readDailyIntervlsStage(window.localStorage);
    if (current === "complete") {
      setStage(current);
      return;
    }
    saveDailyIntervlsStage(window.localStorage, "complete");
    try { window.sessionStorage.setItem(dailyIntervlsTipKey, "1"); } catch { /* Keep the tip on this visit. */ }
    setStage("complete");
    setShowsTip(true);
  }, [canOfferTip, stage]);

  function acknowledgeGameplay() {
    saveDailyIntervlsStage(window.localStorage, "scoring");
    setStage("scoring");
  }

  function dismissTip() {
    try { window.sessionStorage.removeItem(dailyIntervlsTipKey); } catch { /* Dismiss in memory. */ }
    setShowsTip(false);
  }

  return {
    firstLaunchStep: stage === "gameplay" || stage === "scoring" ? stage : null,
    showsTip: stage === "complete" && showsTip,
    acknowledgeGameplay,
    recordCompletion: () => saveDailyIntervlsStage(window.localStorage, "complete"),
    closeOnboarding: () => setStage("complete"),
    dismissTip
  };
}
