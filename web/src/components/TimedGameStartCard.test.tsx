import { fireEvent, render, screen } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import { TimedGameStartCard } from "./TimedGameStartCard";

describe("Timed game introductions", () => {
  it.each(["anagram", "midword"] as const)("prevents starting %s until the puzzle is ready without replacing the panel", game => {
    const onStart = vi.fn();
    const props = { game, headings: ["Ready to play"], explanation: "Press Start to begin.", detail: "No time limit", onStart };
    const view = render(<TimedGameStartCard {...props} loading />);
    const panel = screen.getByRole("region", { name: /introduction/ });
    const start = screen.getByRole("button", { name: "Start" });
    expect(panel).toHaveAttribute("aria-busy", "true");
    expect(start).toBeDisabled();
    fireEvent.click(start);
    expect(onStart).not.toHaveBeenCalled();
    view.rerender(<TimedGameStartCard {...props} loading={false} />);
    expect(screen.getByRole("region", { name: /introduction/ })).toBe(panel);
    expect(panel).toHaveAttribute("aria-busy", "false");
    expect(start).toBeEnabled();
    fireEvent.click(start);
    expect(onStart).toHaveBeenCalledOnce();
  });
  it.each(["anagram", "midword"] as const)("uses the same readable panel and explicit Start action for %s", (game) => {
    const onStart = vi.fn();
    const style = document.createElement("style");
    style.textContent = readFileSync("src/styles.css", "utf8");
    document.head.append(style);
    try {
      render(<main className={`${game}-main timed-game-start-layout`}><TimedGameStartCard game={game} headings={["Find the connection.", "Complete both words."]}
        explanation="The clock starts when you press Start." detail="4 letters · no time limit" onStart={onStart} /></main>);
      expect(getComputedStyle(screen.getByRole("main")).justifyContent).toBe(game === "anagram" ? "flex-start" : "center");
      expect(getComputedStyle(screen.getByRole("main")).minHeight).toBe("0");
      const panel = screen.getByRole("region", { name: /introduction/ });
      expect(getComputedStyle(panel).textAlign).toBe("left");
      const heading = screen.getByRole("heading", { level: 2 });
      expect(heading.children).toHaveLength(2);
      expect(getComputedStyle(heading).fontSize).toBe("24px");
      expect(getComputedStyle(screen.getByText("The clock starts when you press Start.")).fontSize).toBe("16px");
      expect(screen.getByText("4 letters · no time limit")).toBeInTheDocument();
      expect(onStart).not.toHaveBeenCalled();
      fireEvent.click(screen.getByRole("button", { name: "Start" }));
      expect(onStart).toHaveBeenCalledOnce();
    } finally { style.remove(); }
  });
});
