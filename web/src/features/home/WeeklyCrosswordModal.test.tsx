import { fireEvent, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { WeeklyCrosswordModal } from "./WeeklyCrosswordModal";

describe("Pro details sheet dismissal", () => {
  it("dismisses on backdrop clicks and keeps inside clicks in the sheet", () => {
    const onClose = vi.fn();
    render(<MemoryRouter><WeeklyCrosswordModal onClose={onClose} /></MemoryRouter>);
    const dialog = screen.getByRole("dialog", { name: "The full game experience" });
    fireEvent.click(dialog);
    fireEvent.click(screen.getByRole("heading", { name: "The full game experience" }));
    expect(onClose).not.toHaveBeenCalled();
    fireEvent.click(dialog.parentElement!);
    expect(onClose).toHaveBeenCalledOnce();
  });
});
