import { readFileSync } from "node:fs";
import { render, screen } from "@testing-library/react";
import { GameInputMessage } from "./GameInputMessage";

describe("GameInputMessage", () => {
  it("retains text through exit and reverses in place while announcing only visible errors", () => {
    const { container, rerender } = render(<GameInputMessage className="midword-message" message="" />);
    const transition = container.firstElementChild!;
    const label = container.querySelector("p")!;
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(transition).toHaveAttribute("aria-hidden", "true");

    rerender(<GameInputMessage className="midword-message" message="Not in the dictionary" />);
    expect(screen.getByRole("alert")).toBe(label);
    expect(label).toHaveTextContent("Not in the dictionary");
    expect(label).toHaveAttribute("aria-live", "assertive");
    expect(transition).toHaveClass("game-input-message--visible");
    expect(transition).toHaveAttribute("aria-hidden", "false");

    rerender(<GameInputMessage className="midword-message" message="" />);
    expect(transition).not.toHaveClass("game-input-message--visible");
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(label).toBeInTheDocument();
    expect(label).toHaveTextContent("Not in the dictionary");

    rerender(<GameInputMessage className="midword-message" message="Already guessed" />);
    expect(screen.getByRole("alert")).toBe(label);
    expect(label).toHaveTextContent("Already guessed");
    expect(transition).toHaveClass("game-input-message--visible");
    rerender(<GameInputMessage className="midword-message" message="" />);
    expect(label).toHaveTextContent("Already guessed");
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  });

  it("displays an initial message with the game's existing styling", () => {
    render(<GameInputMessage className="bw-invalid-word" message="Not a valid word" />);
    expect(screen.getByRole("alert")).toHaveClass("bw-invalid-word");
    expect(screen.getByRole("alert")).toHaveTextContent("Not a valid word");
  });

  it("collapses the label and its spacing smoothly and skips transitions with Reduce Motion", () => {
    const styles = readFileSync("src/styles.css", "utf8");
    expect(styles).toMatch(/\.game-input-message\s*\{[^}]*grid-template-rows: 0fr;[^}]*opacity: 0;[^}]*transition: grid-template-rows 240ms ease, opacity 180ms ease;/);
    expect(styles).toMatch(/\.game-input-message--visible\s*\{[^}]*grid-template-rows: 1fr;[^}]*opacity: 1;/);
    expect(styles).toMatch(/\.game-input-message__inner\s*\{[^}]*min-height: 0;[^}]*overflow: hidden;/);
    expect(styles).toMatch(/@media \(prefers-reduced-motion: reduce\)\s*\{\s*\.game-input-message\s*\{\s*transition: none;/);
  });
});
