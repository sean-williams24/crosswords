import { localDateString } from "../backword/date";
import { formatProfileDate } from "../profile/profileRating";
import type { MidwordStats } from "./engine";

export function MidwordRatingBar({ score }: { score: number }) {
  const percentage = Math.max(0, Math.min(100, score / 70 * 100));
  return <section aria-label={`${score} of 70 Midword points`} className="midword-rating-section">
    <div className="midword-rating"><span style={{ width: `${percentage}%` }} /><i aria-hidden="true" style={{ left: `${percentage}%` }} /></div>
    <strong>{score}/70</strong>
  </section>;
}

export function MidwordStatistics({ stats }: { stats: MidwordStats }) {
  return <>
    <section aria-label="Midword statistics summary" className="midword-summary">
      <div><strong>{stats.currentStreak}</strong><small>Current streak</small></div>
      <div><strong>{stats.totalSolved}</strong><small>Total solved</small></div>
      <div><strong>{stats.bestStreak}</strong><small>Best streak</small></div>
    </section>
    <section className="midword-distribution"><h3>Guess distribution</h3>
      {stats.guessDistribution.map((count, index) => <div aria-label={`${index + 1} guesses: ${count} solves`} key={index}>
        <span>{index + 1}</span><div><i style={{ width: `${count / Math.max(1, ...stats.guessDistribution) * 100}%` }} /></div><strong>{count}</strong>
      </div>)}
    </section>
    <section className="midword-history"><h3>Last 14 days</h3>
      <table><thead><tr><th>Date</th><th>Guesses</th><th>Score</th></tr></thead>
        <tbody>{stats.rows.map((row) => <tr key={row.date}>
          <td><time dateTime={row.date}>{formatProfileDate(row.date)}</time>
            {row.date === localDateString() ? <small>TODAY</small> : null}
            {row.outcome !== "unplayed" ? <small>{row.outcome === "inProgress" ? "IN PROGRESS" : row.outcome.toUpperCase()}</small> : null}</td>
          <td>{row.guessCount ?? "–"}</td><td><strong className={`midword-score-chip${row.score ? " is-earned" : ""}`}>{row.score}</strong></td>
        </tr>)}</tbody>
      </table>
    </section>
  </>;
}
