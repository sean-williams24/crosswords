import { act, fireEvent, render, screen } from "@testing-library/react";
import { BACKWORD_ONBOARDING_STEPS, backwordOnboardingText } from "../onboarding";
import type { BackwordMode } from "../types";
import { BackwordOnboardingCards } from "./BackwordOnboardingCards";

describe("Backword onboarding cards", () => {
  it.each<BackwordMode>(["easy", "normal"])("uses the existing explainer lightbulb for every %s onboarding card", (mode) => {
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
      expect(icon?.tagName.toLowerCase()).toBe("span");
      expect(icon).toHaveTextContent("💡");
      expect(icon).toHaveClass("bw-onboarding-card__icon");
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
