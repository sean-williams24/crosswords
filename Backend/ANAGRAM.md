# Anagram content release

`anagram_pool.json` contains 75 previously curated seed candidates. The 30-day
launch artifact was manually approved; published rows stay immutable. Future
issue numbers follow the Supabase queue, not pool positions. The unchanged
crossword bank contains 11,436 eligible 7–9-letter ASCII entries. The Monday
job searches it for additional candidates and maintains 30 future release
days. It requires a primary wordfreq Zipf score of at least 3.5. Every common
alternative found in the bank is presented to two separate AI reviews, along
with likely missing alternatives from wordfreq's top 200,000 English words.
Both reviews must agree on the accepted answer set. Any accepted external
alternative causes the group to be rejected rather than silently omitting it.
The script also validates scrambles, release sequence, exact reviewer responses,
and a minimum 365-day gap between repeated letter combinations. It prefers
never-used combinations.

The original pool frequency report can still be regenerated with:

```bash
python3 Backend/review_anagram_frequency.py \
  --output Backend/anagram_frequency_review.json
```

The frequency report remains historical evidence for the seed pool. Automated
artifacts include their own scores, ranks, reviewer verdicts, source and prompt
digests, policy version, and a digest of the exact artifact contents.

The reviewed 30-day launch artifact is `anagram_launch_2026-09-26.json`. It is
approved for publication beginning 26 September 2026. If the release date
changes, regenerate it and repeat editorial review before publication:

```bash
python3 Backend/generate_anagram.py \
  --start-date YYYY-MM-DD --first-issue 1 --count 30 \
  --output Backend/anagram_launch_YYYY-MM-DD.json
```

After the launch rows are published, the scheduled job can fill the buffer:

```bash
SUPABASE_URL=... SUPABASE_KEY=... OPENAI_API_KEY=... \
  python3 Backend/automate_anagram.py --publish \
  --output /tmp/anagram-replenishment.json \
  --report /tmp/anagram-review-report.json
```

Use a service-role key so the read includes future queued rows. `--dry-run`
instead of `--publish` performs curation and writes the artifact without
inserting rows. `--today YYYY-MM-DD` sets the UTC planning date for a replay or
test; `--model` changes the reviewer model. A full buffer is a successful no-op
with no AI calls or writes. Missing launch rows, a gap, insufficient reviewed
answers after eight 42-group candidate batches, API errors that prevent a full
batch, or publication/readback failure stop the run and produce a report. The
workflow uploads the report and creates or updates a GitHub issue on failure.

The manually approved launch artifact remains supported. To publish one of
those historical artifacts explicitly:

```bash
SUPABASE_URL=... SUPABASE_KEY=... python3 Backend/publish_anagram.py \
  approved-artifact.json --yes
```

Publication re-reads the remote queue immediately before insert, verifies the
manual pool match or the automated evidence against current sources, inserts
the entire batch in one request, then reads the rows back. No upsert is used;
the table rejects later row edits or deletion. Repository variable
`ANAGRAM_REPLENISHMENT_ENABLED=true` enables the Monday 09:30 UTC schedule.
Manual workflow dispatch remains available.
