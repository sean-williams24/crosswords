import type { CSSProperties, ReactNode, Ref } from "react";
import { Link } from "react-router-dom";
import type { PlayerProfileRating } from "../profile/profileRating";

type HomeProfileRatingLinkProps = Pick<PlayerProfileRating, "fraction" | "tier"> & {
  isSyncing?: boolean;
  dailySummary?: ReactNode;
  ratingTrackRef?: Ref<HTMLSpanElement>;
};

export function HomeProfileRatingLink({ fraction, isSyncing = false, tier, dailySummary, ratingTrackRef }: HomeProfileRatingLinkProps) {
  const style = { "--home-profile-rating-position": `${Math.max(0, Math.min(100, fraction * 100))}%` } as CSSProperties;
  const label = isSyncing ? "SYNCING" : tier.toUpperCase();

  return (
    <Link
      aria-label={isSyncing ? "Syncing player progress. View player profile" : `Overall rating: ${tier}. View player profile`}
      className={`home-profile-rating-link is-${tier.toLowerCase()}${isSyncing ? " is-syncing" : ""}`}
      to="/player-profile"
    >
      <HomeRatingTrack fraction={fraction} isSyncing={isSyncing} ref={ratingTrackRef} />
      <span className="home-profile-rating-link__label-row"><span aria-hidden="true" className="home-profile-rating-link__label" style={style}>{label}</span>{dailySummary}</span>
    </Link>
  );
}

export function HomeRatingTrack({ fraction, isSyncing = false, ref }: { fraction: number; isSyncing?: boolean; ref?: Ref<HTMLSpanElement> }) {
  const percentage = Math.max(0, Math.min(100, fraction * 100));
  return (
    <span aria-hidden="true" className="home-profile-rating-link__track" ref={ref}>
      <span className="home-profile-rating-link__fill" style={isSyncing ? undefined : { clipPath: `inset(0 ${100 - Math.max(1, percentage)}% 0 0)` }} />
      {isSyncing ? null : <span className="home-profile-rating-link__marker" style={{ left: `${percentage}%` }} />}
    </span>
  );
}
