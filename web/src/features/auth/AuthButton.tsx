import { Link, useLocation } from "react-router-dom";
import { useAuth } from "./AuthProvider";

export function AuthButton({ className = "" }: { className?: string }) {
  const { pathname, search, hash } = useLocation();
  const { ready, user } = useAuth();
  const destination = `${pathname}${search}${hash}`;
  const label = !ready ? "…" : user ? "Account" : "Login";

  return (
    <Link className={`auth-button ${className}`.trim()} state={{ returnTo: destination }} to="/sign-in">
      {label}
    </Link>
  );
}
