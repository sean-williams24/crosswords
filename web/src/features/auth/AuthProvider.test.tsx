import { act, render, screen, waitFor } from "@testing-library/react";
import { useEffect } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const supabaseMock = vi.hoisted(() => {
  const auth = {
    getSession: vi.fn(),
    getUser: vi.fn(),
    onAuthStateChange: vi.fn(),
    signInWithIdToken: vi.fn(),
    signOut: vi.fn()
  };
  return { client: { auth, functions: { invoke: vi.fn() }, rpc: vi.fn() }, auth };
});

vi.mock("../../lib/supabase", () => ({
  supabase: supabaseMock.client,
  supabaseConfigurationError: "Supabase is not configured."
}));

vi.mock("../sync/progressSync", () => ({
  flushSyncQueue: vi.fn()
}));

import { AuthProvider, useAuth } from "./AuthProvider";

function AuthConsumer({ onReady }: { onReady: (auth: ReturnType<typeof useAuth>) => void }) {
  const auth = useAuth();

  useEffect(() => {
    if (auth.ready) onReady(auth);
  }, [auth, onReady]);

  return <p>{auth.user?.email ?? "signed out"}</p>;
}

function RefreshIdentityProbe({ onRefresh }: { onRefresh: (refresh: ReturnType<typeof useAuth>["refreshEntitlement"]) => void }) {
  const { entitlement, ready, user, refreshEntitlement } = useAuth();

  useEffect(() => {
    if (ready && user) onRefresh(refreshEntitlement);
  }, [onRefresh, ready, refreshEntitlement, user?.id]);

  return <p>{entitlement?.isPro ? "Pro" : "No Pro"}</p>;
}

function EntitlementWarningProbe() {
  const { entitlementWarning, ready } = useAuth();

  return <p>{ready ? entitlementWarning ?? "No entitlement warning" : "Loading"}</p>;
}

function EntitlementReadyProbe() {
  const { entitlementReady } = useAuth();
  return <p>{entitlementReady ? "Entitlement ready" : "Checking entitlement"}</p>;
}

