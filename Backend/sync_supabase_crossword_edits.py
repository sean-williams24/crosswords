#!/usr/bin/env python3
"""
Sync reviewed Supabase crossword clue edits back into word_bank.json.

Review-first workflow:
  python3 Backend/sync_supabase_crossword_edits.py export --start-date 2026-07-01 --end-date 2026-07-07
  python3 Backend/sync_supabase_crossword_edits.py apply --input Backend/supabase_crossword_edit_replacements.json

Export never mutates Supabase or word_bank.json. Apply only updates word_bank.json
from reviewed replacements and validates current values before writing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from answer_leakage import clue_ideas_are_redundant, redundant_clue_groups, scan_text


BANK_PATH = Path(__file__).parent / "word_bank.json"
OUTPUT_PATH = Path(__file__).parent / "supabase_crossword_edit_replacements.json"
CLUE_FIELD_RE = re.compile(r"^clues\[(\d+)\]$")
SMART_TRANSLATION = str.maketrans({
    "\u2018": "'",
    "\u2019": "'",
    "\u201c": '"',
    "\u201d": '"',
    "\u2013": "-",
    "\u2014": "-",
})

TABLES = {
    "daily": {
        "table": "puzzles",
        "textTarget": "text",
        "hintTarget": "clues",
    },
    "weekly": {
        "table": "weekly_puzzles",
        "textTarget": "clues",
        "hintTarget": "hard_text",
    },
}


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
        venv_python = Path(__file__).parent / ".venv" / "bin" / "python3"
        if venv_python.exists():
            print(
                "ERROR: supabase package not installed for this Python. "
                f"Run with the backend venv instead: {venv_python} Backend/sync_supabase_crossword_edits.py ...",
                file=sys.stderr,
            )
        else:
            print("ERROR: supabase package not installed. Run: pip install -r Backend/requirements.txt", file=sys.stderr)
        raise SystemExit(1)

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        print("ERROR: SUPABASE_URL and SUPABASE_KEY are required.", file=sys.stderr)
        raise SystemExit(1)
    return create_client(url, key)


def load_entries(path: Path) -> list[dict[str, Any]]:
    with path.open() as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"Expected top-level JSON array in {path}")
    return data


def save_entries(path: Path, entries: list[dict[str, Any]]) -> None:
    path.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")


def fetch_rows(table_key: str, start_date: str, end_date: str) -> list[dict[str, Any]]:
    table = TABLES[table_key]["table"]
    rows = (
        client()
        .table(table)
        .select("id,date,puzzle_number,clues")
        .gte("date", start_date)
        .lte("date", end_date)
        .order("date")
        .execute()
    )
    return rows.data or []


def build_word_index(entries: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    index: dict[str, dict[str, Any]] = {}
    for entry_index, entry in enumerate(entries):
        word = str(entry.get("word", "")).strip().upper()
        if word and word not in index:
            index[word] = {"index": entry_index, "entry": entry}
    return index


def normalize_value(value: Any) -> str:
    return str(value or "").strip()


def normalize_review_match(value: Any) -> str:
    normalized = normalize_value(value).translate(SMART_TRANSLATION)
    normalized = normalized.rstrip(".?!")
    normalized = re.sub(r"\s+", " ", normalized)
    return normalized.lower()


def clue_label(index: int) -> str:
    return f"clues[{index}]"


def parse_clue_label(field: str) -> int | None:
    match = CLUE_FIELD_RE.match(field)
    return int(match.group(1)) if match else None


def get_field(entry: dict[str, Any], field: str) -> str:
    clue_index = parse_clue_label(field)
    if clue_index is not None:
        clues = entry.get("clues") or []
        if clue_index >= len(clues):
            raise IndexError(f"{entry.get('word')} {field} is out of range")
        return normalize_value(clues[clue_index])
    return normalize_value(entry.get(field))


def set_field(entry: dict[str, Any], field: str, value: str) -> None:
    clue_index = parse_clue_label(field)
    if clue_index is not None:
        clues = entry.setdefault("clues", [])
        if clue_index >= len(clues):
            raise IndexError(f"{entry.get('word')} {field} is out of range")
        clues[clue_index] = value
        return
    entry[field] = value


def active_fields(entry: dict[str, Any]) -> list[tuple[str, str]]:
    values = []
    for field in ("text", "hard_text"):
        value = normalize_value(entry.get(field))
        if value:
            values.append((field, value))
    for index, clue in enumerate(entry.get("clues") or []):
        value = normalize_value(clue)
        if value:
            values.append((clue_label(index), value))
    return values


def validate_replacement(entry: dict[str, Any], field: str, current: str, proposed: str) -> None:
    word = normalize_value(entry.get("word")).upper()
    if field == "hint":
        raise ValueError(f"{word} hint is dormant fallback metadata and is not updated by this script")
    if field not in {"text", "hard_text"} and parse_clue_label(field) is None:
        raise ValueError(f"{word} unsupported replacement field: {field}")

    actual = get_field(entry, field)
    if actual != current:
        raise ValueError(f"{word} {field} changed since export: expected {current!r}, found {actual!r}")
    if not proposed:
        raise ValueError(f"{word} {field} proposed value is empty")

    leakage = scan_text(word, proposed)
    if leakage:
        reasons = ", ".join(issue.reason for issue in leakage)
        raise ValueError(f"{word} {field} proposed value leaks answer ({reasons}): {proposed!r}")

    candidate = deepcopy(entry)
    set_field(candidate, field, proposed)
    grouped = redundant_clue_groups(active_fields(candidate))
    for _, matches in grouped.items():
        if any(match_field == field for match_field, _ in matches):
            fields = ", ".join(match_field for match_field, _ in matches)
            raise ValueError(f"{word} {field} duplicates an active clue idea with {fields}: {proposed!r}")

    for other_field, other_value in active_fields(candidate):
        if other_field != field and clue_ideas_are_redundant(proposed, other_value):
            raise ValueError(f"{word} {field} is redundant with {other_field}: {proposed!r}")


def direct_replacement(
    *,
    table_key: str,
    row: dict[str, Any],
    clue: dict[str, Any],
    entry_index: int,
    entry: dict[str, Any],
    supabase_field: str,
    target_field: str,
) -> dict[str, Any] | None:
    proposed = normalize_value(clue.get(supabase_field))
    current = get_field(entry, target_field)
    if not proposed or proposed == current:
        return None
    return replacement_item(
        status="ready",
        table_key=table_key,
        row=row,
        clue=clue,
        entry_index=entry_index,
        field=target_field,
        current=current,
        proposed=proposed,
        supabase_field=supabase_field,
    )


def clue_array_replacement(
    *,
    table_key: str,
    row: dict[str, Any],
    clue: dict[str, Any],
    entry_index: int,
    entry: dict[str, Any],
    supabase_field: str,
) -> dict[str, Any] | None:
    proposed = normalize_value(clue.get(supabase_field))
    if not proposed:
        return None

    source_field = clue.get(f"{supabase_field}SourceField")
    source_index = clue.get(f"{supabase_field}SourceIndex")
    clues = [normalize_value(value) for value in entry.get("clues") or []]

    if source_field == "clues" and isinstance(source_index, int) and 0 <= source_index < len(clues):
        field = clue_label(source_index)
        current = clues[source_index]
        if proposed == current:
            return None
        return replacement_item(
            status="ready",
            table_key=table_key,
            row=row,
            clue=clue,
            entry_index=entry_index,
            field=field,
            current=current,
            proposed=proposed,
            supabase_field=supabase_field,
        )

    exact_matches = [index for index, value in enumerate(clues) if value == proposed]
    if exact_matches:
        return None

    item = replacement_item(
        status="manualReviewRequired",
        table_key=table_key,
        row=row,
        clue=clue,
        entry_index=entry_index,
        field=None,
        current=None,
        proposed=proposed,
        supabase_field=supabase_field,
    )
    item["reason"] = "Missing source metadata for edited clues[] value"
    item["candidateFields"] = [
        {"field": clue_label(index), "current": current}
        for index, current in enumerate(clues)
    ]
    return item


def replacement_item(
    *,
    status: str,
    table_key: str,
    row: dict[str, Any],
    clue: dict[str, Any],
    entry_index: int,
    field: str | None,
    current: str | None,
    proposed: str,
    supabase_field: str,
) -> dict[str, Any]:
    answer = normalize_value(clue.get("answer")).upper()
    return {
        "id": f"{table_key}:{row.get('date')}:{clue.get('id')}:{answer}:{supabase_field}",
        "status": status,
        "table": TABLES[table_key]["table"],
        "date": row.get("date"),
        "puzzleNumber": row.get("puzzle_number"),
        "rowId": row.get("id"),
        "clueId": clue.get("id"),
        "clueNumber": clue.get("number"),
        "direction": clue.get("direction"),
        "answer": answer,
        "wordBankIndex": entry_index,
        "supabaseField": supabase_field,
        "field": field,
        "current": current,
        "proposed": proposed,
    }


def scan_rows(entries: list[dict[str, Any]], rows_by_table: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    word_index = build_word_index(entries)
    replacements: list[dict[str, Any]] = []

    for table_key, rows in rows_by_table.items():
        for row in rows:
            for clue in row.get("clues") or []:
                answer = normalize_value(clue.get("answer")).upper()
                indexed = word_index.get(answer)
                if not indexed:
                    continue
                entry_index = int(indexed["index"])
                entry = indexed["entry"]

                for supabase_field in ("text", "hint"):
                    target = TABLES[table_key][f"{supabase_field}Target"]
                    if target == "clues":
                        item = clue_array_replacement(
                            table_key=table_key,
                            row=row,
                            clue=clue,
                            entry_index=entry_index,
                            entry=entry,
                            supabase_field=supabase_field,
                        )
                    else:
                        item = direct_replacement(
                            table_key=table_key,
                            row=row,
                            clue=clue,
                            entry_index=entry_index,
                            entry=entry,
                            supabase_field=supabase_field,
                            target_field=target,
                        )
                    if item:
                        replacements.append(item)

    return deduplicate_ready_replacements(replacements)


def deduplicate_ready_replacements(replacements: list[dict[str, Any]]) -> list[dict[str, Any]]:
    deduped: list[dict[str, Any]] = []
    seen_ready: set[tuple[Any, ...]] = set()
    for item in replacements:
        if item.get("status") != "ready":
            deduped.append(item)
            continue
        key = (
            item.get("answer"),
            item.get("field"),
            item.get("current"),
            item.get("proposed"),
        )
        if key in seen_ready:
            continue
        seen_ready.add(key)
        deduped.append(item)
    return deduped


def build_report(
    *,
    entries: list[dict[str, Any]],
    rows_by_table: dict[str, list[dict[str, Any]]],
    replacements: list[dict[str, Any]],
    bank_path: Path,
    start_date: str,
    end_date: str,
) -> dict[str, Any]:
    ready = sum(1 for item in replacements if item.get("status") == "ready")
    manual = sum(1 for item in replacements if item.get("status") == "manualReviewRequired")
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sourceBank": str(bank_path),
        "startDate": start_date,
        "endDate": end_date,
        "tables": [TABLES[key]["table"] for key in rows_by_table],
        "wordBankEntryCount": len(entries),
        "rowCount": sum(len(rows) for rows in rows_by_table.values()),
        "replacementCount": len(replacements),
        "readyReplacementCount": ready,
        "manualReviewCount": manual,
        "instructions": (
            "Rows with status=manualReviewRequired need field/current copied from one candidateFields item "
            "before apply. The dormant word_bank hint field is intentionally not updated."
        ),
        "replacements": replacements,
    }


def apply_report(entries: list[dict[str, Any]], report: dict[str, Any]) -> int:
    changed = 0
    for item in report.get("replacements", []):
        apply_replacement_item(entries, item)
        changed += 1
    return changed


def apply_replacement_item(entries: list[dict[str, Any]], item: dict[str, Any]) -> None:
    field = item.get("field")
    current = item.get("current")
    proposed = normalize_value(item.get("proposed"))
    status = item.get("status")
    if not field or current is None:
        raise ValueError(f"{item.get('id')} requires manual field/current review before apply")
    if status not in {"ready", "manualReviewRequired"}:
        raise ValueError(f"{item.get('id')} has unsupported status: {status}")

    index = int(item["wordBankIndex"])
    if index >= len(entries):
        raise IndexError(f"Replacement index out of range: {index}")
    entry = entries[index]
    if normalize_value(entry.get("word")).upper() != normalize_value(item.get("answer")).upper():
        raise ValueError(
            f"Word mismatch at index {index}: expected {item.get('answer')}, found {entry.get('word')}"
        )

    validate_replacement(entry, str(field), str(current), proposed)
    set_field(entry, str(field), proposed)


def validate_report(entries: list[dict[str, Any]], report: dict[str, Any]) -> list[str]:
    trial_entries = deepcopy(entries)
    errors: list[str] = []
    for item in report.get("replacements", []):
        try:
            apply_replacement_item(trial_entries, item)
        except (IndexError, ValueError) as error:
            errors.append(str(error))
    return errors


def print_validation_errors(errors: list[str]) -> None:
    print(f"Validation failed: {len(errors)} replacement(s) need review. No changes were written.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)


def resolve_obvious_manual_items(report: dict[str, Any]) -> int:
    resolved = 0
    for item in report.get("replacements", []):
        if item.get("status") != "manualReviewRequired":
            continue
        if item.get("field") or item.get("current") is not None:
            continue

        proposed_key = normalize_review_match(item.get("proposed"))
        matches = [
            candidate
            for candidate in item.get("candidateFields", [])
            if normalize_review_match(candidate.get("current")) == proposed_key
        ]
        if len(matches) != 1:
            continue

        item["field"] = matches[0]["field"]
        item["current"] = matches[0]["current"]
        item["status"] = "ready"
        item["autoResolvedReason"] = "candidate matched proposed value after punctuation/smart-quote normalization"
        resolved += 1
    return resolved


def parse_tables(value: str) -> list[str]:
    keys = [part.strip() for part in value.split(",") if part.strip()]
    invalid = [key for key in keys if key not in TABLES]
    if invalid:
        raise argparse.ArgumentTypeError(f"Unsupported table key(s): {', '.join(invalid)}")
    return keys or ["daily", "weekly"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sync reviewed Supabase crossword edits back into word_bank.json.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    export = subparsers.add_parser("export", help="Export reviewed Supabase edits as proposed word-bank replacements.")
    export.add_argument("--start-date", required=True, help="Inclusive start date, YYYY-MM-DD")
    export.add_argument("--end-date", required=True, help="Inclusive end date, YYYY-MM-DD")
    export.add_argument("--tables", type=parse_tables, default=["daily", "weekly"], help="Comma-separated: daily,weekly")
    export.add_argument("--bank", type=Path, default=BANK_PATH)
    export.add_argument("--output", type=Path, default=OUTPUT_PATH)

    apply = subparsers.add_parser("apply", help="Apply a reviewed replacement file to word_bank.json.")
    apply.add_argument("--input", type=Path, default=OUTPUT_PATH, dest="input_path")
    apply.add_argument("--bank", type=Path, default=BANK_PATH)

    validate = subparsers.add_parser("validate", help="Validate a replacement file without updating word_bank.json.")
    validate.add_argument("--input", type=Path, default=OUTPUT_PATH, dest="input_path")
    validate.add_argument("--bank", type=Path, default=BANK_PATH)

    resolve = subparsers.add_parser("resolve-obvious", help="Fill obvious manual review items in a replacement file.")
    resolve.add_argument("--input", type=Path, default=OUTPUT_PATH, dest="input_path")
    resolve.add_argument("--output", type=Path)

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.command == "export":
        entries = load_entries(args.bank)
        rows_by_table = {
            table_key: fetch_rows(table_key, args.start_date, args.end_date)
            for table_key in args.tables
        }
        replacements = scan_rows(entries, rows_by_table)
        report = build_report(
            entries=entries,
            rows_by_table=rows_by_table,
            replacements=replacements,
            bank_path=args.bank,
            start_date=args.start_date,
            end_date=args.end_date,
        )
        args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        print(
            f"Exported {report['replacementCount']} replacement(s) "
            f"({report['readyReplacementCount']} ready, {report['manualReviewCount']} manual) "
            f"from {report['rowCount']} row(s) to {args.output}"
        )
        return

    if args.command == "apply":
        if not args.input_path.exists():
            print(f"Replacement file not found: {args.input_path}", file=sys.stderr)
            raise SystemExit(1)
        entries = load_entries(args.bank)
        report = json.loads(args.input_path.read_text())
        errors = validate_report(entries, report)
        if errors:
            print_validation_errors(errors)
            raise SystemExit(1)
        changed = apply_report(entries, report)
        save_entries(args.bank, entries)
        print(f"Applied {changed} reviewed replacement(s) to {args.bank}")
        return

    if args.command == "validate":
        if not args.input_path.exists():
            print(f"Replacement file not found: {args.input_path}", file=sys.stderr)
            raise SystemExit(1)
        entries = load_entries(args.bank)
        report = json.loads(args.input_path.read_text())
        errors = validate_report(entries, report)
        if errors:
            print_validation_errors(errors)
            raise SystemExit(1)
        print("Validation passed: replacement file is ready to apply.")
        return

    if args.command == "resolve-obvious":
        if not args.input_path.exists():
            print(f"Replacement file not found: {args.input_path}", file=sys.stderr)
            raise SystemExit(1)
        report = json.loads(args.input_path.read_text())
        resolved = resolve_obvious_manual_items(report)
        output = args.output or args.input_path
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        print(f"Resolved {resolved} obvious manual item(s) in {output}")


if __name__ == "__main__":
    main()
