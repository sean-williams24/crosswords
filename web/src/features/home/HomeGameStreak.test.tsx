import { render, screen } from "@testing-library/react";
import { HomeGameStreak } from "./HomeGameStreak";

describe("HomeGameStreak", () => {
  it("hides zero streaks", () => {
    const { container } = render(<HomeGameStreak streak={0} />);
    expect(container).toBeEmptyDOMElement();
  });

  it.each([1, 12])("shows a %i-day count with a decorative Lucide outline flame using CSS colour", (streak) => {
    render(<HomeGameStreak streak={streak} />);
    const badge = screen.getByLabelText(`${streak}-day streak`);
    expect(badge).toHaveTextContent(String(streak));
    expect(badge).not.toHaveTextContent("🔥");
    expect(badge.querySelector("svg")).toHaveClass("home-game-card__streak-icon");
    expect(badge.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
    expect(badge.querySelector("svg")).toHaveAttribute("fill", "none");
    expect(badge.querySelector("svg")).toHaveAttribute("stroke", "currentColor");
    expect(badge.querySelector("svg")).toHaveAttribute("stroke-width", "2");
    expect(badge.querySelector("svg")).toHaveAttribute("stroke-linecap", "round");
    expect(badge.querySelector("svg")).toHaveAttribute("stroke-linejoin", "round");
  });

  it("announces weekly crossword counts as weeks", () => {
    render(<HomeGameStreak streak={2} unit="week" />);
    expect(screen.getByLabelText("2-week streak")).toHaveTextContent("2");
    expect(screen.queryByLabelText("2-day streak")).not.toBeInTheDocument();
  });
});
