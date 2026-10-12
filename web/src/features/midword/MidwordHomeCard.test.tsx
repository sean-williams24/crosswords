import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { render, screen, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { emptyProgress, type MidwordProgress } from "./engine";
import { MidwordHomeCard } from "./MidwordHomeCard";

describe("MidwordHomeCard", () => {
  it.each([0, 4])("keeps %i points and status available in the bottom row", (score) => {
    const now = new Date(2026, 9, 11, 12);
    const progress: MidwordProgress = {
      ...emptyProgress("2026-10-11", now),
      guesses: ["NOTE"],
      completedAt: now.toISOString(),
      outcome: score === 0 ? "failed" : "won",
      releaseDateScore: score
    };
    render(<MemoryRouter><MidwordHomeCard issueNumber={11} progress={progress} /></MemoryRouter>);

    const card = screen.getByRole("link", { name: "Midword, issue #11" });
    const details = card.querySelector(".midword-home-card__details")!;
    expect(details.firstElementChild).toHaveClass("home-game-card__score");
    expect(within(details.firstElementChild as HTMLElement).getByText(String(score))).toBeInTheDocument();
    expect(details.querySelector(".home-status")).toBe(within(card).getByLabelText(`Status: ${score === 0 ? "Failed" : "Solved"}`));
  });

  it("keeps the new-game status at the bottom without points", () => {
    render(<MemoryRouter><MidwordHomeCard issueNumber={null} progress={emptyProgress("2026-10-11")} /></MemoryRouter>);
    const card = screen.getByRole("link", { name: "Midword" });
    expect(card.querySelector(".home-game-card__score")).not.toBeInTheDocument();
    expect(card.querySelector(".midword-home-card__details")?.querySelector(".home-status"))
      .toBe(within(card).getByLabelText("Status: New"));
  });

  it.each([0, 3])("keeps a %i-day streak outside the centred logo and footer", (streak) => {
    render(<MemoryRouter><MidwordHomeCard issueNumber={11} progress={emptyProgress("2026-10-11")} streak={streak} /></MemoryRouter>);
    const card = screen.getByRole("link", { name: "Midword, issue #11" });
    const badge = within(card).queryByLabelText(`${streak}-day streak`);
    if (streak > 0) {
      expect(badge).toHaveTextContent(`🔥 ${streak}`);
      expect(badge?.parentElement).toBe(card);
    } else {
      expect(badge).not.toBeInTheDocument();
      expect(card.querySelector(".home-game-card__streak")).toBeNull();
    }
  });

  it("uses the unchanged white and black iOS Home logo in both themes", () => {
    render(<MemoryRouter><MidwordHomeCard issueNumber={11} progress={emptyProgress("2026-10-11")} /></MemoryRouter>);
    expect(screen.getByRole("img", { name: "Midword" })).toHaveAttribute("src", "/brand/midword-logo-light.png");

    const nativeAssetDirectory = resolve(process.cwd(), "../Backword/Resources/Assets.xcassets/MidwordLogoLight.imageset");
    const catalog = JSON.parse(readFileSync(resolve(nativeAssetDirectory, "Contents.json"), "utf8")) as {
      images: { filename: string; scale: string }[];
    };
    const nativeImage = catalog.images.find((image) => image.scale === "3x")!;
    expect(readFileSync(resolve(process.cwd(), "public/brand/midword-logo-light.png")))
      .toEqual(readFileSync(resolve(nativeAssetDirectory, nativeImage.filename)));
    const styles = readFileSync(resolve(process.cwd(), "src/features/midword/midword.css"), "utf8");
    expect(styles).not.toMatch(/\.midword-home-card__identity img\s*\{[^}]*filter:/);
  });
});
