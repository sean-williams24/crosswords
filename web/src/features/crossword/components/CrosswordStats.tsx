import { BackwordModal } from "../../backword/components/BackwordModal";
import { formatDuration } from "../engine";
import type { WeeklyCrosswordStats } from "../engine";
import type { CrosswordKind, CrosswordStats as CrosswordStatsModel } from "../types";

type CrosswordStatsProps = {
  onClose: () => void;
  stats: CrosswordStatsModel | WeeklyCrosswordStats;
  kind?: CrosswordKind;
};

export function CrosswordStats({ onClose, stats, kind = "daily" }: CrosswordStatsProps) {
  return (
    <BackwordModal className="bw-stats-modal" onClose={onClose} title={`${kind === "weekly" ? "Weekly" : "Daily"} Crossword Stats`}>
      <div className="bw-modal-scroll bw-stats-scroll">
        <CrosswordStatsContent stats={stats} kind={kind} />
      </div>
    </BackwordModal>
  );
}

export function CrosswordStatsContent({ stats, kind = "daily" }: { stats: CrosswordStatsModel | WeeklyCrosswordStats; kind?: CrosswordKind }) {
  const weekly = kind === "weekly";
  const history = weekly ? (stats as WeeklyCrosswordStats).recentHistory : (stats as CrosswordStatsModel).history;
  const previousHistory = weekly ? (stats as WeeklyCrosswordStats).previousHistory : [];
  const maxPoints = weekly ? 10 : 70;
  return (
    <>
      <section aria-label="14 day crossword score" className="bw-rating-section">
        <div className="bw-rating-track">
          <span className="bw-rating-fill" style={ratingFillStyle(stats.rollingScore, maxPoints)} />
          <span aria-hidden="true" className="bw-rating-marker" style={ratingMarkerStyle(stats.rollingScore, maxPoints)} />
        </div>
        <strong>{stats.rollingScore}/{maxPoints}</strong>
      </section>
      <section className="bw-stat-summary">
        <Stat label="Current Streak" value={stats.currentStreak} />
        <Stat label="Total Solved" value={stats.totalSolved} />
        <Stat label="Best Streak" value={stats.longestStreak} />
        <Stat label="Average Time" value={formatDuration(stats.averageSolveTimeSeconds)} />
      </section>
      <HistorySection rows={history} title={weekly ? "LAST 14 DAYS" : "LAST 14 DAYS"} />
      {previousHistory.length ? <HistorySection rows={previousHistory} title="PREVIOUS GAMES" /> : null}
    </>
  );
}

function HistorySection({ rows, title }: { rows: CrosswordStatsModel["history"]; title: string }) {
  return (
    <section className="bw-history">
        <h3>{title}</h3>
        <div className="bw-history-table cw-history-table">
          <div className="bw-history-heading"><span>Date</span><span>Score</span><span>Time</span></div>
          {rows.map((row) => (
            <div className="bw-history-row" key={row.date}>
              <span>
                {formatDate(row.date)}
                {row.isToday ? <small className="is-today">TODAY</small> : null}
                {row.outcome === "solved" ? <small className="is-solved">SOLVED</small> : null}
              </span>
              <strong className={`bw-score-chip ${scoreChipTone(row.score)}`}>{row.score}</strong>
              <span className={`is-${row.outcome}`}>{formatDuration(row.solveTimeSeconds)}</span>
            </div>
          ))}
        </div>
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return <div><strong>{value}</strong><span>{label}</span></div>;
}

function formatDate(dateString: string): string {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" }).format(new Date(year, month - 1, day, 12));
}

function scoreChipTone(score: number): string {
  if (score === 5) return "is-perfect";
  if (score === 0) return "is-zero";
  return "";
}

function ratingFillStyle(score: number, maxPoints: number) {
  const percentage = Math.max(1, (score / maxPoints) * 100);
  return { clipPath: `inset(0 ${100 - percentage}% 0 0)` };
}

function ratingMarkerStyle(score: number, maxPoints: number) {
  return { left: `${Math.max(0, Math.min(100, (score / maxPoints) * 100))}%` };
}
