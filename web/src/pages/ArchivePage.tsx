import { useEffect, useMemo, useState } from "react";
import { Link, Navigate, useSearchParams } from "react-router-dom";
import { AppStoreBadge } from "../components/AppStoreBadge";
import { Footer } from "../components/Footer";
import { BackwordLogo } from "../features/backword/components/BackwordLogo";
import { GameMenu } from "../features/backword/components/GameMenu";
import { createBackwordRepository } from "../features/backword/repository";
import type { BackwordRepository } from "../features/backword/repository";
import type { BackwordWord } from "../features/backword/types";
import { ArchiveEntryCard, type ArchiveGameType } from "../features/archive/ArchiveEntryCard";
import { AuthButton } from "../features/auth/AuthButton";
import { useAuth } from "../features/auth/AuthProvider";
import { createCrosswordRepository } from "../features/crossword/repository";
import type { CrosswordRepository } from "../features/crossword/repository";
import type { CrosswordPuzzle } from "../features/crossword/types";

type ArchiveItem = BackwordWord | CrosswordPuzzle;
type MonthsByType = Record<ArchiveGameType, string[]>;
type SelectedMonths = Partial<Record<ArchiveGameType, string>>;

const archiveTypes: { id: ArchiveGameType; label: string; shortLabel: string }[] = [
  { id: "backword", label: "Backword", shortLabel: "Backword" },
  { id: "daily", label: "Quick Crossword", shortLabel: "Daily" },
  { id: "weekly", label: "Pro Crossword", shortLabel: "Pro" }
];

const emptyMonths: MonthsByType = { backword: [], daily: [], weekly: [] };

function archiveTypeFromSearch(value: string | null): ArchiveGameType {
  return value === "daily" || value === "weekly" || value === "backword" ? value : "backword";
}

function displayMonth(month: string) {
  return new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric", timeZone: "UTC" })
    .format(new Date(`${month}-01T12:00:00Z`));
}

function ArchiveTabs({ activeType, onSelect, compact = false }: {
  activeType: ArchiveGameType;
  onSelect: (type: ArchiveGameType) => void;
  compact?: boolean;
}) {
  return (
    <nav aria-label="Archive game type" className={compact ? "archive-tabs archive-tabs--compact" : "archive-tabs"}>
      {archiveTypes.map((type) => (
        <button aria-pressed={activeType === type.id} className={activeType === type.id ? "is-selected" : ""} key={type.id} onClick={() => onSelect(type.id)} type="button">
          {compact ? type.shortLabel : type.label}
        </button>
      ))}
    </nav>
  );
}

export function ArchivePage() {
  const { entitlement, entitlementReady, ready, user } = useAuth();
  const [searchParams] = useSearchParams();
  const returnTo = `/archive${searchParams.size ? `?${searchParams.toString()}` : ""}`;

  if (!ready || (user && !entitlementReady)) return <main className="archive-page">Checking Pro access…</main>;
  if (!entitlement?.isPro) return <Navigate replace to={`/pro?return_to=${encodeURIComponent(returnTo)}`} />;

  return <ArchiveContent entitlement={entitlement} user={user} />;
}

