type BackwordLogoProps = {
  isPro?: boolean;
  large?: boolean;
};

export function BackwordLogo({ isPro = false, large = false }: BackwordLogoProps) {
  return (
    <span className={`bw-logo-lockup${large ? " bw-logo-lockup--large" : ""}`}>
      <img
        alt="Backword"
        className={`bw-logo${large ? " bw-logo--large" : ""}`}
        src="/brand/backword-logo.png"
      />
      {isPro ? <img alt="Pro" className="bw-logo__pro" src="/brand/backword-pro.png" /> : null}
    </span>
  );
}
