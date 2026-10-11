import { useEffect, useState } from "react";

export function GameInputMessage({ className, message }: { className: string; message: string }) {
  const [lastMessage, setLastMessage] = useState(message);
  useEffect(() => {
    if (message) setLastMessage(message);
  }, [message]);

  return (
    <div aria-hidden={!message} className={`game-input-message${message ? " game-input-message--visible" : ""}`}>
      <div className="game-input-message__inner">
        <p aria-live="assertive" className={className} role="alert">{message || lastMessage}</p>
      </div>
    </div>
  );
}
