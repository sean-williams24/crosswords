import { Link } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";

type HomeArchiveLinkProps = {
  ariaLabel: string;
  to: string;
};

export function HomeArchiveLink({ ariaLabel, to }: HomeArchiveLinkProps) {
  const { entitlement } = useAuth();
  const destination = entitlement?.isPro ? to : `/pro?return_to=${encodeURIComponent(to)}`;

  return (
    <Link aria-label={ariaLabel} className="home-archive-link" to={destination}>
      <svg aria-hidden="true" fill="none" viewBox="0 0 24 24">
        <rect height="5" rx="1" stroke="currentColor" strokeWidth="1.7" width="20" x="2" y="3" />
        <path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8M10 12h4" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.7" />
      </svg>
      <span>Archive</span>
    </Link>
  );
}
