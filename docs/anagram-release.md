# Anagram release sequence

The bundled iOS review puzzle is retained for SwiftUI previews and isolated
development tests. Home shows only the dated production puzzle after the
backend has a published row for that local day. Web uses the same gameplay
contract.

1. Review every row of the 30-puzzle launch artifact, including familiarity,
   spelling, accepted alternatives, and the starting scramble. Run the
   `wordfreq` review report and resolve its flagged entries. Confirm the first
   release date and issue numbers.
2. Apply the Anagram migration and verify read policies and the progress merge
   function in the target Supabase environment.
3. Publish the reviewed rows with service credentials, then read them back and
   confirm their hashes and release dates. The launch generator prepares its
   artifact locally; publishing that manually approved artifact is separate.
4. Enable the iOS production entry after the first dated row is available.
   Validate the Home card, gameplay, offline cache, account sync, and Pro
   archive against released rows.
5. Review the iOS look and gameplay. Build the web client from the same v1
   contract and parity fixtures after that review.

After launch, scheduled replenishment curates and publishes automatically.
The original 75-entry pool supplies preferred seed candidates, and additional
7–9-letter answers come from the unchanged crossword word bank. Wordfreq and
two separate AI reviews check familiarity, family suitability, and the full
answer set. The generator prefers never-used letter combinations and requires
at least 365 days before any combination repeats. A puzzle's date, issue
number, answer set, and scramble remain immutable once published.

After the launch rows are published, set the repository variable
`ANAGRAM_REPLENISHMENT_ENABLED=true` to activate the Monday workflow. It reads
all published rows, including future queued rows, and fills the buffer through
UTC today plus 30 days. A full buffer needs no AI calls or writes. A curation
failure or queue gap stops publication and creates or updates a GitHub issue;
the workflow retains the artifact and report for inspection. Manual dispatch
remains available for a one-off buffer check or replenishment. The
`SUPABASE_URL`, service-role `SUPABASE_KEY`, and `OPENAI_API_KEY` secrets must be
configured before activation.
