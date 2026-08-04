type BackwordLogoProps = {
  large?: boolean;
};

export function BackwordLogo({ large = false }: BackwordLogoProps) {
  return (
    <img
      alt="Backword"
      className={`bw-logo${large ? " bw-logo--large" : ""}`}
      src="/brand/backword-logo.png"
    />
  );
}
