import { clueCells, isCompletedCell } from "../engine";
import type { CSSProperties } from "react";
import type { CrosswordClue, CrosswordProgress, CrosswordPuzzle, CrosswordSelection } from "../types";

type CrosswordGridProps = {
  activeClue: CrosswordClue | null;
  correctHighlight: boolean;
  onSelect: (row: number, col: number) => void;
  progress: CrosswordProgress;
  puzzle: CrosswordPuzzle;
  selection: CrosswordSelection;
};

export function CrosswordGrid({ activeClue, correctHighlight, onSelect, progress, puzzle, selection }: CrosswordGridProps) {
  const activeCells = new Set((activeClue ? clueCells(activeClue) : []).map(({ row, col }) => `${row}:${col}`));
  return (
    <div
      aria-label="Crossword grid"
      className={`cw-grid ${puzzle.size === 13 ? "cw-grid--weekly" : ""}`}
      role="grid"
      style={{ "--cw-grid-size": puzzle.size } as CSSProperties}
    >
      {puzzle.cells.flatMap((row, rowIndex) => row.map((cell, colIndex) => {
        if (cell.letter === null) return <span aria-hidden="true" className="cw-cell cw-cell--black" key={`${rowIndex}:${colIndex}`} />;
        const selected = selection.row === rowIndex && selection.col === colIndex;
        const completed = correctHighlight && isCompletedCell(progress, puzzle, rowIndex, colIndex);
        const inActiveWord = activeCells.has(`${rowIndex}:${colIndex}`);
        return (
          <button
            aria-label={`Row ${rowIndex + 1}, column ${colIndex + 1}${cell.clueNumber ? `, clue ${cell.clueNumber}` : ""}`}
            className={`cw-cell ${selected ? "is-selected" : ""} ${inActiveWord ? "is-active" : ""} ${completed ? "is-completed" : ""}`}
            key={`${rowIndex}:${colIndex}`}
            onClick={() => onSelect(rowIndex, colIndex)}
            role="gridcell"
            type="button"
          >
            {cell.clueNumber ? <small>{cell.clueNumber}</small> : null}
            <strong>{progress.entries[rowIndex][colIndex] ?? ""}</strong>
          </button>
        );
      }))}
    </div>
  );
}
