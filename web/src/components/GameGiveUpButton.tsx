export function GameGiveUpButton({ onClick, flag = false }: { onClick: () => void; flag?: boolean }) {
  return <button aria-label="Give up" className={flag ? "bw-icon-button cw-give-up-action" : "game-give-up-button"}
    onClick={onClick} title="Give up" type="button">
    {flag ? <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M5 21V3m0 1c5-4 9 4 14 0v10c-5 4-9-4-14 0" /></svg> : "Give up"}
  </button>;
}
