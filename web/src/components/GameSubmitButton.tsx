type GameSubmitButtonProps = {
  onSubmit: () => void;
  visible: boolean;
};

export function GameSubmitButton({ onSubmit, visible }: GameSubmitButtonProps) {
  return (
    <div
      aria-hidden={!visible}
      className={`game-submit${visible ? " game-submit--visible" : ""}`}
      inert={!visible}
    >
      <div className="game-submit__inner">
        <button className="bw-submit" disabled={!visible} onClick={onSubmit} type="button">
          Submit
        </button>
      </div>
    </div>
  );
}
