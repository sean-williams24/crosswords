import { Link } from "react-router-dom";
import { useAuth } from "../features/auth/AuthProvider";

export function Footer() {
  const { entitlement } = useAuth();
  const weeklyCrosswordDestination = entitlement?.isPro ? "/weekly-crossword" : "/pro?return_to=%2Fweekly-crossword";
  const archiveDestination = entitlement?.isPro ? "/archive" : "/pro?return_to=%2Farchive";

  return (
    <footer className="site-footer border-t border-line/80 px-6 py-8 text-sm text-textSecondary">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <p>© 2026 Backword</p>
        <nav aria-label="Footer" className="flex flex-wrap gap-x-5 gap-y-2">
          <Link className="transition hover:text-textPrimary" to="/">
            Home
          </Link>
          <Link className="transition hover:text-textPrimary" to="/backword">
            Backword
          </Link>
          <Link className="transition hover:text-textPrimary" to="/crossword">
            Crossword
          </Link>
          {!entitlement?.isPro ? (
            <Link className="transition hover:text-textPrimary" to="/pro">
              Get Pro
            </Link>
          ) : null}
          <Link className="transition hover:text-textPrimary" to={weeklyCrosswordDestination}>
            Pro Crossword
          </Link>
          <Link className="transition hover:text-textPrimary" to={archiveDestination}>
            Archive
          </Link>
          <Link className="transition hover:text-textPrimary" to="/player-profile">
            Player Profile
          </Link>
          <Link className="transition hover:text-textPrimary" to="/info">
            Info
          </Link>
          <Link className="transition hover:text-textPrimary" to="/contact">
            Contact
          </Link>
          <Link className="transition hover:text-textPrimary" to="/privacy">
            Privacy
          </Link>
          <Link className="transition hover:text-textPrimary" to="/terms">
            Terms
          </Link>
        </nav>
      </div>
    </footer>
  );
}
