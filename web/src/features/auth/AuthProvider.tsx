import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import type { Provider, Session, User } from "@supabase/supabase-js";
import { supabase, supabaseConfigurationError } from "../../lib/supabase";
import { flushSyncQueue } from "../sync/progressSync";

type ProEntitlement = {
  isPro: boolean;
  expiresAt: string | null;
};

type AuthContextValue = {
  ready: boolean;
  user: User | null;
  session: Session | null;
  entitlement: ProEntitlement | null;
  error: string | null;
  signIn: (provider: Extract<Provider, "apple">, returnTo: string) => Promise<void>;
  signInWithGoogle: (idToken: string, returnTo: string) => Promise<void>;
  signOut: () => Promise<void>;
  deleteAccount: () => Promise<void>;
  refreshEntitlement: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);
const returnToKey = "backword:web:auth:return-to";
const guestAuth: AuthContextValue = {
  ready: true,
  user: null,
  session: null,
  entitlement: null,
  error: null,
  signIn: async () => { throw new Error(supabaseConfigurationError); },
  signInWithGoogle: async () => { throw new Error(supabaseConfigurationError); },
  signOut: async () => undefined,
  deleteAccount: async () => { throw new Error(supabaseConfigurationError); },
  refreshEntitlement: async () => undefined
};

function safeReturnTo(value: string) {
  return value.startsWith("/") && !value.startsWith("//") ? value : "/home";
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [session, setSession] = useState<Session | null>(null);
  const [entitlement, setEntitlement] = useState<ProEntitlement | null>(null);
  const [error, setError] = useState<string | null>(null);

  const refreshEntitlement = useCallback(async () => {
    if (!supabase || !session) {
      setEntitlement(null);
      return;
    }
    const { data, error: entitlementError } = await supabase.rpc("current_user_pro_entitlement");
    if (entitlementError) {
      setError(entitlementError.message);
      return;
    }
    const result = Array.isArray(data) ? data[0] : data;
    setEntitlement(result ? {
      isPro: Boolean(result.is_pro),
      expiresAt: result.expires_at ?? null
    } : { isPro: false, expiresAt: null });
  }, [session]);

  useEffect(() => {
    if (!supabase) {
      setReady(true);
      return;
    }

    let active = true;
    void supabase.auth.getSession().then(({ data, error: sessionError }) => {
      if (!active) return;
      setSession(data.session);
      setError(sessionError?.message ?? null);
      setReady(true);
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setError(null);
    });

    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    void refreshEntitlement();
  }, [session?.user.id]);

  useEffect(() => {
    const userId = session?.user.id;
    if (!userId) return;
    void flushSyncQueue(userId);
    const retry = () => void flushSyncQueue(userId);
    window.addEventListener("online", retry);
    return () => window.removeEventListener("online", retry);
  }, [session?.user.id]);

  const value = useMemo<AuthContextValue>(() => ({
    ready,
    user: session?.user ?? null,
    session,
    entitlement,
    error: supabase ? error : null,
    async signIn(provider, returnTo) {
      if (!supabase) throw new Error(supabaseConfigurationError);
      sessionStorage.setItem(returnToKey, safeReturnTo(returnTo));
      const { error: signInError } = await supabase.auth.signInWithOAuth({
        provider,
        options: { redirectTo: `${window.location.origin}/auth/callback` }
      });
      if (signInError) throw signInError;
    },
    async signInWithGoogle(idToken, returnTo) {
      if (!supabase) throw new Error(supabaseConfigurationError);
      sessionStorage.setItem(returnToKey, safeReturnTo(returnTo));
      const { data, error: signInError } = await supabase.auth.signInWithIdToken({
        provider: "google",
        token: idToken
      });
      if (signInError) throw signInError;
      setSession(data.session);
    },
    async signOut() {
      if (!supabase) return;
      const { error: signOutError } = await supabase.auth.signOut();
      if (signOutError) throw signOutError;
      setEntitlement(null);
    },
    async deleteAccount() {
      if (!supabase) throw new Error(supabaseConfigurationError);
      const { error: deleteError } = await supabase.functions.invoke("delete-account");
      if (deleteError) throw deleteError;
      await supabase.auth.signOut();
      setEntitlement(null);
    },
    refreshEntitlement
  }), [ready, session, entitlement, error, refreshEntitlement]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  return value ?? guestAuth;
}

export function consumeAuthReturnTo() {
  const returnTo = safeReturnTo(sessionStorage.getItem(returnToKey) ?? "/home");
  sessionStorage.removeItem(returnToKey);
  return returnTo;
}
