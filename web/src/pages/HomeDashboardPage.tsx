import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { BackwordLogo } from "../features/backword/components/BackwordLogo";
import { GameMenu } from "../features/backword/components/GameMenu";
import { localDateString } from "../features/backword/date";
import { backwordDashboardStatus } from "../features/home/backwordStatus";
import { crosswordDashboardStatus } from "../features/crossword/engine";
import { createCrosswordStorage } from "../features/crossword/storage";
import { DailyGameCard } from "../features/home/DailyGameCard";
import { WeeklyCrosswordModal } from "../features/home/WeeklyCrosswordModal";
import { WordOfTheDayCard, type WordOfTheDayLoadState } from "../features/wotd/components/WordOfTheDayCard";
import { Footer } from "../components/Footer";
import { AppStoreBadge } from "../components/AppStoreBadge";
import { AuthButton } from "../features/auth/AuthButton";
import { useAuth } from "../features/auth/AuthProvider";
import { HomeDashboardLoadingCard } from "../features/home/HomeDashboardLoadingCard";

function formattedToday() {
  return new Intl.DateTimeFormat("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric"
  }).format(new Date());
}

export function HomeDashboardPage() {
  const { entitlement, ready, user } = useAuth();
  const [showWeeklyModal, setShowWeeklyModal] = useState(false);
  const [wordOfTheDayState, setWordOfTheDayState] = useState<WordOfTheDayLoadState>("loading");
  const backwordStatus = useMemo(() => backwordDashboardStatus(window.localStorage, localDateString(), user?.id), [user?.id]);
  const crosswordStatus = useMemo(() => {
    const storage = createCrosswordStorage(window.localStorage, { userId: user?.id });
    const now = new Date();
    return crosswordDashboardStatus(storage.loadProgressForDate(localDateString(now)), now, storage.loadAllProgress());
  }, [user?.id]);
  const isLoading = !ready || wordOfTheDayState === "loading";

  return (
    <main className="home-dashboard">
      <header className="home-dashboard__header">
        <GameMenu />
        <Link aria-label="Backword home" to="/">
          <BackwordLogo isPro={entitlement?.isPro === true} large />
        </Link>
        <div className="home-dashboard__actions">
          <AuthButton />
          <AppStoreBadge />
        </div>
      </header>

      <section className="home-dashboard__content" aria-labelledby="daily-games-title">
        <div className="home-dashboard__heading">
          <h1 id="daily-games-title">Daily Games</h1>
          <p>{formattedToday()}</p>
        </div>

        <div aria-busy={isLoading} className="home-dashboard__daily-layout">
          {isLoading ? <span className="home-dashboard__loading-label" role="status">Loading daily games</span> : null}
          <div className="home-dashboard__daily-cards">
            {isLoading ? (
              <>
                <HomeDashboardLoadingCard variant="backword" />
                <HomeDashboardLoadingCard variant="crossword" />
              </>
            ) : (
              <>
                <DailyGameCard
                  className="home-game-card--backword"
                  destination="/backword"
                  status={backwordStatus}
                  title="Backword"
                >
                  <img alt="Backword" className="home-game-card__logo" src="/brand/backword-logo.png" />
                </DailyGameCard>
                <DailyGameCard
                  className="home-game-card--crossword"
                  description="9×9"
                  destination="/crossword"
                  score={crosswordStatus.score}
                  status={crosswordStatus}
                  streak={crosswordStatus.streak}
                  title="Quick Crossword"
                />
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

        <section className="weekly-card-section" aria-labelledby="weekly-games-title">
          <div>
            <h2 id="weekly-games-title">Weekly Games</h2>
            <p>Refreshes every Sunday</p>
          </div>
          {isLoading ? <HomeDashboardLoadingCard variant="weekly" /> : (
            <button className="weekly-card" onClick={() => setShowWeeklyModal(true)} type="button">
              <span className="weekly-card__crown" aria-hidden="true">♛</span>
              <span>PRO CROSSWORD</span>
              <small>13×13</small>
            </button>
          )}
        </section>
      </section>

      <Footer />

      {showWeeklyModal ? <WeeklyCrosswordModal onClose={() => setShowWeeklyModal(false)} /> : null}
    </main>
  );
}
