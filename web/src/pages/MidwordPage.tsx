import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Footer } from "../components/Footer";
import { GameSubmitButton } from "../components/GameSubmitButton";
import { useAuth } from "../features/auth/AuthProvider";
import { ProAccessRedirect } from "../features/pro/ProAccessRedirect";
import { isCompletedOnReleaseDate, isLocalDateString, localDateString } from "../features/backword/date";
import { BackwordKeyboard } from "../features/backword/components/BackwordKeyboard";
import { GameMenu } from "../features/backword/components/GameMenu";
import { createMidwordRepository } from "../features/midword/repository";
import { createMidwordStorage } from "../features/midword/storage";
import { midwordStats, submitGuess, type MidwordProgress, type MidwordPuzzle } from "../features/midword/engine";
import { validMidwordGuesses } from "../features/midword/validGuesses";
import { MidwordBoard } from "../features/midword/MidwordBoard";
import { MidwordDialog } from "../features/midword/MidwordDialog";
import { midwordCloudRecord, migrateProgress, queueAndDebounce, refreshAccountProgress, type CloudRecord } from "../features/sync/progressSync";
import { canMigrateGuestProgress, clearGuestMigrationOwnerIfEmpty } from "../features/sync/guestMigration";
import { useAnalytics } from "../features/analytics/AnalyticsProvider";
import { contentLoadFailed, gameCompleted, gameStarted } from "../features/analytics/events";
import { buildPlayerProfileRating } from "../features/profile/profileRating";
import { loadLocalProfileRecords } from "../features/profile/profileRecords";
import { buildMidwordShareResult } from "../features/share/puzzleResult";
import { PuzzleResultShare } from "../features/share/PuzzleResultShare";

export function MidwordPage() {
  const { date: routeDate } = useParams<{ date?: string }>();
  const { ready, user, entitlement, entitlementReady } = useAuth();
  const [today, setToday] = useState(localDateString);
  useEffect(() => {
    const refreshDate = () => setToday(localDateString());
    const timer = window.setInterval(refreshDate, 1000);
    window.addEventListener("focus", refreshDate);
    return () => { window.clearInterval(timer); window.removeEventListener("focus", refreshDate); };
  }, []);
  const date = routeDate ?? today;
  if (!ready || (user && !entitlementReady && date < today)) return <main className="midword-page">Checking Midword access…</main>;
  if (routeDate && !isLocalDateString(routeDate)) return <main className="midword-page"><p>Invalid Midword date.</p><Link to="/midword">Today’s Midword</Link></main>;
  if (date > today) return <main className="midword-page"><p>This Midword has not been released yet.</p><Link to="/midword">Today’s Midword</Link></main>;
  if (date < today && !entitlement?.isPro) return <ProAccessRedirect feature="archive" returnTo={`/midword/${date}`} />;
  return <MidwordGame date={date} key={`${user?.id ?? "guest"}:${date}`} />;
}

