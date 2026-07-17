#!/usr/bin/env python3
"""Repair released weekly puzzles whose main clue and hint are identical.

Review-first workflow:
  Backend/.venv/bin/python3 Backend/repair_weekly_duplicate_clues.py export
  Backend/.venv/bin/python3 Backend/repair_weekly_duplicate_clues.py validate
  Backend/.venv/bin/python3 Backend/repair_weekly_duplicate_clues.py apply

Export and validate never mutate Supabase. Apply updates only ready replacements
from the reviewed report and skips unresolved answers that are absent from the
current word bank.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from copy import deepcopy
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any


BANK_PATH = Path(__file__).parent / "word_bank.json"
OUTPUT_PATH = Path(__file__).parent / "weekly_duplicate_clue_replacements.json"
TABLE = "weekly_puzzles"


_env_file = Path(__file__).parent / ".env"
if _env_file.exists():
    for line in _env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())


def client():
    try:
        from supabase import create_client
    except ImportError:
        print("ERROR: supabase package not installed. Run: pip install -r Backend/requirements.txt", file=sys.stderr)
        raise SystemExit(1)

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        print("ERROR: SUPABASE_URL and SUPABASE_KEY are required.", file=sys.stderr)
        raise SystemExit(1)
    return create_client(url, key)


def load_json(path: Path) -> Any:
    with path.open() as handle:
        return json.load(handle)


def load_entries(path: Path) -> list[dict[str, Any]]:
    entries = load_json(path)
    if not isinstance(entries, list):
        raise ValueError(f"Expected top-level JSON array in {path}")
    return entries


def normalize_value(value: Any) -> str:
    return str(value or "").strip()


def normalize_match(value: Any) -> str:
    translation = str.maketrans({
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u2013": "-",
        "\u2014": "-",
    })
    normalized = normalize_value(value).translate(translation)
    normalized = " ".join(normalized.split()).rstrip(".?!")
    return normalized.lower()


def build_word_index(entries: list[dict[str, Any]]) -> dict[str, tuple[int, dict[str, Any]]]:
    index: dict[str, tuple[int, dict[str, Any]]] = {}
    for entry_index, entry in enumerate(entries):
        word = normalize_value(entry.get("word")).upper()
        if word and word not in index:
            index[word] = (entry_index, entry)
    return index


def parse_iso_date(value: str) -> str:
    try:
        return date.fromisoformat(value).isoformat()
    except ValueError as error:
        raise argparse.ArgumentTypeError("Expected an ISO date in YYYY-MM-DD format") from error


def fetch_released_rows(through_date: str) -> list[dict[str, Any]]:
    result = (
        client()
        .table(TABLE)
        .select("id,date,puzzle_number,clues")
        .lte("date", through_date)
        .order("date")
        .execute()
    )
    return result.data or []


def fetch_report_rows(report: dict[str, Any]) -> list[dict[str, Any]]:
    row_ids = sorted({
        str(item["rowId"])
        for item in report.get("replacements", [])
        if item.get("status") == "ready" and item.get("rowId")
    })
    if not row_ids:
        return []
    result = (
        client()
        .table(TABLE)
        .select("id,date,puzzle_number,clues")
        .in_("id", row_ids)
        .execute()
    )
    return result.data or []


def choose_alternative(entry: dict[str, Any], text: str, hint: str) -> tuple[int, str] | None:
    excluded = {normalize_match(text), normalize_match(hint)}
    for source_index, candidate in enumerate(entry.get("clues") or []):
        candidate_value = normalize_value(candidate)
        if candidate_value and normalize_match(candidate_value) not in excluded:
            return source_index, candidate_value
    return None


def replacement_item(
    row: dict[str, Any],
    clue: dict[str, Any],
    *,
    status: str,
    proposed_text: str | None = None,
    word_bank_index: int | None = None,
    source_index: int | None = None,
    reason: str | None = None,
) -> dict[str, Any]:
    answer = normalize_value(clue.get("answer")).upper()
    item = {
        "id": f"weekly:{row.get('date')}:{clue.get('id')}:{answer}",
        "status": status,
        "table": TABLE,
        "rowId": row.get("id"),
        "date": row.get("date"),
        "puzzleNumber": row.get("puzzle_number"),
        "clueId": clue.get("id"),
        "clueNumber": clue.get("number"),
        "direction": clue.get("direction"),
        "answer": answer,
        "currentText": normalize_value(clue.get("text")),
        "currentHint": normalize_value(clue.get("hint")),
        "currentTextSourceField": clue.get("textSourceField"),
        "currentTextSourceIndex": clue.get("textSourceIndex"),
        "proposedText": proposed_text,
        "proposedTextSourceField": "clues" if proposed_text is not None else None,
        "proposedTextSourceIndex": source_index,
        "wordBankIndex": word_bank_index,
    }
    if reason:
        item["reason"] = reason
    return item


def scan_rows(
    entries: list[dict[str, Any]],
    rows: list[dict[str, Any]],
    through_date: str,
) -> list[dict[str, Any]]:
    word_index = build_word_index(entries)
    replacements: list[dict[str, Any]] = []

    for row in rows:
        row_date = normalize_value(row.get("date"))
        if not row_date or row_date > through_date:
            continue
        for clue in row.get("clues") or []:
            text = normalize_value(clue.get("text"))
            hint = normalize_value(clue.get("hint"))
            if not text or normalize_match(text) != normalize_match(hint):
                continue

            answer = normalize_value(clue.get("answer")).upper()
            indexed = word_index.get(answer)
            if not indexed:
                replacements.append(replacement_item(
                    row,
                    clue,
                    status="unresolved",
                    reason="Answer is absent from the current word bank",
                ))
                continue

            entry_index, entry = indexed
            selected = choose_alternative(entry, text, hint)
            if selected is None:
                replacements.append(replacement_item(
                    row,
                    clue,
                    status="unresolved",
                    word_bank_index=entry_index,
                    reason="Word-bank entry has no non-identical clues[] alternative",
                ))
                continue

            source_index, proposed = selected
            replacements.append(replacement_item(
                row,
                clue,
                status="ready",
                proposed_text=proposed,
                word_bank_index=entry_index,
                source_index=source_index,
            ))

    return replacements


def build_report(
    entries: list[dict[str, Any]],
    rows: list[dict[str, Any]],
    replacements: list[dict[str, Any]],
    through_date: str,
    bank_path: Path,
) -> dict[str, Any]:
    ready = sum(item.get("status") == "ready" for item in replacements)
    unresolved = sum(item.get("status") == "unresolved" for item in replacements)
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "table": TABLE,
        "throughDate": through_date,
        "sourceBank": str(bank_path),
        "wordBankEntryCount": len(entries),
        "rowCount": len(rows),
        "duplicateCount": len(replacements),
        "readyReplacementCount": ready,
        "unresolvedCount": unresolved,
        "selectionPolicy": "First non-empty current word_bank.clues[] value differing from both text and hint",
        "instructions": "Review ready replacements before apply. Unresolved entries are reported but never updated.",
        "replacements": replacements,
    }


def find_clue(row: dict[str, Any], item: dict[str, Any]) -> dict[str, Any] | None:
    answer = normalize_value(item.get("answer")).upper()
    matches = [
        clue
        for clue in row.get("clues") or []
        if clue.get("id") == item.get("clueId")
        and normalize_value(clue.get("answer")).upper() == answer
    ]
    return matches[0] if len(matches) == 1 else None


def validate_report(
    entries: list[dict[str, Any]],
    report: dict[str, Any],
    rows: list[dict[str, Any]],
) -> tuple[list[str], int]:
    errors: list[str] = []
    already_applied = 0
    row_index = {str(row.get("id")): row for row in rows if row.get("id")}
    through_date = normalize_value(report.get("throughDate"))

    if report.get("table") != TABLE:
        errors.append(f"Report table must be {TABLE}")
    try:
        date.fromisoformat(through_date)
    except ValueError:
        errors.append("Report throughDate must be an ISO date")
    if through_date > date.today().isoformat():
        errors.append(f"Report cutoff {through_date} is later than today")

    for item in report.get("replacements", []):
        if item.get("status") == "unresolved":
            continue
        if item.get("status") != "ready":
            errors.append(f"{item.get('id')} has unsupported status: {item.get('status')}")
            continue
        if normalize_value(item.get("date")) > through_date:
            errors.append(f"{item.get('id')} is later than report cutoff {through_date}")
            continue

        try:
            entry_index = int(item["wordBankIndex"])
            source_index = int(item["proposedTextSourceIndex"])
            entry = entries[entry_index]
            answer = normalize_value(item.get("answer")).upper()
            if normalize_value(entry.get("word")).upper() != answer:
                raise ValueError("word-bank answer changed since export")
            clues = entry.get("clues") or []
            if source_index >= len(clues) or normalize_value(clues[source_index]) != item.get("proposedText"):
                raise ValueError("word-bank source clue changed since export")
        except (IndexError, KeyError, TypeError, ValueError) as error:
            errors.append(f"{item.get('id')} {error}")
            continue

        row = row_index.get(str(item.get("rowId")))
        if not row:
            errors.append(f"{item.get('id')} Supabase row is missing")
            continue
        if normalize_value(row.get("date")) != normalize_value(item.get("date")):
            errors.append(f"{item.get('id')} Supabase row date changed since export")
            continue
        if row.get("puzzle_number") != item.get("puzzleNumber"):
            errors.append(f"{item.get('id')} puzzle number changed since export")
            continue

        clue = find_clue(row, item)
        if clue is None:
            errors.append(f"{item.get('id')} Supabase clue is missing or ambiguous")
            continue

        proposed = normalize_value(item.get("proposedText"))
        is_applied = (
            normalize_value(clue.get("text")) == proposed
            and clue.get("textSourceField") == "clues"
            and clue.get("textSourceIndex") == source_index
            and normalize_value(clue.get("hint")) == item.get("currentHint")
        )
        if is_applied:
            already_applied += 1
            continue

        current_fields = {
            "text": normalize_value(clue.get("text")),
            "hint": normalize_value(clue.get("hint")),
            "textSourceField": clue.get("textSourceField"),
            "textSourceIndex": clue.get("textSourceIndex"),
        }
        expected_fields = {
            "text": item.get("currentText"),
            "hint": item.get("currentHint"),
            "textSourceField": item.get("currentTextSourceField"),
            "textSourceIndex": item.get("currentTextSourceIndex"),
        }
        if current_fields != expected_fields:
            errors.append(f"{item.get('id')} Supabase clue changed since export")
            continue
        if not proposed or normalize_match(proposed) == normalize_match(clue.get("hint")):
            errors.append(f"{item.get('id')} proposed text is empty or still duplicates the hint")

    return errors, already_applied


def prepare_updates(
    entries: list[dict[str, Any]],
    report: dict[str, Any],
    rows: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], int]:
    errors, already_applied = validate_report(entries, report, rows)
    if errors:
        raise ValueError("\n".join(errors))

    working_rows = {str(row.get("id")): deepcopy(row) for row in rows if row.get("id")}
    changed_rows: set[str] = set()
    for item in report.get("replacements", []):
        if item.get("status") != "ready":
            continue
        row_id = str(item.get("rowId"))
        row = working_rows[row_id]
        clue = find_clue(row, item)
        if clue is None:
            raise ValueError(f"{item.get('id')} Supabase clue is missing or ambiguous")
        if (
            normalize_value(clue.get("text")) == item.get("proposedText")
            and clue.get("textSourceField") == "clues"
            and clue.get("textSourceIndex") == item.get("proposedTextSourceIndex")
        ):
            continue
        clue["text"] = item["proposedText"]
        clue["textSourceField"] = "clues"
        clue["textSourceIndex"] = item["proposedTextSourceIndex"]
        changed_rows.add(row_id)

    updates = [working_rows[row_id] for row_id in sorted(changed_rows)]
    return updates, already_applied


def print_validation_errors(errors: list[str]) -> None:
    print(f"Validation failed: {len(errors)} issue(s). No Supabase changes were made.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Repair duplicate text/hint values in released weekly puzzles.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    export = subparsers.add_parser("export", help="Export reviewable released-puzzle replacements.")
    export.add_argument(
        "--through-date",
        type=parse_iso_date,
        default=date.today().isoformat(),
        help="Inclusive release-date cutoff (defaults to today and cannot be in the future)",
    )
    export.add_argument("--bank", type=Path, default=BANK_PATH)
    export.add_argument("--output", type=Path, default=OUTPUT_PATH)

    for command in ("validate", "apply"):
        subparser = subparsers.add_parser(command, help=f"{command.title()} a reviewed replacement report.")
        subparser.add_argument("--input", type=Path, default=OUTPUT_PATH, dest="input_path")
        subparser.add_argument("--bank", type=Path, default=BANK_PATH)

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.command == "export":
        if args.through_date > date.today().isoformat():
            print("ERROR: --through-date cannot be later than today.", file=sys.stderr)
            raise SystemExit(1)
        entries = load_entries(args.bank)
        rows = fetch_released_rows(args.through_date)
        replacements = scan_rows(entries, rows, args.through_date)
        report = build_report(entries, rows, replacements, args.through_date, args.bank)
        args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        print(
            f"Exported {report['duplicateCount']} duplicate(s) "
            f"({report['readyReplacementCount']} ready, {report['unresolvedCount']} unresolved) "
            f"from {report['rowCount']} released row(s) to {args.output}"
        )
        return

    if not args.input_path.exists():
        print(f"Replacement file not found: {args.input_path}", file=sys.stderr)
        raise SystemExit(1)
    entries = load_entries(args.bank)
    report = load_json(args.input_path)
    rows = fetch_report_rows(report)
    errors, already_applied = validate_report(entries, report, rows)
    if errors:
        print_validation_errors(errors)
        raise SystemExit(1)

    ready_count = sum(item.get("status") == "ready" for item in report.get("replacements", []))
    unresolved_count = sum(item.get("status") == "unresolved" for item in report.get("replacements", []))
    if args.command == "validate":
        print(
            f"Validation passed: {ready_count} ready replacement(s), "
            f"{already_applied} already applied, {unresolved_count} unresolved item(s)."
        )
        return

    updates, _ = prepare_updates(entries, report, rows)
    sb = client()
    for row in updates:
        sb.table(TABLE).update({"clues": row.get("clues") or []}).eq("id", row["id"]).execute()
    changed_clues = ready_count - already_applied
    print(
        f"Updated {changed_clues} clue(s) across {len(updates)} weekly puzzle row(s); "
        f"skipped {unresolved_count} unresolved item(s)."
    )


if __name__ == "__main__":
    main()
