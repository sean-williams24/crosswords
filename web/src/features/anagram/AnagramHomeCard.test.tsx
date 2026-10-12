import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { AnagramHomeCard } from "./AnagramHomeCard";

describe("AnagramHomeCard", () => {
  it("keeps the streak at the card level and points with the bottom status", () => {
    render(
      <MemoryRouter>
        <AnagramHomeCard
          issueNumber={7}
          score={4}
          status={{ label: "Solved", tone: "solved" }}
          streak={3}
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
    expect(within(stats as HTMLElement).queryByText("🔥 3")).not.toBeInTheDocument();
    expect(within(card).getByText("🔥 3").parentElement).toBe(card);
  });
});
