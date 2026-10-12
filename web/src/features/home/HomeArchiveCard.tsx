import { Link } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";

export function HomeArchiveCard() {
  const { entitlement } = useAuth();
  const destination = entitlement?.isPro ? "/archive" : "/pro?return_to=%2Farchive";

  return (
    <Link aria-label="Archive" className="home-game-card home-game-card--archive" to={destination}>
      <div className="home-game-card__identity home-archive-card__identity">
        <svg aria-hidden="true" fill="none" viewBox="0 0 24 24">
          <rect height="5" rx="1" stroke="currentColor" strokeWidth="1.7" width="20" x="2" y="3" />
          <path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8M10 12h4" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.7" />
        </svg>
        <p className="home-game-card__title">Archive</p>
      </div>
    </Link>
  );
}
