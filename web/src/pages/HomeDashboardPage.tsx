import { useEffect, useMemo, useRef, useState, type MouseEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { BrandLogo } from "../features/brand/BrandLogo";
import { GameMenu } from "../features/backword/components/GameMenu";
import { localDateString, localWeekStartString } from "../features/backword/date";
import { deriveStats } from "../features/backword/engine";
import { midwordStats } from "../features/midword/engine";
import { createBackwordStorage } from "../features/backword/storage";
import { createAnagramStorage } from "../features/anagram/storage";
import { anagramStats } from "../features/anagram/engine";
import { AnagramHomeCard } from "../features/anagram/AnagramHomeCard";
import { createMidwordStorage } from "../features/midword/storage";
import { MidwordHomeCard } from "../features/midword/MidwordHomeCard";
import { backwordDashboardScore, backwordDashboardStatus } from "../features/home/backwordStatus";
import { HomeProfileRatingLink } from "../features/home/HomeProfileRatingLink";
import { crosswordDashboardStatus, weeklyCrosswordDashboardStatus } from "../features/crossword/engine";
import { createCrosswordStorage } from "../features/crossword/storage";
import { DailyGameCard, HomeGameScore } from "../features/home/DailyGameCard";
import { HomeGameStreak } from "../features/home/HomeGameStreak";
import { HomeGameIssueNumber } from "../features/home/HomeGameIssueNumber";
import { useHomeGameIssueNumbers } from "../features/home/useHomeGameIssueNumbers";
import { WordOfTheDayCard, type WordOfTheDayLoadState } from "../features/wotd/components/WordOfTheDayCard";
import { Footer } from "../components/Footer";
import { AuthButton } from "../features/auth/AuthButton";
import { useAuth } from "../features/auth/AuthProvider";
import { HomeDashboardLoadingCard } from "../features/home/HomeDashboardLoadingCard";
import { HomeArchiveCard } from "../features/home/HomeArchiveCard";
import { buildPlayerProfileRating } from "../features/profile/profileRating";
import { anagramCloudRecord, midwordCloudRecord, backwordCloudRecord, crosswordCloudRecord, refreshAccountProgress } from "../features/sync/progressSync";

import { dailyChallenge, dailyChallengePreview, shouldCelebrate, type DailyAttempt, type DailyGame, type DailySnapshot } from "../features/home/dailyChallenge";
import { DailyChallengeSummary, DailyChallengeCelebration } from "../features/home/DailyChallengeViews";
import { DailyIntervlsGuide } from "../features/home/DailyIntervlsGuide";
import { useDailyIntervlsOnboarding } from "../features/home/useDailyIntervlsOnboarding";

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
  const midwordStorage = createMidwordStorage(window.localStorage, { userId: user.id });
  const dailyCrosswordStorage = createCrosswordStorage(window.localStorage, { userId: user.id });
  const weeklyCrosswordStorage = createCrosswordStorage(window.localStorage, { kind: "weekly", userId: user.id });

  const request = Promise.allSettled([
    refreshAccountProgress(user.id, "backword", backwordStorage.loadAllProgress().map(backwordCloudRecord),
      (record) => backwordStorage.replaceProgress(record.payload)),
    refreshAccountProgress(user.id, "anagram", anagramStorage.loadAllProgress().map(anagramCloudRecord),
      (record) => anagramStorage.replaceProgress(record.payload)),
    refreshAccountProgress(user.id, "midword", midwordStorage.loadAllProgress().map(midwordCloudRecord),
      (record) => midwordStorage.replaceProgress(record.payload)),
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
  const navigate = useNavigate();
  const { entitlement, ready, user } = useAuth();
  const homeSyncKey = user ? homeSyncStorageKey(user) : null;
  const [today, setToday] = useState(localDateString);
  const [syncRevision, setSyncRevision] = useState(0);
  const [clock, setClock] = useState(Date.now);
  const [celebration, setCelebration] = useState<DailySnapshot | null>(null);
  const [celebrationId, setCelebrationId] = useState(0);
  const [syncedSessionKey, setSyncedSessionKey] = useState<string | null>(() => homeSyncKey && homeProgressIsFresh(homeSyncKey) ? homeSyncKey : null);
  useEffect(() => {
    const timer = window.setInterval(() => (setToday(localDateString()), setClock(Date.now())), 1_000);
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
  const isLoading = !ready || wordOfTheDayState === "loading";
  const onboarding = useDailyIntervlsOnboarding();
  const ratingLink = useRef<HTMLAnchorElement>(null);
  const onboardingStep = ready ? onboarding.pendingStep : null;
  const showsGuide = onboardingStep !== null;
  const backwordStatus = useMemo(() => backwordDashboardStatus(window.localStorage, today, user?.id), [syncRevision, today, user?.id]);
  const backwordStreak = useMemo(() => deriveStats(createBackwordStorage(window.localStorage, { userId: user?.id }).loadAllProgress()).currentStreak, [syncRevision, today, user?.id]);
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
  const midwordProgress = useMemo(() => createMidwordStorage(window.localStorage, { userId: user?.id }).loadProgress(today), [syncRevision, today, user?.id]);
  const midwordStreak = useMemo(() => midwordStats(createMidwordStorage(window.localStorage, { userId: user?.id }).loadAllProgress()).currentStreak, [syncRevision, today, user?.id]);
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
      midword: createMidwordStorage(window.localStorage, { userId: user?.id }).loadAllProgress().map(midwordCloudRecord),
      dailyCrossword: dailyCrosswordStorage.loadAllProgress().map((progress) => crosswordCloudRecord(progress)),
      weeklyCrossword: weeklyCrosswordStorage.loadAllProgress().map((progress) => crosswordCloudRecord(progress))
    }, entitlement?.isPro === true);
  }, [entitlement?.isPro, user?.id, today, issueNumbers.firstAnagramRelease, syncRevision]);
  const daily = useMemo(() => {
    const crossword = createCrosswordStorage(window.localStorage, { userId: user?.id });
    return dailyChallenge(today, {
      backword: createBackwordStorage(window.localStorage, { userId: user?.id }).loadProgress(today),
      crossword: crossword.loadProgressForDate(today), puzzle: crossword.loadCachedPuzzle(today),
      anagram: createAnagramStorage(window.localStorage, { userId: user?.id }).loadAllProgress().find(p => p.date === today) ?? null,
      midword: midwordProgress
    }, new Date(clock));
  }, [today, user?.id, syncRevision, midwordProgress, clock]);
  const context = `${user?.id ?? "guest"}:${today}`;
  const previousContext = useRef(context);
  useEffect(() => {
    if (isLoading || showsGuide) return;
    if (previousContext.current !== context) { setCelebration(null); previousContext.current = context; }
    try {
      const key = `intervls:daily-celebrated:${context}`;
      const attempt = JSON.parse(sessionStorage.getItem("intervls:daily-attempt") ?? "null") as DailyAttempt | null;
      sessionStorage.removeItem("intervls:daily-attempt");
      if (daily.complete && !localStorage.getItem(key)) {
        const qualifies = shouldCelebrate(daily, context, attempt);
        localStorage.setItem(key, "1");
        if (qualifies) {
          setCelebration(daily);
          setCelebrationId(id => id + 1);
          window.scrollTo?.({ top: 0, behavior: "auto" });
        }
      }
    } catch { /* Storage may be unavailable in private browsing. */ }
  // Evaluate the locally saved result once on arrival or a change of account/date.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [context, isLoading, showsGuide]);
  const beginDailyGame = (event: MouseEvent<HTMLDivElement>) => {
    const link = (event.target as Element).closest('a');
    if (!link || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const game = ({ '/backword': 'backword', '/crossword': 'crossword', '/anagram': 'anagram', '/midword': 'midword' } as Record<string, DailyGame>)[new URL(link.href).pathname];
    if (!game) return;
    try { sessionStorage.setItem('intervls:daily-attempt', JSON.stringify({ context, game, started: Date.now(), wasFinished: daily.games.find(g => g.game === game)?.state === 'finished' })); } catch { /* Storage unavailable. */ }
  };
  const isSyncing = Boolean(homeSyncKey && syncedSessionKey !== homeSyncKey);

  return (
    <main className="home-dashboard">
      {onboardingStep ? (
        <DailyIntervlsGuide
          isPro={entitlement?.isPro === true}
          onboarding={{ startingStep: onboardingStep, onAdvance: onboarding.acknowledgeGameplay, onComplete: onboarding.finishOnboarding }}
          onClose={() => ratingLink.current?.focus()}
        />
      ) : null}
      {celebration && !showsGuide ? <DailyChallengeCelebration snapshot={celebration} dismiss={() => setCelebration(null)} openArchive={() => {
        setCelebration(null);
        navigate(entitlement?.isPro ? "/archive" : "/pro?return_to=%2Farchive");
      }} /> : null}
      <header className="home-dashboard__header" inert={celebration !== null}>
        <GameMenu onPreviewDailyCompletion={() => {
          setCelebration(dailyChallengePreview(daily));
          setCelebrationId(id => id + 1);
        }} />
        <Link aria-label="Intervls home" to="/">
          <BrandLogo isPro={entitlement?.isPro === true} large />
        </Link>
        <div className="home-dashboard__actions">
          <AuthButton className="auth-button--menu-upgrade" />
        </div>
        <HomeProfileRatingLink fraction={profileRating.fraction} isSyncing={isSyncing} tier={profileRating.tier} ref={ratingLink} dailySummary={<DailyChallengeSummary snapshot={daily} celebration={celebrationId} />} />
      </header>

      <section aria-label="Games" className="home-dashboard__content" inert={celebration !== null}>
        <div aria-busy={isLoading} className="home-dashboard__daily-layout">
          {isLoading ? <span className="home-dashboard__loading-label" role="status">Loading daily games</span> : null}
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
          <div className="home-dashboard__games-grid" onClickCapture={beginDailyGame}>
            {isLoading ? (
              <>
                <HomeDashboardLoadingCard variant="backword" />
                <HomeDashboardLoadingCard variant="crossword" />
                <HomeDashboardLoadingCard variant="archive" />
                <HomeDashboardLoadingCard variant="anagram" />
                <HomeDashboardLoadingCard variant="midword" />
                <HomeDashboardLoadingCard variant="weekly" />
              </>
            ) : (
              <>
                <div className={`home-dashboard__game home-dashboard__game--backword daily-backword${daily.games.find(g => g.game === "backword")?.state === "finished" ? " is-daily-finished" : ""}`}>
                  <DailyGameCard
                    className="home-game-card--backword"
                    destination="/backword"
                    issueNumber={issueNumbers.backword}
                    score={backwordScore}
                    streak={backwordStreak}
                    status={backwordStatus}
                    title="Backword"
                  >
                    <img alt="Backword" className="home-game-card__logo" src="/brand/backword-logo.png" />
                  </DailyGameCard>
                </div>
                <div className={`home-dashboard__game home-dashboard__game--crossword daily-crossword${daily.games.find(g => g.game === "crossword")?.state === "finished" ? " is-daily-finished" : ""}`}>
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
                </div>
                <div className="home-dashboard__game home-dashboard__game--archive">
                  <HomeArchiveCard />
                </div>
                <div className={`home-dashboard__game home-dashboard__game--anagram daily-anagram${daily.games.find(g => g.game === "anagram")?.state === "finished" ? " is-daily-finished" : ""}`}>
                  <AnagramHomeCard issueNumber={issueNumbers.anagram}
                    score={anagramProgress?.outcome ? anagramProgress.releaseDateScore : null}
                    status={anagramStatus} streak={anagramStreak} />
                </div>
                <div className={`home-dashboard__game home-dashboard__game--midword daily-midword${daily.games.find(g => g.game === "midword")?.state === "finished" ? " is-daily-finished" : ""}`}>
                  <MidwordHomeCard issueNumber={issueNumbers.midword ?? null} progress={midwordProgress} streak={midwordStreak} />
                </div>
                <div className="home-dashboard__game home-dashboard__game--weekly">
                  {entitlement?.isPro ? (
                    <Link aria-label={issueNumbers.weeklyCrossword === null ? "Pro Crossword" : `Pro Crossword, issue #${issueNumbers.weeklyCrossword}`} className="weekly-card" to="/weekly-crossword">
                      <HomeGameStreak streak={weeklyCrosswordStatus.streak} unit="week" />
                      <span className="weekly-card__identity">
                        <span className="weekly-card__title">PRO CROSSWORD</span>
                        <small className="weekly-card__description">13×13</small>
                      </span>
                      <span className="weekly-card__details">
                        {weeklyCrosswordStatus.score !== null ? <span className="home-game-card__stats weekly-card__stats">{weeklyCrosswordStatus.score !== null ? <HomeGameScore score={weeklyCrosswordStatus.score} /> : null}</span> : null}
                        <span className="weekly-card__status"><span className={`home-status home-status--${weeklyCrosswordStatus.tone}`}>{weeklyCrosswordStatus.label}</span></span>
                        <HomeGameIssueNumber className="weekly-card__issue" issueNumber={issueNumbers.weeklyCrossword} />
                      </span>
                    </Link>
                  ) : (
                    <Link aria-label={issueNumbers.weeklyCrossword === null ? "Pro Crossword" : `Pro Crossword, issue #${issueNumbers.weeklyCrossword}`} className="weekly-card" to="/pro?return_to=%2Fweekly-crossword">
                      <HomeGameStreak streak={weeklyCrosswordStatus.streak} unit="week" />
                      <span className="weekly-card__identity">
                        <span className="weekly-card__title">PRO CROSSWORD</span>
                        <small className="weekly-card__description">13×13</small>
                      </span>
                      <span className="weekly-card__details">
                        <span className="weekly-card__status"><span className="home-status home-status--pro-only">Pro Only</span></span>
                        <HomeGameIssueNumber className="weekly-card__issue" issueNumber={issueNumbers.weeklyCrossword} />
                      </span>
                    </Link>
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      </section>

      <div className="daily-home-footer" inert={celebration !== null}><Footer /></div>
    </main>
  );
}
