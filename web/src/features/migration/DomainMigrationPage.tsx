import { useAnalytics } from "../analytics/AnalyticsProvider";
import { domainMigration } from "../analytics/events";
import { useEffect, useRef, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useAuth } from "../auth/AuthProvider";
import { BrandLogo } from "../brand/BrandLogo";
import { brand, migrationDestination } from "../brand/brand";
import { runDomainMigration, type MigrationGameState } from "./migrationCoordinator";
import { inspectMigrationStorage, migrationGames } from "./migrationStorage";

export function DomainMigrationPage() {
  const location = useLocation();
  const { track } = useAnalytics();
  const { user, ready: authReady, signOut } = useAuth();
  const [games, setGames] = useState<MigrationGameState[]>([]);
  const [busy, setBusy] = useState(false);
  const [verified, setVerified] = useState(false);
  const [error, setError] = useState("");
  const [startFresh, setStartFresh] = useState(false);
  const [revision, setRevision] = useState(0);
  const activeUser = useRef(user?.id);
  activeUser.current = user?.id;
  const attempt = useRef(0);
  const target = location.pathname === "/move" ? new URLSearchParams(location.search).get("return_to") ?? "/" : `${location.pathname}${location.search}`;
  const destination = migrationDestination(target);
  const returnTo = `/move?return_to=${encodeURIComponent(new URL(destination).pathname + new URL(destination).search)}`;
  let inventory: ReturnType<typeof inspectMigrationStorage> | null = null;
  try { inventory = inspectMigrationStorage(localStorage); } catch { /* Show recovery instructions below. */ }
  const otherAccounts = inventory?.accountIds.some((id) => id !== user?.id) ?? false;

  useEffect(() => {
    attempt.current += 1;
    setVerified(false); setGames([]); setBusy(false); setError("");
    const invalidate = () => { setVerified(false); setRevision((value) => value + 1); };
    window.addEventListener("storage", invalidate);
    return () => { attempt.current += 1; window.removeEventListener("storage", invalidate); };
  }, [user?.id]);

  async function sync(continueAfterVerification = false) {
    if (!user) return;
    const userId = user.id;
    const currentAttempt = ++attempt.current;
    setBusy(true); setError(""); setVerified(false);
    track(domainMigration("started"));
    try {
      const result = await runDomainMigration(userId, (next) => {
        if (attempt.current === currentAttempt && activeUser.current === userId) setGames(next);
      });
      if (attempt.current !== currentAttempt || activeUser.current !== userId) return;
      setRevision((value) => value + 1);
      setVerified(result.ready);
      track(domainMigration(result.ready ? "verified" : "failed"));
      if (result.ready && continueAfterVerification && brand.launchEnabled) window.location.assign(destination);
      if (!result.ready) setError("Some saves have not been confirmed yet. Your progress is still on this browser. Check your connection, close other game tabs, and try again with the account you first used to sync.");
    } catch {
      if (attempt.current === currentAttempt) setError("We could not check your saves. They have been kept on this browser. Please try again.");
    } finally {
      if (attempt.current === currentAttempt) setBusy(false);
    }
  }

  function continueWithoutSaves() {
    try {
      // Recheck on the click: a different tab may have saved since this page rendered.
      if (brand.launchEnabled && (!inspectMigrationStorage(localStorage).hasSaves || startFresh)) {
        if (startFresh) track(domainMigration("continued_without_history"));
        window.location.assign(destination);
      }
      else { setVerified(false); setRevision((value) => value + 1); }
    } catch { setError("Browser storage is unavailable. Reopen this page in the original browser before moving your history."); }
  }

  return <main className="migration-page" data-revision={revision}>
    <BrandLogo large />
    <section className="migration-panel" aria-labelledby="migration-title">
      <p className="migration-eyebrow">Same games. A new name.</p>
      <h1 id="migration-title">Backword is {brand.launchEnabled ? "now" : "becoming"} intervls</h1>
      {!brand.launchEnabled ? <p className="migration-notice">intervls is being prepared. You can sync and check your history now; moving to the new website opens at launch.</p> : null}
      <p>We’re moving to intervls.com. Your games, scores, and Pro subscription can come with you.</p>
      {!inventory ? <p role="alert">We cannot read this browser’s saves. Open this link in the browser and device you used to play, and allow website storage before moving your history.</p> : <>
        {!inventory.hasSaves && !user ? <>
          <p>No saved games were found on this website address in this browser.</p>
          <button className="migration-primary" disabled={!authReady || !brand.launchEnabled} onClick={continueWithoutSaves}>Continue to intervls</button>
        </> : <>
          <p>Sign in here to save your history, then use the same Apple or Google account on intervls. We’ll check all five games before you move.</p>
          {otherAccounts ? <p className="migration-notice">This browser also holds saves for another account. Sign into each account here to sync its history before using it on intervls.</p> : null}
          {!user ? <Link className="migration-primary" to="/sign-in" state={{ returnTo }}>Sign in to keep my progress</Link> : <>
            <p>Signed in{user.email ? ` as ${user.email}` : ""}. Use this same account on intervls.</p>
            <ul className="migration-games" aria-label="Save transfer progress" aria-live="polite">
              {migrationGames.map((game) => {
                const status = games.find((item) => item.game === game.type)?.status ?? "pending";
                const label = { pending: "Waiting", syncing: "Checking…", verified: "Saved and verified", failed: "Needs retry" }[status];
                return <li key={game.type}><span>{game.name}</span><span>{label}</span></li>;
              })}
            </ul>
            {verified ? <p role="status">Your saves for this account are confirmed. {brand.launchEnabled ? "You can continue and sign in on intervls." : "Your history is ready for launch."}</p> : null}
            <button className="migration-primary" disabled={busy} onClick={() => void sync(verified)}>{busy ? "Checking your saves…" : verified ? brand.launchEnabled ? "Continue to intervls" : "Check saves again" : "Sync and check my saves"}</button>
            <button className="migration-secondary" disabled={busy} onClick={() => void signOut().catch(() => setError("We could not sign out. Please try again."))}>Use a different account</button>
          </>}
          <label className="migration-fresh"><input type="checkbox" checked={startFresh} disabled={busy} onChange={(event) => setStartFresh(event.target.checked)} /> I want to continue without moving this browser’s history. My old saves will stay here for recovery.</label>
          <button className="migration-secondary" disabled={busy || !startFresh || !brand.launchEnabled} onClick={continueWithoutSaves}>Continue without moving history</button>
        </>}
      </>}
      {error ? <p role="alert">{error}</p> : null}
      <p className="migration-small">Keep this browser’s old website data until your history appears on intervls. Device settings and analytics choices start fresh on the new website.</p>
      <p className="migration-small"><a href="https://www.playbackword.com/move">Check saves on www.playbackword.com</a> · <a href="https://playbackword.com/move">Check saves on playbackword.com</a></p>
    </section>
  </main>;
}
