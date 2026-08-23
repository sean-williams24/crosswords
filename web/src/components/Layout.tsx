import type { ReactNode } from "react";
import { Link, useLocation } from "react-router-dom";
import { GameMenu } from "../features/backword/components/GameMenu";
import { Footer } from "./Footer";

type LayoutProps = {
  children: ReactNode;
};

export function Layout({ children }: LayoutProps) {
  const { pathname } = useLocation();
  const isMinimalNavigationPage = pathname === "/info" || pathname === "/privacy" || pathname === "/privacy-choices" || pathname === "/terms";
  const isContactPage = pathname === "/contact";

  return (
    <div className="flex min-h-screen flex-col bg-ink text-textPrimary">
      {isContactPage ? (
        <GameMenu />
      ) : (
        <header className="site-layout-header px-6 py-5">
          <div className="mx-auto flex max-w-6xl items-center gap-4">
            <GameMenu />
            {!isMinimalNavigationPage ? (
              <Link
                className="text-lg font-semibold text-textPrimary transition hover:text-heading"
                to="/home"
              >
                Home
              </Link>
            ) : null}
            {!isMinimalNavigationPage ? (
              <nav aria-label="Main" className="ml-auto flex gap-5 text-sm text-textSecondary">
                <Link className="font-medium text-accent transition hover:text-textPrimary" to="/">
                  Play Backword
                </Link>
                <Link className="transition hover:text-textPrimary" to="/info">
                  Info
                </Link>
                <Link className="transition hover:text-textPrimary" to="/privacy">
                  Privacy
                </Link>
                <Link className="transition hover:text-textPrimary" to="/terms">
                  Terms
                </Link>
              </nav>
            ) : null}
          </div>
        </header>
      )}
      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}
