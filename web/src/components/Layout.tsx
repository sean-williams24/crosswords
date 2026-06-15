import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import { Footer } from "./Footer";

type LayoutProps = {
  children: ReactNode;
};

export function Layout({ children }: LayoutProps) {
  return (
    <div className="min-h-screen bg-ink text-textPrimary">
      <header className="px-6 py-5">
        <div className="mx-auto flex max-w-6xl items-center justify-between">
          <Link
            className="text-lg font-semibold text-textPrimary transition hover:text-heading"
            to="/"
          >
            Backword
          </Link>
          <nav aria-label="Main" className="flex gap-5 text-sm text-textSecondary">
            <Link className="transition hover:text-textPrimary" to="/privacy">
              Privacy
            </Link>
            <Link className="transition hover:text-textPrimary" to="/terms">
              Terms
            </Link>
          </nav>
        </div>
      </header>
      <main>{children}</main>
      <Footer />
    </div>
  );
}
