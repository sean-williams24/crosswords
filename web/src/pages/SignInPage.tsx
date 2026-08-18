import { useState } from "react";
import { Link, Navigate, useLocation } from "react-router-dom";
import { useAuth } from "../features/auth/AuthProvider";
import { BackwordLogo } from "../features/backword/components/BackwordLogo";
import { AccountBenefitIcon } from "../features/auth/AccountBenefitIcon";
import { GoogleSignInButton } from "../features/auth/GoogleSignInButton";
import { GameMenu } from "../features/backword/components/GameMenu";

type ProviderChoice = "apple" | "google";

export function SignInPage() {
  const location = useLocation();
  const { user, ready, error: authError, signIn, signInWithGoogle } = useAuth();
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

  if (ready && user) {
    return <Navigate replace to="/player-profile" />;
  }

  return (
    <main className="auth-page">
      {navigationHeader}
      <section aria-labelledby="sign-in-title" className="auth-content">
        <h1 className="auth-content__sign-in-title" id="sign-in-title">Sign in or create an account</h1>
        <p className="auth-content__intro">
          Play as a guest whenever you like, or create an account to:
        </p>
        <ul className="auth-content__benefits auth-content__benefits--sign-in">
          <li><AccountBenefitIcon name="sync" /><span>Continue a game on another device or the web.</span></li>
          <li><AccountBenefitIcon name="stats" /><span>Keep your stats, streaks, and score history safe.</span></li>
          <li><AccountBenefitIcon name="pro" /><span>Keep your verified Pro access connected to Backword.</span></li>
        </ul>
        <div className="auth-content__providers auth-content__providers--sign-in">
          <GoogleSignInButton
            disabled={!ready || pending !== null}
            onCredential={(idToken) => void continueWithGoogle(idToken)}
            onError={(signInError) => setError(signInError.message)}
          />
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
        </div>
        {error || authError ? <p className="auth-content__error" role="alert">{error ?? authError}</p> : null}
        <p className="auth-content__note">If you use Apple’s Hide My Email, use Apple to sign in on every device.</p>
      </section>
    </main>
  );
}
