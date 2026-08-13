import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { SignInPage } from "./SignInPage";

describe("SignInPage", () => {
  it("uses the shared menu with a plain, borderless account layout", () => {
    const { container } = render(<MemoryRouter><SignInPage /></MemoryRouter>);

    expect(screen.getByRole("heading", { name: "Keep your games with you." })).toBeInTheDocument();
    const appleButton = screen.getByRole("button", { name: "Sign in with Apple" });
    expect(appleButton).toHaveClass("auth-apple-button");
    expect(appleButton.querySelector("img")).toHaveAttribute(
      "src",
      expect.stringContaining("https://appleid.cdn-apple.com/appleid/button?type=sign-in&color=white&border=true")
    );
    expect(appleButton.querySelector("img")).toHaveAttribute("src", expect.stringContaining("height=50&width=225"));
    const googleButton = screen.getByRole("button", { name: "Sign in with Google" });
    expect(googleButton).toHaveClass("auth-google-button");
    expect(googleButton.querySelector("img")).toHaveAttribute("src", "/brand/continue-with-google.png");
    expect(screen.getByText(/guest play still works/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Backword home" })).not.toBeInTheDocument();
    expect(container.querySelector(".auth-card")).not.toBeInTheDocument();
    expect(container.querySelector(".auth-content")).toBeInTheDocument();
  });
});
