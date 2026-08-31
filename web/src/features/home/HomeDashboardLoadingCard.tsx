type HomeDashboardLoadingCardProps = {
  variant: "backword" | "crossword" | "word-of-the-day" | "weekly";
};

export function HomeDashboardLoadingCard({ variant }: HomeDashboardLoadingCardProps) {
  return (
    <div aria-hidden="true" className={`home-dashboard-loading-card home-dashboard-loading-card--${variant}`}>
      <span className="home-dashboard-loading-card__line home-dashboard-loading-card__line--eyebrow" />
      <span className="home-dashboard-loading-card__line home-dashboard-loading-card__line--title" />
      <span className="home-dashboard-loading-card__line home-dashboard-loading-card__line--detail" />
    </div>
  );
}
