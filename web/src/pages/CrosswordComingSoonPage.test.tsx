import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import userEvent from "@testing-library/user-event";
import { CrosswordComingSoonPage } from "./CrosswordComingSoonPage";

describe("CrosswordComingSoonPage", () => {
  it("shows the crossword preview, site menu, and footer", () => {
    render(
      <MemoryRouter>
        <CrosswordComingSoonPage />
      </MemoryRouter>
    );

    expect(screen.getByRole("heading", { level: 1, name: "Coming soon" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Footer" })).toBeInTheDocument();
    const preview = screen.getByAltText("Preview of the Quick Crossword game");
    expect(preview).toHaveAttribute(
      "src",
      "/screenshots/crossword.png"
    );
    expect(preview.parentElement).toHaveClass("crossword-coming-soon__content");
  });

  it("opens the tappable game navigation above the coming-soon content", async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <CrosswordComingSoonPage />
      </MemoryRouter>
    );

    await user.click(screen.getByRole("button", { name: "Open game menu" }));
    expect(screen.getByRole("dialog", { name: "Game navigation" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Play Backword" })).toHaveAttribute("href", "/");
  });
});
