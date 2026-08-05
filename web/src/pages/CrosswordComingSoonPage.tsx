import { GameMenu } from "../features/backword/components/GameMenu";
import { Footer } from "../components/Footer";

export function CrosswordComingSoonPage() {
  return (
    <main className="crossword-coming-soon">
      <header className="crossword-coming-soon__header">
        <GameMenu />
        {/* <Link className="crossword-coming-soon__back" to="/home">← Back to home</Link> */}
      </header>
      <div className="crossword-coming-soon__content">
        <div className="crossword-coming-soon__copy">
          <p>QUICK CROSSWORD</p>
          <h1>Coming soon</h1>
          <span>The daily 9×9 crossword is on its way to the web.</span>
        </div>
        <img
          alt="Preview of the Quick Crossword game"
          className="crossword-coming-soon__preview"
          src="/screenshots/crossword.png"
        />
      </div>
      <Footer />
    </main>
  );
}
