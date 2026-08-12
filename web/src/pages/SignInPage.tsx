import { useState } from "react";
import { useLocation } from "react-router-dom";
import type { Provider } from "@supabase/supabase-js";
import { useAuth } from "../features/auth/AuthProvider";
import { GameMenu } from "../features/backword/components/GameMenu";

type ProviderChoice = Extract<Provider, "apple" | "google">;

export function SignInPage() {
  const location = useLocation();
  const { user, ready, entitlement, error: authError, signIn, signOut, deleteAccount, refreshEntitlement } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState<ProviderChoice | null>(null);
  const returnTo = typeof location.state?.returnTo === "string" ? location.state.returnTo : "/home";

  async function continueWith(provider: ProviderChoice) {
    setError(null);
    setPending(provider);
    try {
      await signIn(provider, returnTo);
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
        <GameMenu />
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
      <GameMenu />
      <section aria-labelledby="sign-in-title" className="auth-content">
        <p className="auth-content__eyebrow">YOUR BACKWORD ACCOUNT</p>
        <h1 id="sign-in-title">Keep your games with you.</h1>
        <p className="auth-content__intro">
          Sign in to save your progress, carry your stats and streaks between devices, and keep your Pro access connected to Backword.
        </p>
        <ul className="auth-content__benefits">
          <li>Pick up a game on iPhone or the web.</li>
          <li>Keep your completed games and score history safe.</li>
          <li>Use an account only when you want to — guest play still works.</li>
        </ul>
        <div className="auth-content__providers">
          <button
            aria-label={pending === "apple" ? "Opening Apple" : "Sign in with Apple"}
            className="auth-apple-button"
            disabled={!ready || pending !== null}
            onClick={() => void continueWith("apple")}
            type="button"
          >
            <img
              alt=""
              src="https://appleid.cdn-apple.com/appleid/button?type=sign-in&color=white&border=true&border_radius=10&locale=en_GB&height=50&width=375&scale=2"
            />
          </button>
          <button className="auth-provider" disabled={!ready || pending !== null} onClick={() => void continueWith("google")} type="button">
            {pending === "google" ? "Opening Google…" : "Continue with Google"}
          </button>
        </div>
        {error || authError ? <p className="auth-content__error" role="alert">{error ?? authError}</p> : null}
        <p className="auth-content__note">If you use Apple’s Hide My Email, use Apple to sign in on every device.</p>
      </section>
    </main>
  );
}
