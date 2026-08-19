import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { consumeAuthReturnTo, useAuth } from "../features/auth/AuthProvider";
import { supabase } from "../lib/supabase";
import { isExpectedSignInCancellation, signInErrorAlert, type AuthAlert } from "../features/auth/authErrorPresentation";

export function AuthCallbackPage() {
  const navigate = useNavigate();
  const { ready, user } = useAuth();
  const [error, setError] = useState<AuthAlert | null>(null);

  useEffect(() => {
    if (!ready) return;
    if (user) {
      navigate(consumeAuthReturnTo(), { replace: true });
      return;
    }
    if (!supabase) {
      setError(signInErrorAlert(new Error("Supabase is not configured."), "apple"));
      return;
    }
    void supabase.auth.exchangeCodeForSession(window.location.href)
      .then(({ error: exchangeError }) => {
        if (!exchangeError) return;
        console.error("Apple sign-in callback failed", exchangeError);
        if (isExpectedSignInCancellation(exchangeError)) {
          navigate("/sign-in", { replace: true });
          return;
        }
        setError(signInErrorAlert(exchangeError, "apple"));
      });
  }, [navigate, ready, user]);

  return <main className="auth-page"><div className="auth-callback">{error ? <><strong>{error.title}</strong><span>{error.message}</span></> : "Signing you in…"}</div></main>;
}
