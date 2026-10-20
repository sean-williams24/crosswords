import { useNavigate } from "react-router-dom";
import "./StatsSheetActions.css";

export function StatsSheetActions({ onClose, showHome = true, autoFocusHome = false }: {
  onClose: () => void;
  showHome?: boolean;
  autoFocusHome?: boolean;
}) {
  return <div className="stats-sheet-actions">
    <div aria-label="Stats sheet actions" className="stats-sheet-actions__bar" role="group">
      {showHome ? <HomeButton autoFocus={autoFocusHome} /> : null}
      <button autoFocus={!showHome} className="stats-sheet-actions__button" onClick={onClose} type="button">BACK TO GAME</button>
    </div>
  </div>;
}

function HomeButton({ autoFocus }: { autoFocus: boolean }) {
  const navigate = useNavigate();
  return <button autoFocus={autoFocus} className="stats-sheet-actions__button" onClick={() => navigate("/")} type="button">HOME</button>;
}
