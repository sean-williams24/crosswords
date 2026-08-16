import { useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useAuth } from "../features/auth/AuthProvider";
import { BackwordLogo } from "../features/backword/components/BackwordLogo";
import { GoogleSignInButton } from "../features/auth/GoogleSignInButton";
import { GameMenu } from "../features/backword/components/GameMenu";

type ProviderChoice = "apple" | "google";

export function SignInPage() {
  const location = useLocation();
  const { user, ready, entitlement, error: authError, signIn, signInWithGoogle, signOut, deleteAccount, refreshEntitlement } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState<ProviderChoice | null>(null);
  const returnTo = typeof location.state?.returnTo === "string" ? location.state.returnTo : "/home";
  const navigationHeader = (
    <header className="home-dashboard__header auth-page__header">
      <GameMenu />
      <Link aria-label="Backword home" to="/home">
        <BackwordLogo large />
      </Link>
    </header>
  );

  useEffect(() => {
    if (!user) setPending(null);
  }, [user]);

  async function continueWithApple() {
    setError(null);
    setPending("apple");
    try {
      await signIn("apple", returnTo);
    } catch (signInError) {
      setError(signInError instanceof Error ? signInError.message : "Sign in could not be started.");
      setPending(null);
    }
  }

  async function continueWithGoogle(idToken: string) {
    setError(null);
    setPending("google");
    try {
      await signInWithGoogle(idToken, returnTo);
    } catch (signInError) {
      setError(signInError instanceof Error ? signInError.message : "Sign in could not be started.");
      setPending(null);
    }
  }

  async function removeAccount() {
    if (!window.confirm("Delete your Backword account and synced progress? This does not cancel an Apple subscription.")) return;
    setError(null);
    try {
      await deleteAccount();
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : "Your account could not be deleted.");
    }
  }

  if (ready && user) {
    return (
      <main className="auth-page">
        {navigationHeader}
        <section aria-labelledby="account-title" className="auth-content">
          <p className="auth-content__eyebrow">YOUR BACKWORD ACCOUNT</p>
          <h1 id="account-title">Your games are synced.</h1>
          <p className="auth-content__intro">{user.email ?? "Signed in"}</p>
          <ul className="auth-content__benefits">
            <li>{entitlement?.isPro ? "Pro is active for this account." : "No account-linked Pro subscription."}</li>
            <li>Progress and stats are stored securely for this account.</li>
          </ul>
          <div className="auth-content__providers">
            <button className="auth-provider" onClick={() => void refreshEntitlement()} type="button">Refresh account</button>
            <button className="auth-provider" onClick={() => void signOut()} type="button">Sign out</button>
            <button className="auth-provider auth-provider--danger" onClick={() => void removeAccount()} type="button">Delete account</button>
          </div>
          {error || authError ? <p className="auth-content__error" role="alert">{error ?? authError}</p> : null}
        </section>
      </main>
    );
  }

  return (
    <main className="auth-page">
      {navigationHeader}
      <section aria-labelledby="sign-in-title" className="auth-content">
        <h1 className="auth-content__sign-in-title" id="sign-in-title">Sign in or create an account</h1>
        <p className="auth-content__intro">
          Play as a guest whenever you like, or create an account to:
        </p>
        <ul className="auth-content__benefits">
          <li>Continue a game on another device or the web.</li>
          <li>Keep your stats, streaks, and score history safe.</li>
          <li>Keep your verified Pro access connected to Backword.</li>
        </ul>
        <div className="auth-content__providers">
          <button
            aria-label={pending === "apple" ? "Opening Apple" : "Continue with Apple"}
            className="auth-apple-button"
            disabled={!ready || pending !== null}
            onClick={() => void continueWithApple()}
            type="button"
          >
            <span className="auth-apple-button__content">
              <img
                alt=""
                src="https://appleid.cdn-apple.com/appleid/button/logo?color=white&border=false&border_radius=0&size=30&scale=2"
              />
              <span>Continue with Apple</span>
            </span>
          </button>
          <GoogleSignInButton
            disabled={!ready || pending !== null}
            onCredential={(idToken) => void continueWithGoogle(idToken)}
            onError={(signInError) => setError(signInError.message)}
          />
        </div>
        {error || authError ? <p className="auth-content__error" role="alert">{error ?? authError}</p> : null}
        <p className="auth-content__note">If you use Apple’s Hide My Email, use Apple to sign in on every device.</p>
      </section>
    </main>
  );
}
