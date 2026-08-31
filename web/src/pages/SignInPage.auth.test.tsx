import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import userEvent from "@testing-library/user-event";
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
  GoogleSignInButton: ({ disabled, onCredential, onError }: { disabled: boolean; onCredential: (idToken: string) => void; onError: (error: Error) => void }) => (
    <>
      <button disabled={disabled} onClick={() => onCredential("google-id-token")} type="button">
        Continue with Google
      </button>
      <button onClick={() => onError(new Error("invalid JWT audience"))} type="button">Trigger Google Error</button>
    </>
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

  it("sends signed-in users to Player Profile instead of rendering account controls", () => {
    testAuth.value.user = { email: "player@example.com" };
    render(<MemoryRouter initialEntries={["/sign-in"]}><Routes>
      <Route path="/sign-in" element={<SignInPage />} />
      <Route path="/player-profile" element={<p>Player Profile destination</p>} />
    </Routes></MemoryRouter>);

    expect(screen.getByText("Player Profile destination")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Delete account" })).not.toBeInTheDocument();
  });

  it("returns an already Pro player to the requested weekly crossword", () => {
    testAuth.value.user = { email: "player@example.com" };
    render(<MemoryRouter initialEntries={[{ pathname: "/sign-in", state: { returnTo: "/weekly-crossword" } }]}><Routes>
      <Route path="/sign-in" element={<SignInPage />} />
      <Route path="/weekly-crossword" element={<p>Weekly Crossword destination</p>} />
    </Routes></MemoryRouter>);

    expect(screen.getByText("Weekly Crossword destination")).toBeInTheDocument();
  });

  it("shows a safe inline alert for a Google failure", async () => {
    const user = userEvent.setup();
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    render(<MemoryRouter initialEntries={["/sign-in"]}><Routes>
      <Route path="/sign-in" element={<SignInPage />} />
    </Routes></MemoryRouter>);

    await user.click(screen.getByRole("button", { name: "Trigger Google Error" }));

    expect(screen.getByRole("alert")).toHaveTextContent("We couldn't complete Google sign-in.");
    expect(screen.getByRole("alert")).not.toHaveTextContent("invalid JWT audience");
  });
});
