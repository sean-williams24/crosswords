import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Footer } from "../components/Footer";
import { useAuth } from "../features/auth/AuthProvider";
import { ProAccessRedirect } from "../features/pro/ProAccessRedirect";
import { isLocalDateString, localDateString } from "../features/backword/date";
import { createAnagramRepository } from "../features/anagram/repository";
import { createAnagramStorage } from "../features/anagram/storage";
import { AnagramBoard, AnagramDialog } from "../features/anagram/components";
import { AnagramHeader } from "../features/anagram/AnagramHeader";
import { anagramStats, giveUp, placeTile, reshuffle, restartTiles, revealHint, reviewAnagramPuzzle, startProgress, undoTile, type AnagramProgress, type AnagramPuzzle } from "../features/anagram/engine";
import { anagramCloudRecord, migrateProgress, queueAndDebounce, refreshAccountProgress } from "../features/sync/progressSync";
import { canMigrateGuestProgress, clearGuestMigrationOwnerIfEmpty } from "../features/sync/guestMigration";
import { useAnalytics } from "../features/analytics/AnalyticsProvider";
import { contentLoadFailed, gameCompleted, gameStarted } from "../features/analytics/events";
import { loadLocalProfileRecords } from "../features/profile/profileRecords";
import { buildPlayerProfileRating } from "../features/profile/profileRating";
import { buildAnagramShareResult } from "../features/share/puzzleResult";

