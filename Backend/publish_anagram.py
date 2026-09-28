"""Publish a manually signed-off or automatically reviewed Anagram batch."""

from __future__ import annotations

import argparse
from datetime import date, timedelta
import json
import os
from pathlib import Path

from generate_anagram import load_pool, prepare, read_published_rows, validate_rows


def validate_publication(artifact: dict, existing: list[dict]) -> list[dict]:
    if artifact.get("approvalMode") == "automated":
        from automate_anagram import validate_automated_artifact
        return validate_automated_artifact(artifact, existing)
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


def publish_artifact(artifact: dict, client=None) -> list[dict]:
    """Re-read the queue, insert once, then verify the exact inserted content."""
    existing = read_published_rows()
    rows = validate_publication(artifact, existing)
    if client is None:
        from supabase import create_client
        client = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
    client.table("anagram_puzzles").insert(rows).execute()
    published = {row["date"]: row for row in read_published_rows()}
    for row in rows:
        if published.get(row["date"]) != row:
            raise RuntimeError(f"Published Anagram row did not verify: {row['date']}")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--yes", action="store_true", help="Confirm the reviewed batch should be inserted")
    args = parser.parse_args()
    if not args.yes:
        parser.error("Publication requires --yes")
    artifact = json.loads(args.artifact.read_text())
    rows = publish_artifact(artifact)
    print(f"Published {len(rows)} Anagram rows, issues {rows[0]['puzzle_number']}–{rows[-1]['puzzle_number']}")


if __name__ == "__main__":
    main()
