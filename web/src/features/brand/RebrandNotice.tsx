import { Link, useLocation } from "react-router-dom";
import { brand, isLegacyOrigin } from "./brand";

export function RebrandNotice() {
  const location = useLocation();
  if (brand.launchEnabled || !brand.noticeEnabled || !isLegacyOrigin(window.location.origin)
    || ["/auth/callback", "/sign-in"].includes(location.pathname)) return null;
  return <aside className="rebrand-notice" aria-label="Upcoming name change">
    <span>Backword is becoming Intervls. Sign in before launch to sync your history. Browser-only history will start fresh on Intervls.</span>{" "}
    <Link to="/sign-in" state={{ returnTo: location.pathname + location.search }}>Sign in to sync</Link>
  </aside>;
}
