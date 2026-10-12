import { Link } from "react-router-dom";
import { DashboardStatusLabel } from "../home/DashboardStatusLabel";
import { HomeGameIssueNumber } from "../home/HomeGameIssueNumber";
import { HomeGameScore } from "../home/DailyGameCard";
import { midwordStatus, type MidwordProgress } from "./engine";

export function MidwordHomeCard({ issueNumber, progress }: { issueNumber: number | null; progress: MidwordProgress }) {
  return <Link aria-label={issueNumber === null ? "Midword" : `Midword, issue #${issueNumber}`} className="home-game-card home-game-card--midword" to="/midword">
    <div className="midword-home-card__identity"><img alt="Midword" src="/brand/midword-logo-light.png" /></div>
    <div className="midword-home-card__details">
      {progress.completedAt ? <HomeGameScore score={progress.releaseDateScore} /> : null}
      <DashboardStatusLabel status={midwordStatus(progress)} />
    <HomeGameIssueNumber issueNumber={issueNumber} />
    </div>
  </Link>;
}
