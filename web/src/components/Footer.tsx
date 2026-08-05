import { Link } from "react-router-dom";

export function Footer() {
  return (
    <footer className="site-footer border-t border-line/80 px-6 py-8 text-sm text-textSecondary">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <p>© 2026 Backword</p>
        <nav aria-label="Footer" className="flex flex-wrap gap-x-5 gap-y-2">
          <Link className="transition hover:text-textPrimary" to="/home">
            Home
          </Link>
          <Link className="transition hover:text-textPrimary" to="/">
            Backword
          </Link>
          <Link className="transition hover:text-textPrimary" to="/crossword">
            Crossword
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
      </div>
    </footer>
  );
}
