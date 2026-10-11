import { InstructionRow, InstructionSection } from "../../components/GameInstructions";

const scoringRules = [
  ["Under 30 seconds", "5 pts"],
  ["30–59 seconds", "4 pts"],
  ["1:00–1:59", "3 pts"],
  ["2:00–2:59", "2 pts"],
  ["3:00 or longer", "1 pt"],
  ["Give up", "0 pts"]
] as const;

export function AnagramInstructions() {
  return <div className="game-instructions">
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
      <dl className="game-instructions__scoring">
        {scoringRules.map(([label, points]) => <div key={label}><dt>{label}</dt><dd>{points}</dd></div>)}
      </dl>
      <p>Your score uses your elapsed time plus any 30-second hint penalty. Only a solve completed on the puzzle&apos;s release day adds points to your rolling 14-day rating and streak.</p>
    </InstructionSection>
  </div>;
}
