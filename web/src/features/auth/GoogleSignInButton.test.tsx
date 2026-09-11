import { act, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const googleIdentity = vi.hoisted(() => ({
  renderGoogleSignInButton: vi.fn()
}));

vi.mock("./googleIdentity", () => googleIdentity);

import { GoogleSignInButton } from "./GoogleSignInButton";

describe("GoogleSignInButton", () => {
  beforeEach(() => {
    googleIdentity.renderGoogleSignInButton.mockReset();
    googleIdentity.renderGoogleSignInButton.mockResolvedValue(undefined);
  });

  it("initialises Google Identity once while using updated handlers", async () => {
    const firstCredentialHandler = vi.fn();
    const latestCredentialHandler = vi.fn();
    const onError = vi.fn();
    const { container, rerender } = render(
      <GoogleSignInButton disabled={false} onCredential={firstCredentialHandler} onError={onError} />
    );

    await waitFor(() => expect(googleIdentity.renderGoogleSignInButton).toHaveBeenCalledTimes(1));
    rerender(<GoogleSignInButton disabled={false} onCredential={latestCredentialHandler} onError={onError} />);

    expect(googleIdentity.renderGoogleSignInButton).toHaveBeenCalledTimes(1);
    const handlers = googleIdentity.renderGoogleSignInButton.mock.calls[0][1] as {
      onCredential: (idToken: string) => void;
    };
    act(() => handlers.onCredential("google-id-token"));

    expect(firstCredentialHandler).not.toHaveBeenCalled();
    expect(latestCredentialHandler).toHaveBeenCalledWith("google-id-token");
    expect(container.querySelector(".auth-google-button__identity")).not.toHaveAttribute("aria-hidden");
  });

  it("shows a clear unavailable state when Google Identity cannot load", async () => {
    const onError = vi.fn();
    googleIdentity.renderGoogleSignInButton.mockRejectedValueOnce(new Error("blocked"));

    render(<GoogleSignInButton disabled={false} onCredential={vi.fn()} onError={onError} />);

    expect(await screen.findByRole("status")).toHaveTextContent("Google sign-in is unavailable. Reload to try again.");
    expect(onError).toHaveBeenCalledWith(expect.objectContaining({ message: "blocked" }));
  });
});
