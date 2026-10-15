export function OnboardingLightbulbIcon() {
  return (
    <svg aria-hidden="true" className="bw-onboarding-card__icon" fill="currentColor" focusable="false" viewBox="0 0 24 24">
      <path
        className="bw-onboarding-card__icon-globe"
        d="M12 2a7 7 0 0 0-7 7c0 2.5 1.3 4.3 3 5.7.9.8 1.4 1.4 1.5 2.3h5c.1-.9.6-1.5 1.5-2.3 1.7-1.4 3-3.2 3-5.7a7 7 0 0 0-7-7Z"
      />
      <g className="bw-onboarding-card__icon-base" fill="var(--app-text-muted)">
        <rect height="2" rx=".75" width="7" x="8.5" y="17" />
        <path d="M8.5 20h7a1 1 0 0 1-1 1H14a2.1 2.1 0 0 1-4 0h-.5a1 1 0 0 1-1-1Z" />
      </g>
    </svg>
  );
}
