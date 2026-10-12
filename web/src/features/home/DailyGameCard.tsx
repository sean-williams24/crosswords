import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import type { DashboardStatus } from "./backwordStatus";
import { DashboardStatusLabel } from "./DashboardStatusLabel";
import { HomeGameIssueNumber } from "./HomeGameIssueNumber";

type DailyGameCardProps = {
  children?: ReactNode;
  className: "home-game-card--backword" | "home-game-card--crossword" | "home-game-card--anagram";
  description?: string;
  destination: string;
  issueNumber?: number | null;
  score?: number | null;
  streak?: number;
  status: DashboardStatus;
  title: string;
};

export function HomeGameScore({ score }: { score: number }) {
  return (
    <span className={`home-game-card__score ${score === 5 ? "is-perfect" : ""}`}>
      <strong>{score}</strong>
      <small>/ 5</small>
    </span>
  );
}

export function DailyGameCard({
  children,
  className,
  description,
  destination,
  issueNumber = null,
  score,
  streak = 0,
  status,
  title
}: DailyGameCardProps) {
  return (
    <Link aria-label={issueNumber === null ? title : `${title}, issue #${issueNumber}`} className={`home-game-card ${className}`} to={destination}>
      {streak > 0 ? <span className="home-game-card__streak" aria-label={`${streak}-day streak`}>🔥 {streak}</span> : null}
      <div className="home-game-card__identity">
        {children}
        <p className="home-game-card__title">{title}</p>
        {description ? <p className="home-game-card__description">{description}</p> : null}
      </div>
      <div className="home-game-card__details">
        {score !== undefined || streak !== undefined ? (
          <div className="home-game-card__stats">
            {score !== null && score !== undefined ? <HomeGameScore score={score} /> : null}
          </div>
        ) : null}
        <DashboardStatusLabel status={status} />
        <HomeGameIssueNumber issueNumber={issueNumber} />
      </div>
    </Link>
  );
}
