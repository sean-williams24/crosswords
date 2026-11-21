import { useId, useLayoutEffect, useRef, useState } from "react";
import { DailyIntervlsLineup } from "./DailyIntervlsLineup";
import { DailyIntervlsRatingDemo } from "./DailyIntervlsRatingDemo";
import { maximumDailyPoints } from "./dailyChallenge";
import type { GuideStep } from "./dailyIntervlsOnboarding";
import { ratingWindowDays } from "../profile/profileRating";
import "./dailyChallenge.css";
import "./dailyIntervlsGuide.css";

type GuideProps = {
  isPro: boolean;
  onClose: () => void;
  onboarding?: { startingStep: GuideStep; onAdvance: () => void; onComplete: () => void };
};

export function DailyIntervlsGuide({ isPro, onClose, onboarding }: GuideProps) {
  const [step, setStep] = useState<GuideStep>(onboarding?.startingStep ?? "gameplay");
  const dialog = useRef<HTMLDialogElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const headingId = useId();
  const reduceMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;

  useLayoutEffect(() => {
    const element = dialog.current!;
    if (!element.open) element.showModal();
    return () => { if (element.open) element.close(); };
  }, []);

  useLayoutEffect(() => { heading.current?.focus(); }, [step]);

  function close() {
    dialog.current?.close();
    onClose();
  }

  function advance() {
    if (step === "gameplay") {
      onboarding?.onAdvance();
      setStep("scoring");
    } else {
      onboarding?.onComplete();
      close();
    }
  }

  function dismiss() {
    if (!onboarding) close();
  }

  return (
    <dialog aria-labelledby={headingId} aria-modal="true" className="daily-intervls-guide" data-onboarding={onboarding ? "" : undefined} onCancel={event => {
      event.preventDefault();
      dismiss();
    }} onClick={event => { if (event.target === event.currentTarget) dismiss(); }} onKeyDown={event => {
      if (event.key === "Enter" && event.target === heading.current) advance();
    }} ref={dialog}>
      <div className="daily-intervls-guide__card">
        <div className="daily-intervls-guide__content" key={step}>
          <h2 id={headingId} ref={heading} tabIndex={-1}>{step === "gameplay" ? "Your Daily Intervls" : "Points and Rating"}</h2>
          {step === "gameplay" ? <>
            <p className="daily-intervls-guide__intro">Complete all four daily games before midnight, score a maximum of {maximumDailyPoints} points.</p>
            <DailyIntervlsLineup />
          </> : <>
            <DailyIntervlsRatingDemo isPro={isPro} reduceMotion={reduceMotion} />
            <ul className="daily-intervls-guide__bullets">
              <li>Your rating is based on the points you earned over the last {ratingWindowDays} days.</li>
              <li>Complete your Intervls everyday to reach the highest tier and stay there.</li>
              <li>Each new day replaces the oldest.</li>
            </ul>
          </>}
        </div>
        <div className="daily-intervls-guide__actions">
          <button className="daily-intervls-guide__primary" onClick={advance} type="button">{step === "gameplay" ? "OK" : onboarding ? "Lets play" : "Done"}</button>
          {!onboarding && step === "gameplay" ? <button onClick={dismiss} type="button">Close</button> : null}
        </div>
      </div>
    </dialog>
  );
}
