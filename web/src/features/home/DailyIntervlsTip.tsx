export function DailyIntervlsTip({ openGuide, dismiss }: { openGuide: () => void; dismiss: () => void }) {
  return (
    <aside aria-label="Your Daily Intervls guide" className="daily-intervls-tip">
      <div>
        <strong>Your Daily Intervls guide</strong>
        <p>See how to finish your daily games and build your rating.</p>
        <button onClick={openGuide} type="button">View guide</button>
      </div>
      <button aria-label="Dismiss Daily Intervls tip" className="daily-intervls-tip__close" onClick={dismiss} type="button">×</button>
    </aside>
  );
}
