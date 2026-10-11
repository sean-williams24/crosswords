import { InstructionRow, InstructionSection } from "../../components/GameInstructions";

export function MidwordInstructions() {
  return <div className="game-instructions midword-instructions">
    <InstructionSection icon="connection" title="Find the connection">
      <InstructionRow icon="letters">The missing middle word joins with both shown words to make two familiar compound words.</InstructionRow>
      <InstructionRow icon="cells">The empty letter cells show exactly how long the answer is.</InstructionRow>
      <InstructionRow icon="dictionary">Guesses must be valid English words. Invalid or repeated words do not use an attempt.</InstructionRow>
      <InstructionRow icon="attempts">You have five attempts.</InstructionRow>
    </InstructionSection>
    <InstructionSection icon="example" title="Example"><p>Starting with two words, Bank and Book.</p>
      <p>NOTE is the answer because it completes both compounds.</p>
      <div className="midword-example"><p>BANK + NOTE = BANKNOTE</p><p>NOTE + BOOK = NOTEBOOK</p></div>
    </InstructionSection>
    <InstructionSection icon="scoring" title="Scoring"><dl className="game-instructions__scoring">
      {["First guess", "Second guess", "Third guess", "Fourth guess", "Fifth guess", "Not solved"].map((label, index) =>
        <div key={label}><dt>{label}</dt><dd>{5 - index} {index === 4 ? "pt" : "pts"}</dd></div>)}
    </dl><p>Only a solve completed on the puzzle’s release day adds points to your rolling 14-day rating.</p></InstructionSection>
  </div>;
}
