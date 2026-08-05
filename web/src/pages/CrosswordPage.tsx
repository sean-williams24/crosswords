import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Footer } from "../components/Footer";
import { GameMenu } from "../features/backword/components/GameMenu";
import { localDateString } from "../features/backword/date";
import {
  activeClue,
  adjacentClue,
  crosswordScore,
  deleteLetter,
  deriveCrosswordStats,
  enterLetter,
  firstWhiteSelection,
  navigateToClue,
  selectCell,
  toggleDirection
} from "../features/crossword/engine";
import { CrosswordConfigurationError, createCrosswordRepository } from "../features/crossword/repository";
import { createCrosswordStorage } from "../features/crossword/storage";
import type { CrosswordClue, CrosswordProgress, CrosswordPuzzle, CrosswordSelection } from "../features/crossword/types";
import { CrosswordClueList } from "../features/crossword/components/CrosswordClueList";
import { CrosswordCompletion } from "../features/crossword/components/CrosswordCompletion";
import { CrosswordGrid } from "../features/crossword/components/CrosswordGrid";
import { CrosswordInstructions } from "../features/crossword/components/CrosswordInstructions";
import { CrosswordKeyboard } from "../features/crossword/components/CrosswordKeyboard";
import { CrosswordStats } from "../features/crossword/components/CrosswordStats";

type Sheet = "clues" | "completion" | "instructions" | "stats" | null;

