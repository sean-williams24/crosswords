import { readFileSync } from "node:fs";
import { resolve } from "node:path";
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
  it("hides game footers only in the mobile layout", () => {
    const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

    expect(styles).toMatch(/@media \(max-width: 680px\) \{[\s\S]*?\.bw-page > \.site-footer \{ display: none; \}/);
  });

  it("renders the game dashboard at /", () => {
    renderRoute("/");

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
      "Player Profile",
      "Info",
      "Contact",
      "Privacy",
      "Terms"
    ]);
    expect(footerLinks.map((link) => link.getAttribute("href"))).toEqual([
      "/",
      "/backword",
      "/crossword",
      "/player-profile",
      "/info",
      "/contact",
      "/privacy",
      "/terms"
    ]);
    expect(screen.getAllByRole("link", { name: /Play.*Backword/i }).length).toBeGreaterThan(1);
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.queryByRole("navigation", { name: "Main" })).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Play today’s Backword" })).toHaveAttribute(
      "href",
      "/backword"
    );
    expect(
      screen.getByText(
        "Solve a six-letter word by extending its correct ending from right to left. A guess may reveal a connected chain or nothing new, with an extra letter revealed after three misses."
      )
    ).toBeInTheDocument();
  });

  it("renders Backword at /backword with a footer but without marketing navigation", () => {
    localStorage.setItem(
      "backword:web:settings:v1",
      JSON.stringify({
        schemaVersion: 1,
        mode: "normal",
        hasSeenOnboarding: true,
        lastSeenRulesVersion: 2
      })
    );
    renderRoute("/backword");

    expect(screen.queryByRole("link", { name: "Back to home" })).not.toBeInTheDocument();
    expect(screen.getAllByRole("img", { name: "Backword" })[0]).toHaveAttribute(
      "src",
      "/brand/backword-logo.png"
    );
    expect(screen.queryByRole("navigation", { name: "Main" })).not.toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Footer" })).toBeInTheDocument();
  });

  it("redirects the previous dashboard URL to the home page", () => {
    renderRoute("/home");

    expect(screen.getByRole("heading", { level: 1, name: "Daily Games" })).toBeInTheDocument();
  });

  it("keeps marketing section text before screenshots in mobile source order", () => {
    renderRoute("/info");

    const backwordHeading = screen.getByRole("heading", {
      level: 2,
      name: "Guess forwards. Reveal backwards."
    });
    const backwordImage = screen.getByAltText("Backword gameplay screen");
    const dailyCrosswordImage = screen.getByAltText("Backword daily crossword screen");
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
    expect(dailyCrosswordImage).toHaveAttribute("src", "/screenshots/crossword.png");
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
    const privacyChoices = screen.getByRole("link", { name: "Manage your privacy choices" });
    expect(privacyChoices).toHaveAttribute(
      "href",
      "/privacy-choices"
    );
    expect(privacyChoices.closest("section")).toHaveClass("pt-8", "pb-16", "sm:py-24");
    expect(privacyChoices.parentElement).toHaveClass("legal-page__top-link");
    expect(
      privacyChoices.parentElement?.compareDocumentPosition(screen.getByText(/Last updated/i))
        & Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy();
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

  it("renders the public privacy choices route", () => {
    renderRoute("/privacy-choices");

    expect(
      screen.getByRole("heading", { level: 1, name: "Privacy Choices" })
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { level: 2, name: "Account and Cloud Progress" })
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
  });

  it("redirects the singular privacy-choice URL to the privacy choices page", () => {
    renderRoute("/privacy-choice");

    expect(
      screen.getByRole("heading", { level: 1, name: "Privacy Choices" })
    ).toBeInTheDocument();
  });

  it("renders the contact route with an email hand-off", () => {
    renderRoute("/contact");

    expect(screen.getByText("Contact us")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Send email" })).toHaveAttribute(
      "href",
      "mailto:backword.support@gmail.com"
    );
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
    expect(screen.queryByRole("navigation", { name: "Main" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
  });
});
