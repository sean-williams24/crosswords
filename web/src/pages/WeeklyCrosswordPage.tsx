import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { Footer } from "../components/Footer";
import { GameMenu } from "../features/backword/components/GameMenu";
import { localWeekStartString } from "../features/backword/date";
import {
  activeClue,
  adjacentClue,
  crosswordScore,
  deleteLetter,
  deriveWeeklyCrosswordStats,
  enterLetter,
  firstWhiteSelection,
  navigateToClue,
  selectCell,
  toggleDirection,
  toggleHint
} from "../features/crossword/engine";
import { CrosswordConfigurationError, createCrosswordRepository } from "../features/crossword/repository";
import { createCrosswordStorage } from "../features/crossword/storage";
import type { CrosswordClue, CrosswordProgress, CrosswordPuzzle, CrosswordSelection } from "../features/crossword/types";
import { CrosswordClueList } from "../features/crossword/components/CrosswordClueList";
import { CrosswordCompletion } from "../features/crossword/components/CrosswordCompletion";
import { CrosswordGrid } from "../features/crossword/components/CrosswordGrid";
import { CrosswordKeyboard } from "../features/crossword/components/CrosswordKeyboard";
import { CrosswordStats } from "../features/crossword/components/CrosswordStats";
import { useAuth } from "../features/auth/AuthProvider";
import { WeeklyCrosswordModal } from "../features/home/WeeklyCrosswordModal";
import { crosswordCloudRecord, migrateProgress, queueAndDebounce, refreshAccountProgress } from "../features/sync/progressSync";

type Sheet = "clues" | "completion" | "stats" | null;

