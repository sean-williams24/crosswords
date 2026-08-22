import { render, screen } from "@testing-library/react";
import { BackwordLogo } from "./BackwordLogo";

describe("BackwordLogo", () => {
  it("adds the Pro mark to the logo lockup for active Pro users", () => {
    render(<BackwordLogo isPro large />);

    expect(screen.getByRole("img", { name: "Backword" })).toHaveAttribute(
      "src",
      "/brand/backword-logo.png"
    );
    expect(screen.getByRole("img", { name: "Pro" })).toHaveAttribute(
      "src",
      "/brand/backword-pro.png"
    );
    expect(screen.getByRole("img", { name: "Pro" })).toHaveClass("bw-logo__pro");
  });

  it("does not show the Pro mark for non-Pro users", () => {
    render(<BackwordLogo />);

    expect(screen.queryByRole("img", { name: "Pro" })).not.toBeInTheDocument();
  });
});
