import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import type { DashboardStatus } from "./backwordStatus";
import { DashboardStatusLabel } from "./DashboardStatusLabel";

type DailyGameCardProps = {
  children?: ReactNode;
  className: "home-game-card--backword" | "home-game-card--crossword";
  description?: string;
  destination: string;
  score?: number | null;
  streak?: number;
  status: DashboardStatus;
  title: string;
};

export function DailyGameCard({
  children,
  className,
  description,
  destination,
  score,
  streak,
  status,
  title
}: DailyGameCardProps) {
  return (
    <Link className={`home-game-card ${className}`} to={destination}>
      <div className="home-game-card__content">
        {children}
        <p className="home-game-card__title">{title}</p>
        {description ? <p className="home-game-card__description">{description}</p> : null}
        <DashboardStatusLabel status={status} />
        {score !== undefined || streak !== undefined ? (
          <div className="home-game-card__stats">
            {score !== null && score !== undefined ? <span><strong>{score}</strong> / 5</span> : <span />}
            {streak !== undefined ? <span>🔥 {streak}</span> : null}
          </div>
        ) : null}
      </div>
    </Link>
  );
}
