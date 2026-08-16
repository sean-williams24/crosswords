import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const testAuth = vi.hoisted(() => ({
  value: {
    ready: true,
    user: null as { email?: string } | null,
    entitlement: null,
    error: null,
    signIn: vi.fn(),
    signInWithGoogle: vi.fn(),
    signOut: vi.fn(),
    deleteAccount: vi.fn(),
    refreshEntitlement: vi.fn()
  }
}));

vi.mock("../features/auth/AuthProvider", () => ({
  useAuth: () => testAuth.value
}));

vi.mock("../features/auth/GoogleSignInButton", () => ({
  GoogleSignInButton: ({ disabled, onCredential }: { disabled: boolean; onCredential: (idToken: string) => void }) => (
    <button disabled={disabled} onClick={() => onCredential("google-id-token")} type="button">
      Sign in with Google
    </button>
  )
}));

import { SignInPage } from "./SignInPage";

describe("SignInPage authentication state", () => {
  beforeEach(() => {
    testAuth.value = {
      ready: true,
      user: null,
      entitlement: null,
      error: null,
      signIn: vi.fn(),
      signInWithGoogle: vi.fn(() => new Promise<void>(() => undefined)),
      signOut: vi.fn(),
      deleteAccount: vi.fn(),
      refreshEntitlement: vi.fn()
    };
  });

  it("clears a pending Google sign-in after the user signs out", async () => {
    const view = render(<MemoryRouter><SignInPage /></MemoryRouter>);

    fireEvent.click(screen.getByRole("button", { name: "Sign in with Google" }));
    expect(screen.getByRole("button", { name: "Sign in with Apple" })).toBeDisabled();

    testAuth.value.user = { email: "player@example.com" };
    view.rerender(<MemoryRouter><SignInPage /></MemoryRouter>);
    testAuth.value.user = null;
    view.rerender(<MemoryRouter><SignInPage /></MemoryRouter>);

    await waitFor(() => {
      expect(screen.getByRole("button", { name: "Sign in with Apple" })).toBeEnabled();
      expect(screen.getByRole("button", { name: "Sign in with Google" })).toBeEnabled();
    });
  });
});
