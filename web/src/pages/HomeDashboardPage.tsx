import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { BackwordLogo } from "../features/backword/components/BackwordLogo";
import { GameMenu } from "../features/backword/components/GameMenu";
import { backwordDashboardStatus } from "../features/home/backwordStatus";
import { DailyGameCard } from "../features/home/DailyGameCard";
import { WeeklyCrosswordModal } from "../features/home/WeeklyCrosswordModal";
import { WordOfTheDayCard } from "../features/wotd/components/WordOfTheDayCard";
import { Footer } from "../components/Footer";
import { CrosswordComingSoonPage } from "./CrosswordComingSoonPage";

type HomeDashboardPageProps = {
  showCrosswordPlaceholder?: boolean;
};

const newCrosswordStatus = { label: "New", tone: "new" } as const;

function formattedToday() {
  return new Intl.DateTimeFormat("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric"
  }).format(new Date());
}

export function HomeDashboardPage({ showCrosswordPlaceholder = false }: HomeDashboardPageProps) {
  const [showWeeklyModal, setShowWeeklyModal] = useState(false);
  const backwordStatus = useMemo(() => backwordDashboardStatus(), []);

  if (showCrosswordPlaceholder) {
    return <CrosswordComingSoonPage />;
  }

  return (
    <main className="home-dashboard">
      <header className="home-dashboard__header">
        <GameMenu />
        <Link aria-label="Backword home" to="/home">
          <BackwordLogo large />
        </Link>
      </header>

      <section className="home-dashboard__content" aria-labelledby="daily-games-title">
        <div className="home-dashboard__heading">
          <h1 id="daily-games-title">Daily Games</h1>
          <p>{formattedToday()}</p>
        </div>

        <div className="home-dashboard__daily-cards">
          <DailyGameCard
            className="home-game-card--backword"
            destination="/"
            status={backwordStatus}
            title="Backword"
          >
            <img alt="Backword" className="home-game-card__logo" src="/brand/backword-logo.png" />
          </DailyGameCard>
          <DailyGameCard
            className="home-game-card--crossword"
            description="9×9"
            destination="/crossword"
            status={newCrosswordStatus}
            title="Quick Crossword"
          />
        </div>

        <WordOfTheDayCard />

        <section className="weekly-card-section" aria-labelledby="weekly-games-title">
          <div>
            <h2 id="weekly-games-title">Weekly Games</h2>
            <p>Refreshes every Sunday</p>
          </div>
          <button className="weekly-card" onClick={() => setShowWeeklyModal(true)} type="button">
            <span className="weekly-card__crown" aria-hidden="true">♛</span>
            <span>PRO CROSSWORD</span>
            <small>13×13</small>
          </button>
        </section>
      </section>

      <Footer />

      {showWeeklyModal ? <WeeklyCrosswordModal onClose={() => setShowWeeklyModal(false)} /> : null}
    </main>
  );
}
