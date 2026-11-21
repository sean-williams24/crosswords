import { backwordScore } from '../backword/engine';
import type { BackwordProgress } from '../backword/types';
import { elapsedSeconds, type AnagramProgress } from '../anagram/engine';
import { elapsedSeconds as midwordElapsed, type MidwordProgress } from '../midword/engine';
import { crosswordScore } from '../crossword/engine';
import type { CrosswordProgress, CrosswordPuzzle } from '../crossword/types';

export type DailyGame = 'backword' | 'crossword' | 'anagram' | 'midword';
export const dailyGameNames = {
  backword: 'Backword',
  crossword: 'Quick Crossword',
  anagram: 'Anagram',
  midword: 'Midword'
} satisfies Record<DailyGame, string>;
export const maximumPointsPerDailyGame = 5;
export const maximumDailyPoints = Object.keys(dailyGameNames).length * maximumPointsPerDailyGame;
export type DailyItem = { game: DailyGame; name: string; state: 'notStarted' | 'inProgress' | 'finished'; won: boolean; fraction: number; detail?: string; points: number; completedAt?: string | null };
export type DailySnapshot = { games: DailyItem[]; points: number; complete: boolean };

export function dailyChallenge(date: string, data: { backword: BackwordProgress | null; crossword: CrosswordProgress | null; puzzle: CrosswordPuzzle | null; anagram: AnagramProgress | null; midword: MidwordProgress | null }, now = new Date()): DailySnapshot {
  const b = data.backword?.date === date ? data.backword : null;
  const c = data.crossword?.date === date && data.crossword.isWeekly !== true ? data.crossword : null;
  const a = data.anagram?.date === date ? data.anagram : null;
  const m = data.midword?.date === date ? data.midword : null;
  const guesses = (n: number) => Math.min(n, 4) / 5;
  const total = c && data.puzzle && data.puzzle.id === c.puzzleId && data.puzzle.date === date ? data.puzzle.clues.length : c?.totalClues ?? 0;
  const count = c?.completedClueIds.length ?? 0;
  const cFinished = Boolean(c?.completedAt || c?.gaveUpAt);
  const intervals = a ? Math.min(6, Math.floor(elapsedSeconds(a, now) / 30)) : 0;
  const games: DailyItem[] = [
    { game: 'backword', name: dailyGameNames.backword, state: b?.completedAt ? 'finished' : b?.guesses.length || b?.clueRevealed ? 'inProgress' : 'notStarted', won: b?.outcome === 'won', fraction: guesses(b?.guesses.length ?? 0), detail: b?.guesses.length ? `${b.guesses.length} of 5 guesses used` : undefined, points: b ? backwordScore(b) : 0, completedAt: b?.completedAt },
    { game: 'crossword', name: dailyGameNames.crossword, state: cFinished ? 'finished' : c ? 'inProgress' : 'notStarted', won: cFinished && !c?.gaveUpAt, fraction: total > 0 ? count / Math.max(total, count + 1) : 0, detail: total > 0 ? `${count} of ${Math.max(total, count + 1)} answers completed` : undefined, points: c ? c.gaveUpAt ? c.gaveUpScore ?? c.releaseDateScore : total > 0 ? crosswordScore(Math.min(count, total), total, c.hintsUsed) : c.releaseDateScore : 0, completedAt: c?.completedAt ?? c?.gaveUpAt },
    { game: 'anagram', name: dailyGameNames.anagram, state: a?.outcome && a.completedAt ? 'finished' : a ? 'inProgress' : 'notStarted', won: a?.outcome === 'solved', fraction: intervals / 7, detail: `${intervals} 30-second intervals elapsed`, points: a?.releaseDateScore ?? 0, completedAt: a?.completedAt },
    { game: 'midword', name: dailyGameNames.midword, state: m?.completedAt ? 'finished' : m?.startedAt || m?.guesses.length ? 'inProgress' : 'notStarted', won: m?.outcome === 'won', fraction: m?.startedAt ? Math.min(6, Math.floor(midwordElapsed(m, now) / 30)) / 7 : 0, detail: m?.startedAt ? `${Math.min(6, Math.floor(midwordElapsed(m, now) / 30))} 30-second intervals elapsed` : undefined, points: m?.releaseDateScore ?? 0, completedAt: m?.completedAt }
  ];
  return { games, points: games.reduce((sum, game) => sum + Math.max(0, Math.min(maximumPointsPerDailyGame, game.points)), 0), complete: games.every(game => game.state === 'finished') };
}

export type DailyAttempt = { context: string; game: DailyGame; started: number; wasFinished: boolean };
export function shouldCelebrate(snapshot: DailySnapshot, context: string, attempt: DailyAttempt | null): boolean {
  if (!snapshot.complete || !attempt || attempt.context !== context || attempt.wasFinished) return false;
  const result = snapshot.games.find(game => game.game === attempt.game);
  return !!result?.completedAt && Date.parse(result.completedAt) >= attempt.started;
}

/** Display-only sample matching the iOS debug preview. */
export function dailyChallengePreview(snapshot: DailySnapshot): DailySnapshot {
  const scores = [5, 4, 3, 0];
  return {
    games: snapshot.games.map((game, index) => ({ ...game, state: 'finished', won: scores[index] > 0, fraction: 1, detail: undefined, completedAt: undefined, points: scores[index] })),
    points: 12,
    complete: true
  };
}
