import { useTheme } from "../theme/ThemeProvider";

type BrandLogoProps = { isPro?: boolean; large?: boolean };

export function BrandLogo({ isPro = false, large = false }: BrandLogoProps) {
  const { resolvedTheme } = useTheme();
  return <span className={`brand-logo${large ? " brand-logo--large" : ""}`}>
    <img alt="intervls" src={`/brand/intervls-${resolvedTheme === "light" ? "light" : "dark"}.svg`} />
    {isPro ? <img alt="Pro" className="brand-logo__pro" src="/brand/backword-pro.png" /> : null}
  </span>;
}
