type InstructionIconName = "gameplay" | "letters" | "undo" | "restart" | "giveUp" | "timer" | "hint" | "scoring" | "connection" | "cells" | "dictionary" | "attempts" | "example";

export function InstructionSection({ children, icon, title }: { children: React.ReactNode; icon: InstructionIconName; title: string }) {
  return <section className="game-instructions__section">
    <h3><InstructionIcon name={icon} />{title}</h3>
    {children}
  </section>;
}

export function InstructionRow({ children, icon }: { children: React.ReactNode; icon: InstructionIconName }) {
  return <div className="game-instructions__row"><InstructionIcon name={icon} /><p>{children}</p></div>;
}

export function InstructionIcon({ name }: { name: InstructionIconName }) {
  if (name === "letters") return <span aria-hidden="true" className="game-instructions__icon game-instructions__icon--letters">ABC</span>;
  const paths: Record<Exclude<InstructionIconName, "letters">, React.ReactNode> = {
    connection: <><path d="m10 13 4-4" /><path d="m8 10-3 3a4 4 0 0 0 6 6l3-3M10 8l3-3a4 4 0 0 1 6 6l-3 3" /></>,
    cells: <><rect x="2" y="6" width="20" height="12" rx="2" /><path d="M9 6v12M15 6v12" /></>,
    dictionary: <><rect x="5" y="3" width="14" height="18" rx="2" /><path d="M5 17h14M9 7h6M9 10h4" /></>,
    attempts: <><rect x="4" y="8" width="16" height="13" rx="2" /><path d="M6 5h12M8 2h8" /></>,
    example: <><circle cx="12" cy="12" r="9" /><path d="m8 12 3 3 5-6" /></>,
    gameplay: <><path d="M8.5 11V7.5a1.5 1.5 0 0 1 3 0V11" /><path d="M11.5 10V5.5a1.5 1.5 0 0 1 3 0V10" /><path d="M14.5 10V7a1.5 1.5 0 0 1 3 0v6.5c0 4-2.6 7-6.5 7-2.2 0-3.8-.8-5.2-2.5L3.5 15.2a1.6 1.6 0 0 1 2.3-2.2l2.7 2.1" /><path d="M4 5.5 2.5 4M7 3.5V1.5M3.5 8H1.5" /></>,
    undo: <><path d="m9 8-4 4 4 4" /><path d="M5 12h8a6 6 0 0 1 6 6" /></>,
    restart: <><path d="M4 11a8 8 0 1 1 2.3 6" /><path d="M4 5v6h6" /></>,
    giveUp: <><path d="M5 21V4" /><path d="M5 5h11l-2 3 2 3H5" /></>,
    timer: <><circle cx="12" cy="13" r="8" /><path d="M12 13V8m-3-5h6M7 6 5.5 4.5" /></>,
    hint: <><path d="M9 18h6M10 21h4" /><path d="M8.2 14.5A7 7 0 1 1 15.8 14.5c-1 .8-1.3 1.5-1.3 2.5h-5c0-1-.3-1.7-1.3-2.5Z" /></>,
    scoring: <><circle cx="12" cy="12" r="9" /><path d="m12 7 1.5 3 3.5.5-2.5 2.4.6 3.5-3.1-1.7-3.1 1.7.6-3.5L7 10.5l3.5-.5Z" /></>
  };
  return <svg aria-hidden="true" className="game-instructions__icon" viewBox="0 0 24 24">{paths[name]}</svg>;
}
