import { useEffect, useRef } from "react";

export function GameGiveUpDialog({ game, onClose, onConfirm, description = "This ends today’s attempt for zero points and reveals the answer. You cannot replay it for a higher score." }: {
  game: "anagram" | "midword" | "backword" | "daily_crossword" | "weekly_crossword";
  description?: string;
  onClose: () => void;
  onConfirm: () => void;
}) {
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeRef.current?.focus();
    const escape = (event: KeyboardEvent) => { if (event.key === "Escape") onClose(); };
    window.addEventListener("keydown", escape);
    return () => {
      window.removeEventListener("keydown", escape);
      document.body.style.overflow = previousOverflow;
    };
  }, [onClose]);

  return <div className="game-confirmation-backdrop" onClick={event => {
    if (event.target === event.currentTarget) onClose();
  }}>
    <section aria-label="Give up?" aria-modal="true" className={`game-confirmation-dialog game-confirmation-dialog--${game}`} role="dialog">
      <button aria-label="Close" className="game-confirmation-close" onClick={onClose} ref={closeRef} type="button">×</button>
      <h2>Give up?</h2>
      <p>{description}</p>
      <button className="game-confirmation-primary" onClick={onConfirm} type="button">Give up and reveal</button>
      <button onClick={onClose} type="button">Keep playing</button>
    </section>
  </div>;
}
