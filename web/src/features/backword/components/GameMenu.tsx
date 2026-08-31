import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { AppStoreBadge } from "../../../components/AppStoreBadge";
import { AuthButton } from "../../auth/AuthButton";

type GameMenuProps = {
  isOpen?: boolean;
  onClose?: () => void;
  onOpen?: () => void;
};

export function GameMenu({ isOpen, onClose, onOpen }: GameMenuProps) {
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const [uncontrolledIsOpen, setUncontrolledIsOpen] = useState(false);
  const menuIsOpen = isOpen ?? uncontrolledIsOpen;

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
                className="bw-icon-button"
                onClick={closeMenu}
                ref={closeButtonRef}
                type="button"
              >
                ×
              </button>
            </div>
            <nav aria-label="Game navigation links" className="bw-menu-links">
              <Link className="bw-menu-link bw-menu-link--primary" to="/">Home</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/backword">Backword</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/crossword">Quick Crossword</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/weekly-crossword">Pro Crossword</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/info">Info</Link>
              <Link className="bw-menu-link bw-menu-link--primary" to="/contact">Contact</Link>
              <AuthButton className="bw-menu-link bw-menu-link--primary bw-menu-auth" />
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
