type Props = {
  game: "anagram" | "midword";
  headings: string[];
  explanation: string;
  detail: string;
  onStart: () => void;
};

export function TimedGameStartCard({ game, headings, explanation, detail, onStart }: Props) {
  return <section aria-label={`${game === "anagram" ? "Anagram" : "Midword"} introduction`} className={`${game}-start timed-game-start-card`}>
    <h2>{headings.map(heading => <span key={heading}>{heading}</span>)}</h2>
    <p>{explanation}</p>
    <small>{detail}</small>
    <button onClick={onStart} type="button">Start</button>
  </section>;
}
