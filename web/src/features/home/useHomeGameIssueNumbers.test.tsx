import { render, screen, waitFor } from "@testing-library/react";
import { useHomeGameIssueNumbers } from "./useHomeGameIssueNumbers";

const repositories = vi.hoisted(() => ({
  anagram: { getByDate: vi.fn(), getFirstReleaseDate: vi.fn() },
  backword: { getByDate: vi.fn() },
  crossword: { getByDate: vi.fn(), getCurrentWeekly: vi.fn() }
}));

vi.mock("../anagram/repository", () => ({
  createAnagramRepository: () => repositories.anagram
}));

vi.mock("../backword/repository", () => ({
  createBackwordRepository: () => repositories.backword
}));
vi.mock("../crossword/repository", () => ({
  createCrosswordRepository: () => repositories.crossword
}));

function IssueNumbers({ date, weekDate }: { date: string; weekDate: string }) {
  const issues = useHomeGameIssueNumbers(date, weekDate);

  return <output>{`${issues.backword}/${issues.anagram}/${issues.crossword}/${issues.weeklyCrossword}/${issues.firstAnagramRelease}`}</output>;
}

describe("useHomeGameIssueNumbers", () => {
  beforeEach(() => {
    localStorage.clear();
    repositories.backword.getByDate.mockResolvedValue({
      id: "backword", puzzleNumber: 121, date: "2026-09-16", word: "CASTLE", clue: "Fortress"
    });
    repositories.anagram.getFirstReleaseDate.mockResolvedValue("2026-09-16");
    repositories.anagram.getByDate.mockResolvedValue({ id: "anagram", puzzleNumber: 1, date: "2026-09-16", schemaVersion: 1,
      answer: "TRIANGLE", acceptedAnswers: ["INTEGRAL"], initialScramble: "RAGTLINE" });
    repositories.crossword.getByDate.mockResolvedValue({ id: "daily", puzzleNumber: 122, date: "2026-09-16", size: 9 });
    repositories.crossword.getCurrentWeekly.mockResolvedValue({ id: "weekly", puzzleNumber: 23, date: "2026-09-13", size: 13 });
  });

  it("loads and caches the current issue number for each Home game card", async () => {
    render(<IssueNumbers date="2026-09-16" weekDate="2026-09-13" />);

    await waitFor(() => expect(screen.getByRole("status")).toHaveTextContent("121/1/122/23/2026-09-16"));
    expect(repositories.anagram.getByDate).toHaveBeenCalledWith("2026-09-16");
    expect(repositories.backword.getByDate).toHaveBeenCalledWith("2026-09-16");
    expect(repositories.crossword.getByDate).toHaveBeenCalledWith("2026-09-16");
    expect(repositories.crossword.getCurrentWeekly).toHaveBeenCalledWith("2026-09-13");
  });
});
