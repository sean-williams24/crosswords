import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { consumeAuthReturnTo, useAuth } from "../features/auth/AuthProvider";
import { supabase } from "../lib/supabase";

export function AuthCallbackPage() {
  const navigate = useNavigate();
  const { ready, user } = useAuth();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!ready) return;
    if (user) {
      navigate(consumeAuthReturnTo(), { replace: true });
      return;
    }
    if (!supabase) {
      setError("Accounts are not configured for this site yet.");
      return;
    }
    void supabase.auth.exchangeCodeForSession(window.location.href)
      .then(({ error: exchangeError }) => {
        if (exchangeError) setError(exchangeError.message);
      });
  }, [navigate, ready, user]);

  return <main className="auth-page"><p className="auth-callback">{error ?? "Signing you in…"}</p></main>;
}
