import { useState } from "react";
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AnagramDialog } from "../features/anagram/components";
import { anagramStats } from "../features/anagram/engine";
import { deriveStats } from "../features/backword/engine";
import { BackwordStats } from "../features/backword/components/BackwordStats";
import { CrosswordStats } from "../features/crossword/components/CrosswordStats";
import { deriveCrosswordStats, deriveWeeklyCrosswordStats } from "../features/crossword/engine";
import { emptyProgress, midwordStats } from "../features/midword/engine";
import { MidwordDialog } from "../features/midword/MidwordDialog";

const now = new Date("2026-10-20T12:00:00");
type Game = "Backword" | "Quick Crossword" | "Pro Crossword" | "Anagram" | "Midword";

function StatsSheetHarness({ game }: { game: Game }) {
  const [open, setOpen] = useState(true);
  const onClose = () => setOpen(false);
  const sheet = game === "Backword"
    ? <BackwordStats onClose={onClose} stats={deriveStats([], now)} />
    : game === "Quick Crossword" || game === "Pro Crossword"
      ? <CrosswordStats kind={game === "Pro Crossword" ? "weekly" : "daily"} onClose={onClose}
        stats={game === "Pro Crossword" ? deriveWeeklyCrosswordStats([], now) : deriveCrosswordStats([], now)} />
      : game === "Midword"
        ? <MidwordDialog kind="stats" now={now} onClose={onClose} progress={emptyProgress("2026-10-20", now)}
          puzzle={null} shareResult={null} stats={midwordStats([], now)} />
        : <AnagramDialog history={[]} kind="stats" now={now} onClose={onClose}
          onConfirmGiveUp={() => {}} onConfirmHint={() => {}} progress={null} puzzle={null}
          shareResult={null} stats={anagramStats([], now)} />;

  return <><p>{game} game remains open</p>{open ? sheet : null}</>;
}

describe("Stats sheet dismissal", () => {
  it.each<Game>(["Backword", "Quick Crossword", "Pro Crossword", "Anagram", "Midword"])(
    "returns to %s from the pinned stats footer", (game) => {
      render(<StatsSheetHarness game={game} />);
      const back = screen.getByRole("button", { name: "BACK TO GAME" });
      expect(back).toHaveFocus();
      expect(screen.queryByRole("button", { name: /^Close/ })).not.toBeInTheDocument();
      expect(screen.getByRole("heading", { name: /Stats$/ })).toBeInTheDocument();
      expect(back.closest(".stats-sheet-scroll")).toBeNull();
      expect(screen.getByRole("dialog").querySelector(".stats-sheet-scroll")).toBeInTheDocument();

      fireEvent.click(back);

      expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
      expect(screen.getByText(`${game} game remains open`)).toBeInTheDocument();
    }
  );

  it.each<Game>(["Backword", "Quick Crossword", "Pro Crossword", "Anagram", "Midword"])(
    "keeps Escape dismissal available for %s without a top-right close button", (game) => {
      render(<StatsSheetHarness game={game} />);
      fireEvent.keyDown(window, { key: "Escape" });
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    }
  );
});
