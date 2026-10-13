import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { AnagramHomeCard } from "./AnagramHomeCard";

describe("AnagramHomeCard", () => {
  it.each(["light", "dark"])("matches the native %s streak colour for both count and flame", (theme) => {
    render(<MemoryRouter><AnagramHomeCard issueNumber={7} score={null} status={{ label: "New", tone: "new" }} streak={3} /></MemoryRouter>);
    const badge = screen.getByLabelText("3-day streak");
    expect(badge.querySelector("svg")).toHaveAttribute("fill", "none");
    expect(badge.querySelector("svg")).toHaveAttribute("stroke", "currentColor");

    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");
    const paletteRules = Array.from(styles.matchAll(/(:root|html\[data-theme="light"\])\s*\{([^}]+)\}/g));
    const palette = paletteRules.find((rule) => rule[1] === (theme === "light" ? 'html[data-theme="light"]' : ":root")
      && rule[2].includes("--anagram-on-accent:"))![2];
    const foreground = palette.match(/--anagram-on-accent:\s*(#[\da-f]+);/)![1];
    const nativeAsset = JSON.parse(readFileSync(resolve(process.cwd(), "../Backword/Resources/Assets.xcassets/AnagramOnOrange.colorset/Contents.json"), "utf8"));
    const nativeColor = nativeAsset.colors.find((entry: { appearances?: { value: string }[] }) =>
      theme === "dark" ? entry.appearances?.some((appearance) => appearance.value === "dark") : !entry.appearances).color.components;
    const nativeHex = `#${[nativeColor.red, nativeColor.green, nativeColor.blue]
      .map((component) => Math.round(Number(component) * 255).toString(16).padStart(2, "0")).join("")}`;
    expect(foreground).toBe(nativeHex);
    expect(styles).toMatch(/\.home-game-card--anagram \.home-game-card__streak\s*\{[^}]*color:\s*var\(--anagram-on-accent\);/);
    expect(styles).toMatch(/\.home-game-card--anagram \.home-game-card__streak-icon\s*\{[^}]*color:\s*inherit;/);
  });

  it("keeps the card available before its issue number loads", () => {
    render(<MemoryRouter><AnagramHomeCard issueNumber={null} score={null} status={{ label: "New", tone: "new" }} streak={0} /></MemoryRouter>);
    const card = screen.getByRole("link", { name: "Anagram" });
    expect(card).toHaveAttribute("href", "/anagram");
    expect(card.querySelector(".home-game-card__issue")).toBeNull();
    expect(card).not.toHaveTextContent("null");
  });

  it.each([0, 3])("keeps a %i-day streak at the card level and points with the bottom status", (streak) => {
    render(
      <MemoryRouter>
        <AnagramHomeCard
          issueNumber={7}
          score={4}
          status={{ label: "Solved", tone: "solved" }}
          streak={streak}
        />
      </MemoryRouter>
    );

    const card = screen.getByRole("link", { name: "Anagram, issue #7" });
    const stats = card.querySelector(".anagram-home-card__stats");
    expect(within(card).getByLabelText("Issue #7").parentElement).toBe(card.querySelector(".anagram-home-card__details"));
    expect(card.querySelector(".anagram-home-card__identity")).not.toHaveTextContent("#7");

    expect(within(card).queryByText(/letters/i)).not.toBeInTheDocument();
    expect(stats).toHaveClass("home-game-card__stats");
    expect(card.querySelector(".anagram-home-card__details")?.firstElementChild).toBe(stats);
    expect(card.querySelector(".anagram-home-card__details")?.querySelector(".home-status"))
      .toBe(within(card).getByLabelText("Status: Solved"));
    expect(within(stats as HTMLElement).getByText("4")).toBeInTheDocument();
    expect(within(stats as HTMLElement).queryByLabelText("3-day streak")).not.toBeInTheDocument();
    if (streak > 0) {
      expect(within(card).getByLabelText(`${streak}-day streak`).parentElement).toBe(card);
    } else {
      expect(card.querySelector(".home-game-card__streak")).not.toBeInTheDocument();
    }
  });
});
