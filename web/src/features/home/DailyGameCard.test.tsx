import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { DailyGameCard } from "./DailyGameCard";
import { HomeGameIssueNumber } from "./HomeGameIssueNumber";

describe("DailyGameCard", () => {
  it("shows the issue number in the card's top-right label and accessible name", () => {
    render(
      <MemoryRouter>
        <DailyGameCard
          className="home-game-card--crossword"
          destination="/crossword"
          issueNumber={123}
          status={{ label: "New", tone: "new" }}
          title="Quick Crossword"
        />
      </MemoryRouter>
    );

    expect(screen.getByRole("link", { name: "Quick Crossword, issue #123" })).toBeInTheDocument();
    expect(screen.getByLabelText("Issue #123")).toHaveClass("home-game-card__issue");
    expect(screen.getByText("#123")).toBeInTheDocument();
  });

  it("does not render a label before an issue number is available", () => {
    const { container } = render(<HomeGameIssueNumber issueNumber={null} />);

    expect(container).toBeEmptyDOMElement();
  });
});
