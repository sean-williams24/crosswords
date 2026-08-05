import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { localDateString } from "../features/backword/date";
import { BackwordPage } from "./BackwordPage";

vi.mock("../features/backword/repository", async () => {
  const actual = await vi.importActual<typeof import("../features/backword/repository")>(
    "../features/backword/repository"
  );
  return {
    ...actual,
    createBackwordRepository: () => ({
      getByDate: async (date: string) => ({
        id: "today",
        date,
        word: "CASTLE",
        clue: "Fortress"
      })
    })
  };
});

function renderGame() {
  return render(
    <MemoryRouter initialEntries={["/backword"]}>
      <BackwordPage />
    </MemoryRouter>
  );
}

describe("Backword browser game", () => {
  beforeEach(() => {
    localStorage.clear();
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
  });

  it("uses the iOS logo asset and provides the game navigation menu", async () => {
    renderGame();

    const logo = await screen.findByRole("img", { name: "Backword" });
    expect(logo).toHaveAttribute("src", "/brand/backword-logo.png");
    expect(logo).toHaveClass("bw-logo--large");
    expect(logo.closest("header")).toHaveClass("bw-game-header--offset");
    expect(screen.getByRole("navigation", { name: "Backword actions" })).toHaveClass("bw-game-actions--top");
    expect(screen.queryByRole("link", { name: "Back to home" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open game menu" })).toBeInTheDocument();
  });

  it("opens and closes a menu with game and legal routes", async () => {
    const user = userEvent.setup();
    renderGame();

    await user.click(screen.getByRole("button", { name: "Open game menu" }));

    const menu = screen.getByRole("dialog", { name: "Game navigation" });
    expect(menu).toBeInTheDocument();
    expect(within(menu).queryByText("MENU")).not.toBeInTheDocument();
    expect(within(menu).getByRole("link", { name: "Home" })).toHaveAttribute("href", "/home");
    expect(within(menu).getByRole("link", { name: "Play Backword" })).toHaveAttribute("href", "/");
    expect(within(menu).getByRole("link", { name: "Quick Crossword" })).toHaveAttribute("href", "/crossword");
    expect(within(menu).getByRole("link", { name: "Info" })).toHaveAttribute("href", "/info");
    expect(within(menu).getByRole("link", { name: "Privacy" })).toHaveAttribute("href", "/privacy");
    expect(within(menu).getByRole("link", { name: "Terms" })).toHaveAttribute("href", "/terms");

    await user.click(screen.getByRole("button", { name: "Close game menu" }));
    expect(screen.queryByRole("dialog", { name: "Game navigation" })).not.toBeInTheDocument();
  });

  it("renders the score progress and keyboard within the game controls", async () => {
    const { container } = renderGame();

    expect(await screen.findByText("FORTRESS")).toHaveClass("bw-clue");
    expect(container.querySelector(".bw-explainer-card")).toBeInTheDocument();
    await screen.findByRole("group", { name: "Backword keyboard" });
    const controls = container.querySelector(".bw-game-controls");
    expect(controls?.querySelector(".bw-game-score")).toHaveClass("bw-game-score--keyboard-width");
    expect(controls?.querySelector(".bw-keyboard")).toBeInTheDocument();
  });

  it("shows onboarding, persists the mode, and clears partial input when mode changes", async () => {
    const user = userEvent.setup();
    const { container } = renderGame();

    expect(await screen.findByRole("dialog", { name: "How to Play" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close How to Play" }));
    expect(await screen.findByText("FORTRESS")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "C" }));
    expect(container.querySelector(".bw-letter-row")?.textContent).toContain("C");

    await user.click(screen.getByRole("button", { name: "How to Play" }));
    await user.click(screen.getByRole("switch", { name: "Easy Mode" }));
    await user.click(screen.getByRole("button", { name: "Close How to Play" }));

    expect(container.querySelector(".bw-letter-row")?.textContent).not.toContain("C");
    expect(JSON.parse(localStorage.getItem("backword:web:settings:v1") ?? "{}").mode).toBe("easy");
  });

  it("supports keyboard play, saves a win, and opens the completion stats", async () => {
    const user = userEvent.setup();
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: { writeText }
    });
    renderGame();
    await user.click(await screen.findByRole("button", { name: "Close How to Play" }));

    await user.keyboard("CASTL{Enter}");

    expect(await screen.findByRole("dialog", { name: "Solved!" })).toBeInTheDocument();
    expect(screen.getByText("... in 1 guess")).toBeInTheDocument();
    expect(screen.getByText("5/70")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Share result" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Share result" }));
    expect(writeText).toHaveBeenCalledWith(expect.stringContaining("Got it in 1/5!"));
    expect(screen.getByText("Copied to clipboard")).toBeInTheDocument();

    const stored = JSON.parse(localStorage.getItem("backword:web:progress:v1") ?? "{}");
    expect(stored[localDateString()]).toMatchObject({ outcome: "won", guesses: ["CASTLE"] });
  });

  it("restores an unfinished game after remounting", async () => {
    const user = userEvent.setup();
    const first = renderGame();
    await user.click(await screen.findByRole("button", { name: "Close How to Play" }));
    await user.keyboard("XXXXX{Enter}");
    expect(await screen.findByText("Previous Guesses")).toBeInTheDocument();
    first.unmount();

    renderGame();
    await waitFor(() => expect(screen.getByLabelText("XXXXXE")).toBeInTheDocument());
    expect(screen.queryByRole("dialog", { name: "How to Play" })).not.toBeInTheDocument();
  });
});
