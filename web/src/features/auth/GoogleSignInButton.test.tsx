import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const googleIdentity = vi.hoisted(() => ({
  renderGoogleSignInButton: vi.fn()
}));

vi.mock("./googleIdentity", () => googleIdentity);

import { GoogleSignInButton } from "./GoogleSignInButton";
import { ThemeProvider } from "../theme/ThemeProvider";

describe("GoogleSignInButton", () => {
  beforeEach(() => {
    googleIdentity.renderGoogleSignInButton.mockReset();
    googleIdentity.renderGoogleSignInButton.mockResolvedValue(undefined);
  });

  it("shows a disabled local button on the first render while Google's script is pending", () => {
    googleIdentity.renderGoogleSignInButton.mockReturnValue(new Promise<void>(() => undefined));
    render(<GoogleSignInButton disabled={false} onCredential={vi.fn()} onError={vi.fn()} />);

    const button = screen.getByRole("button", { name: "Sign in with Google" });
    expect(button).toBeVisible();
    expect(button).toBeDisabled();
    expect(button.querySelector("img")).toHaveAttribute("src", "/brand/google-sign-in-logo.svg");
    expect(screen.getByLabelText("Continue with Google")).toHaveAttribute("aria-busy", "true");
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
    expect(container.querySelector(".auth-google-button > img")).toBeNull();
  });

  it("shows a clear unavailable state when Google Identity cannot load", async () => {
    const onError = vi.fn();
    googleIdentity.renderGoogleSignInButton.mockRejectedValueOnce(new Error("blocked"));

    render(<GoogleSignInButton disabled={false} onCredential={vi.fn()} onError={onError} />);

    expect(await screen.findByRole("status")).toHaveTextContent("Google sign-in is unavailable. Reload to try again.");
    expect(onError).toHaveBeenCalledWith(expect.objectContaining({ message: "blocked" }));
  });

  it("reveals only after Google sizes its iframe and removes the temporary button", async () => {
    googleIdentity.renderGoogleSignInButton.mockImplementation(async (parent: HTMLElement) => {
      const fallback = document.createElement("button");
      fallback.textContent = "Intermediate Google control";
      const iframe = document.createElement("iframe");
      iframe.title = "Sign in with Google";
      iframe.src = "https://accounts.google.com/gsi/button";
      iframe.style.height = "0px";
      iframe.style.width = "0px";
      parent.append(fallback, iframe);
    });
    const { container, rerender } = render(
      <GoogleSignInButton disabled={false} onCredential={vi.fn()} onError={vi.fn()} />
    );
    const iframe = screen.getByTitle("Sign in with Google");
    expect(screen.getByRole("button", { name: "Sign in with Google" })).toBeVisible();
    expect(screen.getByText("Intermediate Google control")).not.toBeVisible();
    await act(async () => undefined);
    expect(iframe).not.toBeVisible();
    expect(screen.getByLabelText("Continue with Google")).toHaveAttribute("aria-busy", "true");

    // Images in Google's initial markup do not mean its iframe is ready.
    const image = document.createElement("img");
    container.querySelector(".auth-google-button__identity")!.append(image);
    fireEvent.load(image);
    expect(iframe).not.toBeVisible();

    fireEvent.load(iframe);
    expect(iframe).not.toBeVisible();

    // Google sizes its iframe before removing the fallback on later frames.
    await act(async () => {
      iframe.style.height = "44px";
      iframe.style.width = "420px";
    });
    expect(iframe).not.toBeVisible();

    await act(async () => screen.getByText("Intermediate Google control").remove());
    expect(iframe).toBeVisible();
    expect(screen.queryByRole("button", { name: "Sign in with Google" })).not.toBeInTheDocument();
    expect(iframe).not.toHaveAttribute("aria-hidden");
    expect(screen.getByLabelText("Continue with Google")).toHaveAttribute("aria-busy", "false");

    rerender(<GoogleSignInButton disabled onCredential={vi.fn()} onError={vi.fn()} />);
    expect(iframe).toBeVisible();
    expect(googleIdentity.renderGoogleSignInButton).toHaveBeenCalledTimes(1);
  });

  it("reveals Google's inline button when no iframe is rendered", async () => {
    googleIdentity.renderGoogleSignInButton.mockImplementation(async (parent: HTMLElement) => {
      const button = document.createElement("button");
      button.textContent = "Sign in with Google";
      parent.append(button);
    });
    render(<GoogleSignInButton disabled={false} onCredential={vi.fn()} onError={vi.fn()} />);

    await waitFor(() => expect(screen.getByRole("button", { name: "Sign in with Google" })).toBeVisible());
    expect(screen.getByLabelText("Continue with Google")).toHaveAttribute("aria-busy", "false");
  });

  it("renders Google's outline control in Light mode", async () => {
    window.localStorage.setItem("backword:web:theme:v1", "light");
    render(<ThemeProvider><GoogleSignInButton disabled={false} onCredential={vi.fn()} onError={vi.fn()} /></ThemeProvider>);

    await waitFor(() => expect(googleIdentity.renderGoogleSignInButton).toHaveBeenCalledWith(
      expect.any(HTMLDivElement),
      expect.any(Object),
      expect.objectContaining({ theme: "outline" })
    ));
  });
});
