/** Immediate presentation while Google's native sign-in control initialises. */
export function GoogleSignInPlaceholder() {
  return (
    <button className="auth-google-placeholder" disabled type="button">
      <span aria-hidden="true" className="auth-google-placeholder__logo">
        <img alt="" height="18" src="/brand/google-sign-in-logo.svg" width="18" />
      </span>
      <span className="auth-google-placeholder__label">Sign in with Google</span>
    </button>
  );
}