export function AnagramPage() {
  const { date: routeDate } = useParams<{ date?: string }>();
  const isReview = routeDate === "review" && import.meta.env.DEV;
  const archiveDate = isLocalDateString(routeDate) ? routeDate : null;
  const [today, setToday] = useState(localDateString);
  const date = isReview ? "review" : archiveDate ?? today;
  const { ready, entitlementReady, entitlement, user } = useAuth();
  const { track } = useAnalytics();
  const storage = useMemo(() => createAnagramStorage(window.localStorage, { userId: user?.id,
    onProgressSaved: (progress) => { if (user) queueAndDebounce(user.id, anagramCloudRecord(progress)); }
  }), [user?.id]);
  const [puzzle, setPuzzle] = useState<AnagramPuzzle | null>(null);
  const [progress, setProgress] = useState<AnagramProgress | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [offline, setOffline] = useState(false);
  const [syncError, setSyncError] = useState("");
  const [dialog, setDialog] = useState<"instructions" | "hint" | "giveUp" | "stats" | "result" | null>(null);
  const [showTip, setShowTip] = useState(false);
  const [now, setNow] = useState(new Date());
  const isArchive = date < today;
  const needsPro = isArchive && !entitlement?.isPro;

  const loadPuzzle = useCallback(async () => {
    setLoading(true); setError(""); setOffline(false); setPuzzle(null); setProgress(null);
    if (isReview) {
      setPuzzle(reviewAnagramPuzzle(today));
      setLoading(false);
      return;
    }
    const cached = storage.loadCachedPuzzle(date);
    try {
      const repository = createAnagramRepository();
      try {
        const firstRelease = await repository.getFirstReleaseDate();
        if (firstRelease) storage.setFirstReleaseDate(firstRelease);
      } catch { /* A released puzzle can still load when this metadata query fails. */ }
      const next = await repository.getByDate(date);
      storage.cachePuzzle(next); setPuzzle(next); setProgress(storage.loadProgress(next));
    } catch (cause) {
      if (cached) { setPuzzle(cached); setProgress(storage.loadProgress(cached)); setOffline(true); }
      else {
        setError("Anagram could not be loaded. Check your connection and try again.");
        track(contentLoadFailed("anagram", cause instanceof Error && cause.message.includes("configuration") ? "configuration" : "network"));
      }
    } finally { setLoading(false); }
  }, [date, isReview, storage, today, track]);

  useEffect(() => { if (!needsPro) void loadPuzzle(); }, [loadPuzzle, needsPro]);
  useEffect(() => {
    const timer = window.setInterval(() => { setNow(new Date()); if (!archiveDate) setToday(localDateString()); }, 1000);
    return () => window.clearInterval(timer);
  }, [archiveDate]);
  useEffect(() => {
    if (!puzzle || !user || isReview) return;
    const guest = createAnagramStorage();
    const guestRecords = canMigrateGuestProgress(window.localStorage, user.id) ? guest.loadAllProgress().map(anagramCloudRecord) : [];
    void migrateProgress(user.id, "anagram", guestRecords, storage.loadAllProgress().map(anagramCloudRecord),
      (record) => storage.replaceProgress(record.payload),
      (record) => { guest.deleteProgress(record.content_key); clearGuestMigrationOwnerIfEmpty(window.localStorage); })
      .then(() => { setSyncError(""); setProgress(storage.loadProgress(puzzle)); })
      .catch(() => setSyncError("Your saved progress will sync when the connection is restored."));
  }, [isReview, puzzle, storage, user?.id]);
  useEffect(() => {
    if (!puzzle || !user || isReview) return;
    let refreshing = false;
    const refresh = () => {
      if (refreshing || document.visibilityState === "hidden") return;
      refreshing = true;
      void refreshAccountProgress(user.id, "anagram", storage.loadAllProgress().map(anagramCloudRecord),
        (record) => storage.replaceProgress(record.payload))
        .then(() => { setSyncError(""); setProgress(storage.loadProgress(puzzle)); })
        .catch(() => setSyncError("Your saved progress will sync when the connection is restored."))
        .finally(() => { refreshing = false; });
    };
    window.addEventListener("focus", refresh); window.addEventListener("online", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => { window.removeEventListener("focus", refresh); window.removeEventListener("online", refresh); document.removeEventListener("visibilitychange", refresh); };
  }, [isReview, puzzle, storage, user?.id]);
  useEffect(() => {
    if (!puzzle || progress || (!isReview && storage.hasSeenTip())) return;
    setShowTip(true);
    if (!isReview) storage.markTipSeen();
  }, [isReview, puzzle, progress, storage]);
  useEffect(() => {
    if (!showTip) return;
    const dismissTip = () => setShowTip(false);
    document.addEventListener("click", dismissTip);
    return () => document.removeEventListener("click", dismissTip);
  }, [showTip]);

  const stats = useMemo(() => anagramStats(storage.loadAllProgress(), now), [progress, storage, now]);
  const history = useMemo(() => storage.loadAllProgress(), [progress, storage]);
  const rating = useMemo(() => buildPlayerProfileRating(loadLocalProfileRecords(user?.id), entitlement?.isPro === true), [progress, user?.id, entitlement?.isPro]);
  const shareResult = puzzle && progress?.outcome ? buildAnagramShareResult({ puzzle, progress, stats, rating }) : null;

  function update(next: AnagramProgress) {
    if (next === progress) return;
    if (!isReview) storage.saveProgress(next);
    setProgress(next);
    if (next.outcome && !progress?.outcome) {
      if (!isReview) {
        track(gameCompleted("anagram", next.outcome, { releaseDay: next.releaseDateScore > 0,
          score: next.releaseDateScore, durationSeconds: next.elapsedSecondsAtCompletion }));
      }
      setDialog("result");
    }
  }
  function begin() {
    if (!puzzle || progress) return;
    const next = startProgress(puzzle);
    update(next);
    if (!isReview) track(gameStarted("anagram"));
    setDialog(null);
  }
  function shuffle() {
    if (!progress) return;
    const available = progress.trayOrder.filter((tile) => !progress.placedTileIDs.includes(tile));
    const order = [...available];
    for (let i = order.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
    if (order.join() === available.join() && order.length > 1) order.push(order.shift()!);
    update(reshuffle(progress, order));
  }

  if (!ready || (user && !entitlementReady)) return <main className="anagram-page">Checking Anagram access…</main>;
  if (routeDate && !archiveDate && !isReview) return <main className="anagram-page"><p>Invalid Anagram date.</p><Link to="/anagram">Today’s Anagram</Link></main>;
  if (!isReview && date > today) return <main className="anagram-page"><p>This Anagram has not been released yet.</p><Link to="/anagram">Today’s Anagram</Link></main>;
  if (needsPro) return <ProAccessRedirect feature="archive" returnTo={`/anagram/${date}`} />;

  return <div className="anagram-page">
    <AnagramHeader onDismissTip={() => setShowTip(false)} onInfo={() => { setShowTip(false); setDialog("instructions"); }} onStats={() => setDialog("stats")} showTip={showTip} />
    <main className={`anagram-main${puzzle ? ` anagram-main--${puzzle.answer.length}` : ""}`}>
      <div className="anagram-title-block">
        <h1>ANAGRAM</h1>
        <p>{isReview ? "Review puzzle" : puzzle ? `Puzzle #${puzzle.puzzleNumber}` : "Daily puzzle"}</p>
      </div>
      {loading ? <p role="status">Loading Anagram…</p> : null}
      {!loading && error ? <div role="alert"><p>{error}</p><button onClick={() => void loadPuzzle()} type="button">Try again</button></div> : null}
      {puzzle ? <>
        {offline ? <p className="anagram-note">Playing saved game offline</p> : null}
        {syncError ? <p className="anagram-note">{syncError}</p> : null}
        {!progress ? <section className="anagram-start"><div><strong>Unscramble the letters.</strong><strong>Find the word.</strong></div><p>Tap letters to build an answer. Your clock starts when you press Start and keeps running if you leave the game. Solve in under 30 seconds for five points.</p><small>{puzzle.answer.length} letters · one optional hint · no time limit</small><button className="anagram-primary" onClick={begin} type="button">Start</button></section>
          : <AnagramBoard now={now} onGiveUp={() => setDialog("giveUp")} onHint={() => setDialog("hint")}
              onPlace={(tile) => update(placeTile(progress, puzzle, tile))} onRestart={() => update(restartTiles(progress))}
              onResetReview={isReview ? () => { setProgress(null); setDialog(null); } : undefined}
              onShuffle={shuffle} onUndo={() => update(undoTile(progress))} progress={progress} puzzle={puzzle} />}
      </> : null}
    </main>
    <Footer />
    {dialog ? <AnagramDialog kind={dialog} onClose={() => setDialog(null)} onStart={begin}
      onConfirmHint={() => { if (progress && puzzle) update(revealHint(progress, puzzle)); setDialog(null); }}
      onConfirmGiveUp={() => { if (progress) update(giveUp(progress)); setDialog("result"); }}
      progress={progress} puzzle={puzzle} shareResult={shareResult} stats={stats}
      history={history} now={now} /> : null}
  </div>;
}
