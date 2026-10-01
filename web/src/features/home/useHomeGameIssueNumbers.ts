import { useEffect, useState } from "react";
import { localDateString, localWeekStartString } from "../backword/date";
import { createBackwordRepository } from "../backword/repository";
import { createAnagramRepository } from "../anagram/repository";
import { createAnagramStorage } from "../anagram/storage";
import { createBackwordStorage } from "../backword/storage";
import { createCrosswordRepository } from "../crossword/repository";
import { createCrosswordStorage } from "../crossword/storage";

export type HomeGameIssueNumbers = {
  backword: number | null;
  anagram: number | null;
  firstAnagramRelease: string | null;
  crossword: number | null;
  weeklyCrossword: number | null;
};

const emptyIssueNumbers: HomeGameIssueNumbers = {
  backword: null,
  anagram: null,
  firstAnagramRelease: null,
  crossword: null,
  weeklyCrossword: null
};

/** Loads stable issue numbers without making the dashboard unavailable when content is offline. */
export function useHomeGameIssueNumbers(
  date = localDateString(),
  weekDate = localWeekStartString()
): HomeGameIssueNumbers {
  const [issueNumbers, setIssueNumbers] = useState<HomeGameIssueNumbers>(emptyIssueNumbers);

  useEffect(() => {
    let cancelled = false;
    const backwordStorage = createBackwordStorage(window.localStorage);
    const anagramStorage = createAnagramStorage(window.localStorage);
    const crosswordStorage = createCrosswordStorage(window.localStorage);
    const weeklyStorage = createCrosswordStorage(window.localStorage, { kind: "weekly" });

    setIssueNumbers({
      backword: backwordStorage.loadCachedWord(date)?.puzzleNumber ?? null,
      anagram: anagramStorage.loadCachedPuzzle(date)?.puzzleNumber ?? null,
      firstAnagramRelease: anagramStorage.firstReleaseDate(),
      crossword: crosswordStorage.loadCachedPuzzle(date)?.puzzleNumber ?? null,
      weeklyCrossword: weeklyStorage.loadCachedPuzzle(weekDate)?.puzzleNumber ?? null
    });

    const updateIssueNumber = (game: keyof HomeGameIssueNumbers, issueNumber: number) => {
      if (!cancelled) setIssueNumbers((current) => ({ ...current, [game]: issueNumber }));
    };

    void (async () => {
      try {
        const repository = createAnagramRepository();
        const puzzle = await repository.getByDate(date);
        anagramStorage.cachePuzzle(puzzle);
        updateIssueNumber("anagram", puzzle.puzzleNumber);
        try {
          const firstRelease = await repository.getFirstReleaseDate();
          if (firstRelease) {
            anagramStorage.setFirstReleaseDate(firstRelease);
            if (!cancelled) setIssueNumbers((current) => ({ ...current, firstAnagramRelease: firstRelease }));
          }
        } catch { /* Daily content may still be available. */ }
      } catch {
        // The card remains usable while content is offline or unreleased.
      }
    })();
    void (async () => {
      try {
        const word = await createBackwordRepository().getByDate(date);
        backwordStorage.cacheWord(word);
        updateIssueNumber("backword", word.puzzleNumber);
      } catch {
        // The card remains usable when a release is unavailable or the player is offline.
      }
    })();
    void (async () => {
      try {
        const puzzle = await createCrosswordRepository().getByDate(date);
        crosswordStorage.cachePuzzle(puzzle);
        updateIssueNumber("crossword", puzzle.puzzleNumber);
      } catch {
        // The card remains usable when a release is unavailable or the player is offline.
      }
    })();
    void (async () => {
      try {
        const puzzle = await createCrosswordRepository().getCurrentWeekly(weekDate);
        weeklyStorage.cachePuzzle(puzzle);
        updateIssueNumber("weeklyCrossword", puzzle.puzzleNumber);
      } catch {
        // The card remains usable when a release is unavailable or the player is offline.
      }
    })();

    return () => { cancelled = true; };
  }, [date, weekDate]);

  return issueNumbers;
}
