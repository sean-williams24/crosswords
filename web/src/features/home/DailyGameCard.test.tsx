import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { DailyGameCard } from "./DailyGameCard";
import { HomeGameIssueNumber } from "./HomeGameIssueNumber";

describe("DailyGameCard", () => {
  it("groups crossword dimensions beneath the centred title", () => {
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

    expect(within(card).queryByLabelText("0-day streak")).not.toBeInTheDocument();
    expect(identity).not.toBeNull();
    expect(details).not.toBeNull();
    expect(within(identity as HTMLElement).getByText("Quick Crossword")).toBeInTheDocument();
    expect(within(identity as HTMLElement).getByText("9×9").parentElement).toBe(identity);
    expect(within(card).getByText("9×9")).toHaveClass("home-game-card__description");
    expect(within(identity as HTMLElement).queryByLabelText("Issue #123")).not.toBeInTheDocument();
    expect(within(card).getByLabelText("Issue #123").parentElement).toBe(details);
    expect(Array.from((identity as HTMLElement).children).map((child) => child.className)).toEqual([
      "home-game-card__title",
      "home-game-card__description"
    ]);
    expect(within(details as HTMLElement).queryByText("9×9")).not.toBeInTheDocument();
    expect(details?.querySelector(".home-status")).toBe(within(card).getByLabelText("Status: New"));
  });

  it.each(["home-game-card--backword", "home-game-card--crossword"] as const)(
    "keeps streak outside the centred status footer in %s",
    (className) => {
      render(
        <MemoryRouter>
          <DailyGameCard
            className={className}
            destination="/crossword"
            score={0}
            streak={3}
            status={{ label: "In Progress", tone: "progress" }}
            title="Game"
          />
        </MemoryRouter>
      );

      const card = screen.getByRole("link", { name: "Game" });
      const details = card.querySelector(".home-game-card__details")!;
      expect(details.firstElementChild).toHaveClass("home-game-card__stats");
      expect(within(details.firstElementChild as HTMLElement).getByText("0")).toBeInTheDocument();
      expect(within(details).queryByLabelText("3-day streak")).not.toBeInTheDocument();
      expect(within(card).getByLabelText("3-day streak").parentElement).toBe(card);
      expect(details.querySelector(".home-status")).toBe(screen.getByLabelText("Status: In Progress"));
    }
  );

  it("does not render a label before an issue number is available", () => {
    const { container } = render(<HomeGameIssueNumber issueNumber={null} />);

    expect(container).toBeEmptyDOMElement();
  });

  it("keeps the streak and status when there are no points", () => {
    render(
      <MemoryRouter>
        <DailyGameCard
          className="home-game-card--crossword"
          destination="/crossword"
          score={null}
          status={{ label: "New", tone: "new" }}
          streak={1}
          title="Quick Crossword"
        />
      </MemoryRouter>
    );

    const card = screen.getByRole("link", { name: "Quick Crossword" });

    expect(card.querySelector(".home-game-card__score")).not.toBeInTheDocument();
    expect(within(card).getByLabelText("1-day streak")).toHaveClass("home-game-card__streak");
    expect(within(card).getByLabelText("Status: New")).toBeInTheDocument();
  });
});
