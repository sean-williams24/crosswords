import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AccountDeletionConfirmationModal } from "./AccountDeletionConfirmationModal";

describe("account-deleted sheet dismissal", () => {
  it("uses the Continue action for backdrop clicks, including after a retryable error", () => {
    const onContinue = vi.fn();
    render(<AccountDeletionConfirmationModal error="Please try again" isFinishing={false}
      onContinue={onContinue} summary={null} />);
    const dialog = screen.getByRole("dialog", { name: "Your intervls account has been deleted" });
    fireEvent.click(dialog);
    fireEvent.click(screen.getByRole("heading", { name: "Not deleted" }));
    expect(onContinue).not.toHaveBeenCalled();
    fireEvent.click(dialog.parentElement!);
    expect(onContinue).toHaveBeenCalledOnce();
  });

  it("ignores backdrop clicks while final cleanup is already running", () => {
    const onContinue = vi.fn();
    render(<AccountDeletionConfirmationModal error={null} isFinishing
      onContinue={onContinue} summary={null} />);
    fireEvent.click(screen.getByRole("dialog").parentElement!);
    expect(screen.getByRole("button", { name: "Returning to sign in…" })).toBeDisabled();
    expect(onContinue).not.toHaveBeenCalled();
  });
});
