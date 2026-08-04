import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { CrosswordComingSoonPage } from "./CrosswordComingSoonPage";

describe("CrosswordComingSoonPage", () => {
  it("shows the crossword preview and a route back to the dashboard", () => {
    render(
      <MemoryRouter>
        <CrosswordComingSoonPage />
      </MemoryRouter>
    );

    expect(screen.getByRole("heading", { level: 1, name: "Coming soon" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "← Back to home" })).toHaveAttribute("href", "/home");
    expect(screen.getByAltText("Preview of the Quick Crossword game")).toHaveAttribute(
      "src",
      "/screenshots/crossword.png"
    );
  });
});
