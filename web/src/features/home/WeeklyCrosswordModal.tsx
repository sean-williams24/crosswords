import { useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { AppStoreBadge } from "../../components/AppStoreBadge";

type WeeklyCrosswordModalProps = {
  onClose: () => void;
  showSignIn?: boolean;
};

const features = [
  ["♧", "Weekly challenging puzzles"],
  ["▰", "Unlimited puzzle archive"],
  ["⚑", "Reveal answers when stuck"]
] as const;

export function WeeklyCrosswordModal({ onClose, showSignIn = false }: WeeklyCrosswordModalProps) {
  const closeButton = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    closeButton.current?.focus();
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [onClose]);

  return (
    <div className="weekly-modal-backdrop" onMouseDown={onClose}>
      <section
        aria-labelledby="weekly-modal-title"
        aria-modal="true"
        className="weekly-modal"
        onMouseDown={(event) => event.stopPropagation()}
        role="dialog"
      >
        <button
          aria-label="Close weekly crossword details"
          className="weekly-modal__close"
          onClick={onClose}
          ref={closeButton}
          type="button"
        >
          ×
        </button>
        <div className="weekly-modal__hero">
          <div className="weekly-modal__logo" aria-label="Backword Pro">
            <img alt="Backword" src="/brand/backword-logo.png" />
            <img alt="Pro" src="/brand/backword-pro.png" />
          </div>
        </div>
        <div className="weekly-modal__body">
          <h2 className="weekly-modal__title" id="weekly-modal-title">The full game experience</h2>
          <ul className="weekly-modal__features">
            {features.map(([icon, feature]) => (
              <li key={feature}>
                <span aria-hidden="true">{icon}</span>
                {feature}
              </li>
            ))}
          </ul>
          <p className="weekly-modal__intro">Available with a Backword Pro subscription on iOS.</p>
          {showSignIn ? <Link className="weekly-modal__sign-in" state={{ returnTo: "/weekly-crossword" }} to="/sign-in">Already Pro? Sign in</Link> : null}
          <div className="weekly-modal__store-badge">
            <AppStoreBadge />
          </div>
        </div>
      </section>
    </div>
  );
}
