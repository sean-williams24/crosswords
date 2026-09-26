type InstructionIconName = "gameplay" | "letters" | "undo" | "restart" | "giveUp" | "timer" | "hint" | "scoring";

const scoringRules = [
  ["Under 30 seconds", "5 pts"],
  ["30–59 seconds", "4 pts"],
  ["1:00–1:59", "3 pts"],
  ["2:00–2:59", "2 pts"],
  ["3:00 or longer", "1 pt"],
  ["Give up", "0 pts"]
] as const;

export function AnagramInstructions() {
  return <div className="anagram-instructions">
    <InstructionSection icon="gameplay" title="Gameplay">
      <InstructionRow icon="letters">Tap the scrambled letters in order to build the answer from left to right. Every tile is used once.</InstructionRow>
      <InstructionRow icon="undo">Undo removes your last letter. Shuffle changes the tray order without changing your answer.</InstructionRow>
      <InstructionRow icon="restart">Restart returns your placed letters to the tray. Your timer and any used hint are preserved.</InstructionRow>
      <InstructionRow icon="giveUp">Give up reveals the answer, ends the attempt, and awards zero points.</InstructionRow>
    </InstructionSection>

    <InstructionSection icon="timer" title="Timer">
      <p>The timer starts when you tap Start and measures real elapsed time. It continues while the app is in the background or you leave the game, and stops when you solve or give up. There is no time limit.</p>
    </InstructionSection>

    <InstructionSection icon="hint" title="Hint">
      <p>You can reveal one letter per game. Using a hint returns your placed letters to the tray, then locks one correct letter in the answer so it cannot be undone.</p>
      <p>Free players can watch a rewarded ad. If an ad is unavailable, or if you are a Pro player, the hint adds 30 seconds to your scoring time.</p>
    </InstructionSection>

    <InstructionSection icon="scoring" title="Scoring">
      <dl className="anagram-instructions__scoring">
        {scoringRules.map(([label, points]) => <div key={label}><dt>{label}</dt><dd>{points}</dd></div>)}
      </dl>
      <p>Your score uses your elapsed time plus any 30-second hint penalty. Only a solve completed on the puzzle&apos;s release day adds points to your rolling 14-day rating and streak.</p>
    </InstructionSection>
  </div>;
}

function InstructionSection({ children, icon, title }: { children: React.ReactNode; icon: InstructionIconName; title: string }) {
  return <section className="anagram-instructions__section">
    <h3><InstructionIcon name={icon} />{title}</h3>
    {children}
  </section>;
}

function InstructionRow({ children, icon }: { children: React.ReactNode; icon: InstructionIconName }) {
  return <div className="anagram-instructions__row"><InstructionIcon name={icon} /><p>{children}</p></div>;
}

function InstructionIcon({ name }: { name: InstructionIconName }) {
  if (name === "letters") return <span aria-hidden="true" className="anagram-instructions__icon anagram-instructions__icon--letters">ABC</span>;
  const paths: Record<Exclude<InstructionIconName, "letters">, React.ReactNode> = {
    gameplay: <><path d="M8.5 11V7.5a1.5 1.5 0 0 1 3 0V11" /><path d="M11.5 10V5.5a1.5 1.5 0 0 1 3 0V10" /><path d="M14.5 10V7a1.5 1.5 0 0 1 3 0v6.5c0 4-2.6 7-6.5 7-2.2 0-3.8-.8-5.2-2.5L3.5 15.2a1.6 1.6 0 0 1 2.3-2.2l2.7 2.1" /><path d="M4 5.5 2.5 4M7 3.5V1.5M3.5 8H1.5" /></>,
    undo: <><path d="m9 8-4 4 4 4" /><path d="M5 12h8a6 6 0 0 1 6 6" /></>,
    restart: <><path d="M4 11a8 8 0 1 1 2.3 6" /><path d="M4 5v6h6" /></>,
    giveUp: <><path d="M5 21V4" /><path d="M5 5h11l-2 3 2 3H5" /></>,
    timer: <><circle cx="12" cy="13" r="8" /><path d="M12 13V8m-3-5h6M7 6 5.5 4.5" /></>,
    hint: <><path d="M9 18h6M10 21h4" /><path d="M8.2 14.5A7 7 0 1 1 15.8 14.5c-1 .8-1.3 1.5-1.3 2.5h-5c0-1-.3-1.7-1.3-2.5Z" /></>,
    scoring: <><circle cx="12" cy="12" r="9" /><path d="m12 7 1.5 3 3.5.5-2.5 2.4.6 3.5-3.1-1.7-3.1 1.7.6-3.5L7 10.5l3.5-.5Z" /></>
  };
  return <svg aria-hidden="true" className="anagram-instructions__icon" viewBox="0 0 24 24">{paths[name]}</svg>;
}
