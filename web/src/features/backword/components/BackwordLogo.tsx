type BackwordLogoProps = {
  isPro?: boolean;
  large?: boolean;
};

export function BackwordLogo({ isPro = false, large = false }: BackwordLogoProps) {
  const { resolvedTheme } = useTheme();
  return (
    <span className={`bw-logo-lockup${large ? " bw-logo-lockup--large" : ""}`}>
      <img
        alt="Backword"
        className={`bw-logo${large ? " bw-logo--large" : ""}`}
        src={resolvedTheme === "light" ? "/brand/backword-logo-light.png" : "/brand/backword-logo.png"}
      />
      {isPro ? <img alt="Pro" className="bw-logo__pro" src="/brand/backword-pro.png" /> : null}
    </span>
  );
}
import { useTheme } from "../../theme/ThemeProvider";
