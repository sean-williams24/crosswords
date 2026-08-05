import { BackwordModal } from "../../backword/components/BackwordModal";
import { directionLabel } from "../engine";
import type { CrosswordClue, CrosswordProgress, CrosswordPuzzle } from "../types";

type CrosswordClueListProps = {
  activeClueId: number | null;
  onClose: () => void;
  onSelect: (clue: CrosswordClue) => void;
  progress: CrosswordProgress;
  puzzle: CrosswordPuzzle;
};

export function CrosswordClueList({ activeClueId, onClose, onSelect, progress, puzzle }: CrosswordClueListProps) {
  return (
    <BackwordModal className="cw-clue-list-modal" onClose={onClose} title="Clues">
      <div className="bw-modal-scroll cw-clue-list">
        {(["across", "down"] as const).map((direction) => (
          <section key={direction}>
            <h3>{directionLabel(direction).toUpperCase()}</h3>
            {puzzle.clues.filter((clue) => clue.direction === direction).sort((first, second) => first.number - second.number).map((clue) => {
              const complete = progress.completedClueIds.includes(clue.id);
              return (
                <button className={`${activeClueId === clue.id ? "is-active" : ""} ${complete ? "is-completed" : ""}`} key={clue.id} onClick={() => onSelect(clue)} type="button">
                  <strong>{clue.number}</strong><span>{clue.text}</span><small>({clue.length})</small>
                </button>
              );
            })}
          </section>
        ))}
      </div>
    </BackwordModal>
  );
}
