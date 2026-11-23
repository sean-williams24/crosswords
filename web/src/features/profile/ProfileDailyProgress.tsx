import { useEffect, useState } from "react";
import { localDateString } from "../backword/date";
import { createBackwordStorage } from "../backword/storage";
import { createCrosswordStorage } from "../crossword/storage";
import { createAnagramStorage } from "../anagram/storage";
import { createMidwordStorage } from "../midword/storage";
import { dailyChallenge, maximumDailyPoints } from "../home/dailyChallenge";
import { DailyIntervlsLineup } from "../home/DailyIntervlsLineup";
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
      <strong>{snapshot.points} / {maximumDailyPoints} PTS</strong>
    </div>
    <p>{finished} of {snapshot.games.length} games finished</p>
    <DailyIntervlsLineup snapshot={snapshot} />
  </section>;
}
