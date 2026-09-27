import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { BackwordLogo } from "../features/backword/components/BackwordLogo";
import { GameMenu } from "../features/backword/components/GameMenu";
import { localDateString, localWeekStartString } from "../features/backword/date";
import { createBackwordStorage } from "../features/backword/storage";
import { createAnagramStorage } from "../features/anagram/storage";
import { anagramStats } from "../features/anagram/engine";
import { AnagramHomeCard } from "../features/anagram/AnagramHomeCard";
import { backwordDashboardScore, backwordDashboardStatus } from "../features/home/backwordStatus";
import { HomeProfileRatingLink } from "../features/home/HomeProfileRatingLink";
import { crosswordDashboardStatus, weeklyCrosswordDashboardStatus } from "../features/crossword/engine";
import { createCrosswordStorage } from "../features/crossword/storage";
import { DailyGameCard, HomeGameScore } from "../features/home/DailyGameCard";
import { HomeGameIssueNumber } from "../features/home/HomeGameIssueNumber";
import { useHomeGameIssueNumbers } from "../features/home/useHomeGameIssueNumbers";
import { WordOfTheDayCard, type WordOfTheDayLoadState } from "../features/wotd/components/WordOfTheDayCard";
import { Footer } from "../components/Footer";
import { AuthButton } from "../features/auth/AuthButton";
import { useAuth } from "../features/auth/AuthProvider";
import { HomeDashboardLoadingCard } from "../features/home/HomeDashboardLoadingCard";
import { HomeArchiveLink } from "../features/home/HomeArchiveLink";
import { buildPlayerProfileRating } from "../features/profile/profileRating";
import { anagramCloudRecord, backwordCloudRecord, crosswordCloudRecord, refreshAccountProgress } from "../features/sync/progressSync";

type HomeSyncUser = { id: string; last_sign_in_at?: string };

const homeSyncFreshnessMs = 5 * 60 * 1000;
const homeSyncRequests = new Map<string, Promise<void>>();
const homeSyncStorageKey = (user: HomeSyncUser) =>
  `backword:web:home-sync:v1:${user.id}:${user.last_sign_in_at ?? "current"}`;

function homeProgressIsFresh(key: string) {
  try {
    const completedAt = Number(window.sessionStorage.getItem(key) ?? 0);
    return Number.isFinite(completedAt) && Date.now() - completedAt < homeSyncFreshnessMs;
  } catch {
    return false;
  }
}

function refreshHomeProgress(user: HomeSyncUser, key: string) {
  const existing = homeSyncRequests.get(key);
  if (existing) return existing;
  const backwordStorage = createBackwordStorage(window.localStorage, { userId: user.id });
  const anagramStorage = createAnagramStorage(window.localStorage, { userId: user.id });
  const dailyCrosswordStorage = createCrosswordStorage(window.localStorage, { userId: user.id });
  const weeklyCrosswordStorage = createCrosswordStorage(window.localStorage, { kind: "weekly", userId: user.id });

  const request = Promise.allSettled([
    refreshAccountProgress(user.id, "backword", backwordStorage.loadAllProgress().map(backwordCloudRecord),
      (record) => backwordStorage.replaceProgress(record.payload)),
    refreshAccountProgress(user.id, "anagram", anagramStorage.loadAllProgress().map(anagramCloudRecord),
      (record) => anagramStorage.replaceProgress(record.payload)),
    refreshAccountProgress(user.id, "daily_crossword", dailyCrosswordStorage.loadAllProgress().map((progress) => crosswordCloudRecord(progress)),
      (record) => dailyCrosswordStorage.replaceProgress(record.payload)),
    refreshAccountProgress(user.id, "weekly_crossword", weeklyCrosswordStorage.loadAllProgress().map((progress) => crosswordCloudRecord(progress, "weekly")),
      (record) => weeklyCrosswordStorage.replaceProgress(record.payload))
  ]).then(() => {
    try { window.sessionStorage.setItem(key, String(Date.now())); } catch { /* A later Home visit will retry. */ }
  }).finally(() => {
    homeSyncRequests.delete(key);
  });
  homeSyncRequests.set(key, request);
  return request;
}

