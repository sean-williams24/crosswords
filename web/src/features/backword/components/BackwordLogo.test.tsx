import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { render, screen } from "@testing-library/react";
import { BackwordLogo } from "./BackwordLogo";
import { ThemeProvider } from "../../theme/ThemeProvider";

describe("BackwordLogo", () => {
  it("adds the Pro mark to the logo lockup for active Pro users", () => {
    render(<BackwordLogo isPro large />);

    expect(screen.getByRole("img", { name: "Backword" })).toHaveAttribute(
      "src",
      "/brand/backword-logo.png"
    );
    expect(screen.getByRole("img", { name: "Pro" })).toHaveAttribute(
      "src",
      "/brand/backword-pro.png"
    );
    expect(screen.getByRole("img", { name: "Pro" })).toHaveClass("bw-logo__pro");
  });

  it("does not show the Pro mark for non-Pro users", () => {
    render(<BackwordLogo />);

    expect(screen.queryByRole("img", { name: "Pro" })).not.toBeInTheDocument();
  });

  it("uses the iOS light logo artwork in Light mode", () => {
    window.localStorage.setItem("backword:web:theme:v1", "light");
    render(<ThemeProvider><BackwordLogo /></ThemeProvider>);

    expect(screen.getByRole("img", { name: "Backword" })).toHaveAttribute(
      "src",
      "/brand/backword-logo-light.png"
    );
  });

  it("keeps space between the Backword and Pro artwork", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/\.bw-logo__pro\s*\{[^}]*\btop:\s*41%/);
  });

  it("centers the header lockup independently of menu and action widths", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    for (const header of ["bw-game-header", "home-dashboard__header"]) {
      expect(styles).toMatch(new RegExp(`\\.${header}\\s*\\{[^}]*grid-template-columns:\\s*minmax\\(0, 1fr\\) auto minmax\\(0, 1fr\\)`));
    }
    expect(styles).toMatch(/\.home-dashboard__header > a\[aria-label="Backword home"\]\s*\{[^}]*grid-column:\s*2;[^}]*justify-self:\s*center/);
    expect(styles).toMatch(/\.bw-logo-lockup\s*\{[^}]*grid-column:\s*2;[^}]*justify-self:\s*center;[^}]*width:\s*74px/);
    expect(styles).toMatch(/\.bw-logo-lockup--large\s*\{[^}]*width:\s*149px/);
    expect(styles).toMatch(/\.home-dashboard__header \.bw-logo-lockup\s*\{[^}]*width:\s*141px/);
    expect(styles).toMatch(/@media \(max-width: 680px\)\s*\{[\s\S]*?\.home-dashboard__header \.bw-logo-lockup\s*\{[^}]*width:\s*113px/);
    expect(styles).toMatch(/\.bw-game-header \.bw-logo-lockup--large\s*\{[^}]*width:\s*clamp\(80px, calc\(100vw - 208px\), 149px\)/);
  });
});