function MidwordGame({ date }: { date: string }) {
  const { user, entitlement } = useAuth();
  const { track } = useAnalytics();
  const storage = useMemo(() => createMidwordStorage(window.localStorage, { userId: user?.id,
    onProgressSaved: (progress) => { if (user) queueAndDebounce(user.id, midwordCloudRecord(progress)); }
  }), [user?.id]);
  const [puzzle, setPuzzle] = useState<MidwordPuzzle | null>(null);
  const [progress, setProgress] = useState(() => storage.loadProgress(date));
  const [input, setInput] = useState("");
  const [feedback, setFeedback] = useState<{ message: string } | null>(null);
  const [inputError, setInputError] = useState(false);
  const message = feedback?.message ?? "";
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [offline, setOffline] = useState(false);
  const [syncError, setSyncError] = useState("");
  const [retry, setRetry] = useState(0);
  const [sheet, setSheet] = useState<"instructions" | "stats" | "completion" | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [now, setNow] = useState(new Date());
  const completionPresented = useRef(false);

  useEffect(() => {
    setInputError(feedback !== null);
    if (!feedback) return;
    const shakeTimer = window.setTimeout(() => setInputError(false), 500);
    const messageTimer = window.setTimeout(() => setFeedback(null), 2_000);
    return () => {
      window.clearTimeout(shakeTimer);
      window.clearTimeout(messageTimer);
    };
  }, [feedback]);

  useEffect(() => {
    let active = true;
    setLoading(true); setError(""); setOffline(false);
    void (async () => {
      try {
        const next = await createMidwordRepository().getByDate(date);
        if (active) { storage.cachePuzzle(next); setPuzzle(next); }
      } catch (cause) {
        if (!active) return;
        const cached = storage.loadCachedPuzzle(date);
        if (cached) { setPuzzle(cached); setOffline(true); }
        else {
          setError("Midword could not be loaded. Check your connection and try again.");
          track(contentLoadFailed("midword", cause instanceof Error && cause.message.includes("configuration") ? "configuration" : "network"));
        }
      } finally { if (active) setLoading(false); }
    })();
    return () => { active = false; };
  }, [date, retry, storage, track]);

  useEffect(() => {
    if (!user) return;
    let active = true, refreshing = false;
    const guest = createMidwordStorage();
    const applyWinner = (record: CloudRecord<MidwordProgress>) => storage.replaceProgress(record.payload);
    const afterSync = () => { if (active) { setProgress(storage.loadProgress(date)); setSyncError(""); } };
    const failedSync = () => { if (active) setSyncError("Your saved progress will sync when the connection is restored."); };
    const guestRecords = canMigrateGuestProgress(window.localStorage, user.id) ? guest.loadAllProgress().map(midwordCloudRecord) : [];
    void migrateProgress(user.id, "midword", guestRecords, storage.loadAllProgress().map(midwordCloudRecord), applyWinner,
      (record) => { guest.deleteProgress(record.content_key); clearGuestMigrationOwnerIfEmpty(window.localStorage); })
      .then(afterSync).catch(failedSync);
    const refresh = () => {
      if (refreshing || document.visibilityState === "hidden") return;
      refreshing = true;
      void refreshAccountProgress(user.id, "midword", storage.loadAllProgress().map(midwordCloudRecord), applyWinner)
        .then(afterSync).catch(failedSync).finally(() => { refreshing = false; });
    };
    window.addEventListener("focus", refresh); window.addEventListener("online", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => {
      active = false; window.removeEventListener("focus", refresh); window.removeEventListener("online", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, [date, storage, user?.id]);

  useEffect(() => {
    if (loading || !puzzle || !progress.completedAt || completionPresented.current) return;
    completionPresented.current = true; setInput(""); setFeedback(null); setSheet("completion");
  }, [loading, progress.completedAt, puzzle]);
  useEffect(() => {
    if (sheet !== "completion") return;
    setNow(new Date());
    const timer = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(timer);
  }, [sheet]);

  const history = useMemo(() => storage.loadAllProgress(), [progress, storage]);
  const stats = useMemo(() => midwordStats(history, now), [history, now]);
  const rating = useMemo(() => buildPlayerProfileRating(loadLocalProfileRecords(user?.id), entitlement?.isPro === true), [progress, user?.id, entitlement?.isPro]);
  const shareResult = puzzle && progress.completedAt ? buildMidwordShareResult({ puzzle, progress, stats, rating }) : null;
  const canSubmit = !!puzzle && !progress.completedAt && input.length === puzzle.answer.length;
  const enterLetter = useCallback((letter: string) => {
    if (!puzzle || progress.completedAt || !/^[a-z]$/i.test(letter)) return;
    setInput((current) => (current + letter.toUpperCase()).slice(0, puzzle.answer.length)); setFeedback(null);
  }, [progress.completedAt, puzzle]);
  const deleteLetter = useCallback(() => {
    if (!progress.completedAt) { setInput((current) => current.slice(0, -1)); setFeedback(null); }
  }, [progress.completedAt]);
  const submit = useCallback(() => {
    if (!puzzle) return;
    const result = submitGuess(progress, puzzle, input, (word) => validMidwordGuesses.has(word));
    if (result.message) { setFeedback({ message: result.message }); navigator.vibrate?.([30, 50, 80]); }
    if (result.progress === progress) return;
    storage.saveProgress(result.progress); setProgress(result.progress); setInput(""); setFeedback(null);
    if (!progress.guesses.length) track(gameStarted("midword"));
    if (result.progress.completedAt) track(gameCompleted("midword", result.progress.outcome === "won" ? "won" : "failed", {
      releaseDay: isCompletedOnReleaseDate(date, result.progress.completedAt), score: result.progress.releaseDateScore, durationSeconds: null
    }));
  }, [date, input, progress, puzzle, storage, track]);
  useEffect(() => {
    const keyDown = (event: KeyboardEvent) => {
      if (sheet || menuOpen || loading || event.ctrlKey || event.metaKey || event.altKey
        || (event.target instanceof HTMLElement && (event.target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(event.target.tagName)))) return;
      if (/^[a-z]$/i.test(event.key)) { event.preventDefault(); enterLetter(event.key); }
      else if (event.key === "Backspace") { event.preventDefault(); deleteLetter(); }
      else if (event.key === "Enter") { event.preventDefault(); submit(); }
    };
    window.addEventListener("keydown", keyDown);
    return () => window.removeEventListener("keydown", keyDown);
  }, [deleteLetter, enterLetter, loading, menuOpen, sheet, submit]);

  return <div className="bw-page midword-page">
    <div className="bw-shell midword-shell">
      <header className="bw-game-header bw-game-header--offset midword-header">
        <GameMenu isOpen={menuOpen} onOpen={() => setMenuOpen(true)} onClose={() => setMenuOpen(false)} />
        <h1 className="bw-logo-lockup bw-logo-lockup--large"><img alt="Midword" className="bw-logo bw-logo--large" src="/brand/midword-logo.png" /></h1>
        <nav aria-label="Midword actions" className="bw-game-actions--top bw-game-actions--logo-header"><button aria-label="Midword stats" className="bw-icon-button" onClick={() => setSheet("stats")} type="button">🧠</button>
          <button aria-label="How to play Midword" className="bw-icon-button bw-info-icon" onClick={() => setSheet("instructions")} type="button">ⓘ</button></nav>
      </header>
      <main className="midword-main">
        {loading ? <p role="status">Loading Midword…</p> : error ? <div role="alert"><p>{error}</p><button className="bw-primary-button" onClick={() => setRetry((value) => value + 1)} type="button">Try again</button></div>
          : puzzle ? <>
            <p className="midword-issue">PUZZLE #{puzzle.puzzleNumber}</p>
            {offline ? <p className="midword-note">Playing saved game offline</p> : null}
            {syncError ? <p className="midword-note">{syncError}</p> : null}
            <MidwordBoard input={input} inputError={inputError} message={message} progress={progress} puzzle={puzzle} />
            {shareResult && sheet === null ? <PuzzleResultShare compact result={shareResult} showPreview={false} /> : null}
          </> : null}
      </main>
      {!loading && puzzle && !progress.completedAt ? <footer className="bw-game-controls midword-controls">
        <div aria-label={`${stats.rollingScore} of 70 Midword points`} className="bw-game-score bw-game-score--keyboard-width"><span style={{ clipPath: `inset(0 ${100 - Math.max(1, (stats.rollingScore / 70) * 100)}% 0 0)` }} /></div>
        <GameSubmitButton onSubmit={submit} visible={canSubmit} />
        <BackwordKeyboard ariaLabel="Midword keyboard" disabled={false} onDelete={deleteLetter} onLetter={enterLetter} />
      </footer> : null}
    </div>
    <Footer />
    {sheet ? <MidwordDialog kind={sheet} now={now} onClose={() => setSheet(null)} progress={progress} puzzle={puzzle} shareResult={shareResult} stats={stats} /> : null}
  </div>;
}
