import type { DashboardStatus } from "./backwordStatus";

type DashboardStatusLabelProps = {
  status: DashboardStatus;
};

export function DashboardStatusLabel({ status }: DashboardStatusLabelProps) {
  const symbol = status.tone === "failed" ? "×" : status.tone === "progress" ? "✎" : "✓";

  return (
    <span className={`home-status home-status--${status.tone}`} aria-label={`Status: ${status.label}`}>
      <span aria-hidden="true" className="home-status__icon">{symbol}</span>
      {status.label}
    </span>
  );
}
