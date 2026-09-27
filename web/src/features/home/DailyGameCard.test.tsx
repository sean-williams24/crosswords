import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { DailyGameCard } from "./DailyGameCard";
import { HomeGameIssueNumber } from "./HomeGameIssueNumber";

describe("DailyGameCard", () => {
  it("groups the title and issue at the start and the status at the end", () => {
    render(
      <MemoryRouter>
        <DailyGameCard
          className="home-game-card--crossword"
          description="9×9"
          destination="/crossword"
          issueNumber={123}
          status={{ label: "New", tone: "new" }}
          title="Quick Crossword"
        />
      </MemoryRouter>
    );

    const card = screen.getByRole("link", { name: "Quick Crossword, issue #123" });
    const identity = card.querySelector(".home-game-card__identity");
    const details = card.querySelector(".home-game-card__details");

    expect(identity).not.toBeNull();
    expect(details).not.toBeNull();
    expect(within(identity as HTMLElement).getByText("Quick Crossword")).toBeInTheDocument();
    expect(within(identity as HTMLElement).getByText("9×9")).toHaveClass("home-game-card__description");
    expect(within(identity as HTMLElement).getByLabelText("Issue #123")).toHaveClass("home-game-card__issue");
    expect(Array.from((identity as HTMLElement).children).map((child) => child.className)).toEqual([
      "home-game-card__title",
      "home-game-card__description",
      "home-game-card__issue"
    ]);
    expect(within(details as HTMLElement).queryByText("9×9")).not.toBeInTheDocument();
    expect(within(details as HTMLElement).getByLabelText("Status: New")).toBeInTheDocument();
  });

  it("does not render a label before an issue number is available", () => {
    const { container } = render(<HomeGameIssueNumber issueNumber={null} />);

    expect(container).toBeEmptyDOMElement();
  });
});
