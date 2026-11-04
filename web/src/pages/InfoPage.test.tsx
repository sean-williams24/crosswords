import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { InfoPage } from "./InfoPage";

describe("InfoPage", () => {
  it("shows the current Home screenshot instead of the dated video", () => {
    const { container } = render(<MemoryRouter><InfoPage /></MemoryRouter>);

    expect(screen.getByRole("img", { name: "Intervls home screen" }))
      .toHaveAttribute("src", "/screenshots/home.png");
    expect(container.querySelector("video")).toBeNull();
  });

  it("links each crossword section to its playable crossword route", () => {
    render(<MemoryRouter><InfoPage /></MemoryRouter>);

    const quickSection = screen.getByRole("heading", { level: 2, name: "A quick 9 x 9 crossword every day." }).parentElement;
    const weeklySection = screen.getByRole("heading", { level: 2, name: "A larger 13 x 13 puzzle for a slower challenge." }).parentElement;

    expect(within(quickSection!).getByRole("link", { name: "Play" })).toHaveAttribute("href", "/crossword");
    expect(within(weeklySection!).getByRole("link", { name: "Play" })).toHaveAttribute("href", "/weekly-crossword");
  });
});
