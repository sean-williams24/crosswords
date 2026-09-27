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
   confirm their hashes and release dates. Publication is a separate approved
   operation; generating a batch never writes to Supabase.
4. Enable the iOS production entry after the first dated row is available.
   Validate the Home card, gameplay, offline cache, account sync, and Pro
   archive against released rows.
5. Review the iOS look and gameplay. Build the web client from the same v1
   contract and parity fixtures after that review.

Scheduled replenishment produces review artifacts only. It does not publish
unreviewed content. The content pool is independent of the crossword word bank,
and a puzzle's date, issue number, answer set, and scramble are immutable once
released.

After the launch rows are published, set the repository variable
`ANAGRAM_REPLENISHMENT_ENABLED=true` to activate the Monday workflow. It reads
the published rows, creates a 14-day review artifact, and stops on exhausted
content or a gap in the published sequence. Manual dispatch remains available
for a one-off review batch.