describe("AuthProvider", () => {
  beforeEach(() => {
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session: null }, error: null });
    supabaseMock.auth.getUser.mockResolvedValue({
      data: { user: { id: "user-id", email: "player@example.com" } },
      error: null
    });
    supabaseMock.auth.onAuthStateChange.mockReturnValue({
      data: { subscription: { unsubscribe: vi.fn() } }
    });
    supabaseMock.auth.signInWithIdToken.mockReset();
    supabaseMock.auth.signOut.mockReset();
    supabaseMock.auth.signOut.mockResolvedValue({ error: null });
    supabaseMock.client.functions.invoke.mockReset();
    supabaseMock.client.functions.invoke.mockResolvedValue({ error: null });
    supabaseMock.client.rpc.mockReset();
    supabaseMock.client.rpc.mockResolvedValue({ data: null, error: null });
  });

  it("sets the returned Google session without waiting for a listener event", async () => {
    const session = { user: { id: "user-id", email: "player@example.com" } };
    supabaseMock.auth.signInWithIdToken.mockResolvedValue({ data: { session }, error: null });
    let auth: ReturnType<typeof useAuth> | undefined;

    render(
      <AuthProvider>
        <AuthConsumer onReady={(value) => { auth = value; }} />
      </AuthProvider>
    );

    await screen.findByText("signed out");
    await waitFor(() => expect(auth).toBeDefined());
    await act(async () => {
      await auth?.signInWithGoogle("google-id-token", "/");
    });

    expect(supabaseMock.auth.signInWithIdToken).toHaveBeenCalledWith({
      provider: "google",
      token: "google-id-token"
    });
    expect(screen.getByText("player@example.com")).toBeInTheDocument();
  });

  it("keeps entitlement refresh stable after its result updates the provider", async () => {
    const onRefresh = vi.fn();
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session: { user: { id: "user-id", email: "player@example.com" } } }, error: null });
    supabaseMock.client.rpc.mockResolvedValue({ data: { is_pro: true, expires_at: null, provider: "stripe", cancel_at_period_end: true, has_used_trial: true }, error: null });

    render(
      <AuthProvider>
        <RefreshIdentityProbe onRefresh={onRefresh} />
      </AuthProvider>
    );

    await screen.findByText("Pro");
    expect(onRefresh).toHaveBeenCalledTimes(1);
  });

  it("coalesces concurrent entitlement refreshes for the active session", async () => {
    const session = { access_token: "session-token", user: { id: "user-id", email: "player@example.com" } };
    let resolveEntitlement: ((value: { data: { is_pro: boolean; expires_at: null }; error: null }) => void) | undefined;
    const entitlementResponse = new Promise<{ data: { is_pro: boolean; expires_at: null }; error: null }>((resolve) => {
      resolveEntitlement = resolve;
    });
    let auth: ReturnType<typeof useAuth> | undefined;
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session }, error: null });
    supabaseMock.client.rpc.mockReturnValue(entitlementResponse);

    render(
      <AuthProvider>
        <AuthConsumer onReady={(value) => { auth = value; }} />
      </AuthProvider>
    );

    await screen.findByText("player@example.com");
    await waitFor(() => expect(auth).toBeDefined());
    await waitFor(() => expect(supabaseMock.client.rpc).toHaveBeenCalledTimes(1));
    const activeAuth = auth!;
    const firstRefresh = activeAuth.refreshEntitlement();
    const secondRefresh = activeAuth.refreshEntitlement();
    expect(supabaseMock.client.rpc).toHaveBeenCalledTimes(1);

    await act(async () => {
      resolveEntitlement!({ data: { is_pro: true, expires_at: null }, error: null });
      await Promise.all([firstRefresh, secondRefresh]);
    });

    await waitFor(() => expect(auth?.entitlement?.isPro).toBe(true));
  });

  it("does not mark a signed-in entitlement ready before its lookup finishes", async () => {
    const session = { access_token: "session-token", user: { id: "user-id", email: "player@example.com" } };
    let resolveEntitlement: ((value: { data: { is_pro: boolean; expires_at: null }; error: null }) => void) | undefined;
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session }, error: null });
    supabaseMock.client.rpc.mockReturnValue(new Promise((resolve) => { resolveEntitlement = resolve; }));

    render(<AuthProvider><EntitlementReadyProbe /></AuthProvider>);

    expect(await screen.findByText("Checking entitlement")).toBeInTheDocument();
    await act(async () => { resolveEntitlement!({ data: { is_pro: true, expires_at: null }, error: null }); });
    expect(await screen.findByText("Entitlement ready")).toBeInTheDocument();
  });

  it("keeps the signed-in state until account-deletion confirmation is acknowledged", async () => {
    const session = { user: { id: "user-id", email: "player@example.com" } };
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session }, error: null });
    let auth: ReturnType<typeof useAuth> | undefined;

    render(
      <AuthProvider>
        <AuthConsumer onReady={(value) => { auth = value; }} />
      </AuthProvider>
    );

    await screen.findByText("player@example.com");
    supabaseMock.client.functions.invoke.mockResolvedValue({
      data: { deletion_summary: { has_apple_purchase: false, has_stripe_subscription: true } },
      error: null
    });
    let deletionSummary: Awaited<ReturnType<ReturnType<typeof useAuth>["deleteAccount"]>> | undefined;
    await act(async () => {
      deletionSummary = await auth?.deleteAccount();
    });

    expect(supabaseMock.client.functions.invoke).toHaveBeenCalledWith("delete-account");
    expect(deletionSummary).toEqual({ hasApplePurchase: false, hasStripeSubscription: true });
    expect(supabaseMock.auth.signOut).not.toHaveBeenCalled();
    expect(screen.getByText("player@example.com")).toBeInTheDocument();

    await act(async () => {
      await auth?.finishAccountDeletion();
    });

    expect(supabaseMock.auth.signOut).toHaveBeenCalledWith({ scope: "local" });
    expect(screen.getByText("signed out")).toBeInTheDocument();
  });

  it("keeps the entitlement failure out of auth state and exposes safe profile copy", async () => {
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session: { user: { id: "user-id", email: "player@example.com" } } }, error: null });
    supabaseMock.client.rpc.mockResolvedValue({ data: null, error: new Error("permission denied for current_user_pro_entitlement") });
    vi.spyOn(console, "error").mockImplementation(() => undefined);

    render(
      <AuthProvider>
        <EntitlementWarningProbe />
      </AuthProvider>
    );

    expect(await screen.findByText("We couldn't check account-linked Pro access right now. Please try again later.")).toBeInTheDocument();
    expect(screen.queryByText("permission denied for current_user_pro_entitlement")).not.toBeInTheDocument();
  });

  it("clears an account deleted on another device when the browser regains focus", async () => {
    const session = { access_token: "session-token", user: { id: "user-id", email: "player@example.com" } };
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session }, error: null });
    supabaseMock.auth.getUser.mockResolvedValue({ data: { user: session.user }, error: null });
    let auth: ReturnType<typeof useAuth> | undefined;

    render(
      <AuthProvider>
        <AuthConsumer onReady={(value) => { auth = value; }} />
      </AuthProvider>
    );

    await screen.findByText("player@example.com");
    await waitFor(() => expect(supabaseMock.auth.getUser).toHaveBeenCalled());
    supabaseMock.auth.getUser.mockResolvedValue({
      data: { user: null },
      error: { code: "user_not_found", status: 404 }
    });

    await act(async () => {
      window.dispatchEvent(new Event("focus"));
    });

    await waitFor(() => expect(screen.getByText("signed out")).toBeInTheDocument());
    expect(supabaseMock.auth.signOut).toHaveBeenCalledWith({ scope: "local" });
    expect(auth?.accountDeletionNotice).toBe(true);
  });

  it("keeps a cached session when account validation is temporarily offline", async () => {
    const session = { access_token: "session-token", user: { id: "user-id", email: "player@example.com" } };
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session }, error: null });
    supabaseMock.auth.getUser.mockResolvedValue({ data: { user: session.user }, error: null });
    vi.spyOn(console, "error").mockImplementation(() => undefined);

    render(
      <AuthProvider>
        <AuthConsumer onReady={() => undefined} />
      </AuthProvider>
    );

    await screen.findByText("player@example.com");
    supabaseMock.auth.getUser.mockResolvedValue({
      data: { user: null },
      error: new TypeError("Failed to fetch")
    });

    await act(async () => {
      window.dispatchEvent(new Event("focus"));
    });

    await waitFor(() => expect(console.error).toHaveBeenCalledWith(
      "Account session validation failed",
      expect.any(TypeError)
    ));
    expect(screen.getByText("player@example.com")).toBeInTheDocument();
    expect(supabaseMock.auth.signOut).not.toHaveBeenCalled();
  });
});
