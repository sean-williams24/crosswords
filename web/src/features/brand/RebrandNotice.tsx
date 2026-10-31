import { Link, useLocation } from "react-router-dom";
import { brand, isLegacyOrigin } from "./brand";

export function RebrandNotice() {
  const location = useLocation();
  if (brand.launchEnabled || !brand.noticeEnabled || !isLegacyOrigin(window.location.origin)
    || ["/move", "/auth/callback", "/sign-in"].includes(location.pathname)) return null;
  return <aside className="rebrand-notice" aria-label="Upcoming name change">
    <span>Backword is becoming Intervls. Keep your history ready for the move.</span>{" "}
    <Link to={`/move?return_to=${encodeURIComponent(location.pathname + location.search)}`}>Check and sync my saves</Link>
  </aside>;
}
