export function GameGiveUpButton({ onClick }: { onClick: () => void }) {
  return <button aria-label="Give up" className="bw-icon-button cw-give-up-action"
    onClick={onClick} title="Give up" type="button">
    <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M5 21V3m0 1c5-4 9 4 14 0v10c-5 4-9-4-14 0" /></svg>
  </button>;
}
