import { act, render, screen, waitFor } from "@testing-library/react";
import { useEffect } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const supabaseMock = vi.hoisted(() => {
  const auth = {
    getSession: vi.fn(),
    onAuthStateChange: vi.fn(),
    signInWithIdToken: vi.fn()
  };
  return { client: { auth, rpc: vi.fn() }, auth };
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

describe("AuthProvider", () => {
  beforeEach(() => {
    supabaseMock.auth.getSession.mockResolvedValue({ data: { session: null }, error: null });
    supabaseMock.auth.onAuthStateChange.mockReturnValue({
      data: { subscription: { unsubscribe: vi.fn() } }
    });
    supabaseMock.auth.signInWithIdToken.mockReset();
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
      await auth?.signInWithGoogle("google-id-token", "/home");
    });

    expect(supabaseMock.auth.signInWithIdToken).toHaveBeenCalledWith({
      provider: "google",
      token: "google-id-token"
    });
    expect(screen.getByText("player@example.com")).toBeInTheDocument();
  });
});
