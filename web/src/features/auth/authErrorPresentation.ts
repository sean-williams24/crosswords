export type SignInProvider = "apple" | "google";

export type AuthAlert = {
  title: string;
  message: string;
};

const signInTitle = "Couldn't sign in";
const offlineMessage = "Check your internet connection and try again.";

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "";
}

export function isExpectedSignInCancellation(error: unknown) {
  return /\b(cancelled|canceled|access denied|access_denied)\b/i.test(errorMessage(error));
}

export function signInErrorAlert(
  error: unknown,
  provider: SignInProvider,
  isOnline = navigator.onLine
): AuthAlert | null {
  if (isExpectedSignInCancellation(error)) return null;
  if (!isOnline) return { title: signInTitle, message: offlineMessage };

  const providerName = provider === "apple" ? "Apple" : "Google";
  return {
    title: signInTitle,
    message: `We couldn't complete ${providerName} sign-in. Please try again or use the other option.`
  };
}

export const entitlementWarning =
  "We couldn't check account-linked Pro access right now. Please try again later.";

export function accountActionErrorMessage(
  action: "refresh" | "signOut" | "deleteAccount",
  isOnline = navigator.onLine
) {
  if (!isOnline) return offlineMessage;

  switch (action) {
    case "refresh":
      return "We couldn't refresh your account right now. Your progress will try to sync again later.";
    case "signOut":
      return "We couldn't sign you out. Please try again.";
    case "deleteAccount":
      return "We couldn't delete your account. Please try again.";
  }
}
