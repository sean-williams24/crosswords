import { useEffect, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from "react";
import { Link } from "react-router-dom";
import { AppStoreBadge } from "../../../components/AppStoreBadge";
import { AuthButton } from "../../auth/AuthButton";
import { useAuth } from "../../auth/AuthProvider";
import { useTheme, type ThemePreference } from "../../theme/ThemeProvider";

type GameMenuProps = {
  isOpen?: boolean;
  onClose?: () => void;
  onOpen?: () => void;
};

const themeOptions = ["light", "dark", "system"] as const;

export function GameMenu({ isOpen, onClose, onOpen }: GameMenuProps) {
  const { entitlement, user, debugProOverrideActive, debugProOverrideAvailable, setDebugProOverride } = useAuth();
  const { preference, setPreference } = useTheme();
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const [uncontrolledIsOpen, setUncontrolledIsOpen] = useState(false);
  const menuIsOpen = isOpen ?? uncontrolledIsOpen;
  const weeklyCrosswordDestination = entitlement?.isPro ? "/weekly-crossword" : "/pro?return_to=%2Fweekly-crossword";
  const archiveDestination = entitlement?.isPro ? "/archive" : "/pro?return_to=%2Farchive";

  function openMenu() {
    if (isOpen === undefined) {
      setUncontrolledIsOpen(true);
    }
    onOpen?.();
  }

  function closeMenu() {
    if (isOpen === undefined) {
      setUncontrolledIsOpen(false);
    }
    onClose?.();
  }

  function moveThemeSelection(event: ReactKeyboardEvent<HTMLButtonElement>, currentTheme: ThemePreference) {
    const currentIndex = themeOptions.indexOf(currentTheme);
    const direction = event.key === "ArrowRight" || event.key === "ArrowDown" ? 1 : event.key === "ArrowLeft" || event.key === "ArrowUp" ? -1 : 0;
    const nextIndex = event.key === "Home" ? 0 : event.key === "End" ? themeOptions.length - 1 : (currentIndex + direction + themeOptions.length) % themeOptions.length;
    if (!direction && event.key !== "Home" && event.key !== "End") return;

    event.preventDefault();
    setPreference(themeOptions[nextIndex]);
    event.currentTarget.parentElement?.querySelectorAll<HTMLButtonElement>('[role="radio"]')[nextIndex]?.focus();
  }

  useEffect(() => {
    if (!menuIsOpen) {
      return;
    }

    closeButtonRef.current?.focus();
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeMenu();
      }
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [menuIsOpen]);

  useEffect(() => {
    if (!menuIsOpen) {
      return;
    }

    const { body } = document;
    const scrollY = window.scrollY;
    const previousStyles = {
      left: body.style.left,
      overflow: body.style.overflow,
      position: body.style.position,
      right: body.style.right,
      top: body.style.top,
      width: body.style.width
    };

    body.style.position = "fixed";
    body.style.top = `-${scrollY}px`;
    body.style.right = "0";
    body.style.left = "0";
    body.style.width = "100%";
    body.style.overflow = "hidden";

    return () => {
      body.style.left = previousStyles.left;
      body.style.overflow = previousStyles.overflow;
      body.style.position = previousStyles.position;
      body.style.right = previousStyles.right;
      body.style.top = previousStyles.top;
      body.style.width = previousStyles.width;
      window.scrollTo(0, scrollY);
    };
  }, [menuIsOpen]);

  return (
    <div className="bw-game-menu">
      <button
        aria-controls="game-navigation-menu"
        aria-expanded={menuIsOpen}
        aria-label="Open game menu"
        className="bw-icon-button bw-menu-button"
        onClick={openMenu}
        type="button"
      >
        ☰
      </button>

      {menuIsOpen ? (
        <div
          className="bw-menu-backdrop"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) {
              closeMenu();
            }
          }}
        >
          <section aria-label="Game navigation" aria-modal="true" className="bw-menu-panel" id="game-navigation-menu" role="dialog">
            <div className="bw-menu-panel__heading">
              <button
                aria-label="Close game menu"
                className="bw-icon-button bw-menu-close"
                onClick={closeMenu}
                ref={closeButtonRef}
                type="button"
              >
                ×
              </button>
            </div>
            <nav aria-label="Game navigation links" className="bw-menu-links">
              <section aria-labelledby="menu-appearance-title" className="bw-menu-appearance">
                <h2 id="menu-appearance-title">Appearance</h2>
                <div aria-label="Theme" className="bw-theme-picker" role="radiogroup">
                  {themeOptions.map((theme) => (
                    <button
                      aria-checked={preference === theme}
                      className={preference === theme ? "is-selected" : ""}
                      key={theme}
                      onClick={() => setPreference(theme)}
                      onKeyDown={(event) => moveThemeSelection(event, theme)}
                      role="radio"
                      type="button"
                    >
                      {theme.charAt(0).toUpperCase() + theme.slice(1)}
                    </button>
                  ))}
                </div>
              </section>
              {debugProOverrideAvailable ? <section aria-labelledby="menu-debug-title" className="bw-menu-debug">
                <h2 id="menu-debug-title">Debug</h2>
                <label className="bw-menu-debug__toggle">
                  <span>Force Pro access</span>
                  <input
                    aria-describedby="menu-debug-description"
                    checked={debugProOverrideActive}
                    disabled={!user}
                    onChange={(event) => setDebugProOverride(event.target.checked)}
                    type="checkbox"
                  />
                </label>
                <p id="menu-debug-description">{user ? "Local browser only. This does not change the account subscription." : "Sign in with a test account to play protected games."}</p>
              </section> : null}
              <Link className="bw-menu-link bw-menu-link--primary" to="/">Home</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/backword">Backword</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/crossword">Quick Crossword</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to={weeklyCrosswordDestination}>Pro Crossword</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to={archiveDestination}>Archive</Link>
              <Link className="bw-menu-link bw-menu-link--primary bw-menu-auth" to="/player-profile">Player Profile</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/info">Info</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/contact">Contact</Link>
              {!user ? <AuthButton className="bw-menu-link bw-menu-link--primary bw-menu-auth" /> : null}
              {!entitlement?.isPro ? <Link className="bw-menu-upgrade" to="/pro">Get full access</Link> : null}
              <div className="bw-menu-links__legal">
                <Link className="bw-menu-link bw-menu-link--secondary" to="/privacy">Privacy</Link>
                <Link className="bw-menu-link bw-menu-link--secondary" to="/terms">Terms</Link>
                <div className="bw-menu-store-badge">
                  <AppStoreBadge />
                </div>
              </div>
            </nav>
          </section>
        </div>
      ) : null}
    </div>
  );
}
