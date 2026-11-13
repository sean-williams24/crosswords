type Props = {
  game: "anagram" | "midword";
  headings: string[];
  explanation: string;
  detail: string;
  onStart: () => void;
  loading?: boolean;
};

export function TimedGameStartCard({ game, headings, explanation, detail, onStart, loading = false }: Props) {
  return <section aria-busy={loading} aria-label={`${game === "anagram" ? "Anagram" : "Midword"} introduction`} className={`${game}-start timed-game-start-card`}>
    <h2>{headings.map(heading => <span key={heading}>{heading}</span>)}</h2>
    <p>{explanation}</p>
    <small>{detail}</small>
    <button disabled={loading} onClick={onStart} type="button">Start</button>
  </section>;
}
