import { Link } from "react-router-dom";
import { DashboardStatusLabel } from "../home/DashboardStatusLabel";
import { HomeGameIssueNumber } from "../home/HomeGameIssueNumber";
import { HomeGameScore } from "../home/DailyGameCard";
import type { DashboardStatus } from "../home/backwordStatus";

export function AnagramHomeCard({ issueNumber, status, score, streak }: {
  issueNumber: number; status: DashboardStatus; score: number | null; streak: number;
}) {
  return <Link aria-label={`Anagram, issue #${issueNumber}`} className="home-game-card home-game-card--anagram" to="/anagram">
    {streak > 0 ? <span className="home-game-card__streak">🔥 {streak}</span> : null}
    <div className="anagram-home-card__identity"><strong>ANAGRAM</strong></div>
    <div className="anagram-home-card__details">
      {score !== null ? <div className="home-game-card__stats anagram-home-card__stats">
        {score !== null ? <HomeGameScore score={score} /> : null}
      </div> : null}
      <DashboardStatusLabel status={status} />
    <HomeGameIssueNumber className="anagram-home-card__issue" issueNumber={issueNumber} />
    </div>
  </Link>;
}
