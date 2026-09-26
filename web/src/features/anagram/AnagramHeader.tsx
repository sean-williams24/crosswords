import { GameMenu } from "../backword/components/GameMenu";

export function AnagramHeader({ onDismissTip, onInfo, onStats, showTip }: {
  onDismissTip: () => void;
  onInfo: () => void;
  onStats: () => void;
  showTip: boolean;
}) {
  return <header className="anagram-header">
    <GameMenu />
    <nav aria-label="Anagram actions">
      <button aria-label="Anagram stats" className="bw-icon-button" onClick={onStats} type="button">🧠</button>
      <span className="bw-info-tip-anchor">
        <button aria-describedby={showTip ? "anagram-info-tip" : undefined} aria-label="How to play Anagram" className="bw-icon-button bw-info-icon" onClick={onInfo} type="button">ⓘ</button>
        {showTip ? <span className="has-close" id="anagram-info-tip" role="tooltip">
          <button aria-label="Dismiss how to play tip" className="bw-info-tip-close" onClick={onDismissTip} type="button">×</button>
          <strong>How to play</strong><span>Tap the info icon at any time to view the rules and scoring.</span>
        </span> : null}
      </span>
    </nav>
  </header>;
}
