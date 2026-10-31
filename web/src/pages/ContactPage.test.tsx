import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { ContactPage } from "./ContactPage";

function renderContactPage() {
  return render(
    <MemoryRouter initialEntries={["/contact"]}>
      <ContactPage />
    </MemoryRouter>
  );
}

describe("ContactPage", () => {
  it("opens the configured support address without collecting website feedback", () => {
    renderContactPage();

    expect(screen.getByRole("link", { name: "Send email" })).toHaveAttribute(
      "href",
      "mailto:support@intervls.com"
    );
    expect(screen.getByRole("link", { name: "support@intervls.com" })).toHaveAttribute(
      "href",
      "mailto:support@intervls.com"
    );
    expect(screen.getByText("Tapping opens your email app.")).toBeInTheDocument();
    expect(screen.getByText(/Or contact us at/)).toBeInTheDocument();
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
  });
});
