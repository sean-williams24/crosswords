import type { CSSProperties } from "react";

export function MidwordLetterRow({ word, length = word.length, active = false, correct = false, failed = false, inputError = false, label }: {
  word: string; length?: number; active?: boolean; correct?: boolean; failed?: boolean; inputError?: boolean; label: string;
}) {
  return <div aria-label={label} className={`midword-letter-row${correct ? " is-correct" : ""}${failed ? " is-incorrect" : ""}${inputError ? " is-shaking" : ""}`}
    role="group" style={{ "--midword-letter-count": length } as CSSProperties}>
    {Array.from({ length }, (_, index) => <span aria-hidden="true"
      className={`${word[index] ? "has-letter" : "is-empty"}${active && index === word.length ? " is-cursor" : ""}`}
      key={index}>{word[index] ?? "_"}</span>)}
  </div>;
}
