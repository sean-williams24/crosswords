import { useCallback, useEffect, useMemo, useState } from "react";
import { BackwordCompletion } from "../features/backword/components/BackwordCompletion";
import { BackwordInstructions } from "../features/backword/components/BackwordInstructions";
import { BackwordKeyboard } from "../features/backword/components/BackwordKeyboard";
import { BackwordLogo } from "../features/backword/components/BackwordLogo";
import { BackwordStats } from "../features/backword/components/BackwordStats";
import { GameMenu } from "../features/backword/components/GameMenu";
import { Footer } from "../components/Footer";
import { localDateString } from "../features/backword/date";
import {
  BACKWORD_RULES_VERSION,
  MAX_GUESSES,
  connectedSuffixIndices,
  deriveStats,
  revealedIndices,
  sanitizeInput,
  submitGuess,
  unrevealedIndices
} from "../features/backword/engine";
import {
  BackwordConfigurationError,
  createBackwordRepository
} from "../features/backword/repository";
import { createBackwordStorage } from "../features/backword/storage";
import type {
  BackwordMode,
  BackwordProgress,
  BackwordSettings,
  BackwordWord
} from "../features/backword/types";

type Sheet = "instructions" | "stats" | "completion" | null;

export function BackwordPage() {
  const storage = useMemo(() => createBackwordStorage(), []);
  const [date, setDate] = useState(() => localDateString());
  const [word, setWord] = useState<BackwordWord | null>(null);
  const [progress, setProgress] = useState<BackwordProgress>(() => storage.loadProgress(date));
  const [settings, setSettings] = useState<BackwordSettings>(() => storage.loadSettings());
  const [input, setInput] = useState("");
  const [sheet, setSheet] = useState<Sheet>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [usingCache, setUsingCache] = useState(false);
  const [inputError, setInputError] = useState(false);
  const [showDetailedExplainer, setShowDetailedExplainer] = useState(false);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const loadWord = useCallback(async (requestedDate: string) => {
    setLoading(true);
    setError("");
    setUsingCache(false);
    const cached = storage.loadCachedWord(requestedDate);
    try {
      const repository = createBackwordRepository();
      const fetched = await repository.getByDate(requestedDate);
      storage.cacheWord(fetched);
      setWord(fetched);
    } catch (loadError) {
      if (cached) {
        setWord(cached);
        setUsingCache(true);
      } else {
        setWord(null);
        setError(
          loadError instanceof BackwordConfigurationError
            ? loadError.message
            : "Today's Backword could not be loaded. Check your connection and try again."
        );
      }
    } finally {
      setLoading(false);
    }
  }, [storage]);

  useEffect(() => {
    void loadWord(date);
  }, [date, loadWord]);

  useEffect(() => {
    if (!settings.hasSeenOnboarding || settings.lastSeenRulesVersion < BACKWORD_RULES_VERSION) {
      setSheet("instructions");
    }
  }, [settings.hasSeenOnboarding, settings.lastSeenRulesVersion]);

  useEffect(() => {
    if (progress.guesses.length > 0) {
      setShowDetailedExplainer(false);
      return;
    }
    const timer = window.setTimeout(() => setShowDetailedExplainer(true), 30_000);
    return () => window.clearTimeout(timer);
  }, [progress.guesses.length]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      const currentDate = localDateString();
      if (currentDate !== date) {
        setDate(currentDate);
        setProgress(storage.loadProgress(currentDate));
        setInput("");
        setSheet(null);
      }
    }, 30_000);
    return () => window.clearInterval(timer);
  }, [date, storage]);

  const revealed = useMemo(
    () => word ? revealedIndices(progress, word.word, settings.mode) : new Set<number>(),
    [progress, settings.mode, word]
  );
  const hidden = useMemo(() => unrevealedIndices(revealed), [revealed]);
  const stats = useMemo(() => deriveStats(storage.loadAllProgress()), [progress, storage]);
  const canSubmit = progress.outcome === "inProgress" && input.length === hidden.length;

  const enterLetter = useCallback((letter: string) => {
    if (progress.outcome !== "inProgress") {
      return;
    }
    setInput((current) => sanitizeInput(`${current}${letter}`, hidden.length));
  }, [hidden.length, progress.outcome]);

  const deleteLetter = useCallback(() => {
    if (progress.outcome === "inProgress") {
      setInput((current) => current.slice(0, -1));
    }
  }, [progress.outcome]);

  const handleSubmit = useCallback(() => {
    if (!word) {
      return;
    }
    const updated = submitGuess(progress, word.word, input, settings.mode);
    if (!updated) {
      setInputError(true);
      window.setTimeout(() => setInputError(false), 500);
      return;
    }
    storage.saveProgress(updated);
    setProgress(updated);
    setInput("");
    if (updated.outcome !== "inProgress") {
      window.setTimeout(() => setSheet("completion"), 180);
    }
  }, [input, progress, settings.mode, storage, word]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (sheet || isMenuOpen || event.metaKey || event.ctrlKey || event.altKey) {
        return;
      }
      if (/^[a-zA-Z]$/.test(event.key)) {
        event.preventDefault();
        enterLetter(event.key);
      } else if (event.key === "Backspace") {
        event.preventDefault();
        deleteLetter();
      } else if (event.key === "Enter") {
        event.preventDefault();
        handleSubmit();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [deleteLetter, enterLetter, handleSubmit, isMenuOpen, sheet]);

  function closeInstructions() {
    const updated = storage.markInstructionsSeen(settings);
    setSettings(updated);
    setSheet(null);
  }

  function changeMode(mode: BackwordMode) {
    const updated = { ...settings, mode };
    storage.saveSettings(updated);
    setSettings(updated);
    if (progress.outcome === "inProgress") {
      setInput("");
    }
  }

  return (
    <div className="bw-page">
      <div className="bw-shell">
        <header className="bw-game-header bw-game-header--offset">
          <GameMenu
            isOpen={isMenuOpen}
            onClose={() => setIsMenuOpen(false)}
            onOpen={() => setIsMenuOpen(true)}
          />
          <BackwordLogo large />
          <nav aria-label="Backword actions" className="bw-game-actions--top">
            <button
              aria-label="Backword stats"
              className="bw-icon-button"
              onClick={() => setSheet("stats")}
              type="button"
            >
              🧠
            </button>
            <button
              aria-label="How to Play"
              className="bw-icon-button bw-info-icon"
              onClick={() => setSheet("instructions")}
              type="button"
            >
              ⓘ
            </button>
          </nav>
        </header>

        {loading ? <StatusPanel title="Loading today’s Backword…" /> : null}
        {!loading && error ? (
          <StatusPanel title={error}>
            <button className="bw-primary-button" onClick={() => void loadWord(date)} type="button">
              Try again
            </button>
          </StatusPanel>
        ) : null}

        {!loading && word ? (
          <>
            <main className="bw-game-main">
              {usingCache ? <p className="bw-offline-note">Playing saved game offline</p> : null}
              <p className="bw-clue"><span>Clue:</span> {word.clue.toUpperCase()}</p>

              <div aria-label={`${progress.guesses.length} of ${MAX_GUESSES} guesses used`} className="bw-guess-counter">
                {Array.from({ length: MAX_GUESSES }, (_, index) => (
                  <span
                    className={
                      index < progress.guesses.length
                        ? progress.outcome === "failed"
                          ? "is-failed"
                          : progress.outcome === "won" && index === progress.guesses.length - 1
                            ? "is-won"
                            : "is-used"
                        : ""
                    }
                    key={index}
                  />
                ))}
              </div>

              <LetterRow
                answer={word.word}
                input={input}
                inputError={inputError}
                outcome={progress.outcome}
                revealed={revealed}
              />

              {progress.guesses.length ? (
                <section className="bw-guess-history">
                  <h2>Previous Guesses</h2>
                  {[...progress.guesses].reverse().map((guess, reverseIndex) => (
                    <GuessRow
                      answer={word.word}
                      guess={guess}
                      key={`${guess}-${reverseIndex}`}
                    />
                  ))}
                </section>
              ) : (
                <div className="bw-explainer-card">
                  {showDetailedExplainer ? <span aria-hidden="true">💡</span> : null}
                  <p>{showDetailedExplainer ? "If you’re stuck, guess any word to reveal letters" : "Guess the 6 letter word..."}</p>
                </div>
              )}
            </main>

            <footer className="bw-game-controls">
              {progress.guesses.length === 0 ? (
                <p className="bw-clue-help"><span>ⓘ</span> The clue is a word associated with the answer, or something connected to it</p>
              ) : null}
              <div aria-label={`${stats.rollingScore} of 70 Backword points`} className="bw-game-score bw-game-score--keyboard-width">
                <span style={{ width: `${Math.max(1, (stats.rollingScore / 70) * 100)}%` }} />
              </div>
              {canSubmit ? (
                <button className="bw-submit" onClick={handleSubmit} type="button">Submit</button>
              ) : null}
              <BackwordKeyboard
                disabled={progress.outcome !== "inProgress"}
                onDelete={deleteLetter}
                onLetter={enterLetter}
              />
            </footer>
          </>
        ) : null}
      </div>
      <Footer />

      {sheet === "instructions" ? (
        <BackwordInstructions
          mode={settings.mode}
          onClose={closeInstructions}
          onModeChange={changeMode}
          showsRulesUpdate={settings.hasSeenOnboarding && settings.lastSeenRulesVersion < BACKWORD_RULES_VERSION}
        />
      ) : null}
      {sheet === "stats" ? <BackwordStats onClose={() => setSheet(null)} stats={stats} /> : null}
      {sheet === "completion" && word ? (
        <BackwordCompletion
          onClose={() => setSheet(null)}
          progress={progress}
          stats={stats}
          word={word}
        />
      ) : null}
    </div>
  );
}

