import { fireEvent, render, screen } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { StatsSheetActions } from "./StatsSheetActions";

describe("Stats sheet actions", () => {
  it("dismisses without navigating away from the game", () => {
    const onClose = vi.fn();
    render(<MemoryRouter initialEntries={["/game"]}><Routes>
      <Route path="/game" element={<StatsSheetActions onClose={onClose} />} />
      <Route path="/" element={<p>Home destination</p>} />
    </Routes></MemoryRouter>);

    fireEvent.click(screen.getByRole("button", { name: "BACK TO GAME" }));

    expect(onClose).toHaveBeenCalledOnce();
    expect(screen.queryByText("Home destination")).not.toBeInTheDocument();
  });

  it("navigates home without firing the sheet-only dismiss action", () => {
    const onClose = vi.fn();
    render(<MemoryRouter initialEntries={["/game"]}><Routes>
      <Route path="/game" element={<StatsSheetActions onClose={onClose} />} />
      <Route path="/" element={<p>Home destination</p>} />
    </Routes></MemoryRouter>);

    fireEvent.click(screen.getByRole("button", { name: "HOME" }));

    expect(screen.getByText("Home destination")).toBeInTheDocument();
    expect(onClose).not.toHaveBeenCalled();
  });

  it("supports a single dismiss action for ordinary stats sheets", () => {
    const onClose = vi.fn();
    render(<StatsSheetActions onClose={onClose} showHome={false} />);

    expect(screen.queryByRole("button", { name: "HOME" })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "BACK TO GAME" }));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it("pins the glass footer and centers both full-size button targets", () => {
    const style = document.createElement("style");
    style.textContent = readFileSync("src/components/StatsSheetActions.css", "utf8");
    document.head.append(style);
    try {
      render(<MemoryRouter><StatsSheetActions onClose={vi.fn()} /></MemoryRouter>);
      const bar = screen.getByRole("group", { name: "Stats sheet actions" });
      expect(getComputedStyle(bar.parentElement!).position).toBe("absolute");
      expect(getComputedStyle(bar.parentElement!).bottom).toBe("0px");
      expect(getComputedStyle(bar).borderRadius).toBe("999px");
      for (const button of screen.getAllByRole("button")) {
        const styles = getComputedStyle(button);
        expect(styles.alignItems).toBe("center");
        expect(styles.justifyContent).toBe("center");
        expect(styles.flexGrow).toBe("1");
        expect(styles.flexBasis).toBe("0px");
        expect(styles.minHeight).toBe("44px");
      }
    } finally {
      style.remove();
    }
  });

  it("keeps focused buttons square and borderless even with Midword's focus styles loaded last", () => {
    const style = document.createElement("style");
    style.textContent = readFileSync("src/components/StatsSheetActions.css", "utf8")
      + readFileSync("src/features/midword/midword.css", "utf8");
    document.head.append(style);
    try {
      render(<MemoryRouter><div className="midword-dialog">
        <StatsSheetActions autoFocusHome onClose={vi.fn()} />
      </div></MemoryRouter>);

      expect(screen.getByRole("button", { name: "HOME" })).toHaveFocus();
      for (const button of screen.getAllByRole("button")) {
        button.focus();
        // jsdom can retain styles computed before the focus state changed.
        style.textContent = style.textContent;
        const styles = getComputedStyle(button);
        expect(styles.borderRadius).toBe("0");
        expect(styles.borderTopWidth).toBe("0px");
        expect(styles.outline).toBe("none");
        expect(styles.background).not.toBe("transparent");
      }
    } finally {
      style.remove();
    }
  });
});
