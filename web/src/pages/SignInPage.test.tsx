import { readFileSync } from "node:fs";
import { resolve } from "node:path";
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
    const providers = container.querySelector(".auth-content__providers--sign-in");
    expect(providers?.children[0]).toHaveClass("auth-google-button");
    expect(providers?.children[1]).toHaveClass("auth-apple-button");
    expect(screen.getByText(/Play as a guest whenever you like/i)).toBeInTheDocument();
    expect(container.querySelectorAll(".auth-benefit-icon--sync, .auth-benefit-icon--stats, .auth-benefit-icon--pro")).toHaveLength(3);
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Backword home" }).querySelector("img")).toHaveClass(
      "bw-logo--large"
    );
    expect(container.querySelector(".auth-card")).not.toBeInTheDocument();
    expect(container.querySelector(".auth-content")).toBeInTheDocument();
  });

  it("makes both provider buttons fill the sign-in area", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.auth-apple-button\s*\{[^}]*\bwidth:\s*100%/);
    expect(styles).toMatch(/\.auth-google-button\s*\{[^}]*\bwidth:\s*100%/);
    expect(styles).toMatch(/\.auth-google-button__identity\s*\{[^}]*\btransform:\s*scaleX\(var\(--auth-google-button-scale-x, 1\)\)/);
    expect(styles).toMatch(/\.auth-content__benefits--sign-in\s*\{[^}]*\bmargin-bottom:\s*40px[^}]*\bgap:\s*16px/);
    expect(styles).toMatch(/\.auth-content__providers--sign-in\s*\{[^}]*\bgap:\s*16px/);
    expect(styles).toMatch(/\.auth-content__note\s*\{[^}]*\bmargin:\s*28px 0 0/);
  });
});
