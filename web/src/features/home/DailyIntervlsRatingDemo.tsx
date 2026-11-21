import { useEffect, useState, type CSSProperties, type Ref } from "react";
import { HomeRatingTrack } from "./HomeProfileRatingLink";
import { maximumDailyPoints } from "./dailyChallenge";
import { ratingWindowDays, ratingTierForFraction, tierThresholds, weeklyRatingMaxPoints } from "../profile/profileRating";

export function DailyIntervlsRatingDemo({ isPro, reduceMotion, trackRef }: {
  isPro: boolean;
  reduceMotion: boolean;
  trackRef: Ref<HTMLSpanElement>;
}) {
  const [progress, setProgress] = useState(0);
  useEffect(() => {
    if (reduceMotion) return;
    let frame = 0;
    const start = performance.now() + 250;
    const tick = (now: number) => {
      const fraction = Math.max(0, Math.min(1, (now - start) / 4500));
      setProgress(fraction);
      if (fraction < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [reduceMotion]);

  const fraction = reduceMotion ? 1 : progress;
  const maximum = ratingWindowDays * maximumDailyPoints + (isPro ? weeklyRatingMaxPoints : 0);
  const points = Math.floor(fraction * maximum);
  const tier = ratingTierForFraction(points / maximum);
  const fade = (threshold: number) => {
    const start = Math.ceil(threshold * maximum) / maximum;
    const value = Math.max(0, Math.min(1, (fraction - start) / 0.05));
    return value * value * (3 - 2 * value);
  };

  return (
    <div className={`daily-intervls-guide__rating is-${tier.toLowerCase()}`}>
      <p className="sr-only">Example rating with all available points: {maximum} out of {maximum}, Virtuoso.</p>
      <div aria-hidden="true">
        <strong className="daily-intervls-guide__earned">{points} / {maximum} pts</strong>
        <div className="daily-intervls-guide__track" data-fraction={fraction}>
          <HomeRatingTrack fraction={fraction} ref={trackRef} />
        </div>
        <div className="daily-intervls-guide__tiers" style={{ "--progress": fraction } as CSSProperties}>
          <div>
            {tierThresholds.map(([name, threshold], index) => {
              const fadeIn = index === 0 ? 1 : fade(threshold);
              const nextThreshold = tierThresholds[index + 1]?.[1];
              return <span className={`is-${name.toLowerCase()}`} key={name} style={{ opacity: fadeIn - (nextThreshold === undefined ? 0 : fade(nextThreshold)) }}>{name.toUpperCase()}</span>;
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
