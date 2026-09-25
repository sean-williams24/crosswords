import { useEffect, useRef, useState, type CSSProperties } from "react";
import { backwordOnboardingText } from "../onboarding";
import type { BackwordMode, BackwordOnboardingStep } from "../types";

type BackwordOnboardingCardsProps = {
  mode: BackwordMode;
  steps: BackwordOnboardingStep[];
  onDismiss: (step: BackwordOnboardingStep) => void;
};

const dismissalDuration = 220;

export function BackwordOnboardingCards({ mode, steps, onDismiss }: BackwordOnboardingCardsProps) {
  const [dismissingStep, setDismissingStep] = useState<BackwordOnboardingStep | null>(null);
  const dismissTimeout = useRef<number | null>(null);

  useEffect(() => () => {
    if (dismissTimeout.current !== null) window.clearTimeout(dismissTimeout.current);
  }, []);

  function dismiss(step: BackwordOnboardingStep) {
    if (dismissingStep) return;
    setDismissingStep(step);
    dismissTimeout.current = window.setTimeout(() => {
      onDismiss(step);
      setDismissingStep(null);
      dismissTimeout.current = null;
    }, dismissalDuration);
  }

  return (
    <section aria-label="How to play Backword" className="bw-onboarding-deck">
      {[...steps].reverse().map((step, reverseIndex) => {
        const index = steps.length - reverseIndex - 1;
        const isTopCard = index === 0;
        return (
          <article
            aria-hidden={!isTopCard}
            className={`bw-onboarding-card ${isTopCard ? "is-top" : ""} ${dismissingStep === step ? "is-dismissing" : ""}`}
            key={step}
            style={{
              "--bw-onboarding-delay": `${index * 70}ms`,
              "--bw-onboarding-offset": `${index * 15}px`,
              "--bw-onboarding-opacity": `${Math.max(0.28, 1 - index * 0.18)}`,
              "--bw-onboarding-scale": `${1 - index * 0.015}`,
              zIndex: steps.length - index
            } as CSSProperties}
          >
            <p>{backwordOnboardingText(step, mode)}</p>
            {isTopCard ? (
              <button aria-label={`OK: ${backwordOnboardingText(step, mode)}`} className="bw-onboarding-card__ok" onClick={() => dismiss(step)} type="button">
                OK
              </button>
            ) : null}
          </article>
        );
      })}
    </section>
  );
}
