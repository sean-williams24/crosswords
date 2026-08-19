import { describe, expect, it, vi } from "vitest";
import {
  GoogleIdentityConfigurationError,
  renderGoogleSignInButton,
  type GoogleIdentity
} from "./googleIdentity";

function makeGoogleIdentity() {
  let callback: ((response: { credential?: string }) => void) | undefined;
  const initialize = vi.fn((configuration: { callback: (response: { credential?: string }) => void }) => {
    callback = configuration.callback;
  });
  const renderButton = vi.fn();
  const google: GoogleIdentity = {
    accounts: { id: { initialize, renderButton } }
  };
  return { callback: () => callback, google, initialize, renderButton };
}

describe("Google Identity", () => {
  it("requires the public web client ID", async () => {
    await expect(renderGoogleSignInButton(document.createElement("div"), {
      onCredential: vi.fn(),
      onError: vi.fn()
    }, { clientID: "" })).rejects.toBeInstanceOf(GoogleIdentityConfigurationError);
  });

  it("renders Google's chooser and returns its credential", async () => {
    const identity = makeGoogleIdentity();
    const onCredential = vi.fn();
    const parent = document.createElement("div");
    await renderGoogleSignInButton(parent, { onCredential, onError: vi.fn() }, {
      clientID: "web-client-id",
      load: async () => identity.google
    });

    identity.callback()?.({ credential: "google-id-token" });

    expect(onCredential).toHaveBeenCalledWith("google-id-token");
    expect(identity.initialize).toHaveBeenCalledWith(expect.objectContaining({
      client_id: "web-client-id",
      auto_select: false
    }));
    expect(identity.renderButton).toHaveBeenCalledWith(parent, expect.objectContaining({
      theme: "filled_black",
      text: "signin_with"
    }));
  });

  it("expands the native button hit target to match a wider visible control", async () => {
    const identity = makeGoogleIdentity();
    const parent = document.createElement("div");
    Object.defineProperty(parent, "clientWidth", { value: 540 });

    await renderGoogleSignInButton(parent, { onCredential: vi.fn(), onError: vi.fn() }, {
      clientID: "web-client-id",
      load: async () => identity.google
    });

    expect(identity.renderButton).toHaveBeenCalledWith(parent, expect.objectContaining({ width: 400 }));
    expect(parent.style.getPropertyValue("--auth-google-button-scale-x")).toBe("1.35");
  });

  it("reports a response without an ID token", async () => {
    const identity = makeGoogleIdentity();
    const onError = vi.fn();
    await renderGoogleSignInButton(document.createElement("div"), {
      onCredential: vi.fn(),
      onError
    }, {
      clientID: "web-client-id",
      load: async () => identity.google
    });

    identity.callback()?.({});

    expect(onError).toHaveBeenCalledWith(expect.objectContaining({
      message: "Google Sign-In did not return an identity token. Please try again."
    }));
  });
});
