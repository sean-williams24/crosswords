import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import type { Provider, Session, User } from "@supabase/supabase-js";
import { supabase, supabaseConfigurationError } from "../../lib/supabase";
import { flushSyncQueue } from "../sync/progressSync";
import { entitlementWarning as entitlementWarningMessage } from "./authErrorPresentation";

type ProEntitlement = {
  isPro: boolean;
  expiresAt: string | null;
};

type AuthContextValue = {
  ready: boolean;
  user: User | null;
  session: Session | null;
  entitlement: ProEntitlement | null;
  entitlementWarning: string | null;
  signIn: (provider: Extract<Provider, "apple">, returnTo: string) => Promise<void>;
  signInWithGoogle: (idToken: string, returnTo: string) => Promise<void>;
  signOut: () => Promise<void>;
  deleteAccount: () => Promise<void>;
  finishAccountDeletion: () => Promise<void>;
  accountDeletionNotice: boolean;
  acknowledgeAccountDeletion: () => void;
  validateAccountSession: () => Promise<void>;
  refreshEntitlement: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);
const returnToKey = "backword:web:auth:return-to";
const guestAuth: AuthContextValue = {
  ready: true,
  user: null,
  session: null,
  entitlement: null,
  entitlementWarning: null,
  signIn: async () => { throw new Error(supabaseConfigurationError); },
  signInWithGoogle: async () => { throw new Error(supabaseConfigurationError); },
  signOut: async () => undefined,
  deleteAccount: async () => { throw new Error(supabaseConfigurationError); },
  finishAccountDeletion: async () => undefined,
  accountDeletionNotice: false,
  acknowledgeAccountDeletion: () => undefined,
  validateAccountSession: async () => undefined,
  refreshEntitlement: async () => undefined
};

function safeReturnTo(value: string) {
  return value.startsWith("/") && !value.startsWith("//") ? value : "/home";
}

export function requiresLocalSignOut(error: unknown) {
  if (!error || typeof error !== "object") return false;
  const accountError = error as { code?: unknown; status?: unknown };
  return accountError.code === "user_not_found"
    || accountError.status === 401
    || accountError.status === 404;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [session, setSession] = useState<Session | null>(null);
  const [entitlement, setEntitlement] = useState<ProEntitlement | null>(null);
  const [entitlementWarning, setEntitlementWarning] = useState<string | null>(null);
  const [accountDeletionNotice, setAccountDeletionNotice] = useState(false);
  const [isDeletingAccount, setIsDeletingAccount] = useState(false);

  const refreshEntitlement = useCallback(async () => {
    if (!supabase || !session) {
      setEntitlement(null);
      setEntitlementWarning(null);
      return;
    }
    const { data, error: entitlementError } = await supabase.rpc("current_user_pro_entitlement");
    if (entitlementError) {
      console.error("Account entitlement refresh failed", entitlementError);
      setEntitlementWarning(entitlementWarningMessage);
      return;
    }
    const result = Array.isArray(data) ? data[0] : data;
    setEntitlement(result ? {
      isPro: Boolean(result.is_pro),
      expiresAt: result.expires_at ?? null
    } : { isPro: false, expiresAt: null });
    setEntitlementWarning(null);
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
      if (sessionError) console.error("Account session lookup failed", sessionError);
      setReady(true);
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setEntitlementWarning(null);
    });

    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  const validateAccountSession = useCallback(async () => {
    const client = supabase;
    if (!client || !session || isDeletingAccount) return;

    const clearUnavailableSession = () => {
      // Local sign-out clears this browser even when the deleted account can
      // no longer acknowledge Supabase's logout request.
      void client.auth.signOut({ scope: "local" }).then(({ error }) => {
        if (error) console.error("Unavailable account local sign-out failed", error);
      });
      setSession(null);
      setEntitlement(null);
      setEntitlementWarning(null);
      setAccountDeletionNotice(true);
    };
    const { data, error } = await client.auth.getUser();
    if (!error && data.user?.id === session.user.id) return;
    if (requiresLocalSignOut(error) || (!error && !data.user)) {
      clearUnavailableSession();
      return;
    }
    console.error("Account session validation failed", error);
  }, [isDeletingAccount, session?.access_token, session?.user.id]);

  useEffect(() => {
    if (!session || isDeletingAccount) return;
    const validateWhenVisible = () => {
      if (document.visibilityState === "visible") void validateAccountSession();
    };

    void validateAccountSession();
    window.addEventListener("focus", validateAccountSession);
    window.addEventListener("online", validateAccountSession);
    document.addEventListener("visibilitychange", validateWhenVisible);
    return () => {
      window.removeEventListener("focus", validateAccountSession);
      window.removeEventListener("online", validateAccountSession);
      document.removeEventListener("visibilitychange", validateWhenVisible);
    };
  }, [isDeletingAccount, session?.access_token, session?.user.id, validateAccountSession]);

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
    entitlementWarning: supabase ? entitlementWarning : null,
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
      setIsDeletingAccount(false);
      setEntitlement(null);
    },
    async deleteAccount() {
      if (!supabase) throw new Error(supabaseConfigurationError);
      setIsDeletingAccount(true);
      const { error: deleteError } = await supabase.functions.invoke("delete-account");
      if (deleteError) {
        setIsDeletingAccount(false);
        throw deleteError;
      }
    },
    async finishAccountDeletion() {
      if (!supabase) return;
      const { error: signOutError } = await supabase.auth.signOut({ scope: "local" });
      if (signOutError) throw signOutError;
      setSession(null);
      setEntitlement(null);
      setEntitlementWarning(null);
      setIsDeletingAccount(false);
    },
    accountDeletionNotice,
    acknowledgeAccountDeletion() {
      setAccountDeletionNotice(false);
    },
    validateAccountSession,
    refreshEntitlement
  }), [ready, session, entitlement, entitlementWarning, accountDeletionNotice, validateAccountSession, refreshEntitlement]);

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
