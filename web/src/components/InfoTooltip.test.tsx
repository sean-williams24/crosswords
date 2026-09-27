import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { InfoTooltip } from "./InfoTooltip";

describe("InfoTooltip", () => {
  it("dismisses from its close button or a pointer press outside, but stays open when its text is pressed", async () => {
    const user = userEvent.setup();
    const onDismiss = vi.fn();
    render(
      <div>
        <InfoTooltip description="Game instructions" id="game-info-tip" onDismiss={onDismiss} />
        <button type="button">Game board</button>
      </div>
    );

    await user.click(screen.getByRole("tooltip"));
    expect(onDismiss).not.toHaveBeenCalled();

    await user.click(screen.getByRole("button", { name: "Game board" }));
    expect(onDismiss).toHaveBeenCalledTimes(1);

    fireEvent.pointerDown(screen.getByRole("button", { name: "Game board" }), { pointerType: "touch" });
    expect(onDismiss).toHaveBeenCalledTimes(2);

    await user.click(screen.getByRole("button", { name: "Close tooltip" }));
    expect(onDismiss).toHaveBeenCalledTimes(3);
  });
});
