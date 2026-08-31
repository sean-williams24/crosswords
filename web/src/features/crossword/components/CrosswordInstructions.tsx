import { BackwordModal } from "../../backword/components/BackwordModal";
import type { CrosswordSettings } from "../types";

type CrosswordInstructionsProps = {
  onClose: () => void;
  onCorrectHighlightChange: (value: boolean) => void;
  settings: CrosswordSettings;
};

export function CrosswordInstructions({ onClose, onCorrectHighlightChange, settings }: CrosswordInstructionsProps) {
  return (
    <BackwordModal onClose={onClose} title="How to Play">
      <div className="bw-modal-scroll cw-instructions">
        <p>Complete the grid and lock in your score before the next crossword refreshes at midnight.</p>
        <p>Tap a cell to select it. Tap it again to switch direction, or use the clue list to browse every clue.</p>
        <p>Use Hint to see an alternative clue for the selected answer. Every three hints deduct one point from your score.</p>
        <label className="bw-mode-row">
          <span><strong>Answer Feedback</strong><small>Highlight and lock correctly completed answers. Turn it off for a harder game.</small></span>
          <input aria-label="Answer feedback" checked={settings.correctHighlight} onChange={(event) => onCorrectHighlightChange(event.target.checked)} type="checkbox" />
        </label>
        <section className="cw-scoring">
          <h3>SCORING</h3>
          <p>100% complete <strong>5 pts</strong></p>
          <p>75–99% complete <strong>4 pts</strong></p>
          <p>50–74% complete <strong>3 pts</strong></p>
          <p>25–49% complete <strong>2 pts</strong></p>
          <p>1–24% complete <strong>1 pt</strong></p>
        </section>
      </div>
    </BackwordModal>
  );
}
