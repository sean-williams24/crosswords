import { useId, useLayoutEffect, useRef, useState, type CSSProperties, type RefObject } from "react";
import { DailyIntervlsLineup } from "./DailyIntervlsLineup";
import { DailyIntervlsRatingDemo } from "./DailyIntervlsRatingDemo";
import { HomeRatingTrack } from "./HomeProfileRatingLink";
import { maximumDailyPoints } from "./dailyChallenge";
import type { GuideStep } from "./dailyIntervlsOnboarding";
import { ratingWindowDays, type PlayerProfileRating } from "../profile/profileRating";
import "./dailyChallenge.css";
import "./dailyIntervlsGuide.css";

type HomeRatingDestination = Pick<PlayerProfileRating, "tier" | "fraction"> & {
  trackRef: RefObject<HTMLSpanElement | null>;
};

type GuideProps = {
  isPro: boolean;
  onClose: () => void;
  homeRating?: HomeRatingDestination;
  onboarding?: { startingStep: GuideStep; onAdvance: () => void; onComplete: () => void };
};

export function DailyIntervlsGuide({ isPro, onClose, homeRating, onboarding }: GuideProps) {
  const [step, setStep] = useState<GuideStep>(onboarding?.startingStep ?? "gameplay");
  const [handoff, setHandoff] = useState<{ style: CSSProperties; fraction: number; tier: string } | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const track = useRef<HTMLSpanElement>(null);
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

  function finish() {
    if (handoff) return;
    const source = track.current?.getBoundingClientRect();
    const target = homeRating?.trackRef.current?.getBoundingClientRect();
    const content = track.current?.closest(".daily-intervls-guide__content")?.getBoundingClientRect();
    const visible = (rect?: DOMRect): rect is DOMRect => !!rect && rect.width > 0 && rect.height > 0
      && rect.top >= 0 && rect.bottom <= innerHeight && rect.left >= 0 && rect.right <= innerWidth;
    if (homeRating && !reduceMotion && visible(source) && visible(target)
      && content && source.top >= content.top && source.bottom <= content.bottom) {
      const startFraction = Number(track.current?.parentElement?.dataset.fraction ?? 0);
      setHandoff({
        fraction: startFraction,
        tier: homeRating.tier,
        style: {
          "--source-left": `${source.left}px`, "--source-top": `${source.top}px`, "--source-width": `${source.width}px`,
          "--target-left": `${target.left}px`, "--target-top": `${target.top}px`, "--target-width": `${target.width}px`,
          "--source-fraction": `${startFraction * 100}%`, "--target-fraction": `${homeRating.fraction * 100}%`,
          "--source-inset": `${100 - Math.max(1, startFraction * 100)}%`,
          "--target-inset": `${100 - Math.max(1, homeRating.fraction * 100)}%`
        } as CSSProperties
      });
    } else {
      close();
    }
  }

  function advance() {
    if (step === "gameplay") {
      onboarding?.onAdvance();
      setStep("scoring");
    } else {
      onboarding?.onComplete();
      finish();
    }
  }

  function dismiss() {
    if (onboarding) return;
    if (step === "scoring") finish();
    else close();
  }

  return (
    <dialog aria-labelledby={headingId} aria-modal="true" className={`daily-intervls-guide${handoff ? " is-handing-off" : ""}`} data-onboarding={onboarding ? "" : undefined} onCancel={event => {
      event.preventDefault();
      dismiss();
    }} onClick={event => { if (event.target === event.currentTarget) dismiss(); }} onKeyDown={event => {
      if (event.key === "Enter" && event.target === heading.current) advance();
    }} ref={dialog}>
      <div className="daily-intervls-guide__card" inert={handoff !== null}>
        <div className="daily-intervls-guide__content" key={step}>
          <h2 id={headingId} ref={heading} tabIndex={-1}>{step === "gameplay" ? "Your Daily Intervls" : "Points and Rating"}</h2>
          {step === "gameplay" ? <>
            <p className="daily-intervls-guide__intro">Complete all four daily games before midnight, score a maximum of {maximumDailyPoints} points.</p>
            <DailyIntervlsLineup />
          </> : <>
            <DailyIntervlsRatingDemo isPro={isPro} reduceMotion={reduceMotion} trackRef={track} />
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
      {handoff ? (
        <div aria-hidden="true" className={`daily-intervls-guide__handoff is-${handoff.tier.toLowerCase()}`} onAnimationEnd={event => {
          if (event.target === event.currentTarget) close();
        }} style={handoff.style}>
          <HomeRatingTrack fraction={handoff.fraction} />
        </div>
      ) : null}
    </dialog>
  );
}