export function HomeDashboardPage() {
  const { entitlement, ready, user } = useAuth();
  const homeSyncKey = user ? homeSyncStorageKey(user) : null;
  const [today, setToday] = useState(localDateString);
  const [syncRevision, setSyncRevision] = useState(0);
  const [syncedSessionKey, setSyncedSessionKey] = useState<string | null>(() => homeSyncKey && homeProgressIsFresh(homeSyncKey) ? homeSyncKey : null);
  useEffect(() => {
    const timer = window.setInterval(() => setToday(localDateString()), 30_000);
    return () => window.clearInterval(timer);
  }, []);
  useEffect(() => {
    if (!user) {
      setSyncedSessionKey(null);
      return;
    }
    const key = homeSyncStorageKey(user);
    if (homeProgressIsFresh(key)) {
      setSyncedSessionKey(key);
      return;
    }

    let active = true;
    void refreshHomeProgress(user, key).then(() => {
      if (active) {
        setSyncRevision((revision) => revision + 1);
        setSyncedSessionKey(key);
      }
    });

    return () => { active = false; };
  }, [homeSyncKey, user]);
  const issueNumbers = useHomeGameIssueNumbers(today);
  const [wordOfTheDayState, setWordOfTheDayState] = useState<WordOfTheDayLoadState>("loading");
  const backwordStatus = useMemo(() => backwordDashboardStatus(window.localStorage, today, user?.id), [syncRevision, today, user?.id]);
  const backwordScore = useMemo(() => backwordDashboardScore(window.localStorage, today, user?.id), [syncRevision, today, user?.id]);
  const anagramProgress = useMemo(() => {
    const storage = createAnagramStorage(window.localStorage, { userId: user?.id });
    const puzzle = storage.loadCachedPuzzle(today);
    return puzzle ? storage.loadProgress(puzzle) : null;
  }, [syncRevision, today, user?.id, issueNumbers.anagram]);
  const anagramStreak = useMemo(() => anagramStats(createAnagramStorage(window.localStorage, { userId: user?.id }).loadAllProgress()).streak, [syncRevision, today, user?.id]);
  const anagramStatus = anagramProgress?.outcome === "solved" ? { label: "Solved", tone: "solved" as const }
    : anagramProgress?.outcome === "gave_up" ? { label: "Gave up", tone: "failed" as const }
    : anagramProgress ? { label: "In Progress", tone: "progress" as const } : { label: "New", tone: "new" as const };
  const crosswordStatus = useMemo(() => {
    const storage = createCrosswordStorage(window.localStorage, { userId: user?.id });
    const now = new Date();
    return crosswordDashboardStatus(storage.loadProgressForDate(today), now, storage.loadAllProgress());
  }, [syncRevision, today, user?.id]);
  const weeklyCrosswordStatus = useMemo(() => {
    const storage = createCrosswordStorage(window.localStorage, { kind: "weekly", userId: user?.id });
    const now = new Date();
    return weeklyCrosswordDashboardStatus(storage.loadProgressForDate(localWeekStartString(now)), now, storage.loadAllProgress());
  }, [syncRevision, today, user?.id]);
  const profileRating = useMemo(() => {
    const backwordStorage = createBackwordStorage(window.localStorage, { userId: user?.id });
    const anagramStorage = createAnagramStorage(window.localStorage, { userId: user?.id });
    const dailyCrosswordStorage = createCrosswordStorage(window.localStorage, { userId: user?.id });
    const weeklyCrosswordStorage = createCrosswordStorage(window.localStorage, { kind: "weekly", userId: user?.id });
    return buildPlayerProfileRating({
      backword: backwordStorage.loadAllProgress().map(backwordCloudRecord),
      anagram: anagramStorage.loadAllProgress().map(anagramCloudRecord),
      dailyCrossword: dailyCrosswordStorage.loadAllProgress().map((progress) => crosswordCloudRecord(progress)),
      weeklyCrossword: weeklyCrosswordStorage.loadAllProgress().map((progress) => crosswordCloudRecord(progress))
    }, entitlement?.isPro === true);
  }, [entitlement?.isPro, user?.id, today, issueNumbers.firstAnagramRelease, syncRevision]);
  const isLoading = !ready || wordOfTheDayState === "loading";
  const isSyncing = Boolean(homeSyncKey && syncedSessionKey !== homeSyncKey);

  return (
    <main className="home-dashboard">
      <header className="home-dashboard__header">
        <GameMenu />
        <Link aria-label="Backword home" to="/">
          <BackwordLogo isPro={entitlement?.isPro === true} large />
        </Link>
        <div className="home-dashboard__actions">
          <AuthButton className="auth-button--menu-upgrade" />
        </div>
        <HomeProfileRatingLink fraction={profileRating.fraction} isSyncing={isSyncing} tier={profileRating.tier} />
      </header>

      <section aria-label="Games" className="home-dashboard__content">
        <div aria-busy={isLoading} className="home-dashboard__daily-layout">
          {isLoading ? <span className="home-dashboard__loading-label" role="status">Loading daily games</span> : null}
          <div className="home-dashboard__games-grid">
            {isLoading ? (
              <>
                <HomeDashboardLoadingCard variant="crossword" />
                <HomeDashboardLoadingCard variant="backword" />
                <HomeDashboardLoadingCard variant="crossword" />
                <HomeDashboardLoadingCard variant="weekly" />
              </>
            ) : (
              <>
                <div className="home-dashboard__game">
                  <DailyGameCard
                    className="home-game-card--backword"
                    destination="/backword"
                    issueNumber={issueNumbers.backword}
                    score={backwordScore}
                    status={backwordStatus}
                    title="Backword"
                  >
                    <img alt="Backword" className="home-game-card__logo" src="/brand/backword-logo.png" />
                  </DailyGameCard>
                  <HomeArchiveLink ariaLabel="Backword Archive" to="/archive?game=backword" />
                </div>
                <div className="home-dashboard__game">
                  <DailyGameCard
                    className="home-game-card--crossword"
                    description="9×9"
                    destination="/crossword"
                    issueNumber={issueNumbers.crossword}
                    score={crosswordStatus.score}
                    status={crosswordStatus}
                    streak={crosswordStatus.streak}
                    title="Quick Crossword"
                  />
                  <HomeArchiveLink ariaLabel="Quick Crossword Archive" to="/archive?game=daily" />
                </div>
                {issueNumbers.anagram !== null ? <div className="home-dashboard__game">
                  <AnagramHomeCard issueNumber={issueNumbers.anagram}
                    score={anagramProgress?.outcome ? anagramProgress.releaseDateScore : null}
                    status={anagramStatus} streak={anagramStreak} />
                  <HomeArchiveLink ariaLabel="Anagram Archive" to="/archive?game=anagram" />
                </div> : null}
                <div className="home-dashboard__game">
                  {entitlement?.isPro ? (
                    <Link aria-label={issueNumbers.weeklyCrossword === null ? "Pro Crossword" : `Pro Crossword, issue #${issueNumbers.weeklyCrossword}`} className="weekly-card" to="/weekly-crossword">
                      <span className="weekly-card__identity">
                        <span className="weekly-card__title">PRO CROSSWORD</span>
                        <small>13×13</small>
                        <HomeGameIssueNumber className="weekly-card__issue" issueNumber={issueNumbers.weeklyCrossword} />
                      </span>
                      <span className="weekly-card__details">
                        <span className="weekly-card__status"><span className={`home-status home-status--${weeklyCrosswordStatus.tone}`}>{weeklyCrosswordStatus.label}</span></span>
                        {weeklyCrosswordStatus.score !== null || weeklyCrosswordStatus.streak ? <span className="home-game-card__stats weekly-card__stats">{weeklyCrosswordStatus.score !== null ? <HomeGameScore score={weeklyCrosswordStatus.score} /> : null}{weeklyCrosswordStatus.streak ? <span className="home-game-card__streak">🔥 {weeklyCrosswordStatus.streak}</span> : null}</span> : null}
                      </span>
                    </Link>
                  ) : (
                    <Link aria-label={issueNumbers.weeklyCrossword === null ? "Pro Crossword" : `Pro Crossword, issue #${issueNumbers.weeklyCrossword}`} className="weekly-card" to="/pro?return_to=%2Fweekly-crossword">
                      <span className="weekly-card__identity">
                        <span className="weekly-card__title">PRO CROSSWORD</span>
                        <small>13×13</small>
                        <HomeGameIssueNumber className="weekly-card__issue" issueNumber={issueNumbers.weeklyCrossword} />
                      </span>
                      <span className="weekly-card__details" />
                    </Link>
                  )}
                  <HomeArchiveLink ariaLabel="Pro Crossword Archive" to="/archive?game=weekly" />
                </div>
              </>
            )}
          </div>
          {isLoading ? <HomeDashboardLoadingCard variant="word-of-the-day" /> : null}
          {wordOfTheDayState === "unavailable" && !isLoading ? (
            <section aria-label="Word of the Day unavailable" className="wotd-unavailable-card">
              <p>WORD OF THE DAY</p>
              <strong>Unavailable today</strong>
              <span>Please check back later.</span>
            </section>
          ) : null}
          <WordOfTheDayCard
            className={isLoading ? "wotd-widget--preloading" : ""}
            onLoadStateChange={setWordOfTheDayState}
          />
        </div>
      </section>

      <Footer />
    </main>
  );
}
