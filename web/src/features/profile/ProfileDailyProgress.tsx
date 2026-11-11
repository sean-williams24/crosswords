import { useEffect, useState } from "react";
import { localDateString } from "../backword/date";
import { createBackwordStorage } from "../backword/storage";
import { createCrosswordStorage } from "../crossword/storage";
import { createAnagramStorage } from "../anagram/storage";
import { createMidwordStorage } from "../midword/storage";
import { dailyChallenge, type DailyItem } from "../home/dailyChallenge";
import "../home/dailyChallenge.css";
import "./profileDailyProgress.css";

export function ProfileDailyProgress({ userId }: { userId?: string }) {
  const [clock, setClock] = useState(Date.now);
  useEffect(() => {
    const refresh = () => setClock(Date.now());
    const timer = window.setInterval(refresh, 30_000);
    window.addEventListener("storage", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener("storage", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, []);

  // The parent re-renders after account sync; each render reads the active namespace.
  const now = new Date(clock);
  const today = localDateString(now);
  const crossword = createCrosswordStorage(window.localStorage, { userId });
  const snapshot = dailyChallenge(today, {
    backword: createBackwordStorage(window.localStorage, { userId }).loadProgress(today),
    crossword: crossword.loadProgressForDate(today),
    puzzle: crossword.loadCachedPuzzle(today),
    anagram: createAnagramStorage(window.localStorage, { userId }).loadAllProgress().find(progress => progress.date === today) ?? null,
    midword: createMidwordStorage(window.localStorage, { userId }).loadProgress(today)
  }, now);
  const finished = snapshot.games.filter(game => game.state === "finished").length;

  return <section className="profile-daily-progress player-profile__card" aria-labelledby="profile-daily-title">
    <div className="profile-daily-progress__heading">
      <h2 id="profile-daily-title">TODAY'S INTERVLS</h2>
      <strong>{snapshot.points} / 20 PTS</strong>
    </div>
    <p>{finished} of 4 games finished</p>
    <ul>{snapshot.games.map(game => <li className="profile-daily-progress__row" key={game.game}>
      <span className="profile-daily-progress__game">
        <span aria-hidden="true" className={`daily-marker daily-${game.game} is-${game.state}`}>
          <span style={{ width: game.state === "finished" ? "100%" : `min(${game.fraction * 100}%, calc(100% - 4px))` }} />
        </span>
        <span>{game.name}</span>
      </span>
      <span className="profile-daily-progress__status" aria-label={accessibleStatus(game)}>{status(game)}</span>
    </li>)}</ul>
  </section>;
}

function status(game: DailyItem): string {
  if (game.state === "notStarted") return "Not started";
  return `${game.state === "finished" ? "Finished" : "In progress"} · ${game.points} pts`;
}

function accessibleStatus(game: DailyItem): string {
  if (game.state === "notStarted") return "Not started, 0 of 5 points";
  const result = game.state === "finished" ? `Finished, ${game.won ? "solved" : "without a win"}` : `In progress${game.detail ? `, ${game.detail}` : ""}`;
  return `${result}, ${game.points} of 5 points`;
}
