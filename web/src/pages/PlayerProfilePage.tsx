import { useCallback, useEffect, useMemo, useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../features/auth/AuthProvider";
import { GameMenu } from "../features/backword/components/GameMenu";
import { backwordCloudRecord, fetchCloudProgress, refreshAccountProgress } from "../features/sync/progressSync";
import { createBackwordStorage } from "../features/backword/storage";
import { crosswordCloudRecord } from "../features/sync/progressSync";
import { createCrosswordStorage } from "../features/crossword/storage";
import { buildPlayerProfileRating, formatProfileDate } from "../features/profile/profileRating";
import { Footer } from "../components/Footer";
import { accountActionErrorMessage } from "../features/auth/authErrorPresentation";

const ratingLevels = ["Novice", "Scribe", "Linguist", "Grandmaster", "Virtuoso"] as const;

export function PlayerProfilePage() {
  const navigate = useNavigate();
  const { ready, user, entitlement, entitlementWarning, refreshEntitlement, signOut, deleteAccount } = useAuth();
  const [records, setRecords] = useState({ backword: [], dailyCrossword: [], weeklyCrossword: [] } as {
    backword: Awaited<ReturnType<typeof fetchCloudProgress>>;
    dailyCrossword: Awaited<ReturnType<typeof fetchCloudProgress>>;
    weeklyCrossword: Awaited<ReturnType<typeof fetchCloudProgress>>;
  });
  const [isSyncing, setIsSyncing] = useState(false);
  const [syncError, setSyncError] = useState<string | null>(null);
  const [showScoring, setShowScoring] = useState(false);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const userId = user?.id;

  const refreshProfile = useCallback(async () => {
    if (!userId) return;
    setIsSyncing(true);
    setSyncError(null);
    const backwordStorage = createBackwordStorage(window.localStorage, { userId });
    const crosswordStorage = createCrosswordStorage(window.localStorage, { userId });
    try {
      await Promise.all([
        refreshEntitlement(),
        refreshAccountProgress(
          userId,
          "backword",
          backwordStorage.loadAllProgress().map(backwordCloudRecord),
          (record) => backwordStorage.replaceProgress(record.payload)
        ),
        refreshAccountProgress(
          userId,
          "daily_crossword",
          crosswordStorage.loadAllProgress().map(crosswordCloudRecord),
          (record) => crosswordStorage.replaceProgress(record.payload)
        )
      ]);
      const [backword, dailyCrossword, weeklyCrossword] = await Promise.all([
        fetchCloudProgress("backword"),
        fetchCloudProgress("daily_crossword"),
        fetchCloudProgress("weekly_crossword")
      ]);
      setRecords({ backword, dailyCrossword, weeklyCrossword });
    } catch (error) {
      console.error("Account profile refresh failed", error);
      setSyncError(accountActionErrorMessage("refresh"));
    } finally {
      setIsSyncing(false);
    }
  }, [refreshEntitlement, userId]);

  useEffect(() => {
    void refreshProfile();
  }, [refreshProfile]);

  const isPro = entitlement?.isPro ?? false;
  const rating = useMemo(() => buildPlayerProfileRating(records, isPro), [isPro, records]);

  async function handleSignOut() {
    setIsSigningOut(true);
    setSyncError(null);
    try {
      await signOut();
      navigate("/home", { replace: true });
    } catch (error) {
      console.error("Account sign-out failed", error);
      setSyncError(accountActionErrorMessage("signOut"));
    } finally {
      setIsSigningOut(false);
    }
  }

  async function removeAccount() {
    if (!window.confirm("Delete your Backword account and synced progress? This does not cancel an Apple subscription.")) return;
    setIsDeleting(true);
    setSyncError(null);
    try {
      await deleteAccount();
      navigate("/home", { replace: true });
    } catch (error) {
      console.error("Account deletion failed", error);
      setSyncError(accountActionErrorMessage("deleteAccount"));
    } finally {
      setIsDeleting(false);
    }
  }

  if (!ready) {
    return <main className="player-profile player-profile--loading">Loading your profile…</main>;
  }

  if (!user) {
    return <Navigate replace state={{ returnTo: "/player-profile" }} to="/sign-in" />;
  }

  return (
    <main className="player-profile">
      <header className="home-dashboard__header player-profile__header">
        <GameMenu />
        <h1 className="player-profile__header-title" id="player-profile-title">PLAYER PROFILE</h1>
      </header>

      <section aria-labelledby="player-profile-title" className="player-profile__content">
        <div className="player-profile__heading">
          <p>YOUR BACKWORD ACCOUNT</p>
        </div>

        <div className="player-profile__layout">
          <div className="player-profile__column player-profile__column--summary">
            <section className="player-profile__card player-profile__summary" aria-label="Player summary">
              <RatingHero fraction={rating.fraction} maxPoints={rating.maxPoints} tier={rating.tier} totalPoints={rating.totalPoints} />
              <ScoringDetails isOpen={showScoring} onToggle={() => setShowScoring((open) => !open)} />
              <RollingWindowExplanation isLoading={isSyncing} />
              <div className="player-profile__account-actions">
                <section className="player-profile__account" aria-label="Account summary">
                  <button disabled={isSyncing} onClick={() => void refreshProfile()} type="button">
                    <span>{user.email ?? "Signed in"}</span>
                    <small>{isSyncing ? "Syncing your games…" : "Progress and stats are synced — select to sync again"}</small>
                  </button>
                  <p className={isPro ? "is-active" : ""}><img alt="" className="player-profile__pro-logo" src="/brand/backword-pro.png" /><span>{isPro ? "is active for this account" : "No account-linked Pro subscription"}</span></p>
                  {syncError || entitlementWarning ? <p className="player-profile__error" role="alert">{syncError ?? entitlementWarning}</p> : null}
                </section>
                <ProfileActions className="player-profile__account-controls--desktop" isDeleting={isDeleting} isSigningOut={isSigningOut} onDelete={removeAccount} onSignOut={handleSignOut} />
              </div>
            </section>
          </div>

          <div className="player-profile__column player-profile__column--breakdown">
            <section className="player-profile__breakdown" aria-labelledby="rating-breakdown-title">
              <h2 id="rating-breakdown-title">LAST 14 DAYS</h2>
              <div className="player-profile__table-scroll">
                <div className={`player-profile__table${isPro ? " has-weekly" : ""}`}>
                  <div className="player-profile__table-heading"><span>Date</span><span>Daily</span>{isPro ? <span>Weekly</span> : null}<span>Backword</span><span>Total</span></div>
                  {rating.days.map((day, index) => (
                    <div className="player-profile__table-row" key={day.date}>
                      <span>{formatProfileDate(day.date)}{index === 0 ? <small>TODAY</small> : null}</span>
                      <ScoreChip score={day.dailyCrossword} />
                      {isPro ? day.weeklyCrossword === null ? <span className="player-profile__empty-score">—</span> : <ScoreChip score={day.weeklyCrossword} /> : null}
                      <ScoreChip score={day.backword} />
                      <strong className={day.total === 0 ? "is-zero" : ""}>{day.total}</strong>
                    </div>
                  ))}
                </div>
              </div>
            </section>
            <ProfileActions className="player-profile__account-controls--mobile" isDeleting={isDeleting} isSigningOut={isSigningOut} onDelete={removeAccount} onSignOut={handleSignOut} />
          </div>
        </div>
      </section>
      <Footer />
    </main>
  );
}

function ProfileActions({ className, isDeleting, isSigningOut, onDelete, onSignOut }: { className: string; isDeleting: boolean; isSigningOut: boolean; onDelete: () => Promise<void>; onSignOut: () => Promise<void> }) {
  return <div className={`player-profile__account-controls ${className}`}>
    <button className="player-profile__sign-out" disabled={isSigningOut} onClick={() => void onSignOut()} type="button">{isSigningOut ? "Signing Out…" : "Sign Out"}</button>
    <button className="player-profile__delete-account" disabled={isDeleting} onClick={() => void onDelete()} type="button">{isDeleting ? "Deleting Account…" : "Delete Account"}</button>
  </div>;
}

function RatingHero({ fraction, maxPoints, tier, totalPoints }: { fraction: number; maxPoints: number; tier: string; totalPoints: number }) {
  const percentage = Math.max(0, Math.min(100, fraction * 100));
  return (
    <section className={`player-profile__rating is-${tier.toLowerCase()}`} aria-label="Overall rating">
      <div className="player-profile__tier"><strong>{tier.toUpperCase()}</strong><span>{totalPoints} / {maxPoints} pts</span></div>
      <div className="player-profile__rating-track">
        <span className="player-profile__rating-fill" style={{ clipPath: `inset(0 ${100 - Math.max(1, percentage)}% 0 0)` }} />
        {[20, 50, 75, 90].map((threshold) => <span aria-hidden="true" className="player-profile__threshold" key={threshold} style={{ left: `${threshold}%` }} />)}
        <span aria-hidden="true" className="player-profile__rating-marker" style={{ left: `${percentage}%` }} />
      </div>
      <div className="player-profile__tier-scale">{ratingLevels.map((level) => <span className={level === tier ? "is-current" : ""} key={level}>{level}</span>)}</div>
    </section>
  );
}

function ScoringDetails({ isOpen, onToggle }: { isOpen: boolean; onToggle: () => void }) {
  useEffect(() => {
    if (!isOpen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") onToggle();
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [isOpen, onToggle]);

  return (
    <>
      <button aria-controls="player-profile-scoring" aria-expanded={isOpen} aria-haspopup="dialog" className="player-profile__scoring" onClick={onToggle} type="button">HOW SCORING WORKS</button>
      {isOpen ? <div className="player-profile__scoring-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onToggle(); }}>
        <section aria-labelledby="player-profile-scoring-title" aria-modal="true" className="player-profile__scoring-dialog" id="player-profile-scoring" role="dialog">
          <header><h2 id="player-profile-scoring-title">How scoring works</h2><button aria-label="Close scoring details" onClick={onToggle} type="button">×</button></header>
          <div className="player-profile__scoring-details">
        <ScoringRule rows={[["100% complete", "5 pts"], ["75–99% complete", "4 pts"], ["50–74% complete", "3 pts"], ["25–49% complete", "2 pts"], ["1–24% complete", "1 pt"], ["Missed", "0 pts"]]} title="Daily & Weekly Crossword" />
        <p>− 1 point deducted for every 3 hints used</p>
        <ScoringRule rows={[["Win in 1 guess", "5 pts"], ["Win in 2 guesses", "4 pts"], ["Win in 3 guesses", "3 pts"], ["Win in 4 guesses", "2 pts"], ["Win in 5 guesses", "1 pt"], ["Loss or missed", "0 pts"]]} title="Backword" />
          </div>
        </section>
      </div> : null}
    </>
  );
}

function RollingWindowExplanation({ isLoading }: { isLoading: boolean }) {
  return <div className="player-profile__rolling-window">
    <strong>Rolling 14-day window</strong>
    <p>Your rating reflects only the last 14 days. Skip a day and it scores 0, so play every day to keep your rating up.</p>
    {isLoading ? <div className="player-profile__stats-loading" role="status"><span aria-hidden="true" className="player-profile__stats-spinner" />Loading your 14-day stats…</div> : null}
  </div>;
}

function ScoringRule({ rows, title }: { rows: [string, string][]; title: string }) {
  return <div className="player-profile__rule"><strong>{title}</strong>{rows.map(([label, score]) => <span key={label}><span>{label}</span><b>{score}</b></span>)}</div>;
}

function ScoreChip({ score }: { score: number }) {
  return <strong className={`bw-score-chip${score === 5 ? " is-perfect" : score === 0 ? " is-zero" : ""}`}>{score}</strong>;
}
