import { act, fireEvent, render, screen } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parse } from "postcss";
import { BACKWORD_ONBOARDING_STEPS, backwordOnboardingText } from "../onboarding";
import type { BackwordMode } from "../types";
import { BackwordOnboardingCards } from "./BackwordOnboardingCards";

describe("Backword onboarding cards", () => {
  it.each(["light", "dark"])("keeps the %s bulb bright yellow and consistent with iOS", (theme) => {
    const styles = parse(readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8"));
    let iconColor = "";
    styles.walkRules(theme === "light" ? 'html[data-theme="light"]' : ":root", (rule) => {
      rule.walkDecls("--app-instruction-icon", (declaration) => { iconColor = declaration.value; });
    });
    expect(iconColor).toMatch(/^#[0-9a-f]{6}$/i);
    const channels = [1, 3, 5].map((offset) => parseInt(iconColor.slice(offset, offset + 2), 16) / 255);
    expect(channels[0]).toBeGreaterThanOrEqual(0.95);
    expect(channels[1]).toBeGreaterThanOrEqual(0.8);
    expect(channels[2]).toBeLessThan(0.1);

    const asset = JSON.parse(readFileSync(resolve(process.cwd(),
      "../Backword/Resources/Assets.xcassets/InstructionIcon.colorset/Contents.json"
    ), "utf8")) as {
      colors: { appearances?: { appearance: string; value: string }[]; color: { components: Record<string, string> } }[];
    };
    const appearance = asset.colors.find((entry) => theme === "dark"
      ? entry.appearances?.some(({ appearance, value }) => appearance === "luminosity" && value === "dark")
      : !entry.appearances);
    expect(appearance).toBeDefined();
    ["red", "green", "blue"].forEach((channel, index) => {
      expect(channels[index]).toBeCloseTo(Number(appearance?.color.components[channel]), 2);
    });
  });

  it.each<BackwordMode>(["easy", "normal"])("uses a decorative info icon for the %s clue card and bulbs for other instructions", (mode) => {
    const { container } = render(
      <BackwordOnboardingCards mode={mode} onDismiss={vi.fn()} steps={[...BACKWORD_ONBOARDING_STEPS]} />
    );

    const cards = container.querySelectorAll("article");
    expect(cards).toHaveLength(BACKWORD_ONBOARDING_STEPS.length);
    expect(cards).toHaveLength(5);
    expect(screen.queryByText("Guess the 6 letter word...")).not.toBeInTheDocument();
    expect(screen.getByRole("article")).toHaveTextContent(backwordOnboardingText("clue", mode));
    for (const step of BACKWORD_ONBOARDING_STEPS) {
      const text = screen.getByText(backwordOnboardingText(step, mode));
      const icon = text.previousElementSibling;
      expect(icon).toHaveAttribute("aria-hidden", "true");
      if (step === "clue") {
        expect(icon).toHaveClass("bw-onboarding-card__info-icon");
        expect(icon).toHaveTextContent("ⓘ");
        continue;
      }
      expect(icon?.tagName.toLowerCase()).toBe("svg");
      expect(icon).toHaveAttribute("focusable", "false");
      expect(icon).toHaveAttribute("fill", "currentColor");
      expect(icon).toHaveClass("bw-onboarding-card__icon");
      expect(icon?.querySelector(".bw-onboarding-card__icon-globe")).toBeInTheDocument();
      expect(icon?.querySelector(".bw-onboarding-card__icon-base"))
        .toHaveAttribute("fill", "var(--app-text-muted)");
    }
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
    expect(screen.getAllByRole("article")).toHaveLength(1);
    expect(screen.getAllByRole("button")).toHaveLength(1);
  });

  it("keeps the bulb on the next instruction after the front card is dismissed", () => {
    vi.useFakeTimers();
    try {
      const onDismiss = vi.fn();
      const { rerender } = render(
        <BackwordOnboardingCards mode="easy" onDismiss={onDismiss} steps={[...BACKWORD_ONBOARDING_STEPS]} />
      );

      fireEvent.click(screen.getByRole("button", { name: `OK: ${backwordOnboardingText("clue", "easy")}` }));
      act(() => vi.advanceTimersByTime(220));
      expect(onDismiss).toHaveBeenCalledExactlyOnceWith("clue");

      rerender(
        <BackwordOnboardingCards mode="easy" onDismiss={onDismiss} steps={BACKWORD_ONBOARDING_STEPS.slice(1)} />
      );

      const topCard = screen.getByRole("article");
      expect(topCard.querySelector(".bw-onboarding-card__icon")).toBeInTheDocument();
      expect(topCard).toHaveTextContent(backwordOnboardingText("connectedLetters", "easy"));
      expect(screen.getAllByRole("button")).toHaveLength(1);
    } finally {
      vi.useRealTimers();
    }
  });
});
