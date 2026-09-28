import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { localDateString } from "../features/backword/date";
import { reviewAnagramPuzzle } from "../features/anagram/engine";
import { AnagramPage } from "./AnagramPage";

vi.mock("../features/anagram/repository", () => ({
  createAnagramRepository: () => ({
    getFirstReleaseDate: async () => localDateString(),
    getByDate: async (date: string) => ({ ...reviewAnagramPuzzle(date), id: "today-anagram", puzzleNumber: 7 })
  })
}));

describe("Anagram browser game", () => {
  beforeEach(() => {
    localStorage.clear();
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
  });

  it("shows the compact share action on the game after completion closes", async () => {
    const user = userEvent.setup();
    render(<MemoryRouter><AnagramPage /></MemoryRouter>);

    await user.click(await screen.findByRole("button", { name: "Start" }));
    expect(screen.queryByRole("button", { name: "Share result" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Give up" }));
    await user.click(screen.getByRole("button", { name: "Give up and reveal" }));
    const completion = await screen.findByRole("dialog", { name: "Finished" });
    expect(within(completion).getByRole("button", { name: "Share result" })).toBeInTheDocument();
    expect(within(screen.getByRole("main")).queryByRole("button", { name: "Share result" })).not.toBeInTheDocument();

    await user.click(within(completion).getByRole("button", { name: "BACK TO GAME" }));
    const gameShareButton = within(screen.getByRole("main")).getByRole("button", { name: "Share result" });
    expect(gameShareButton).toHaveClass("puzzle-result-share__button--compact");
    expect(gameShareButton.closest(".puzzle-result-share--compact")?.parentElement).toHaveClass("anagram-main");
  });
});
