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
      "https://apps.apple.com/app/backword/id0000000000"
    );
    expect(screen.getAllByRole("link", { name: "Privacy" })).toHaveLength(2);
    expect(screen.getAllByRole("link", { name: "Terms" })).toHaveLength(2);
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
    expect(screen.getAllByText(/placeholder terms/i).length).toBeGreaterThan(0);
  });
});
