import type { BackwordStats as BackwordStatsModel } from "../types";
import { BackwordModal } from "./BackwordModal";

type BackwordStatsProps = {
  stats: BackwordStatsModel;
  onClose: () => void;
  highlightGuessCount?: number;
};

export function BackwordStats({
  stats,
  onClose,
  highlightGuessCount
}: BackwordStatsProps) {
  return (
    <BackwordModal className="bw-stats-modal" onClose={onClose} title="Backword Stats">
      <div className="bw-modal-scroll bw-stats-scroll">
        <StatsContent highlightGuessCount={highlightGuessCount} stats={stats} />
      </div>
    </BackwordModal>
  );
}

export function StatsContent({
  stats,
  highlightGuessCount
}: Omit<BackwordStatsProps, "onClose">) {
  const maxDistribution = Math.max(1, ...Object.values(stats.guessDistribution));
  return (
    <>
      <section aria-label="14 day Backword score" className="bw-rating-section">
        <div className="bw-rating-track">
          <span className="bw-rating-fill" style={ratingFillStyle(stats.rollingScore)} />
          <span aria-hidden="true" className="bw-rating-marker" style={ratingMarkerStyle(stats.rollingScore)} />
        </div>
        <strong>{stats.rollingScore}/70</strong>
      </section>

      <section className="bw-stat-summary">
        <Stat value={stats.currentStreak} label="Current Streak" />
        <Stat value={stats.gamesWon} label="Total Solved" />
        <Stat value={stats.longestStreak} label="Best Streak" />
        <Stat value={`${stats.winRate}%`} label="Win Rate" />
      </section>

      <section className="bw-stats-card">
        <h3>GUESS DISTRIBUTION</h3>
        {stats.gamesWon === 0 ? (
          <p className="bw-empty-stats">No wins yet — keep playing!</p>
        ) : (
          <div className="bw-distribution">
            {[1, 2, 3, 4, 5].map((guess) => {
              const count = stats.guessDistribution[guess] ?? 0;
              return (
                <div className={highlightGuessCount === guess ? "is-highlighted" : ""} key={guess}>
                  <span>{guess}</span>
                  <span className="bw-distribution-track">
                    <span
                      style={{ width: count ? `${Math.max(12, (count / maxDistribution) * 100)}%` : "0" }}
                    />
                  </span>
                  <strong>{count}</strong>
                </div>
              );
            })}
          </div>
        )}
      </section>

      <section className="bw-history">
        <h3>LAST 14 DAYS</h3>
        <div className="bw-history-table">
          <div className="bw-history-heading">
            <span>Date</span><span>Score</span><span>Guesses</span>
          </div>
          {stats.history.map((row) => (
            <div className="bw-history-row" key={row.date}>
              <span>
                {formatHistoryDate(row.date)}
                {row.isToday ? <small className="is-today">TODAY</small> : null}
                {row.outcome === "solved" ? <small className="is-solved">SOLVED</small> : null}
                {!row.isToday && row.outcome === "failed" ? <small className="is-failed">FAILED</small> : null}
              </span>
              <strong className={`bw-score-chip ${scoreChipTone(row.score)}`}>{row.score}</strong>
              <span className={`is-${row.outcome}`}>{row.guessCount ?? "–"}</span>
            </div>
          ))}
        </div>
      </section>
    </>
  );
}

function Stat({ value, label }: { value: string | number; label: string }) {
  return (
    <div>
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  );
}

function formatHistoryDate(dateString: string): string {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Intl.DateTimeFormat(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric"
  }).format(new Date(year, month - 1, day, 12));
}

function scoreChipTone(score: number): string {
  if (score === 5) return "is-perfect";
  if (score === 0) return "is-zero";
  return "";
}

function ratingFillStyle(score: number) {
  const percentage = Math.max(1, (score / 70) * 100);
  return { clipPath: `inset(0 ${100 - percentage}% 0 0)` };
}

function ratingMarkerStyle(score: number) {
  return { left: `${Math.max(0, Math.min(100, (score / 70) * 100))}%` };
}
