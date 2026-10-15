import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parse } from "postcss";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { WordOfTheDayCard } from "./WordOfTheDayCard";
import type { WordOfTheDayRepository } from "../repository";

const word = {
  id: "verbose",
  date: "2026-08-05",
  word: "Verbose",
  pronunciation: "ver-BOHS",
  partOfSpeech: "adjective",
  definition: "Using more words than are needed.",
  etymology: "From Latin verbosus, meaning full of words.",
  synonyms: ["wordy", "long-winded", "loquacious"],
  exampleSentence: "His verbose lecture left the audience confused."
};

function repositoryFor(result: Promise<typeof word>): WordOfTheDayRepository {
  return { getByDate: () => result };
}

describe("WordOfTheDayCard", () => {
  it("keeps the definition background and rounded corners without a shadow", () => {
    const styles = parse(readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8"));
    const declarations: Record<string, string> = {};
    styles.walkRules(".wotd-detail__definition", (rule) => {
      rule.walkDecls((declaration) => {
        declarations[declaration.prop] = declaration.value;
      });
    });

    expect(declarations["background"]).toBe("var(--app-surface-raised)");
    expect(declarations["border-radius"]).toBe("18px");
    expect(declarations["box-shadow"] ?? "none").toBe("none");
  });

  it.each([
    "Backword/Views/WOTDDetailView.swift",
    "Backword/Views/HomeScreen/HomeWordOfTheDayView.swift"
  ])("keeps the native WOTD surface shadow-free in %s", (path) => {
    const source = readFileSync(resolve(process.cwd(), "..", path), "utf8");

    expect(source).toContain(".background(Color.appBackground)");
    expect(source).toContain("cornerRadius: AppLayout.cardCornerRadius");
    expect(source).not.toMatch(/\.shadow\s*\(/);
  });

  beforeEach(() => {
    Object.defineProperty(window, "matchMedia", {
      configurable: true,
      value: () => ({ matches: false, addEventListener: () => {}, removeEventListener: () => {} })
    });
  });

  it("reveals and hides the mobile detail drawer", async () => {
    const user = userEvent.setup();
    render(<WordOfTheDayCard date="2026-08-05" repository={repositoryFor(Promise.resolve(word))} />);

    const toggle = await screen.findByRole("button", { name: /Word of the Day Verbose/i });
    const drawer = document.getElementById("wotd-details-verbose");
    expect(toggle).toHaveAttribute("aria-expanded", "false");
    expect(drawer).toHaveAttribute("aria-hidden", "true");

    await user.click(toggle);
    expect(toggle).toHaveAttribute("aria-expanded", "true");
    expect(drawer).toHaveAttribute("aria-hidden", "false");
    expect(screen.getByText("Using more words than are needed.")).toBeInTheDocument();

    await user.click(toggle);
    expect(toggle).toHaveAttribute("aria-expanded", "false");
    expect(drawer).toHaveAttribute("aria-hidden", "true");
  });

  it("exposes all details immediately on larger viewports", async () => {
    const matchMedia = vi.fn(() => ({ matches: true, addEventListener: () => {}, removeEventListener: () => {} }));
    Object.defineProperty(window, "matchMedia", {
      configurable: true,
      value: matchMedia
    });
    render(<WordOfTheDayCard date="2026-08-05" repository={repositoryFor(Promise.resolve(word))} />);

    await screen.findByText("From Latin verbosus, meaning full of words.");
    expect(matchMedia).toHaveBeenCalledWith("(min-width: 901px)");
    expect(document.getElementById("wotd-details-verbose")).toHaveAttribute("aria-hidden", "false");
    expect(screen.getByText("Adjective: a describing word that modifies a noun.")).toBeInTheDocument();
  });

  it("does not render when today's row is unavailable", async () => {
    const onLoadStateChange = vi.fn();
    render(
      <WordOfTheDayCard
        date="2026-08-05"
        onLoadStateChange={onLoadStateChange}
        repository={{ getByDate: () => Promise.reject(new Error("missing")) }}
      />
    );

    expect(onLoadStateChange).toHaveBeenCalledWith("loading");

    await waitFor(() => {
      expect(screen.queryByLabelText("Word of the Day")).not.toBeInTheDocument();
      expect(onLoadStateChange).toHaveBeenLastCalledWith("unavailable");
    });
  });

  it("reports completion after loading a valid row", async () => {
    const onLoadStateChange = vi.fn();
    render(
      <WordOfTheDayCard
        date="2026-08-05"
        onLoadStateChange={onLoadStateChange}
        repository={repositoryFor(Promise.resolve(word))}
      />
    );

    await screen.findByRole("button", { name: /Word of the Day Verbose/i });
    expect(onLoadStateChange).toHaveBeenNthCalledWith(1, "loading");
    expect(onLoadStateChange).toHaveBeenLastCalledWith("loaded");
  });
});
