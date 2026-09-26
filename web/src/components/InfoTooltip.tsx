import { useEffect, useRef } from "react";

type InfoTooltipProps = {
  description: string;
  id: string;
  onDismiss: () => void;
};

export function InfoTooltip({ description, id, onDismiss }: InfoTooltipProps) {
  const tooltipRef = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const dismissOutside = (event: PointerEvent) => {
      if (!tooltipRef.current?.contains(event.target as Node)) onDismiss();
    };
    document.addEventListener("pointerdown", dismissOutside);
    return () => document.removeEventListener("pointerdown", dismissOutside);
  }, [onDismiss]);

  return (
    <span className="bw-info-tooltip" ref={tooltipRef}>
      <span id={id} role="tooltip">
        <strong>How to play</strong>
        <span>{description}</span>
      </span>
      <button aria-label="Close tooltip" className="bw-info-tooltip__close" onClick={onDismiss} type="button">×</button>
    </span>
  );
}
