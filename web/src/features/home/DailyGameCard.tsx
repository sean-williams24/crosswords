import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import type { DashboardStatus } from "./backwordStatus";
import { DashboardStatusLabel } from "./DashboardStatusLabel";

type DailyGameCardProps = {
  children?: ReactNode;
  className: "home-game-card--backword" | "home-game-card--crossword";
  description?: string;
  destination: string;
  status: DashboardStatus;
  title: string;
};

export function DailyGameCard({
  children,
  className,
  description,
  destination,
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
      </div>
      <span className="home-game-card__cta" aria-hidden="true">Play →</span>
    </Link>
  );
}
