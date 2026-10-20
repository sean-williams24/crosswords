import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { BackwordModal } from "./BackwordModal";

describe("shared game sheet dismissal", () => {
  it.each([true, false])("dismisses on a backdrop click with showCloseButton=%s", (showCloseButton) => {
    const onClose = vi.fn();
    render(<BackwordModal onClose={onClose} showCloseButton={showCloseButton} title="Game sheet">
      <p>Sheet content</p><button type="button">Sheet action</button>
    </BackwordModal>);
    const dialog = screen.getByRole("dialog", { name: "Game sheet" });
    fireEvent.click(dialog);
    fireEvent.click(screen.getByText("Sheet content"));
    fireEvent.click(screen.getByRole("button", { name: "Sheet action" }));
    expect(onClose).not.toHaveBeenCalled();
    fireEvent.click(dialog.parentElement!);
    expect(onClose).toHaveBeenCalledOnce();
  });

  it("retains close-button and Escape dismissal", () => {
    const onClose = vi.fn();
    render(<BackwordModal onClose={onClose} title="Game sheet"><p>Content</p></BackwordModal>);
    fireEvent.click(screen.getByRole("button", { name: "Close Game sheet" }));
    expect(onClose).toHaveBeenCalledOnce();
    onClose.mockClear();
    fireEvent.keyDown(window, { key: "Escape" });
    expect(onClose).toHaveBeenCalledOnce();
  });

  it("keeps the stats title when its redundant close button is hidden", () => {
    render(<BackwordModal onClose={vi.fn()} showHeader showCloseButton={false} title="Game stats">
      <p>Stats content</p>
    </BackwordModal>);

    expect(screen.getByRole("heading", { name: "Game stats" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Close Game stats" })).not.toBeInTheDocument();
  });
});
