import { useEffect, useRef, useState, type CSSProperties } from 'react';
import type { DailySnapshot } from './dailyChallenge';
import './dailyChallenge.css';

export function DailyChallengeSummary({ snapshot, celebration }: { snapshot: DailySnapshot; celebration: number }) {
  return <span className="daily-summary" role="group" aria-label={`Today's daily challenge, ${snapshot.points} of 20 points, ${snapshot.games.filter(g => g.state === 'finished').length} of 4 games finished`}>
    <span className={snapshot.complete ? 'daily-summary__points is-complete' : 'daily-summary__points'} aria-hidden="true">TODAY - {snapshot.points}/20 PTS</span>
    <span className="daily-summary__markers">{snapshot.games.map((g, index) => <span key={`${g.game}-${celebration}`} role="img" aria-label={`${g.name}: ${g.state === 'finished' ? `Finished, ${g.won ? 'solved' : 'without a win'}` : g.state === 'inProgress' ? `In progress${g.detail ? `, ${g.detail}` : ''}` : 'Not started'}`} className={`daily-marker daily-${g.game} is-${g.state}${celebration ? ' is-celebrating' : ''}`} style={{ '--index': index } as CSSProperties}><span style={{ width: g.state === 'finished' ? '100%' : `min(${g.fraction * 100}%, calc(100% - 4px))` }} /></span>)}</span>
  </span>;
}

export function DailyChallengeCelebration({ snapshot, dismiss }: { snapshot: DailySnapshot; dismiss: () => void }) {
  const [step, setStep] = useState(() => window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 9 : 0);
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    heading.current?.focus();
    return () => { document.querySelector<HTMLAnchorElement>('.home-profile-rating-link')?.focus(); };
  }, []);
  useEffect(() => {
    if (step >= 9) return;
    const delay = step === 0 || step % 2 === 1 ? 300 : 450;
    const timer = window.setTimeout(() => setStep(step + 1), delay);
    return () => window.clearTimeout(timer);
  }, [step]);
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') dismiss();
      if (event.key === 'Tab') { event.preventDefault(); document.querySelector<HTMLButtonElement>('.daily-celebration button')?.focus(); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [dismiss]);
  return <div className="daily-celebration-backdrop" onClick={event => { if (event.target === event.currentTarget) dismiss(); }}><section className="daily-celebration" role="dialog" aria-modal="true" aria-labelledby="daily-celebration-title">
    <h2 id="daily-celebration-title" ref={heading} tabIndex={-1}>Todays Intervls Complete</h2>
    <div className="daily-celebration__rows">{snapshot.games.map((g, index) => <div key={g.game} className={`daily-celebration__row daily-${g.game} ${step >= index * 2 + 1 ? 'is-visible' : ''}`} aria-hidden={step < index * 2 + 2}>
      {g.game === 'midword' ? <span className="daily-celebration__midword-logo"><img alt={g.name} src="/brand/midword-logo.png" /></span> : g.game === 'backword' ? <img alt={g.name} src="/brand/backword-logo.png" /> : <strong>{g.name.toUpperCase()}</strong>}
      <span className={`daily-celebration__score ${step >= index * 2 + 2 ? 'is-visible' : ''}`}><b>{g.points}</b> / 5</span>
    </div>)}</div>
    <div className={`daily-celebration__total ${step >= 9 ? 'is-visible' : ''}`} aria-live="polite">{step >= 9 ? <><span>DAILY TOTAL</span><div><b>{snapshot.points}</b> / 20</div></> : null}</div>
    <button type="button" onClick={dismiss}>Continue</button>
  </section></div>;
}
