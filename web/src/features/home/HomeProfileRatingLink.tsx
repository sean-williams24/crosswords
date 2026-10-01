import type { CSSProperties } from "react";
import { Link } from "react-router-dom";
import type { PlayerProfileRating } from "../profile/profileRating";

type HomeProfileRatingLinkProps = Pick<PlayerProfileRating, "fraction" | "tier"> & {
  isSyncing?: boolean;
};

export function HomeProfileRatingLink({ fraction, isSyncing = false, tier }: HomeProfileRatingLinkProps) {
  const percentage = Math.max(0, Math.min(100, fraction * 100));
  const style = { "--home-profile-rating-position": `${percentage}%` } as CSSProperties;
  const label = isSyncing ? "SYNCING" : tier.toUpperCase();

  return (
    <Link
      aria-label={isSyncing ? "Syncing player progress. View player profile" : `Overall rating: ${tier}. View player profile`}
      className={`home-profile-rating-link is-${tier.toLowerCase()}${isSyncing ? " is-syncing" : ""}`}
      to="/player-profile"
    >
      <span aria-hidden="true" className="home-profile-rating-link__track">
        <span className="home-profile-rating-link__fill" style={isSyncing ? undefined : { clipPath: `inset(0 ${100 - Math.max(1, percentage)}% 0 0)` }} />
        {isSyncing ? null : <span className="home-profile-rating-link__marker" style={{ left: `${percentage}%` }} />}
      </span>
      <span aria-hidden="true" className="home-profile-rating-link__label" style={style}>{label}</span>
    </Link>
  );
}
