type HomeGameStreakProps = {
  streak: number;
  unit?: "day" | "week";
};

export function HomeGameStreak({ streak, unit = "day" }: HomeGameStreakProps) {
  if (streak <= 0) return null;

  return (
    <span className="home-game-card__streak" aria-label={`${streak}-${unit} streak`}>
      {/* Lucide Flame (ISC); license included at /licenses/lucide.txt. */}
      <svg
        aria-hidden="true"
        className="home-game-card__streak-icon"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        viewBox="0 0 24 24"
      >
        <path d="M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4" />
      </svg>
      <span>{streak}</span>
    </span>
  );
}
