import { describe, expect, it } from "vitest";
import {
  accountActionErrorMessage,
  isExpectedSignInCancellation,
  signInErrorAlert
} from "./authErrorPresentation";

describe("auth error presentation", () => {
  it("uses safe provider retry copy instead of a provider error message", () => {
    expect(signInErrorAlert(new Error("invalid JWT audience"), "google", true)).toEqual({
      title: "Couldn't sign in",
      message: "We couldn't complete Google sign-in. Please try again or use the other option."
    });
  });

  it("explains how to recover from an offline sign-in failure", () => {
    expect(signInErrorAlert(new Error("network request failed"), "apple", false)).toEqual({
      title: "Couldn't sign in",
      message: "Check your internet connection and try again."
    });
  });

  it("suppresses expected provider cancellations", () => {
    expect(isExpectedSignInCancellation(new Error("The user cancelled the authorization flow."))).toBe(true);
    expect(signInErrorAlert(new Error("The user cancelled the authorization flow."), "apple", true)).toBeNull();
  });

  it("uses safe account-action copy", () => {
    expect(accountActionErrorMessage("deleteAccount", true)).toBe("We couldn't delete your account. Please try again.");
  });
});
