import { Link } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";
import "./HomeRebrandNotice.css";

export function HomeRebrandNotice() {
  const { ready, user } = useAuth();
  const isBackwordSite = ["https://playbackword.com", "https://www.playbackword.com"].includes(window.location.origin);
  const isLocalDevelopment = import.meta.env.DEV
    && ["localhost", "127.0.0.1", "[::1]"].includes(window.location.hostname);

  if (!ready || (!isBackwordSite && !isLocalDevelopment)) return null;

  return (
    <aside aria-labelledby="home-rebrand-title" className="home-rebrand-notice">
      <div className="home-rebrand-notice__copy">
        <h2 id="home-rebrand-title">Backword is becoming Intervls later this week</h2>
        <p>Same games, a new name and a new home at intervls.com.</p>
        <p>
          {user
            ? "Before the move, check your game history in Player Profile. On Intervls, sign in with the same Apple or Google account to access your synced history."
            : "Sign in with Apple or Google before the move to save your game history to your account. Check your history here, then use the same account on Intervls to access your synced history."}
        </p>
        <p className="home-rebrand-notice__note">Browser-only history and unsynced saves won’t transfer to the new website.</p>
      </div>
      <Link
        className="home-rebrand-notice__action"
        state={user ? undefined : { returnTo: "/" }}
        to={user ? "/player-profile" : "/sign-in"}
      >
        {user ? "Check game history" : "Sign in to save history"}
      </Link>
    </aside>
  );
}
