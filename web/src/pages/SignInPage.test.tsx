import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { SignInPage } from "./SignInPage";

describe("SignInPage", () => {
  it("uses the shared menu with a plain, borderless account layout", () => {
    const { container } = render(<MemoryRouter><SignInPage /></MemoryRouter>);

    expect(screen.getByRole("heading", { name: "Sign in or create an account" })).toHaveClass(
      "auth-content__sign-in-title"
    );
    const appleButton = screen.getByRole("button", { name: "Continue with Apple" });
    expect(appleButton).toHaveClass("auth-apple-button");
    expect(appleButton.querySelector("img")).toHaveAttribute(
      "src",
      expect.stringContaining("https://appleid.cdn-apple.com/appleid/button/logo?color=white&border=false")
    );
    expect(appleButton).toHaveTextContent("Continue with Apple");
    const googleButton = container.querySelector(".auth-google-button");
    expect(googleButton).toHaveAttribute("aria-label", "Continue with Google");
    expect(googleButton?.querySelector("img")).toHaveAttribute("src", "/brand/continue-with-google.png");
    expect(screen.getByText(/Play as a guest whenever you like/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Backword home" }).querySelector("img")).toHaveClass(
      "bw-logo--large"
    );
    expect(container.querySelector(".auth-card")).not.toBeInTheDocument();
    expect(container.querySelector(".auth-content")).toBeInTheDocument();
  });
});
