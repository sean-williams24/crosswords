import { render, screen, waitFor } from "@testing-library/react";
import { useHomeGameIssueNumbers } from "./useHomeGameIssueNumbers";

const repositories = vi.hoisted(() => ({
  backword: { getByDate: vi.fn() },
  crossword: { getByDate: vi.fn(), getCurrentWeekly: vi.fn() }
}));

vi.mock("../backword/repository", () => ({
  createBackwordRepository: () => repositories.backword
}));
vi.mock("../crossword/repository", () => ({
  createCrosswordRepository: () => repositories.crossword
}));

function IssueNumbers({ date, weekDate }: { date: string; weekDate: string }) {
  const issues = useHomeGameIssueNumbers(date, weekDate);

  return <output>{`${issues.backword}/${issues.crossword}/${issues.weeklyCrossword}`}</output>;
}

describe("useHomeGameIssueNumbers", () => {
  beforeEach(() => {
    localStorage.clear();
    repositories.backword.getByDate.mockResolvedValue({
      id: "backword", puzzleNumber: 121, date: "2026-09-16", word: "CASTLE", clue: "Fortress"
    });
    repositories.crossword.getByDate.mockResolvedValue({ id: "daily", puzzleNumber: 122, date: "2026-09-16", size: 9 });
    repositories.crossword.getCurrentWeekly.mockResolvedValue({ id: "weekly", puzzleNumber: 23, date: "2026-09-13", size: 13 });
  });

  it("loads and caches the current issue number for each Home game card", async () => {
    render(<IssueNumbers date="2026-09-16" weekDate="2026-09-13" />);

    await waitFor(() => expect(screen.getByRole("status")).toHaveTextContent("121/122/23"));
    expect(repositories.backword.getByDate).toHaveBeenCalledWith("2026-09-16");
    expect(repositories.crossword.getByDate).toHaveBeenCalledWith("2026-09-16");
    expect(repositories.crossword.getCurrentWeekly).toHaveBeenCalledWith("2026-09-13");
  });
});
