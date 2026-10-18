import { readFileSync } from "node:fs";
import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { GameSubmitButton } from "./GameSubmitButton";

describe("GameSubmitButton", () => {
  it("keeps the button mounted for exit and reversed transitions while disabling hidden input", async () => {
    const onSubmit = vi.fn();
    const user = userEvent.setup();
    const { container, rerender } = render(<GameSubmitButton onSubmit={onSubmit} visible={false} />);
    const button = container.querySelector("button")!;
    const transition = container.firstElementChild!;
    expect(button).toBeDisabled();
    expect(transition).toHaveAttribute("aria-hidden", "true");
    expect(transition).toHaveAttribute("inert");
    expect(screen.queryByRole("button", { name: "Submit" })).not.toBeInTheDocument();
    fireEvent.click(button);
    expect(onSubmit).not.toHaveBeenCalled();

    rerender(<GameSubmitButton onSubmit={onSubmit} visible />);
    expect(screen.getByRole("button", { name: "Submit" })).toBe(button);
    expect(button).toBeEnabled();
    expect(transition).toHaveClass("game-submit--visible");
    expect(transition).not.toHaveAttribute("inert");
    await user.click(button);
    expect(onSubmit).toHaveBeenCalledTimes(1);

    rerender(<GameSubmitButton onSubmit={onSubmit} visible={false} />);
    expect(button).toBeInTheDocument();
    expect(button).toBeDisabled();
    expect(transition).not.toHaveClass("game-submit--visible");
    expect(transition).toHaveAttribute("inert");
    expect(screen.queryByRole("button", { name: "Submit" })).not.toBeInTheDocument();
    fireEvent.click(button);
    expect(onSubmit).toHaveBeenCalledTimes(1);

    rerender(<GameSubmitButton onSubmit={onSubmit} visible />);
    expect(screen.getByRole("button", { name: "Submit" })).toBe(button);
    expect(transition).toHaveClass("game-submit--visible");
    await user.click(button);
    expect(onSubmit).toHaveBeenCalledTimes(2);
  });

  it("skips hidden Submit when navigating with Tab", async () => {
    const user = userEvent.setup();
    render(<><GameSubmitButton onSubmit={vi.fn()} visible={false} /><button>Keyboard key</button></>);
    await user.tab();
    expect(screen.getByRole("button", { name: "Keyboard key" })).toHaveFocus();
  });

  it("animates the full control height without leaving a hidden gap and respects Reduce Motion", () => {
    const styles = readFileSync("src/styles.css", "utf8");
    expect(styles).toMatch(/\.game-submit\s*\{[^}]*grid-template-rows: 0fr;[^}]*opacity: 0;[^}]*transition: grid-template-rows 240ms ease, opacity 180ms ease;/);
    expect(styles).toMatch(/\.game-submit--visible\s*\{[^}]*grid-template-rows: 1fr;[^}]*opacity: 1;/);
    expect(styles).toMatch(/\.game-submit__inner\s*\{[^}]*min-height: 0;[^}]*overflow: hidden;/);
    expect(styles).toMatch(/@media \(prefers-reduced-motion: reduce\)\s*\{\s*\.game-submit\s*\{\s*transition: none;/);
  });
});
