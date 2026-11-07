import { useEffect, useRef, useState } from "react";
import { renderGoogleSignInButton } from "./googleIdentity";
import { observeGoogleButtonReady } from "./googleButtonPresentation";
import { GoogleSignInPlaceholder } from "./GoogleSignInPlaceholder";
import { useTheme } from "../theme/ThemeProvider";

type GoogleSignInButtonProps = {
  disabled: boolean;
  onCredential: (idToken: string) => void;
  onError: (error: Error) => void;
};

export function GoogleSignInButton({ disabled, onCredential, onError }: GoogleSignInButtonProps) {
  const { resolvedTheme } = useTheme();
  const container = useRef<HTMLDivElement>(null);
  const handlers = useRef({ onCredential, onError });
  const [unavailable, setUnavailable] = useState(false);
  const [loadedTheme, setLoadedTheme] = useState<string | null>(null);
  const loading = loadedTheme !== resolvedTheme;
  handlers.current = { onCredential, onError };

  useEffect(() => {
    const parent = container.current;
    if (!parent) return;
    let active = true;
    setLoadedTheme(null);

    const stopObserving = observeGoogleButtonReady(parent, () => {
      if (active) setLoadedTheme(resolvedTheme);
    });

    void renderGoogleSignInButton(parent, {
      onCredential: (idToken) => handlers.current.onCredential(idToken),
      onError: (error) => handlers.current.onError(error)
    }, {
      isActive: () => active,
      theme: resolvedTheme === "light" ? "outline" : "filled_black"
    }).then(() => {
      // Retain Google's inline control when no embedded button is supplied.
      if (active && !parent.querySelector("iframe")) {
        stopObserving();
        setLoadedTheme(resolvedTheme);
      }
    }).catch((error) => {
      if (!active) return;
      stopObserving();
      setUnavailable(true);
      handlers.current.onError(error);
    });

    return () => {
      active = false;
      stopObserving();
      parent.replaceChildren();
    };
  }, [resolvedTheme]);

  if (unavailable) {
    return (
      <div className="auth-google-button auth-google-button--unavailable" role="status">
        Google sign-in is unavailable. Reload to try again.
      </div>
    );
  }

  return (
    <div
      aria-busy={disabled || loading}
      aria-label="Continue with Google"
      className={`auth-google-button${disabled ? " auth-google-button--disabled" : ""}${loading ? " auth-google-button--loading" : ""}`}
    >
      {loading ? <GoogleSignInPlaceholder /> : null}
      <div
        className="auth-google-button__identity"
        ref={container}
        style={{ visibility: loading ? "hidden" : undefined }}
      />
    </div>
  );
}
