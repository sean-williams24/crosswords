type HomeGameStreakProps = {
  streak: number;
  unit?: "day" | "week";
};

export function HomeGameStreak({ streak, unit = "day" }: HomeGameStreakProps) {
  if (streak <= 0) return null;

  return (
    <span className="home-game-card__streak" aria-label={`${streak}-${unit} streak`}>
      <svg aria-hidden="true" className="home-game-card__streak-icon" fill="currentColor" viewBox="0 0 24 24">
        <path fillRule="evenodd" d="M13.2 1.5c.7 3.8-2.9 5.1-2.9 8.1 0 1.2.6 2.2 1.6 2.8-.2-2.2 1.3-3.4 2.6-4.7 3.1 2.4 5.5 5.6 5.5 8.6a8 8 0 0 1-16 0c0-3 1.8-5.4 4-7.4-.3 2.5.5 3.6 1.4 4.2C7.9 8.4 9.6 4.9 13.2 1.5Zm-.9 12c.2 1.8-2.3 2.8-2.3 4.5a2 2 0 0 0 4 0c0-1.6-.7-3-1.7-4.5Z" clipRule="evenodd" />
      </svg>
      <span>{streak}</span>
    </span>
  );
}
