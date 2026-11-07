import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { SignInPage } from "./SignInPage";

describe("SignInPage", () => {
  it("anchors the menu to the full page instead of the centered logo header", () => {
    render(<MemoryRouter><SignInPage /></MemoryRouter>);

    const menu = screen.getByRole("button", { name: "Open game menu" }).closest(".bw-game-menu");
    expect(menu?.parentElement).toBe(screen.getByRole("main"));
    expect(menu?.closest("header")).toBeNull();
    expect(screen.getByRole("link", { name: "Intervls home" }).closest("header")).toHaveClass("auth-page__header");
  });

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
    expect(googleButton?.querySelector(".auth-google-button__identity")).toBeInTheDocument();
    expect(googleButton?.querySelector(".auth-google-placeholder")).toBeVisible();
    expect(googleButton?.querySelector(".auth-google-placeholder img")).toHaveAttribute("src", "/brand/google-sign-in-logo.svg");
    const providers = container.querySelector(".auth-content__providers--sign-in");
    expect(providers?.children[0]).toHaveClass("auth-google-button");
    expect(providers?.children[1]).toHaveClass("auth-apple-button");
    expect(screen.getByText(/Play as a guest whenever you like/i)).toBeInTheDocument();
    expect(container.querySelectorAll(".auth-benefit-icon--sync, .auth-benefit-icon--stats, .auth-benefit-icon--pro")).toHaveLength(3);
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Intervls home" }).querySelector(".brand-logo")).toHaveClass(
      "brand-logo--large"
    );
    expect(screen.getByRole("link", { name: "Intervls home" })).toHaveAttribute("href", "/");
    expect(container.querySelector(".auth-card")).not.toBeInTheDocument();
    expect(container.querySelector(".auth-content")).toBeInTheDocument();
  });

  it("reserves one rounded Google button slot while its controls are replaced", () => {
    const stylesheet = document.createElement("style");
    stylesheet.textContent = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    document.head.appendChild(stylesheet);
    try {
      const { container } = render(<MemoryRouter><SignInPage /></MemoryRouter>);
      const identity = container.querySelector<HTMLElement>(".auth-google-button__identity")!;
      // Google can temporarily leave both controls in the container.
      for (let index = 0; index < 2; index += 1) {
        const control = document.createElement("div");
        control.style.height = "40px";
        identity.append(control);
      }
      const googleStyles = getComputedStyle(identity);
      const placeholder = container.querySelector(".auth-google-placeholder")!;
      const placeholderStyles = getComputedStyle(placeholder);
      const logoStyles = getComputedStyle(placeholder.querySelector("img")!);
      const appleStyles = getComputedStyle(screen.getByRole("button", { name: "Continue with Apple" }));

      expect(identity).not.toHaveFocus();
      expect(googleStyles.height).toBe("40px");
      expect(placeholderStyles.height).toBe(googleStyles.height);
      expect(placeholderStyles.width).toBe(googleStyles.width);
      expect(placeholderStyles.borderRadius).toBe(googleStyles.borderRadius);
      expect(logoStyles.width).toBe("18px");
      expect(logoStyles.height).toBe("18px");
      expect(placeholderStyles.fontFamily).toContain("Google Sans");
      expect(placeholderStyles.fontSize).toBe("14px");
      expect(placeholderStyles.fontWeight).toBe("500");
      expect(placeholderStyles.letterSpacing).toBe(".25px");
      expect(googleStyles.overflow).toBe("hidden");
      expect(googleStyles.borderRadius).not.toBe("");
      expect(googleStyles.borderRadius).not.toBe("0px");
      expect(googleStyles.borderRadius).toBe(appleStyles.borderRadius);
    } finally {
      stylesheet.remove();
    }
  });

  it("matches Google's iframe canvas scheme even when the surrounding page is dark", () => {
    const stylesheet = document.createElement("style");
    stylesheet.textContent = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    document.head.appendChild(stylesheet);
    const previousScheme = document.documentElement.style.colorScheme;
    document.documentElement.style.colorScheme = "dark";
    try {
      const { container } = render(<MemoryRouter><SignInPage /></MemoryRouter>);
      const identity = container.querySelector(".auth-google-button__identity")!;
      const iframe = document.createElement("iframe");
      identity.append(iframe);

      expect(getComputedStyle(iframe).colorScheme).toBe("light");
      expect(document.documentElement.style.colorScheme).toBe("dark");
      expect(iframe).not.toHaveAttribute("aria-hidden");
    } finally {
      document.documentElement.style.colorScheme = previousScheme;
      stylesheet.remove();
    }
  });

  it("clips the native Google button gutter and keeps both providers aligned", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.auth-apple-button\s*\{[^}]*\bwidth:\s*min\(100%, 400px\)/);
    expect(styles).toMatch(/\.auth-google-button\s*\{[^}]*\bwidth:\s*100%/);
    expect(styles).toMatch(/\.auth-google-button__identity\s*\{[^}]*\bwidth:\s*min\(100%, 400px\)[^}]*\boverflow:\s*hidden/);
    expect(styles).toMatch(/\.auth-google-button__identity:focus-within\s*\{[^}]*\boutline:\s*2px solid/);
    expect(styles).toMatch(/\.auth-content__benefits--sign-in\s*\{[^}]*\bmargin-bottom:\s*40px[^}]*\bgap:\s*16px/);
    expect(styles).toMatch(/\.auth-content__providers--sign-in\s*\{[^}]*\bgap:\s*16px/);
    expect(styles).toMatch(/\.auth-content__note\s*\{[^}]*\bmargin:\s*28px 0 0/);
    expect(styles).toMatch(/\.auth-sign-in-alert__icon\s*\{[^}]*\bdisplay:\s*grid[^}]*\bplace-items:\s*center/);
    expect(styles).toMatch(/\.auth-sign-in-alert > div > span\s*\{[^}]*\bdisplay:\s*block/);
  });
});
