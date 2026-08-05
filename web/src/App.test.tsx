import { render, screen, within } from "@testing-library/react";
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
  it("renders the game dashboard at /home", () => {
    renderRoute("/home");

    expect(screen.getByRole("heading", { level: 1, name: "Daily Games" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Quick Crossword/i })).toHaveAttribute(
      "href",
      "/crossword"
    );
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Footer" })).toBeInTheDocument();
  });

  it("renders the playable Quick Crossword route", () => {
    renderRoute("/crossword");

    expect(screen.getByText("Loading today’s crossword…")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Footer" })).toBeInTheDocument();
  });

  it("keeps the marketing page and footer links at /info", () => {
    renderRoute("/info");

    expect(
      screen.getByRole("heading", { level: 1, name: "Backword" })
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Download Backword on the App Store")).toHaveAttribute(
      "href",
      "https://apps.apple.com/app/backword/id6773428497"
    );
    const footer = screen.getByRole("navigation", { name: "Footer" });
    const footerLinks = within(footer).getAllByRole("link");
    expect(footerLinks.map((link) => link.textContent)).toEqual([
      "Home",
      "Backword",
      "Crossword",
      "Info",
      "Privacy",
      "Terms"
    ]);
    expect(footerLinks.map((link) => link.getAttribute("href"))).toEqual([
      "/home",
      "/",
      "/crossword",
      "/info",
      "/privacy",
      "/terms"
    ]);
    expect(screen.getAllByRole("link", { name: /Play.*Backword/i }).length).toBeGreaterThan(1);
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.queryByRole("navigation", { name: "Main" })).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Play today’s Backword" })).toHaveAttribute(
      "href",
      "/"
    );
    expect(
      screen.getByText(
        "Solve a six-letter word by extending its correct ending from right to left. A guess may reveal a connected chain or nothing new, with an extra letter revealed after three misses."
      )
    ).toBeInTheDocument();
  });

  it("renders Backword at the main URL with a footer but without marketing navigation", () => {
    localStorage.setItem(
      "backword:web:settings:v1",
      JSON.stringify({
        schemaVersion: 1,
        mode: "normal",
        hasSeenOnboarding: true,
        lastSeenRulesVersion: 2
      })
    );
    renderRoute("/");

    expect(screen.queryByRole("link", { name: "Back to home" })).not.toBeInTheDocument();
    expect(screen.getAllByRole("img", { name: "Backword" })[0]).toHaveAttribute(
      "src",
      "/brand/backword-logo.png"
    );
    expect(screen.queryByRole("navigation", { name: "Main" })).not.toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Footer" })).toBeInTheDocument();
  });

  it("keeps marketing section text before screenshots in mobile source order", () => {
    renderRoute("/info");

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
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.queryByRole("navigation", { name: "Main" })).not.toBeInTheDocument();
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
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.queryByRole("navigation", { name: "Main" })).not.toBeInTheDocument();
  });
});
