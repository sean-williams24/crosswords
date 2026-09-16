import { useEffect, useRef, useState } from "react";
import { renderGoogleSignInButton } from "./googleIdentity";
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
  handlers.current = { onCredential, onError };

  useEffect(() => {
    const parent = container.current;
    if (!parent) return;
    let active = true;

    void renderGoogleSignInButton(parent, {
      onCredential: (idToken) => handlers.current.onCredential(idToken),
      onError: (error) => handlers.current.onError(error)
    }, {
      isActive: () => active,
      theme: resolvedTheme === "light" ? "outline" : "filled_black"
    }).catch((error) => {
      if (!active) return;
      setUnavailable(true);
      handlers.current.onError(error);
    });

    return () => {
      active = false;
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
      aria-busy={disabled}
      aria-label="Continue with Google"
      className={`auth-google-button${disabled ? " auth-google-button--disabled" : ""}`}
    >
      <div className="auth-google-button__identity" ref={container} />
    </div>
  );
}
