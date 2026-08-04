import type { BackwordMode } from "../types";
import { BackwordModal } from "./BackwordModal";

type BackwordInstructionsProps = {
  mode: BackwordMode;
  onClose: () => void;
  onModeChange: (mode: BackwordMode) => void;
  showsRulesUpdate: boolean;
};

const scoringRows = [
  ["Win in 1 guess", "5 pts"],
  ["Win in 2 guesses", "4 pts"],
  ["Win in 3 guesses", "3 pts"],
  ["Win in 4 guesses", "2 pts"],
  ["Win in 5 guesses", "1 pt"],
  ["Loss or missed", "0 pts"]
];

export function BackwordInstructions({
  mode,
  onClose,
  onModeChange,
  showsRulesUpdate
}: BackwordInstructionsProps) {
  const easy = mode === "easy";
  const examples = easy ? ["LE", "DLE", "NDLE", "UNDLE"] : ["E", "LE", "DLE", "DLE"];

  return (
    <BackwordModal className="bw-instructions" onClose={onClose} title="How to Play">
      <div className="bw-modal-scroll">
        <label className="bw-mode-row">
          <span>
            <strong>Easy Mode - {easy ? "On" : "Off"}</strong>
            <small>Reveal another letter after every wrong guess</small>
          </span>
          <input
            aria-label="Easy Mode"
            checked={easy}
            onChange={(event) => onModeChange(event.target.checked ? "easy" : "normal")}
            role="switch"
            type="checkbox"
          />
        </label>

        {showsRulesUpdate && !easy ? (
          <aside className="bw-rules-update">
            <strong>Rules Updated</strong>
            <p>Normal mode now gives free reveals after the second and third wrong guesses.</p>
          </aside>
        ) : null}

        <div className="bw-rule-list">
          <Instruction number="1">
            Correctly placed letters reveal when they form an unbroken chain from the back of the word.
          </Instruction>
          <Instruction number="2">
            {easy
              ? "If your guesses do not extend that chain, each wrong guess reveals one more letter from the back of the word."
              : "If your guesses do not extend that chain, the second and third wrong guesses each reveal one more letter from the end."}
          </Instruction>
          <Instruction number="3">
            The fewer guesses you need, the more points you score.
          </Instruction>
          <Instruction>
            The clue is a word associated with the answer, or something connected to it.
          </Instruction>
        </div>

        <div className="bw-divider" />
        <p className="bw-example-caption">Example of free reveals after each wrong guess</p>
        <p className="bw-example-answer">Answer: BUNDLE</p>
        <div className="bw-reveal-examples">
          {examples.map((suffix, index) => (
            <div className="bw-reveal-example" key={`${suffix}-${index}`}>
              <span>{ordinal(index + 1)} wrong guess</span>
              <MiniCells suffix={suffix} />
            </div>
          ))}
        </div>

        <div className="bw-divider" />
        <section className="bw-scoring">
          <h3>Scoring</h3>
          {scoringRows.map(([label, points]) => (
            <div key={label}>
              <span>{label}</span>
              <strong>{points}</strong>
            </div>
          ))}
        </section>
      </div>
    </BackwordModal>
  );
}

function Instruction({ number, children }: { number?: string; children: string }) {
  return (
    <p>
      <span className={number ? "bw-rule-number" : "bw-rule-info"}>
        {number ?? "i"}
      </span>
      <span>{children}</span>
    </p>
  );
}

function MiniCells({ suffix }: { suffix: string }) {
  const letters = Array(6 - suffix.length).fill("").concat(Array.from(suffix));
  return (
    <span aria-label={`Reveals ${suffix}`} className="bw-mini-cells">
      {letters.map((letter, index) => (
        <span className={letter ? "is-revealed" : ""} key={index}>
          {letter}
        </span>
      ))}
    </span>
  );
}

function ordinal(number: number): string {
  return number === 1 ? "1st" : number === 2 ? "2nd" : number === 3 ? "3rd" : `${number}th`;
}
