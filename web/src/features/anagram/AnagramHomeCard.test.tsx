import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { AnagramHomeCard } from "./AnagramHomeCard";

describe("AnagramHomeCard", () => {
  it("omits the letter count and groups points with the streak", () => {
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

    expect(within(card).queryByText(/letters/i)).not.toBeInTheDocument();
    expect(stats).toHaveClass("home-game-card__stats");
    expect(within(stats as HTMLElement).getByText("4")).toBeInTheDocument();
    expect(within(stats as HTMLElement).getByText("🔥 3")).toBeInTheDocument();
  });
});