function LetterRow({
  answer,
  input,
  inputError,
  outcome,
  revealed
}: {
  answer: string;
  input: string;
  inputError: boolean;
  outcome: BackwordProgress["outcome"];
  revealed: Set<number>;
}) {
  const hidden = unrevealedIndices(revealed);
  return (
    <div className={`bw-letter-row ${inputError ? "is-shaking" : ""}`}>
      {Array.from(answer).map((answerLetter, index) => {
        const inputIndex = hidden.indexOf(index);
        const typed = inputIndex >= 0 ? input[inputIndex] : undefined;
        const isCursor = outcome === "inProgress" && inputIndex === input.length;
        const display = outcome === "won" ? answerLetter : revealed.has(index) ? answerLetter : typed;
        return (
          <span
            className={`${display ? "has-letter" : ""} ${revealed.has(index) ? "is-revealed" : ""} ${isCursor ? "is-cursor" : ""} ${outcome === "won" ? "is-won" : ""}`}
            key={index}
          >
            {display ?? "_"}
          </span>
        );
      })}
    </div>
  );
}

function GuessRow({ guess, answer }: { guess: string; answer: string }) {
  const connected = connectedSuffixIndices(guess, answer);
  return (
    <div aria-label={guess} className="bw-guess-row">
      {Array.from(guess).map((letter, index) => (
        <span className={connected.has(index) ? "is-connected" : ""} key={index}>{letter}</span>
      ))}
    </div>
  );
}

function StatusPanel({ title, children }: { title: string; children?: React.ReactNode }) {
  return (
    <main className="bw-status-panel">
      <BackwordLogo />
      <p>{title}</p>
      {children}
    </main>
  );
}
