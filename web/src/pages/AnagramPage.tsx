import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { TimedGameStartCard } from "../components/TimedGameStartCard";
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
  const accessReady = ready && (!user || entitlementReady);
  useEffect(() => {
    if (archiveDate || isReview) return;
    const timer = window.setInterval(() => setToday(localDateString()), 1000);
    return () => window.clearInterval(timer);
  }, [archiveDate, isReview]);

  if (accessReady) {
    if (routeDate && !archiveDate && !isReview) return <main className="anagram-page"><p>Invalid Anagram date.</p><Link to="/anagram">Today’s Anagram</Link></main>;
    if (!isReview && date > today) return <main className="anagram-page"><p>This Anagram has not been released yet.</p><Link to="/anagram">Today’s Anagram</Link></main>;
    if (date < today && !entitlement?.isPro) return <ProAccessRedirect feature="archive" returnTo={`/anagram/${date}`} />;
  }
  return <AnagramGame accessReady={accessReady} date={date} isReview={isReview}
    key={`${accessReady ? user?.id ?? "guest" : "pending"}:${date}`} />;
}

function AnagramGame({ date, isReview, accessReady }: { date: string; isReview: boolean; accessReady: boolean }) {
  const { entitlement, user } = useAuth();
  const { track } = useAnalytics();
  const storage = useMemo(() => createAnagramStorage(window.localStorage, { userId: user?.id,
    onProgressSaved: (progress) => { if (user) queueAndDebounce(user.id, anagramCloudRecord(progress)); }
  }), [user?.id]);
  const [puzzle, setPuzzle] = useState<AnagramPuzzle | null>(() => !accessReady ? null
    : isReview ? reviewAnagramPuzzle(localDateString()) : storage.loadCachedPuzzle(date));
  const [progress, setProgress] = useState<AnagramProgress | null>(() => puzzle && !isReview ? storage.loadProgress(puzzle) : null);
  const [loading, setLoading] = useState(() => !puzzle);
  const [error, setError] = useState("");
  const [offline, setOffline] = useState(false);
  const [syncError, setSyncError] = useState("");
  const [dialog, setDialog] = useState<"instructions" | "hint" | "giveUp" | "stats" | "result" | null>(null);
  const [showTip, setShowTip] = useState(false);
  const [now, setNow] = useState(new Date());
  const completionPresented = useRef(false);
  const loadGeneration = useRef(0);

  const loadPuzzle = useCallback(async () => {
    if (!accessReady || isReview) return;
    const generation = ++loadGeneration.current;
    setError(""); setOffline(false);
    const cached = storage.loadCachedPuzzle(date);
    try {
      const repository = createAnagramRepository();
      void repository.getFirstReleaseDate().then(firstRelease => {
        if (firstRelease) storage.setFirstReleaseDate(firstRelease);
      }).catch(() => { /* Optional metadata must not delay the puzzle. */ });
      const next = await repository.getByDate(date);
      if (generation !== loadGeneration.current) return;
      storage.cachePuzzle(next); setPuzzle(next); setProgress(storage.loadProgress(next));
    } catch (cause) {
      if (generation !== loadGeneration.current) return;
      if (cached) { setPuzzle(cached); setProgress(storage.loadProgress(cached)); setOffline(true); }
      else {
        setError("Anagram could not be loaded. Check your connection and try again.");
        track(contentLoadFailed("anagram", cause instanceof Error && cause.message.includes("configuration") ? "configuration" : "network"));
      }
    } finally { if (generation === loadGeneration.current) setLoading(false); }
  }, [accessReady, date, isReview, storage, track]);

  useEffect(() => {
    void loadPuzzle();
    return () => { loadGeneration.current++; };
  }, [loadPuzzle]);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(timer);
  }, []);
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
    if (loading || !puzzle || !progress?.outcome || completionPresented.current) return;
    completionPresented.current = true;
    setShowTip(false);
    setDialog("result");
  }, [loading, puzzle, progress?.outcome]);
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
    if (!accessReady || !puzzle || progress) return;
    const next = startProgress(puzzle);
    update(next);
    if (!isReview) track(gameStarted("anagram"));
    setDialog(null);
  }
  function shuffle() {
    if (!progress || !puzzle) return;
    const available = progress.trayOrder.filter((tile) => !progress.placedTileIDs.includes(tile));
    const order = [...available];
    for (let i = order.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
    if (order.join() === available.join() && order.length > 1) order.push(order.shift()!);
    update(reshuffle(progress, puzzle, order));
  }

  return <div className="anagram-page">
    <AnagramHeader onGiveUp={progress && !progress.completedAt ? () => setDialog("giveUp") : undefined} onDismissTip={() => setShowTip(false)} onInfo={() => { setShowTip(false); setDialog("instructions"); }} onStats={() => setDialog("stats")} showTip={showTip} statsDisabled={!accessReady} />
    <main className={`anagram-main${!progress && !error ? " timed-game-start-layout" : ""}${puzzle ? ` anagram-main--${puzzle.answer.length}` : ""}`}>
      <div className="anagram-title-block">
        <h1>ANAGRAM</h1>
        <p>{isReview ? "Review puzzle" : puzzle ? `Puzzle #${puzzle.puzzleNumber}` : "\u00a0"}</p>
      </div>
      {!loading && error ? <div role="alert"><p>{error}</p><button onClick={() => void loadPuzzle()} type="button">Try again</button></div> : null}
      {!progress && !error ? <div className="timed-game-start-body"><TimedGameStartCard game="anagram" loading={!accessReady || !puzzle}
        headings={["Unscramble the letters.", "Find the word."]}
        explanation="Tap letters to build an answer. Your clock starts when you press Start and keeps running if you leave the game. Solve in under 30 seconds for five points."
        detail={`${puzzle ? `${puzzle.answer.length} letters · ` : ""}one optional hint · no time limit`} onStart={begin} /></div> : null}
      {puzzle ? <>
        {offline ? <p className="anagram-note">Playing saved game offline</p> : null}
        {syncError ? <p className="anagram-note">{syncError}</p> : null}
        {progress ? <AnagramBoard now={now} onHint={() => setDialog("hint")}
              onPlace={(tile) => update(placeTile(progress, puzzle, tile))} onRestart={() => update(restartTiles(progress))}
              onResetReview={isReview ? () => { completionPresented.current = false; setProgress(null); setDialog(null); } : undefined}
              onShuffle={shuffle} onUndo={() => update(undoTile(progress))} progress={progress} puzzle={puzzle}
              shareResult={dialog === null ? shareResult : null} /> : null}
      </> : null}
    </main>
    <Footer />
    {dialog ? <AnagramDialog kind={dialog} onClose={() => setDialog(null)}
      onConfirmHint={() => { if (progress && puzzle) update(revealHint(progress, puzzle)); setDialog(null); }}
      onConfirmGiveUp={() => { if (progress) update(giveUp(progress)); setDialog("result"); }}
      progress={progress} puzzle={puzzle} shareResult={shareResult} stats={stats}
      history={history} now={now} /> : null}
  </div>;
}