export function CrosswordPage() {
  const storage = useMemo(() => createCrosswordStorage(), []);
  const [date, setDate] = useState(() => localDateString());
  const [puzzle, setPuzzle] = useState<CrosswordPuzzle | null>(null);
  const [progress, setProgress] = useState<CrosswordProgress | null>(null);
  const [selection, setSelection] = useState<CrosswordSelection | null>(null);
  const [settings, setSettings] = useState(() => storage.loadSettings());
  const [sheet, setSheet] = useState<Sheet>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [usingCache, setUsingCache] = useState(false);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [clueDragStart, setClueDragStart] = useState<number | null>(null);
  const skipClueToggle = useRef(false);

  const loadPuzzle = useCallback(async (requestedDate: string) => {
    setLoading(true);
    setError("");
    setUsingCache(false);
    const cached = storage.loadCachedPuzzle(requestedDate);
    try {
      const fetched = await createCrosswordRepository().getByDate(requestedDate);
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
          : "Today's crossword could not be loaded. Check your connection and try again.");
      }
    } finally {
      setLoading(false);
    }
  }, [storage]);

  useEffect(() => { void loadPuzzle(date); }, [date, loadPuzzle]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      const currentDate = localDateString();
      if (currentDate !== date) {
        setDate(currentDate);
        setSheet(null);
      }
    }, 30_000);
    return () => window.clearInterval(timer);
  }, [date]);

  useEffect(() => {
    if (!loading && puzzle && !settings.hasSeenOnboarding) {
      setSheet("instructions");
    }
  }, [loading, puzzle, settings.hasSeenOnboarding]);

  const currentClue = puzzle && selection ? activeClue(puzzle, selection) : null;
  const stats = useMemo(() => deriveCrosswordStats(storage.loadAllProgress()), [progress, storage]);

  const persist = useCallback((updated: CrosswordProgress, updatedSelection: CrosswordSelection) => {
    storage.saveProgress(updated);
    setProgress(updated);
    setSelection(updatedSelection);
  }, [storage]);

  const handleLetter = useCallback((letter: string) => {
    if (!puzzle || !progress || !selection) return;
    const result = enterLetter(progress, puzzle, selection, letter, settings.correctHighlight);
    persist(result.progress, result.selection);
    if (progress.completedAt === null && result.progress.completedAt !== null) {
      window.setTimeout(() => setSheet("completion"), 180);
    }
  }, [persist, progress, puzzle, selection, settings.correctHighlight]);

  const handleDelete = useCallback(() => {
    if (!puzzle || !progress || !selection) return;
    const result = deleteLetter(progress, puzzle, selection, settings.correctHighlight);
    persist(result.progress, result.selection);
  }, [persist, progress, puzzle, selection, settings.correctHighlight]);

  const moveClue = useCallback((step: 1 | -1) => {
    if (!puzzle || !progress || !selection) return;
    const clue = adjacentClue(puzzle, selection, step);
    if (clue) setSelection(navigateToClue(progress, clue));
  }, [progress, puzzle, selection]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (sheet || isMenuOpen || event.metaKey || event.ctrlKey || event.altKey) return;
      if (/^[a-zA-Z]$/.test(event.key)) {
        event.preventDefault();
        handleLetter(event.key);
      } else if (event.key === "Backspace") {
        event.preventDefault();
        handleDelete();
      } else if (event.key === "Enter") {
        event.preventDefault();
        moveClue(1);
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [handleDelete, handleLetter, isMenuOpen, moveClue, sheet]);

  function closeInstructions() {
    const updated = { ...settings, hasSeenOnboarding: true };
    storage.saveSettings(updated);
    setSettings(updated);
    setSheet(null);
  }

  function changeCorrectHighlight(correctHighlight: boolean) {
    const updated = { ...settings, correctHighlight };
    storage.saveSettings(updated);
    setSettings(updated);
  }

  function selectClue(clue: CrosswordClue) {
    if (!progress) return;
    setSelection(navigateToClue(progress, clue));
    setSheet(null);
  }

  function handleClueSwipe(endX: number) {
    if (clueDragStart === null) return;
    const delta = endX - clueDragStart;
    if (delta > 50) {
      skipClueToggle.current = true;
      moveClue(-1);
    }
    if (delta < -50) {
      skipClueToggle.current = true;
      moveClue(1);
    }
    setClueDragStart(null);
  }

  const liveScore = puzzle && progress ? crosswordScore(progress.completedClueIds.length, puzzle.clues.length) : 0;

  return (
    <div className="bw-page cw-page">
      <div className="bw-shell">
        <header className="bw-game-header bw-game-header--offset">
          <GameMenu isOpen={isMenuOpen} onClose={() => setIsMenuOpen(false)} onOpen={() => setIsMenuOpen(true)} />
          <h1 className="cw-header-title">QUICK CROSSWORD</h1>
          <nav aria-label="Crossword actions" className="bw-game-actions--top">
            <button aria-label="Crossword stats" className="bw-icon-button" onClick={() => setSheet("stats")} type="button">🧠</button>
            <button aria-label="Show clue list" className="bw-icon-button" onClick={() => setSheet("clues")} type="button">☷</button>
            <button aria-label="How to play" className="bw-icon-button bw-info-icon" onClick={() => setSheet("instructions")} type="button">ⓘ</button>
          </nav>
        </header>
        {loading ? <StatusPanel title="Loading today’s crossword…" /> : null}
        {!loading && error ? <StatusPanel title={error}><button className="bw-primary-button" onClick={() => void loadPuzzle(date)} type="button">Try again</button></StatusPanel> : null}
        {!loading && puzzle && progress && selection ? (
          <>
            <main className="bw-game-main cw-game-main">
              {usingCache ? <p className="bw-offline-note">Playing saved crossword offline</p> : null}
              <p className="cw-puzzle-date">{puzzle.date}</p>
              <button
                aria-label={`Current clue ${currentClue?.number ?? ""} ${currentClue?.direction ?? ""}: ${currentClue?.text ?? ""}`}
                className="cw-clue-bar"
                onClick={() => {
                  if (skipClueToggle.current) {
                    skipClueToggle.current = false;
                    return;
                  }
                  setSelection((current) => current ? toggleDirection(puzzle, current) : current);
                }}
                onPointerDown={(event) => setClueDragStart(event.clientX)}
                onPointerUp={(event) => handleClueSwipe(event.clientX)}
                type="button"
              >
                <span>{currentClue ? `${currentClue.number}${currentClue.direction === "across" ? "A" : "D"}` : ""}</span>
                <strong>{currentClue?.text}</strong>
              </button>
              <CrosswordGrid activeClue={currentClue} correctHighlight={settings.correctHighlight} onSelect={(row, col) => setSelection((current) => current ? selectCell(puzzle, current, row, col) : current)} progress={progress} puzzle={puzzle} selection={selection} />
            </main>
            <footer className="bw-game-controls cw-game-controls">
              <div aria-label={`${stats.rollingScore} of 70 crossword points`} className="bw-game-score bw-game-score--keyboard-width"><span style={{ width: `${Math.max(1, (stats.rollingScore / 70) * 100)}%` }} /></div>
              <p className="cw-score-label">Today: {liveScore}/5</p>
              <CrosswordKeyboard disabled={progress.completedAt !== null} onDelete={handleDelete} onLetter={handleLetter} />
            </footer>
          </>
        ) : null}
      </div>
      <Footer />
      {sheet === "instructions" ? <CrosswordInstructions onClose={closeInstructions} onCorrectHighlightChange={changeCorrectHighlight} settings={settings} /> : null}
      {sheet === "clues" && puzzle && progress ? <CrosswordClueList activeClueId={currentClue?.id ?? null} onClose={() => setSheet(null)} onSelect={selectClue} progress={progress} puzzle={puzzle} /> : null}
      {sheet === "stats" ? <CrosswordStats onClose={() => setSheet(null)} stats={stats} /> : null}
      {sheet === "completion" && puzzle && progress ? <CrosswordCompletion onClose={() => setSheet(null)} progress={progress} puzzle={puzzle} stats={stats} /> : null}
    </div>
  );
}

function StatusPanel({ title, children }: { title: string; children?: React.ReactNode }) {
  return <main className="bw-status-panel"><p>{title}</p>{children}</main>;
}
