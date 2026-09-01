import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";

type HomeArchiveLinkProps = {
  children: ReactNode;
  to: string;
};

export function HomeArchiveLink({ children, to }: HomeArchiveLinkProps) {
  const { entitlement } = useAuth();
  const destination = entitlement?.isPro ? to : `/pro?return_to=${encodeURIComponent(to)}`;

  return (
    <Link className="home-archive-link" to={destination}>
      <span>{children}</span>
      <svg aria-hidden="true" fill="none" height="16" viewBox="0 0 16 16" width="16">
        <path d="m6 3 5 5-5 5" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.8" />
      </svg>
    </Link>
  );
}
