import type { CSSProperties } from "react";
import { Link } from "react-router-dom";
import type { PlayerProfileRating } from "../profile/profileRating";

type HomeProfileRatingLinkProps = Pick<PlayerProfileRating, "fraction" | "tier">;

export function HomeProfileRatingLink({ fraction, tier }: HomeProfileRatingLinkProps) {
  const percentage = Math.max(0, Math.min(100, fraction * 100));
  const style = { "--home-profile-rating-position": `${percentage}%` } as CSSProperties;

  return (
    <Link aria-label={`Overall rating: ${tier}. View player profile`} className={`home-profile-rating-link is-${tier.toLowerCase()}`} to="/player-profile">
      <span aria-hidden="true" className="home-profile-rating-link__track">
        <span className="home-profile-rating-link__fill" style={{ clipPath: `inset(0 ${100 - Math.max(1, percentage)}% 0 0)` }} />
        <span className="home-profile-rating-link__marker" style={{ left: `${percentage}%` }} />
      </span>
      <span aria-hidden="true" className="home-profile-rating-link__label" style={style}>{tier.toUpperCase()}</span>
    </Link>
  );
}
