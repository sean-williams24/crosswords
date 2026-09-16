type HomeGameIssueNumberProps = {
  className?: string;
  issueNumber: number | null;
};

export function HomeGameIssueNumber({ className = "", issueNumber }: HomeGameIssueNumberProps) {
  if (issueNumber === null) return null;

  return <span aria-label={`Issue #${issueNumber}`} className={`home-game-card__issue ${className}`.trim()}>#{issueNumber}</span>;
}
