import { Link, useLocation } from "react-router-dom";
import { useAuth } from "./AuthProvider";

export function AuthButton({ className = "" }: { className?: string }) {
  const { pathname, search, hash } = useLocation();
  const { ready, user } = useAuth();
  const destination = `${pathname}${search}${hash}`;
  const label = !ready ? "…" : user ? "Player Profile" : "Login";
  const to = user ? "/player-profile" : "/sign-in";

  return (
    <Link className={`auth-button ${className}`.trim()} state={user ? undefined : { returnTo: destination }} to={to}>
      {label}
    </Link>
  );
}
