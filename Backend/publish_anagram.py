"""Publish an explicitly approved Anagram batch in one Supabase insert.

This is a manual operation. Generation and scheduled review workflows never
invoke it. Set reviewStatus to "approved" only after editorial signoff.
"""

from __future__ import annotations

import argparse
from datetime import date, timedelta
import json
import os
from pathlib import Path

from generate_anagram import load_pool, prepare, read_published_rows, validate_rows


def validate_publication(artifact: dict, existing: list[dict]) -> list[dict]:
    if artifact.get("reviewStatus") != "approved":
        raise ValueError("Editorial signoff is required: reviewStatus must be approved")
    if artifact.get("frequencyReview") != "reviewed":
        raise ValueError("wordfreq report must be reviewed before publication")
    rows = artifact["rows"]
    if not rows:
        raise ValueError("Empty batch")
    validate_rows(rows, existing)
    if existing:
        expected_date = max(date.fromisoformat(row["date"]) for row in existing) + timedelta(days=1)
        expected_issue = max(row["puzzle_number"] for row in existing) + 1
    else:
        expected_date = date.fromisoformat(artifact["firstReleaseDate"])
        expected_issue = 1
    expected = prepare(expected_date, expected_issue, len(rows), load_pool())
    if rows != expected:
        raise ValueError("Batch differs from the approved pool or next contiguous issue/date range")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--yes", action="store_true", help="Confirm the reviewed batch should be inserted")
    args = parser.parse_args()
    if not args.yes:
        parser.error("Publication requires --yes")
    artifact = json.loads(args.artifact.read_text())
    existing = read_published_rows()
    rows = validate_publication(artifact, existing)
    from supabase import create_client
    client = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
    client.table("anagram_puzzles").insert(rows).execute()
    print(f"Published {len(rows)} Anagram rows, issues {rows[0]['puzzle_number']}–{rows[-1]['puzzle_number']}")


if __name__ == "__main__":
    main()
