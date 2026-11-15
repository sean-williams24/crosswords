import { GameGiveUpButton } from "../../components/GameGiveUpButton";
import { InfoTooltip } from "../../components/InfoTooltip";
import { GameMenu } from "../backword/components/GameMenu";

export function AnagramHeader({ onDismissTip, onInfo, onStats, onGiveUp, showTip, statsDisabled = false }: {
  onDismissTip: () => void;
  onInfo: () => void;
  onGiveUp?: () => void;
  onStats: () => void;
  showTip: boolean;
  statsDisabled?: boolean;
}) {
  return <header className="anagram-header">
    <GameMenu />
    <nav aria-label="Anagram actions">
      {onGiveUp ? <GameGiveUpButton onClick={onGiveUp} /> : null}
      <button aria-label="Anagram stats" className="bw-icon-button" disabled={statsDisabled} onClick={onStats} type="button">🧠</button>
      <span className="bw-info-tip-anchor">
        <button aria-describedby={showTip ? "anagram-info-tip" : undefined} aria-label="How to play Anagram" className="bw-icon-button bw-info-icon" onClick={onInfo} type="button">ⓘ</button>
        {showTip ? <InfoTooltip
          description="Tap the info icon at any time to view the rules and scoring."
          id="anagram-info-tip"
          onDismiss={onDismissTip}
        /> : null}
      </span>
    </nav>
  </header>;
}
