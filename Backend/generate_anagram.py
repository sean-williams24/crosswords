"""Prepare and validate immutable Anagram batches from the curated pool.

No command writes to Supabase. Publication is a separate reviewed operation.
The finite pool deliberately fails when exhausted, so new words get editorial
review rather than silently entering the game from the crossword bank.
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import date, timedelta
import hashlib
import json
import os
from pathlib import Path
import random
import uuid

ROOT = Path(__file__).resolve().parent
POOL = ROOT / "anagram_pool.json"
BANK = ROOT / "word_bank.json"
NAMESPACE = uuid.UUID("3cf90a6b-3349-46da-85a2-39253c76e004")


def signature(word: str) -> str:
    return "".join(sorted(word))


def points_for_seconds(elapsed_with_penalty: float) -> int:
    if elapsed_with_penalty < 0:
        raise ValueError("Scoring time cannot be negative")
    return next((points for limit, points in ((30, 5), (60, 4), (120, 3), (180, 2))
                 if elapsed_with_penalty < limit), 1)


def validate_entry(entry: dict, bank_words: set[str]) -> None:
    answer = entry["answer"]
    accepted = entry["acceptedAnswers"]
    if not isinstance(answer, str) or not 7 <= len(answer) <= 9 or not answer.isascii() or not answer.isalpha() or answer != answer.upper():
        raise ValueError(f"Invalid primary answer: {answer!r}")
    if answer not in bank_words:
        raise ValueError(f"Primary answer is absent from word bank: {answer}")
    if not isinstance(accepted, list) or len(accepted) != len(set(accepted)):
        raise ValueError(f"Duplicate or malformed alternatives: {answer}")
    for alternate in accepted:
        if not isinstance(alternate, str) or alternate == answer or alternate != alternate.upper() or signature(alternate) != signature(answer):
            raise ValueError(f"Invalid alternative {alternate!r} for {answer}")
        if alternate not in bank_words:
            raise ValueError(f"Alternative is absent from word bank: {alternate}")


def load_pool(pool_path: Path = POOL, bank_path: Path = BANK) -> list[dict]:
    pool = json.loads(pool_path.read_text())
    if pool["schemaVersion"] != 1 or pool["source"] != "Backend/word_bank.json":
        raise ValueError("Unsupported pool version or source")
    bank_words = {entry["word"].upper() for entry in json.loads(bank_path.read_text())}
    entries = pool["entries"]
    seen: set[str] = set()
    for entry in entries:
        validate_entry(entry, bank_words)
        key = signature(entry["answer"])
        if key in seen:
            raise ValueError(f"Repeated letter combination: {entry['answer']}")
        seen.add(key)
    return entries


def scramble(entry: dict, issue: int) -> str:
    answer = entry["answer"]
    excluded = {answer, *entry["acceptedAnswers"]}
    letters = list(answer)
    rng = random.Random(f"anagram-v1:{issue}:{answer}")
    for _ in range(100):
        rng.shuffle(letters)
        candidate = "".join(letters)
        if candidate not in excluded:
            return candidate
    raise ValueError(f"Could not scramble {answer}")


def hint_cell_index(entry: dict, issue: int) -> int:
    """Choose a stable position that preserves as many approved answers as possible."""
    answer = entry["answer"]
    alternatives = entry["acceptedAnswers"]
    compatibility = [sum(other[index] == letter for other in alternatives)
                     for index, letter in enumerate(answer)]
    best_count = max(compatibility)
    best = [index for index, count in enumerate(compatibility)
            if count == best_count]
    digest = hashlib.sha256(f"anagram-hint-v1:{issue}:{answer}".encode()).digest()
    return best[int.from_bytes(digest, "big") % len(best)]


def make_row(release: date, issue: int, entry: dict, *, include_hint: bool = True) -> dict:
    puzzle_data = {
        "answer": entry["answer"],
        "acceptedAnswers": entry["acceptedAnswers"],
        "initialScramble": scramble(entry, issue),
    }
    if include_hint:
        puzzle_data["hintCellIndex"] = hint_cell_index(entry, issue)
    return {
        "id": str(uuid.uuid5(NAMESPACE, f"anagram-v1:{issue}:{release.isoformat()}")),
        "date": release.isoformat(),
        "puzzle_number": issue,
        "schema_version": 1,
        "puzzle_data": puzzle_data,
    }


def prepare(start_date: date, first_issue: int, count: int, pool: list[dict],
            *, include_hint: bool = True) -> list[dict]:
    if first_issue < 1 or count < 1 or first_issue + count - 1 > len(pool):
        raise ValueError("Requested range exceeds the approved finite pool")
    rows = []
    for index in range(count):
        issue = first_issue + index
        release = start_date + timedelta(days=index)
        entry = pool[issue - 1]
        rows.append(make_row(release, issue, entry, include_hint=include_hint))
    validate_rows(rows)
    return rows


def validate_rows(rows: list[dict], existing: list[dict] | None = None) -> None:
    all_rows = sorted([*(existing or []), *rows], key=lambda row: row["date"])
    if existing is not None and all_rows and all_rows[0]["puzzle_number"] != 1:
        raise ValueError("Anagram sequence must start at issue 1")
    dates: set[str] = set()
    issues: set[int] = set()
    previous_by_signature: dict[str, date] = {}
    previous_date: date | None = None
    previous_issue: int | None = None
    for row in all_rows:
        release = date.fromisoformat(row["date"])
        issue = row["puzzle_number"]
        if row["date"] in dates or issue in issues:
            raise ValueError(f"Duplicate date or issue: {release} / {issue}")
        if previous_date is not None and (release != previous_date + timedelta(days=1) or issue != previous_issue + 1):
            raise ValueError(f"Gap in Anagram date or issue before {release} / {issue}")
        dates.add(row["date"])
        issues.add(issue)
        previous_date = release
        previous_issue = issue
        if row["schema_version"] != 1:
            raise ValueError(f"Unsupported puzzle schema: {issue}")
        data = row["puzzle_data"]
        answer = data["answer"]
        accepted = data["acceptedAnswers"]
        initial = data["initialScramble"]
        if not 7 <= len(answer) <= 9 or answer != answer.upper() or not answer.isascii() or not answer.isalpha():
            raise ValueError(f"Invalid answer: {issue}")
        if len(accepted) != len(set(accepted)) or any(a == answer or signature(a) != signature(answer) for a in accepted):
            raise ValueError(f"Invalid alternatives: {issue}")
        if signature(initial) != signature(answer) or initial in {answer, *accepted}:
            raise ValueError(f"Invalid scramble: {issue}")
        if "hintCellIndex" in data:
            hint_index = data["hintCellIndex"]
            if type(hint_index) is not int or not 0 <= hint_index < len(answer):
                raise ValueError(f"Invalid hint position: {issue}")
            matching = sum(other[hint_index] == answer[hint_index] for other in accepted)
            best_matching = max(sum(other[index] == letter for other in accepted)
                                for index, letter in enumerate(answer))
            if matching != best_matching:
                raise ValueError(f"Hint excludes avoidable alternatives: {issue}")
        key = signature(answer)
        prior = previous_by_signature.get(key)
        if prior is not None and (release - prior).days < 365:
            raise ValueError(f"Letter combination repeats within 365 days: {answer}")
        previous_by_signature[key] = release


def read_published_rows() -> list[dict]:
    """Read every dated row using service credentials, including future dates."""
    try:
        from supabase import create_client
    except ImportError as error:
        raise RuntimeError("Install Backend/requirements.txt for Supabase reads") from error
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        raise RuntimeError("SUPABASE_URL and service-role SUPABASE_KEY are required")
    client = create_client(url, key)
    rows: list[dict] = []
    offset = 0
    while True:
        page = client.table("anagram_puzzles").select("id,date,puzzle_number,schema_version,puzzle_data").order("date").range(offset, offset + 999).execute().data
        rows.extend(page)
        if len(page) < 1000:
            break
        offset += len(page)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start-date", type=date.fromisoformat)
    parser.add_argument("--first-issue", type=int)
    parser.add_argument("--count", type=int, default=30)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--existing", type=Path, help="Previously prepared or exported rows to check for collisions")
    parser.add_argument("--from-supabase", action="store_true", help="Read published queue and derive the next issue/date; never writes")
    args = parser.parse_args()
    pool = load_pool()
    if args.from_supabase:
        if args.start_date or args.first_issue or args.existing:
            parser.error("--from-supabase derives dates and issues; do not pass manual range options")
        existing = read_published_rows()
        if not existing:
            parser.error("No published Anagram rows; prepare and publish the launch batch first")
        start_date = max(date.fromisoformat(row["date"]) for row in existing) + timedelta(days=1)
        first_issue = max(row["puzzle_number"] for row in existing) + 1
    else:
        if not args.start_date:
            parser.error("--start-date is required without --from-supabase")
        start_date = args.start_date
        first_issue = args.first_issue or 1
        existing = json.loads(args.existing.read_text())["rows"] if args.existing else []
    rows = prepare(start_date, first_issue, args.count, pool)
    validate_rows(rows, existing)
    artifact = {
        "schemaVersion": 1,
        "reviewStatus": "requires_editorial_signoff_before_publication",
        "frequencyReview": "pending_wordfreq_report",
        "firstReleaseDate": start_date.isoformat(),
        "rows": rows,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(artifact, indent=2) + "\n")
    print(f"Prepared {len(rows)} Anagram rows through {rows[-1]['date']} in {args.output}; publication requires review")


if __name__ == "__main__":
    main()
