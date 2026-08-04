const rows = [
  ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
  ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
  ["Z", "X", "C", "V", "B", "N", "M"]
];

type BackwordKeyboardProps = {
  disabled: boolean;
  onDelete: () => void;
  onLetter: (letter: string) => void;
};

export function BackwordKeyboard({
  disabled,
  onDelete,
  onLetter
}: BackwordKeyboardProps) {
  return (
    <div aria-label="Backword keyboard" className="bw-keyboard" role="group">
      {rows.map((row, rowIndex) => (
        <div className="bw-keyboard-row" key={row.join("")}>
          {row.map((letter) => (
            <button
              aria-label={letter}
              className="bw-key"
              disabled={disabled}
              key={letter}
              onClick={() => onLetter(letter)}
              type="button"
            >
              {letter}
            </button>
          ))}
          {rowIndex === rows.length - 1 ? (
            <button
              aria-label="Delete letter"
              className="bw-key bw-key-delete"
              disabled={disabled}
              onClick={onDelete}
              type="button"
            >
              ⌫
            </button>
          ) : null}
        </div>
      ))}
    </div>
  );
}
