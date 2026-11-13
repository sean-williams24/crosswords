import { describe, expect, it } from 'vitest';
import { dailyChallenge, shouldCelebrate } from './dailyChallenge';
import type { BackwordProgress } from '../backword/types';
import type { CrosswordProgress, CrosswordPuzzle } from '../crossword/types';
import type { AnagramProgress } from '../anagram/engine';
import type { MidwordProgress } from '../midword/engine';

const date = '2026-11-10';
const empty = { backword: null, crossword: null, puzzle: null, anagram: null, midword: null };
describe('daily challenge', () => {
  it('derives partial fills and scores without requiring downloaded puzzles', () => {
    const snapshot = dailyChallenge(date, {
      ...empty,
      backword: { date, guesses: ['ABC', 'DEF'], outcome: 'inProgress', completedAt: null } as BackwordProgress,
      crossword: { date, completedClueIds: [1, 2, 3, 4], totalClues: 8, hintsUsed: 3, releaseDateScore: 0 } as CrosswordProgress,
      anagram: { date, startedAt: '2026-11-10T12:00:00Z', outcome: null, completedAt: null, releaseDateScore: 0 } as AnagramProgress,
      midword: { date, startedAt: '2026-11-10T12:01:05Z', guesses: ['ONE'], completedAt: null, releaseDateScore: 0 } as MidwordProgress
    }, new Date('2026-11-10T12:01:35Z'));
    expect(snapshot.games.map(g => g.fraction)).toEqual([.4, .5, 3 / 7, 1 / 7]);
    expect(snapshot.points).toBe(2);
    expect(snapshot.complete).toBe(false);
  });
  it('reserves a gap, favours the cached grid and retains pre-reveal points', () => {
    const crossword = { date, puzzleId: 'p', completedClueIds: [1, 2, 3, 4], totalClues: 3, hintsUsed: 0, releaseDateScore: 5 } as CrosswordProgress;
    const puzzle = { id: 'p', date, clues: Array(10).fill({}) } as CrosswordPuzzle;
    expect(dailyChallenge(date, { ...empty, crossword, puzzle }).games[1]).toMatchObject({ fraction: .4, points: 2 });
    expect(dailyChallenge(date, { ...empty, crossword, puzzle: null }).games[1].fraction).toBe(.8);
    expect(dailyChallenge(date, { ...empty, crossword: { ...crossword, gaveUpAt: '2026-11-10T12:00:00Z', gaveUpScore: 2 }, puzzle }).games[1]).toMatchObject({ state: 'finished', won: false, points: 2 });
  });
  it('counts losses as finished and ignores other dates and weekly grids', () => {
    const b = { date, guesses: ['A', 'B', 'C', 'D', 'E'], outcome: 'failed', completedAt: '2026-11-10T12:00:00Z' } as BackwordProgress;
    const m = { date, guesses: ['A'], outcome: 'won', completedAt: b.completedAt, releaseDateScore: 5 } as MidwordProgress;
    const a = { date, startedAt: b.completedAt, outcome: 'gave_up', completedAt: b.completedAt, releaseDateScore: 0 } as AnagramProgress;
    const c = { date, isWeekly: true, completedAt: b.completedAt, completedClueIds: [], hintsUsed: 0, releaseDateScore: 5 } as CrosswordProgress;
    const result = dailyChallenge(date, { backword: b, crossword: c, anagram: a, midword: m, puzzle: null });
    expect(result.games.map(g => g.state)).toEqual(['finished', 'notStarted', 'finished', 'finished']);
    expect(result.points).toBe(5);
    expect(dailyChallenge('2026-11-11', { backword: b, crossword: c, anagram: a, midword: m, puzzle: null }).games.every(g => g.state === 'notStarted')).toBe(true);
  });
});

it('celebrates only a newly finished local attempt for the same day and account', () => {
  const snapshot = dailyChallenge(date, { ...empty, backword: { date, guesses: ['A'], outcome: 'won', completedAt: '2026-11-10T12:00:01Z' } as BackwordProgress });
  snapshot.games.forEach(g => { g.state = 'finished'; });
  snapshot.complete = true;
  const attempt = { context: 'guest:2026-11-10', game: 'backword' as const, started: Date.parse('2026-11-10T12:00:00Z'), wasFinished: false };
  expect(shouldCelebrate(snapshot, attempt.context, attempt)).toBe(true);
  expect(shouldCelebrate(snapshot, 'other:2026-11-10', attempt)).toBe(false);
  expect(shouldCelebrate(snapshot, attempt.context, { ...attempt, wasFinished: true })).toBe(false);
  expect(shouldCelebrate(snapshot, attempt.context, { ...attempt, started: attempt.started + 2000 })).toBe(false);
  expect(shouldCelebrate(snapshot, attempt.context, null)).toBe(false);
});
