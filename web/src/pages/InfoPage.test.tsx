import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { InfoPage } from "./InfoPage";

describe("InfoPage", () => {
  it("links each crossword section to its playable crossword route", () => {
    render(<MemoryRouter><InfoPage /></MemoryRouter>);

    expect(screen.getByRole("link", { name: "Play the daily crossword online →" })).toHaveAttribute(
      "href",
      "/crossword"
    );
    expect(screen.getByRole("link", { name: "Play the weekly crossword online →" })).toHaveAttribute(
      "href",
      "/weekly-crossword"
    );
  });
});
