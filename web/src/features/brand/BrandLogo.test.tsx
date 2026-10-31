import { render, screen } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { ThemeProvider, themeStorageKey } from "../theme/ThemeProvider";
import { BrandLogo } from "./BrandLogo";
import { BackwordLogo } from "../backword/components/BackwordLogo";

describe("umbrella and game brand separation", () => {
  afterEach(() => localStorage.removeItem(themeStorageKey));
  it("renders Intervls alongside the unchanged Backword game mark", () => {
    render(<><BrandLogo isPro /><BackwordLogo /></>);
    expect(screen.getByRole("img", { name: "Intervls" })).toHaveAttribute("src", "/brand/intervls-dark.svg");
    expect(screen.getByRole("img", { name: "Backword" })).toHaveAttribute("src", "/brand/backword-logo.png");
    expect(screen.getByRole("img", { name: "Pro" })).toHaveAttribute("src", "/brand/backword-pro.png");
    expect(screen.getByRole("img", { name: "Pro" })).toHaveClass("brand-logo__pro");
  });
  it.each(["light", "dark"])("selects the supplied %s artwork with the matching theme", (appearance) => {
    localStorage.setItem(themeStorageKey, appearance);
    render(<ThemeProvider><BrandLogo /></ThemeProvider>);
    expect(screen.getByRole("img", { name: "Intervls" })).toHaveAttribute("src", `/brand/intervls-${appearance}.svg`);
    expect(screen.queryByRole("img", { name: "Pro" })).not.toBeInTheDocument();
  });

  it.each(["light", "dark"])("retains the original gold PRO artwork in %s mode", (appearance) => {
    localStorage.setItem(themeStorageKey, appearance);
    render(<ThemeProvider><BrandLogo isPro large /></ThemeProvider>);
    expect(screen.getByRole("img", { name: "Pro" })).toHaveAttribute("src", "/brand/backword-pro.png");
  });

  it("places the visible PRO lettering at the bottom right for both wordmark sizes", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    // Both sizes share this rule; the translation compensates for 280 transparent
    // pixels at the right of the original 1024-pixel PRO image.
    expect(styles).toMatch(/\.brand-logo\s*\{[^}]*flex-direction:\s*column/);
    expect(styles).toMatch(/\.brand-logo > \.brand-logo__pro\s*\{[^}]*align-self:\s*flex-end;[^}]*transform:\s*translateX\(27\.34375%\)/);
  });

  it("extends PRO slightly past the wordmark on Home, the paywall and upgrade modal", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const paywallRule = styles.match(/\.home-dashboard > \.home-dashboard__header \.brand-logo > \.brand-logo__pro,\s*\.pro-page__header \.brand-logo > \.brand-logo__pro,\s*\.weekly-modal__logo \.brand-logo > \.brand-logo__pro\s*\{[^}]*translateX\(([\d.]+)%\)/);
    expect(paywallRule).not.toBeNull();
    // Measure the visible edge after subtracting the bitmap's transparent padding.
    const overhang = 96 * (Number(paywallRule?.[1]) / 100 - 280 / 1024);
    expect(overhang).toBeGreaterThanOrEqual(6);
    expect(overhang).toBeLessThanOrEqual(10);
  });

});
