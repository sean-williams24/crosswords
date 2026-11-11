import { act, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { DailyChallengeCelebration, DailyChallengeSummary } from './DailyChallengeViews';
import { dailyChallenge } from './dailyChallenge';

const snapshot = dailyChallenge('2026-11-10', { backword: null, crossword: null, puzzle: null, anagram: null, midword: null });
afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals(); });
it('labels all four markers in the correct order', () => {
  render(<DailyChallengeSummary snapshot={snapshot} celebration={0} />);
  expect(screen.getAllByRole('img').map(e => e.getAttribute('aria-label'))).toEqual(['Backword: Not started', 'Quick Crossword: Not started', 'Anagram: Not started', 'Midword: Not started']);
});
it('reveals each result and total in sequence and closes on escape', () => {
  vi.useFakeTimers();
  vi.stubGlobal('matchMedia', () => ({ matches: false }));
  const dismiss = vi.fn();
  render(<DailyChallengeCelebration snapshot={snapshot} dismiss={dismiss} />);
  expect(screen.getByRole('heading')).toHaveFocus();
  expect(screen.queryByText('DAILY TOTAL')).not.toBeInTheDocument();
  act(() => vi.advanceTimersByTime(300));
  expect(screen.getByAltText('Backword').closest('.daily-celebration__row')).toHaveClass('is-visible');
  for (let i = 0; i < 8; i++) act(() => vi.advanceTimersByTime(i % 2 === 0 ? 300 : 450));
  expect(screen.getByText('DAILY TOTAL')).toBeInTheDocument();
  fireEvent.keyDown(window, { key: 'Escape' });
  expect(dismiss).toHaveBeenCalledOnce();
});
it('shows the complete result immediately with reduced motion', () => {
  vi.stubGlobal('matchMedia', () => ({ matches: true }));
  render(<DailyChallengeCelebration snapshot={snapshot} dismiss={() => {}} />);
  expect(screen.getByText('DAILY TOTAL')).toBeVisible();
  expect(screen.getAllByText('/ 5')).toHaveLength(4);
});
