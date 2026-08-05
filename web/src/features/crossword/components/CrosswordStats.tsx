import { BackwordModal } from "../../backword/components/BackwordModal";
import { formatDuration } from "../engine";
import type { CrosswordStats as CrosswordStatsModel } from "../types";

type CrosswordStatsProps = {
  onClose: () => void;
  stats: CrosswordStatsModel;
};

export function CrosswordStats({ onClose, stats }: CrosswordStatsProps) {
  return (
    <BackwordModal className="bw-stats-modal" onClose={onClose} title="Daily Crossword Stats">
      <div className="bw-modal-scroll bw-stats-scroll">
        <CrosswordStatsContent stats={stats} />
      </div>
    </BackwordModal>
  );
}

export function CrosswordStatsContent({ stats }: { stats: CrosswordStatsModel }) {
  return (
    <>
      <section aria-label="14 day crossword score" className="bw-rating-section">
        <div className="bw-rating-track"><span style={{ width: `${Math.max(1, (stats.rollingScore / 70) * 100)}%` }} /></div>
        <strong>{stats.rollingScore}/70</strong>
      </section>
      <section className="bw-stat-summary">
        <Stat label="Current Streak" value={stats.currentStreak} />
        <Stat label="Total Solved" value={stats.totalSolved} />
        <Stat label="Best Streak" value={stats.longestStreak} />
        <Stat label="Average Time" value={formatDuration(stats.averageSolveTimeSeconds)} />
      </section>
      <section className="bw-history">
        <h3>LAST 14 DAYS</h3>
        <div className="bw-history-table cw-history-table">
          <div className="bw-history-heading"><span>Date</span><span>Score</span><span>Time</span></div>
          {stats.history.map((row) => (
            <div className="bw-history-row" key={row.date}>
              <span>{formatDate(row.date)}<small className={`is-${row.outcome}`}>{row.isToday ? "TODAY" : row.outcome === "solved" ? "SOLVED" : ""}</small></span>
              <strong className="bw-score-chip">{row.score}</strong>
              <span className={`is-${row.outcome}`}>{formatDuration(row.solveTimeSeconds)}</span>
            </div>
          ))}
        </div>
      </section>
    </>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return <div><strong>{value}</strong><span>{label}</span></div>;
}

function formatDate(dateString: string): string {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" }).format(new Date(year, month - 1, day, 12));
}
