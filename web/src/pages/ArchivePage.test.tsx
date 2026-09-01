import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { ArchivePage } from "./ArchivePage";

const repositories = vi.hoisted(() => ({
  backword: {
    getArchiveMonths: vi.fn(async () => ["2026-08", "2026-07"]),
    getArchiveMonth: vi.fn(async (month: string) => month === "2026-08" ? [{
      id: "word-1", date: "2026-08-06", word: "CASTLE", clue: "Fortress"
    }] : [{ id: "word-2", date: "2026-07-30", word: "PLANET", clue: "World" }])
  },
  crossword: {
    getArchiveMonths: vi.fn(async () => ["2026-08"]),
    getArchiveMonth: vi.fn(async (kind: "daily" | "weekly") => [{
      id: `${kind}-1`, puzzleNumber: 12, date: "2026-08-05", size: kind === "weekly" ? 13 : 9,
      cells: Array.from({ length: kind === "weekly" ? 13 : 9 }, () => Array.from({ length: kind === "weekly" ? 13 : 9 }, () => ({ letter: null, clueNumber: null, acrossClueId: null, downClueId: null }))),
      clues: [{ id: 1, number: 1, direction: "across", text: "Test", hint: "Test", answer: "AB", startRow: 0, startCol: 0, length: 2 }]
    }])
  }
}));

vi.mock("../features/auth/AuthProvider", () => ({ useAuth: () => ({ entitlement: null, user: null }) }));
vi.mock("../features/auth/AuthButton", () => ({ AuthButton: () => <a href="/sign-in">Login</a> }));
vi.mock("../features/backword/components/GameMenu", () => ({ GameMenu: () => <button type="button">Menu</button> }));
vi.mock("../features/backword/repository", () => ({ createBackwordRepository: () => repositories.backword }));
vi.mock("../features/crossword/repository", () => ({ createCrosswordRepository: () => repositories.crossword }));

describe("ArchivePage", () => {
  beforeEach(() => {
    localStorage.clear();
    repositories.backword.getArchiveMonths.mockClear();
    repositories.backword.getArchiveMonth.mockClear();
    repositories.crossword.getArchiveMonths.mockClear();
    repositories.crossword.getArchiveMonth.mockClear();
  });

  it("loads Backword first and links its selected month with a dated route", async () => {
    render(<MemoryRouter><ArchivePage /></MemoryRouter>);

    const archiveEntry = await screen.findByRole("link", { name: /New/i });
    expect(archiveEntry).toHaveAttribute("href", "/backword/2026-08-06");
    expect(repositories.backword.getArchiveMonth).toHaveBeenCalledWith("2026-08");
    expect(screen.getAllByRole("button", { name: "Backword" })[0]).toHaveAttribute("aria-pressed", "true");
  });

  it("switches games and loads the selected crossword archive", async () => {
    const user = userEvent.setup();
    render(<MemoryRouter><ArchivePage /></MemoryRouter>);
    await screen.findByRole("link", { name: /New/i });

    await user.click(screen.getByRole("button", { name: "Quick Crossword" }));

    await waitFor(() => expect(repositories.crossword.getArchiveMonth).toHaveBeenCalledWith("daily", "2026-08"));
    expect(await screen.findByRole("link", { name: /New/i })).toHaveAttribute("href", "/crossword/2026-08-05");
  });
});