function ArchiveContent({ entitlement, user }: Pick<ReturnType<typeof useAuth>, "entitlement" | "user">) {
  const [searchParams] = useSearchParams();
  const repositories = useMemo((): {
    backword: BackwordRepository | null;
    crossword: CrosswordRepository | null;
    error: string | null;
  } => {
    try {
      return { backword: createBackwordRepository(), crossword: createCrosswordRepository(), error: null };
    } catch {
      return { backword: null, crossword: null, error: "The archive needs its Supabase configuration before it can load." };
    }
  }, []);
  const [activeType, setActiveType] = useState<ArchiveGameType>(() => archiveTypeFromSearch(searchParams.get("game")));
  const [months, setMonths] = useState<MonthsByType>(emptyMonths);
  const [selectedMonths, setSelectedMonths] = useState<SelectedMonths>({});
  const [content, setContent] = useState<Record<string, ArchiveItem[]>>({});
  const [loadingMonths, setLoadingMonths] = useState(true);
  const [loadingContent, setLoadingContent] = useState<string | null>(null);
  const [errors, setErrors] = useState<Partial<Record<ArchiveGameType, string>>>({});

  useEffect(() => {
    if (!repositories.backword || !repositories.crossword) {
      setErrors({ backword: repositories.error ?? undefined, daily: repositories.error ?? undefined, weekly: repositories.error ?? undefined });
      setLoadingMonths(false);
      return;
    }
    let cancelled = false;
    void Promise.allSettled([
      repositories.backword.getArchiveMonths(),
      repositories.crossword.getArchiveMonths("daily"),
      repositories.crossword.getArchiveMonths("weekly")
    ]).then(([backword, daily, weekly]) => {
      if (cancelled) return;
      const nextMonths: MonthsByType = {
        backword: backword.status === "fulfilled" ? backword.value : [],
        daily: daily.status === "fulfilled" ? daily.value : [],
        weekly: weekly.status === "fulfilled" ? weekly.value : []
      };
      setMonths(nextMonths);
      setSelectedMonths((current) => ({
        backword: current.backword ?? nextMonths.backword[0],
        daily: current.daily ?? nextMonths.daily[0],
        weekly: current.weekly ?? nextMonths.weekly[0]
      }));
      setErrors({
        ...(backword.status === "rejected" ? { backword: "Backword history is unavailable right now." } : {}),
        ...(daily.status === "rejected" ? { daily: "Quick Crossword history is unavailable right now." } : {}),
        ...(weekly.status === "rejected" ? { weekly: "Pro Crossword history is unavailable right now." } : {})
      });
      setLoadingMonths(false);
    });
    return () => { cancelled = true; };
  }, [repositories]);

  const selectedMonth = selectedMonths[activeType] ?? null;
  const contentKey = selectedMonth ? `${activeType}:${selectedMonth}` : null;
  const selectedContent = contentKey ? content[contentKey] : undefined;

  useEffect(() => {
    if (!repositories.backword || !repositories.crossword || !selectedMonth || !contentKey || content[contentKey] !== undefined) return;
    let cancelled = false;
    setLoadingContent(contentKey);
    setErrors((current) => ({ ...current, [activeType]: undefined }));
    const request = activeType === "backword"
      ? repositories.backword.getArchiveMonth(selectedMonth)
      : repositories.crossword.getArchiveMonth(activeType === "weekly" ? "weekly" : "daily", selectedMonth);
    void request.then((items) => {
      if (!cancelled) setContent((current) => ({ ...current, [contentKey]: items }));
    }).catch(() => {
      if (!cancelled) setErrors((current) => ({ ...current, [activeType]: "This month is unavailable right now." }));
    }).finally(() => {
      if (!cancelled) setLoadingContent((current) => current === contentKey ? null : current);
    });
    return () => { cancelled = true; };
  }, [activeType, content, contentKey, repositories, selectedMonth]);

  const selectType = (type: ArchiveGameType) => setActiveType(type);
  const selectMonth = (month: string) => setSelectedMonths((current) => ({ ...current, [activeType]: month }));
  const activeLabel = archiveTypes.find((type) => type.id === activeType)?.label ?? "Archive";

  return (
    <div className="archive-page">
      <header className="home-dashboard__header archive-page__header">
        <GameMenu />
        <Link aria-label="Backword home" to="/"><BackwordLogo isPro={entitlement?.isPro === true} large /></Link>
        <div className="home-dashboard__actions"><AuthButton /><AppStoreBadge /></div>
      </header>
      <main className="archive-page__content">
        <div className="archive-page__heading"><p>PLAY PAST GAMES</p><h1>Archive</h1></div>
        <div className="archive-layout">
          <aside className="archive-sidebar">
            <ArchiveTabs activeType={activeType} onSelect={selectType} />
            <ArchiveMonthPicker currentMonth={months[activeType][0] ?? null} months={months[activeType]} onSelect={selectMonth} selectedMonth={selectedMonth} />
          </aside>
          <section aria-busy={loadingMonths || loadingContent === contentKey} aria-labelledby="archive-month-title" className="archive-results">
            <div className="archive-results__heading">
              <p>{activeLabel.toUpperCase()}</p>
              <h2 id="archive-month-title">{selectedMonth ? displayMonth(selectedMonth) : "No games yet"}</h2>
            </div>
            {loadingMonths || loadingContent === contentKey ? <p className="archive-message" role="status">Loading archive…</p> : null}
            {!loadingMonths && errors[activeType] ? <p className="archive-message archive-message--error">{errors[activeType]}</p> : null}
            {!loadingMonths && !errors[activeType] && selectedContent?.length === 0 ? <p className="archive-message">No games are available for this month.</p> : null}
            {selectedContent?.length ? <div className="archive-entry-grid">
              {selectedContent.map((item) => <ArchiveEntryCard gameType={activeType} item={item} key={item.id} userId={user?.id} />)}
            </div> : null}
            <div className="archive-mobile-months"><ArchiveMonthPicker currentMonth={months[activeType][0] ?? null} months={months[activeType]} onSelect={selectMonth} selectedMonth={selectedMonth} /></div>
          </section>
        </div>
      </main>
      <div className="archive-mobile-tabs"><ArchiveTabs activeType={activeType} compact onSelect={selectType} /></div>
      <Footer />
    </div>
  );
}

function ArchiveMonthPicker({ currentMonth, months, onSelect, selectedMonth }: { currentMonth: string | null; months: string[]; onSelect: (month: string) => void; selectedMonth: string | null }) {
  if (!months.length) return null;
  return (
    <section className="archive-month-picker" aria-label="Archive months">
      {currentMonth ? <button aria-pressed={currentMonth === selectedMonth} className={`archive-month-picker__current ${currentMonth === selectedMonth ? "is-selected" : ""}`} onClick={() => onSelect(currentMonth)} type="button">{displayMonth(currentMonth)}</button> : null}
      {months.length > 1 ? <p>EARLIER MONTHS</p> : null}
      <div>
        {months.filter((month) => month !== currentMonth).map((month) => <button aria-pressed={month === selectedMonth} className={month === selectedMonth ? "is-selected" : ""} key={month} onClick={() => onSelect(month)} type="button">{displayMonth(month)}</button>)}
      </div>
    </section>
  );
}
