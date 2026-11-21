import type { CSSProperties } from "react";
import { dailyGameNames, maximumPointsPerDailyGame } from "./dailyChallenge";

export function DailyIntervlsLineup() {
  return <ul className="daily-celebration__rows daily-intervls-lineup">
    {Object.entries(dailyGameNames).map(([game, name], index) => (
      <li className={`daily-celebration__row daily-${game}`} key={game} style={{ "--index": index } as CSSProperties}>
        {game === "midword" ? <span className="daily-celebration__midword-logo"><img alt={name} src="/brand/midword-logo.png" /></span>
          : game === "backword" ? <img alt={name} src="/brand/backword-logo.png" />
          : <strong>{name.toUpperCase()}</strong>}
        <span className="daily-intervls-lineup__example">
          <span aria-hidden="true" className="daily-marker"><span /></span>
          <span className="daily-intervls-lineup__points">
            <span className="sr-only">Up to {maximumPointsPerDailyGame} points</span>
            <span aria-hidden="true" className="daily-game-score"><b>{maximumPointsPerDailyGame}</b> / {maximumPointsPerDailyGame}</span>
          </span>
        </span>
      </li>
    ))}
  </ul>;
}
