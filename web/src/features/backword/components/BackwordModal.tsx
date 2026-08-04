import { useEffect, useRef, type ReactNode } from "react";

type BackwordModalProps = {
  title: string;
  onClose: () => void;
  children: ReactNode;
  className?: string;
  showCloseButton?: boolean;
};

export function BackwordModal({
  title,
  onClose,
  children,
  className = "",
  showCloseButton = true
}: BackwordModalProps) {
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeRef.current?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [onClose]);

  return (
    <div className="bw-modal-backdrop" role="presentation">
      <section
        aria-label={title}
        aria-modal="true"
        className={`bw-modal ${className}`}
        role="dialog"
      >
        {showCloseButton ? (
          <header className="bw-modal-header">
            <h2>{title}</h2>
            <button
              aria-label={`Close ${title}`}
              className="bw-icon-button bw-modal-close"
              onClick={onClose}
              ref={closeRef}
              type="button"
            >
              ✕
            </button>
          </header>
        ) : null}
        {children}
      </section>
    </div>
  );
}
