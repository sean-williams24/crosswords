import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { HomeArchiveCard } from "./HomeArchiveCard";

const auth = vi.hoisted(() => ({ isPro: false }));
vi.mock("../auth/AuthProvider", () => ({
  useAuth: () => ({ entitlement: auth.isPro ? { isPro: true } : null })
}));

describe("HomeArchiveCard", () => {
  it.each([false, true])("opens the full archive through the correct access route (Pro: %s)", (isPro) => {
    auth.isPro = isPro;
    render(<MemoryRouter><HomeArchiveCard /></MemoryRouter>);
    const card = screen.getByRole("link", { name: "Archive" });
    expect(card).toHaveAttribute("href", isPro ? "/archive" : "/pro?return_to=%2Farchive");
    expect(card).toHaveClass("home-game-card", "home-game-card--archive");
    expect(card.querySelector(".home-game-card__identity")).toHaveTextContent("Archive");
    const description = screen.getByText("Unlock the full archive for all five games");
    expect(description.previousElementSibling).toHaveClass("home-archive-card__title");
    expect(description.parentElement).toHaveClass("home-game-card__identity");
    expect(card).toHaveAccessibleDescription("Unlock the full archive for all five games");
    expect(card.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
  });
});
