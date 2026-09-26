# Anagram content release

`anagram_pool.json` is a finite, separate selection from the unchanged crossword
bank. The current bank has 11,436 eligible 7–9 letter ASCII entries (22,299
entries total); the plan's 9,753 count reflects an earlier snapshot. The pool
has 75 familiar, family-friendly answers. Alternatives are included
only where they are bank-backed, common standalone words. The pool is ordered:
issue N always uses entry N, which makes replenishment repeatable. Its
`reviewStatus` and each prepared artifact require editorial signoff before
publication. The script checks spelling, multisets, issue/date uniqueness,
scrambles, and repeats within 365 days; semantic suitability still needs a
human reviewer. Frequency is evidence for that review, not an automatic gate.
Run this after installing `Backend/requirements.txt` to get a zipf score and
top-200,000 rank for every primary and alternative answer:

```bash
python3 Backend/review_anagram_frequency.py \
  --output Backend/anagram_frequency_review.json
```

The frequency report cannot be generated in an environment lacking `wordfreq`.
The prepared artifact records `frequencyReview: pending_wordfreq_report` until
an editor checks the report and changes it to `reviewed`.

The reviewed 30-day launch artifact is `anagram_launch_2026-10-01.json`. It is
approved for publication beginning 1 October 2026. If the release date changes,
regenerate it and repeat editorial review before publication:

```bash
python3 Backend/generate_anagram.py \
  --start-date YYYY-MM-DD --first-issue 1 --count 30 \
  --output Backend/anagram_launch_YYYY-MM-DD.json
```

After the `20260925_add_anagram_v1.sql` migration and launch publication, a
scheduled job can prepare the next 14-day batch without modifying Supabase:

```bash
SUPABASE_URL=... SUPABASE_KEY=... python3 Backend/generate_anagram.py \
  --from-supabase --count 14 --output /tmp/anagram-replenishment.json
```

The key must be the service-role key so the read includes future queued rows.
The command derives the next date and issue from that queue and fails closed
when the pool runs out. The artifact can be attached to a review issue. Once an
editor has checked the frequency report, answers, alternatives, and date range,
set that exact artifact's `frequencyReview` to `reviewed` and `reviewStatus` to
`approved`, then publish with:

```bash
SUPABASE_URL=... SUPABASE_KEY=... python3 Backend/publish_anagram.py \
  approved-artifact.json --yes
```

Publication validates the batch against the fixed pool and the remote queue,
then inserts all rows in one request. No upsert is used, and the table rejects
later row edits or deletion. Launch and replenishment scripts never publish on
their own.
