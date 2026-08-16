import { useEffect, useRef } from "react";
import { renderGoogleSignInButton } from "./googleIdentity";

type GoogleSignInButtonProps = {
  disabled: boolean;
  onCredential: (idToken: string) => void;
  onError: (error: Error) => void;
};

export function GoogleSignInButton({ disabled, onCredential, onError }: GoogleSignInButtonProps) {
  const container = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!container.current) return;
    void renderGoogleSignInButton(container.current, { onCredential, onError }).catch(onError);
  }, [onCredential, onError]);

  return (
    <div
      aria-busy={disabled}
      aria-label="Sign in with Google"
      className={`auth-google-button${disabled ? " auth-google-button--disabled" : ""}`}
    >
      <img alt="" src="/brand/continue-with-google.png" />
      <div
        aria-hidden="true"
        className="auth-google-button__identity"
        ref={container}
      />
    </div>
  );
}
