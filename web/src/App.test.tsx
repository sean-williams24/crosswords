import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import App from "./App";

function renderRoute(route: string) {
  return render(
    <MemoryRouter initialEntries={[route]}>
      <App />
    </MemoryRouter>
  );
}

describe("Backword website routes", () => {
  it("renders the home page and footer links", () => {
    renderRoute("/");

    expect(
      screen.getByRole("heading", { level: 1, name: "Backword" })
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Download Backword on the App Store")).toHaveAttribute(
      "href",
      "https://apps.apple.com/app/backword/id6773428497"
    );
    expect(screen.getAllByRole("link", { name: "Privacy" })).toHaveLength(2);
    expect(screen.getAllByRole("link", { name: "Terms" })).toHaveLength(2);
    expect(
      screen.getByText(
        "Solve a six-letter word by extending its correct ending from right to left. A guess may reveal a connected chain or nothing new, with an extra letter revealed after three misses."
      )
    ).toBeInTheDocument();
  });

  it("keeps homepage section text before screenshots in mobile source order", () => {
    renderRoute("/");

    const backwordHeading = screen.getByRole("heading", {
      level: 2,
      name: "Guess forwards. Reveal backwards."
    });
    const backwordImage = screen.getByAltText("Backword gameplay screen");
    const weeklyHeading = screen.getByRole("heading", {
      level: 2,
      name: "A larger 13 x 13 puzzle for a slower challenge."
    });
    const weeklyImage = screen.getByAltText("Backword weekly crossword screen");

    expect(
      backwordHeading.compareDocumentPosition(backwordImage) &
        Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy();
    expect(
      weeklyHeading.compareDocumentPosition(weeklyImage) &
        Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy();
  });

  it("renders the privacy route", () => {
    renderRoute("/privacy");

    expect(
      screen.getByRole("heading", { level: 1, name: "Privacy Policy" })
    ).toBeInTheDocument();
    expect(screen.getByText(/operated by Sean Williams/i)).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { level: 2, name: "Advertising and AdMob" })
    ).toBeInTheDocument();
  });

  it("renders the terms route", () => {
    renderRoute("/terms");

    expect(
      screen.getByRole("heading", { level: 1, name: "Terms & Conditions" })
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { level: 2, name: "Pro Features, Purchases, and Subscriptions" })
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { level: 2, name: "Advertising and Rewards" })
    ).toBeInTheDocument();
  });
});
