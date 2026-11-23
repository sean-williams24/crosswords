import type { CSSProperties } from "react";
import { useTheme } from "../theme/ThemeProvider";
import { dailyGameNames, maximumPointsPerDailyGame, type DailyItem, type DailySnapshot } from "./dailyChallenge";
import "./dailyChallenge.css";
import "./dailyIntervlsLineup.css";

const guideGames = Object.entries(dailyGameNames).map(([game, name]) => ({ game, name, state: "example" } as const));

export function DailyIntervlsLineup({ snapshot }: { snapshot?: DailySnapshot }) {
  const { resolvedTheme } = useTheme();
  const backwordLogo = resolvedTheme === "light" ? "/brand/backword-logo-light.png" : "/brand/backword-logo.png";
  return <ul className={`daily-celebration__rows daily-intervls-lineup daily-intervls-lineup--${snapshot ? "profile" : "guide"}`} role="list">
    {(snapshot?.games ?? guideGames).map((row, index) => {
      const { game, name } = row;
      const progress = row.state === "example" ? undefined : row;
      const fillWidth = !progress || progress.state === "finished" ? "100%" : `min(${progress.fraction * 100}%, calc(100% - 4px))`;
      return <li className={`daily-celebration__row daily-${game}`} key={game} style={{ "--index": index } as CSSProperties}>
        {game === "midword" ? <span className="daily-celebration__midword-logo"><img alt={name} src="/brand/midword-logo.png" /></span>
          : game === "backword" ? <img alt={name} className="daily-intervls-lineup__backword-logo" src={backwordLogo} />
          : <strong>{name.toUpperCase()}</strong>}
        <span className="daily-intervls-lineup__result">
          <span aria-hidden="true" className={`daily-marker${progress ? ` is-${progress.state}` : ""}`}>
            <span style={{ width: fillWidth }} />
          </span>
          <span className="sr-only">{progress ? accessibleStatus(progress) : `Up to ${maximumPointsPerDailyGame} points`}</span>
          <span aria-hidden="true" className="daily-game-score daily-intervls-lineup__points">
            <b>{progress?.points ?? maximumPointsPerDailyGame}</b> / {maximumPointsPerDailyGame}
          </span>
        </span>
      </li>;
    })}
  </ul>;
}

function accessibleStatus(game: DailyItem): string {
  let status = "Not started";
  if (game.state === "finished") status = `Finished, ${game.won ? "solved" : "without a win"}`;
  if (game.state === "inProgress") status = game.detail ? `In progress, ${game.detail}` : "In progress";
  return `${status}, ${game.points} of ${maximumPointsPerDailyGame} points`;
}