export function WeeklyCrosswordPage() {
  const navigate = useNavigate();
  const { entitlement, entitlementReady, ready, user } = useAuth();
  const storage = useMemo(() => createCrosswordStorage(window.localStorage, {
    kind: "weekly",
    userId: user?.id,
    onProgressSaved: (progress) => {
      if (user) queueAndDebounce(user.id, crosswordCloudRecord(progress, "weekly"));
    }
  }), [user?.id]);
  const [weekDate, setWeekDate] = useState(() => localWeekStartString());
  const [puzzle, setPuzzle] = useState<CrosswordPuzzle | null>(null);
  const [progress, setProgress] = useState<CrosswordProgress | null>(null);
  const [selection, setSelection] = useState<CrosswordSelection | null>(null);
  const [settings] = useState(() => storage.loadSettings());
  const [sheet, setSheet] = useState<Sheet>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [usingCache, setUsingCache] = useState(false);
  const [syncError, setSyncError] = useState("");
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [clueDragStart, setClueDragStart] = useState<number | null>(null);
  const [showHint, setShowHint] = useState(false);
  const skipClueToggle = useRef(false);

  const loadPuzzle = useCallback(async (requestedWeek: string) => {
    setLoading(true);
    setError("");
    setUsingCache(false);
    const cached = storage.loadCachedPuzzle(requestedWeek);
    try {
      const fetched = await createCrosswordRepository().getCurrentWeekly(requestedWeek);
      storage.cachePuzzle(fetched);
      setPuzzle(fetched);
      setProgress(storage.loadProgress(fetched));
      setSelection(firstWhiteSelection(fetched));
    } catch (loadError) {
      if (cached) {
        setPuzzle(cached);
        setProgress(storage.loadProgress(cached));
        setSelection(firstWhiteSelection(cached));
        setUsingCache(true);
      } else {
        setPuzzle(null);
        setProgress(null);
        setSelection(null);
        setError(loadError instanceof CrosswordConfigurationError
          ? loadError.message
          : "This week’s Pro Crossword could not be loaded. Check your connection and try again.");
      }
    } finally {
      setLoading(false);
    }
  }, [storage]);

  useEffect(() => {
    if (ready && entitlementReady && user && entitlement?.isPro) void loadPuzzle(weekDate);
  }, [entitlement?.isPro, entitlementReady, loadPuzzle, ready, user?.id, weekDate]);

  useEffect(() => {
    if (!user) return;
    void migrateProgress(
      user.id,
      "weekly_crossword",
      [],
      storage.loadAllProgress().map((record) => crosswordCloudRecord(record, "weekly")),
      (record) => storage.replaceProgress(record.payload),
      () => undefined
    ).then(() => {
      setSyncError("");
      if (puzzle) setProgress(storage.loadProgress(puzzle));
    }).catch(() => setSyncError("Your saved progress will sync when the connection is restored."));
  }, [puzzle, storage, user?.id]);

  useEffect(() => {
    if (!user) return;
    const refreshFromCloud = () => {
      void refreshAccountProgress(
        user.id,
        "weekly_crossword",
        storage.loadAllProgress().map((record) => crosswordCloudRecord(record, "weekly")),
        (record) => storage.replaceProgress(record.payload)
      ).then(() => {
        setSyncError("");
        if (puzzle) setProgress(storage.loadProgress(puzzle));
      }).catch(() => setSyncError("Your saved progress will sync when the connection is restored."));
    };
    const refreshWhenVisible = () => { if (document.visibilityState === "visible") refreshFromCloud(); };
    window.addEventListener("focus", refreshFromCloud);
    window.addEventListener("online", refreshFromCloud);
    document.addEventListener("visibilitychange", refreshWhenVisible);
    return () => {
      window.removeEventListener("focus", refreshFromCloud);
      window.removeEventListener("online", refreshFromCloud);
      document.removeEventListener("visibilitychange", refreshWhenVisible);
    };
  }, [puzzle, storage, user?.id]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      const currentWeek = localWeekStartString();
      if (currentWeek !== weekDate) {
        setWeekDate(currentWeek);
        setSheet(null);
        setShowHint(false);
      }
    }, 30_000);
    return () => window.clearInterval(timer);
  }, [weekDate]);

  const currentClue = puzzle && selection ? activeClue(puzzle, selection) : null;
  const stats = useMemo(() => deriveWeeklyCrosswordStats(storage.loadAllProgress()), [progress, storage]);
  const persist = useCallback((updated: CrosswordProgress, updatedSelection?: CrosswordSelection) => {
    storage.saveProgress(updated);
    setProgress(updated);
    if (updatedSelection) setSelection(updatedSelection);
  }, [storage]);

  const handleLetter = useCallback((letter: string) => {
    if (!puzzle || !progress || !selection) return;
    const result = enterLetter(progress, puzzle, selection, letter, settings.correctHighlight, new Date(), "weekly");
    persist(result.progress, result.selection);
    if (progress.completedAt === null && result.progress.completedAt !== null) window.setTimeout(() => setSheet("completion"), 180);
  }, [persist, progress, puzzle, selection, settings.correctHighlight]);

  const handleDelete = useCallback(() => {
    if (!puzzle || !progress || !selection) return;
    const result = deleteLetter(progress, puzzle, selection, settings.correctHighlight, new Date(), "weekly");
    persist(result.progress, result.selection);
  }, [persist, progress, puzzle, selection, settings.correctHighlight]);

  const moveClue = useCallback((step: 1 | -1) => {
    if (!puzzle || !progress || !selection) return;
    const clue = adjacentClue(puzzle, selection, step);
    if (clue) {
      setSelection(navigateToClue(progress, clue));
      setShowHint(false);
    }
  }, [progress, puzzle, selection]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (sheet || isMenuOpen || event.metaKey || event.ctrlKey || event.altKey) return;
      if (/^[a-zA-Z]$/.test(event.key)) { event.preventDefault(); handleLetter(event.key); }
      else if (event.key === "Backspace") { event.preventDefault(); handleDelete(); }
      else if (event.key === "Enter") { event.preventDefault(); moveClue(1); }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [handleDelete, handleLetter, isMenuOpen, moveClue, sheet]);

  if (!ready || (user && !entitlementReady)) return <StatusPanel title="Checking Pro access…" />;
  if (!user) return <Navigate replace state={{ returnTo: "/weekly-crossword" }} to="/sign-in" />;
  if (!entitlement?.isPro) return <div className="bw-page"><WeeklyCrosswordModal onClose={() => navigate("/")} /><Footer /></div>;

  const liveScore = puzzle && progress ? crosswordScore(progress.completedClueIds.length, puzzle.clues.length, progress.hintsUsed) : 0;
  const clueText = showHint && currentClue ? currentClue.hint : currentClue?.text;

  return (
    <div className="bw-page cw-page cw-page--weekly">
      <div className="bw-shell">
        <header className="bw-game-header bw-game-header--offset">
          <GameMenu isOpen={isMenuOpen} onClose={() => setIsMenuOpen(false)} onOpen={() => setIsMenuOpen(true)} />
          <h1 className="cw-header-title">PRO CROSSWORD</h1>
          <nav aria-label="Crossword actions" className="bw-game-actions--top">
            <button aria-label={currentClue && showHint ? "Show clue" : "Show hint"} className="cw-hint-action" disabled={!currentClue || progress?.completedAt !== null} onClick={() => {
              if (!puzzle || !progress || !currentClue) return;
              if (progress.hintedClueIds.includes(currentClue.id)) setShowHint((visible) => !visible);
              else { persist(toggleHint(progress, puzzle, currentClue), selection ?? undefined); setShowHint(true); }
            }} type="button">{showHint ? "Clue" : "Hint"} 💡</button>
            <button aria-label="Show clue list" className="bw-icon-button cw-clues-action" onClick={() => setSheet("clues")} type="button"><svg aria-hidden="true" className="cw-clues-action__icon" viewBox="0 0 20 20"><path d="M2 2h4v4H2zM8 2h4v4H8zM14 2h4v4h-4zM2 8h4v4H2zM8 8h4v4H8zM14 8h4v4h-4zM2 14h4v4H2zM8 14h4v4H8zM14 14h4v4h-4z" /></svg><span className="cw-clues-action__label">Clues</span></button>
            <button aria-label="Crossword stats" className="bw-icon-button" onClick={() => setSheet("stats")} type="button">🧠</button>
          </nav>
        </header>
        {loading ? <StatusPanel title="Loading this week’s Pro Crossword…" /> : null}
        {!loading && error ? <StatusPanel title={error}><button className="bw-primary-button" onClick={() => void loadPuzzle(weekDate)} type="button">Try again</button></StatusPanel> : null}
        {!loading && puzzle && progress && selection ? <>
          <main className="bw-game-main cw-game-main">
            {usingCache ? <p className="bw-offline-note">Playing saved crossword offline</p> : null}
            {syncError ? <p className="bw-offline-note">{syncError}</p> : null}
            <p className="cw-puzzle-date">{puzzle.date}</p>
            <button aria-label={`Current clue ${currentClue?.number ?? ""} ${currentClue?.direction ?? ""}: ${clueText ?? ""}`} className="cw-clue-bar" onClick={() => { if (skipClueToggle.current) { skipClueToggle.current = false; return; } setSelection((current) => current ? toggleDirection(puzzle, current) : current); setShowHint(false); }} onPointerDown={(event) => setClueDragStart(event.clientX)} onPointerUp={(event) => { if (clueDragStart === null) return; const delta = event.clientX - clueDragStart; if (delta > 50) { skipClueToggle.current = true; moveClue(-1); } if (delta < -50) { skipClueToggle.current = true; moveClue(1); } setClueDragStart(null); }} type="button"><span>{currentClue ? `${currentClue.number}${currentClue.direction === "across" ? "A" : "D"}` : ""}</span><strong>{clueText}</strong></button>
            <CrosswordGrid activeClue={currentClue} correctHighlight={settings.correctHighlight} onSelect={(row, col) => { setSelection((current) => current ? selectCell(puzzle, current, row, col) : current); setShowHint(false); }} progress={progress} puzzle={puzzle} selection={selection} />
          </main>
          <footer className="bw-game-controls cw-game-controls"><div aria-label={`${stats.rollingScore} of 10 weekly crossword points`} className="bw-game-score bw-game-score--keyboard-width"><span style={{ clipPath: `inset(0 ${100 - Math.max(1, (stats.rollingScore / 10) * 100)}% 0 0)` }} /></div><p className="cw-score-label">This week: {liveScore}/5</p><CrosswordKeyboard disabled={progress.completedAt !== null} onDelete={handleDelete} onLetter={handleLetter} /></footer>
        </> : null}
      </div>
      <Footer />
      {sheet === "clues" && puzzle && progress ? <CrosswordClueList activeClueId={currentClue?.id ?? null} onClose={() => setSheet(null)} onSelect={(clue: CrosswordClue) => { setSelection(navigateToClue(progress, clue)); setShowHint(false); setSheet(null); }} progress={progress} puzzle={puzzle} /> : null}
      {sheet === "stats" ? <CrosswordStats kind="weekly" onClose={() => setSheet(null)} stats={stats} /> : null}
      {sheet === "completion" && puzzle && progress ? <CrosswordCompletion kind="weekly" onClose={() => setSheet(null)} progress={progress} puzzle={puzzle} stats={stats} /> : null}
    </div>
  );
}

function StatusPanel({ title, children }: { title: string; children?: React.ReactNode }) {
  return <main className="bw-status-panel"><p>{title}</p>{children}</main>;
}
