# BackWord

## Historical Backword clue repairs

`Backend/repair_backword_clues.py` repairs released Backword archive clues using
a review-first workflow. Run `export-codex` to use this Codex conversation for
interactive clue authoring without an OpenAI API key, or `propose` for the
API-backed workflow. Review the generated artifact, change every `proposed`
status to `approved` or `skipped`, then run `apply`.

For the interactive route, provide the full snapshot-matched decisions from
Codex to `record-codex --input … --decisions …`. It creates the same review
artifact used by `apply`; it never writes to Supabase.
The tool only reads rows dated today or earlier, retains legacy category metadata,
and safely supports idempotent `apply` and `rollback` operations.

The API-backed proposal command requires `OPENAI_API_KEY`; `export-codex`
requires only Supabase read credentials.
Applying or rolling back additionally requires `SUPABASE_URL` and a service-role
`SUPABASE_KEY`; the public `VITE_SUPABASE_ANON_KEY` in `web/.env` must not be
used to write rows. Run `python3 Backend/repair_backword_clues.py --help` for
the exact commands and options.
