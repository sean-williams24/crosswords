import { Link } from "react-router-dom";
import { DashboardStatusLabel } from "../home/DashboardStatusLabel";
import { HomeGameScore } from "../home/DailyGameCard";
import type { DashboardStatus } from "../home/backwordStatus";

export function AnagramHomeCard({ issueNumber, length, status, score, streak }: {
  issueNumber: number; length: number | null; status: DashboardStatus; score: number | null; streak: number;
}) {
  return <Link aria-label={`Anagram, issue #${issueNumber}`} className="home-game-card home-game-card--anagram" to="/anagram">
    <div className="anagram-home-card__identity"><strong>ANAGRAM</strong><span>#{issueNumber}</span></div>
    <div className="anagram-home-card__details"><span>{length ? `${length} letters` : "7–9 letters"}</span>
      <DashboardStatusLabel status={status} />
      {score !== null ? <HomeGameScore score={score} /> : null}
      {streak > 0 ? <span className="home-game-card__streak">🔥 {streak}</span> : null}
    </div>
  </Link>;
}
