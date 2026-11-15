import { fireEvent, render, screen, within } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import { GameGiveUpDialog } from "./GameGiveUpDialog";

describe.each(["anagram", "midword"] as const)("%s give-up confirmation", game => {
  it("uses the same centered dialog, close control, explanation, and action order", () => {
    const style = document.createElement("style");
    style.textContent = readFileSync("src/styles.css", "utf8");
    document.head.append(style);
    try {
      render(<GameGiveUpDialog game={game} onClose={vi.fn()} onConfirm={vi.fn()} />);
      const dialog = screen.getByRole("dialog", { name: "Give up?" });
      expect(dialog).toHaveAttribute("aria-modal", "true");
      expect(dialog).toHaveClass(`game-confirmation-dialog--${game}`);
      expect(getComputedStyle(dialog.parentElement!).alignItems).toBe("center");
      expect(getComputedStyle(dialog).borderRadius).toBe("28px");
      expect(within(dialog).getByRole("heading", { name: "Give up?" })).toBeInTheDocument();
      expect(within(dialog).getByText(/zero points.*cannot replay/i)).toBeInTheDocument();
      const close = within(dialog).getByRole("button", { name: "Close" });
      const confirm = within(dialog).getByRole("button", { name: "Give up and reveal" });
      const keepPlaying = within(dialog).getByRole("button", { name: "Keep playing" });
      expect(close).toHaveFocus();
      expect(getComputedStyle(close).borderRadius).toBe("50%");
      expect(getComputedStyle(confirm).minHeight).toBe("54px");
      expect(getComputedStyle(confirm).borderRadius).toBe("0");
      expect(confirm.nextElementSibling).toBe(keepPlaying);
    } finally { style.remove(); }
  });

  it.each(["Keep playing", "Close", "Escape", "backdrop"])("dismisses with %s without giving up", method => {
    const onClose = vi.fn(), onConfirm = vi.fn();
    render(<GameGiveUpDialog game={game} onClose={onClose} onConfirm={onConfirm} />);
    const dialog = screen.getByRole("dialog", { name: "Give up?" });
    fireEvent.click(dialog);
    expect(onClose).not.toHaveBeenCalled();
    if (method === "Escape") fireEvent.keyDown(window, { key: "Escape" });
    else if (method === "backdrop") fireEvent.click(dialog.parentElement!);
    else fireEvent.click(within(dialog).getByRole("button", { name: method }));
    expect(onClose).toHaveBeenCalledOnce();
    expect(onConfirm).not.toHaveBeenCalled();
  });

  it("gives up only on confirmation and restores page scrolling on unmount", () => {
    const onClose = vi.fn(), onConfirm = vi.fn();
    const previousOverflow = document.body.style.overflow;
    const page = render(<GameGiveUpDialog game={game} onClose={onClose} onConfirm={onConfirm} />);
    expect(document.body.style.overflow).toBe("hidden");
    fireEvent.click(screen.getByRole("button", { name: "Give up and reveal" }));
    expect(onConfirm).toHaveBeenCalledOnce();
    expect(onClose).not.toHaveBeenCalled();
    page.unmount();
    expect(document.body.style.overflow).toBe(previousOverflow);
    fireEvent.keyDown(window, { key: "Escape" });
    expect(onClose).not.toHaveBeenCalled();
  });
});
