export function MidwordInstructions() {
  return <div className="midword-instructions">
    <section><h3>Find the connection</h3>
      <p>The missing middle word joins with both shown words to make two familiar compound words.</p>
      <p>The empty letter cells show exactly how long the answer is.</p>
      <p>Guesses must be valid English words. Invalid or repeated words do not use an attempt.</p>
      <p>You have five attempts.</p>
    </section>
    <section><h3>Example</h3><p>Starting with two words, Bank and Book.</p>
      <p>NOTE is the answer because it completes both compounds.</p>
      <div className="midword-example"><p>BANK + NOTE = BANKNOTE</p><p>NOTE + BOOK = NOTEBOOK</p></div>
    </section>
    <section><h3>Scoring</h3><dl className="midword-scoring">
      {["First guess", "Second guess", "Third guess", "Fourth guess", "Fifth guess", "Not solved"].map((label, index) =>
        <div key={label}><dt>{label}</dt><dd>{5 - index} {index === 4 ? "pt" : "pts"}</dd></div>)}
    </dl><p>Only a solve completed on the puzzle’s release day adds points to your rolling 14-day rating.</p></section>
  </div>;
}
