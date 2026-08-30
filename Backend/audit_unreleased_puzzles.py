#!/usr/bin/env python3
"""Audit and safely patch crossword clue payloads.

The tool reads future local artifacts and Supabase rows, comparing every shown
answer/clue pair to the active word-bank certification. Remote writes require
an explicitly approved package and ``--yes``. The normal workflow deliberately
considers only future rows. The separate historical workflow can replace only
an exact old word-bank clue with its certified repaired successor.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from copy import deepcopy
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

from answer_leakage import scan_text
from word_bank_safety import CERTIFICATION_PATH, active_fields, load_certification


BACKEND_DIR = Path(__file__).resolve().parent
BANK_PATH = BACKEND_DIR / "word_bank.json"
REPORT_PATH = BACKEND_DIR / "unreleased_puzzle_giveaway_audit.json"
UPDATE_PATH = BACKEND_DIR / "unreleased_puzzle_giveaway_updates.json"
TABLES = {"daily": "puzzles", "weekly": "weekly_puzzles"}


def load_json(path: Path) -> Any:
    with path.open() as handle:
        return json.load(handle)


def load_bank_revision(revision: str) -> list[dict[str, Any]]:
    """Load the checked-in bank at a Git revision without touching the worktree."""
    try:
        content = subprocess.check_output(
            ["git", "-C", str(BACKEND_DIR.parent), "show", f"{revision}:Backend/word_bank.json"],
            text=True,
        )
    except subprocess.CalledProcessError as error:
        raise ValueError(f"Unable to load word bank at Git revision {revision!r}") from error
    value = json.loads(content)
    if not isinstance(value, list):
        raise ValueError(f"Word bank at Git revision {revision!r} is not a list")
    return value


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def clues_sha256(clues: list[dict[str, Any]]) -> str:
    return hashlib.sha256(json.dumps(clues, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def certified_values(certification: dict[str, Any]) -> set[tuple[str, str]]:
    return {
        (str(pair.get("answer", "")).upper(), str(pair.get("clue", "")).strip())
        for pair in certification.get("pairs", [])
        if isinstance(pair, dict)
    }


def infer_kind(payload: dict[str, Any], path: Path | None = None) -> str | None:
    if payload.get("is_free") is True:
        return "daily"
    if payload.get("is_free") is False:
        return "weekly"
    name = path.name.lower() if path else ""
    if "weekly" in name:
        return "weekly"
    if "puzzle" in name or "daily" in name:
        return "daily"
    return None


def load_artifacts(directory: Path, after: date) -> dict[str, list[dict[str, Any]]]:
    result = {"daily": [], "weekly": []}
    if not directory.exists():
        return result
    for path in sorted(directory.rglob("*.json")):
        # Backend/.cache also contains partial model outputs and resumable
        # scratch files.  They are not puzzle artifacts and must not prevent
        # a future-puzzle audit from completing.
        try:
            value = load_json(path)
        except (OSError, json.JSONDecodeError):
            continue
        payloads = value if isinstance(value, list) else [value]
        for payload in payloads:
            if not isinstance(payload, dict):
                continue
            puzzle_date = str(payload.get("date", ""))
            kind = infer_kind(payload, path)
            if kind and puzzle_date > after.isoformat():
                result[kind].append({**payload, "_artifactPath": str(path)})
    return result


def supabase_request(method: str, table: str, query: dict[str, str], payload: dict[str, Any] | None = None) -> Any:
    """Perform the small, dependency-free REST subset this audit requires."""
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        raise ValueError("SUPABASE_URL and SUPABASE_KEY are required for remote puzzle audit")
    request_url = f"{url.rstrip('/')}/rest/v1/{table}?{urlencode(query)}"
    data = json.dumps(payload).encode() if payload is not None else None
    headers = {"apikey": key, "Authorization": f"Bearer {key}"}
    if data is not None:
        headers.update({"Content-Type": "application/json", "Prefer": "return=representation"})
    request = Request(request_url, data=data, headers=headers, method=method)
    with urlopen(request) as response:  # noqa: S310 - URL comes only from SUPABASE_URL
        body = response.read().decode()
    return json.loads(body) if body else None


def fetch_remote_rows(comparison: str, pivot: date) -> dict[str, list[dict[str, Any]]]:
    result = {}
    for kind, table in TABLES.items():
        result[kind] = supabase_request(
            "GET", table,
            {"select": "id,date,puzzle_number,clues", "date": f"{comparison}.{pivot.isoformat()}", "order": "date.asc"},
        ) or []
    return result


def fetch_unreleased(after: date) -> dict[str, list[dict[str, Any]]]:
    return fetch_remote_rows("gt", after)


def fetch_released(before: date) -> dict[str, list[dict[str, Any]]]:
    """Fetch rows released before ``before`` (never the current date)."""
    return fetch_remote_rows("lt", before)


def audit_rows(rows_by_kind: dict[str, list[dict[str, Any]]], certification: dict[str, Any]) -> list[dict[str, Any]]:
    certified = certified_values(certification)
    findings = []
    for kind, rows in rows_by_kind.items():
        for row in rows:
            for clue in row.get("clues") or []:
                answer = str(clue.get("answer", "")).upper().strip()
                for channel in ("text", "hint"):
                    value = str(clue.get(channel, "")).strip()
                    if not answer or not value:
                        findings.append({
                            "kind": kind, "rowId": row.get("id"), "date": row.get("date"),
                            "puzzleNumber": row.get("puzzle_number"), "clueId": clue.get("id"),
                            "answer": answer, "channel": channel, "current": value,
                            "reason": "missing_answer_or_clue",
                        })
                        continue
                    deterministic = scan_text(answer, value)
                    if deterministic or (answer, value) not in certified:
                        findings.append({
                            "kind": kind, "rowId": row.get("id"), "date": row.get("date"),
                            "puzzleNumber": row.get("puzzle_number"), "clueId": clue.get("id"),
                            "answer": answer, "channel": channel, "current": value,
                            "reason": "deterministic_leak" if deterministic else "not_currently_certified",
                            "deterministicIssues": [issue.as_dict() for issue in deterministic],
                            "sourceField": clue.get(f"{channel}SourceField"),
                            "sourceIndex": clue.get(f"{channel}SourceIndex"),
                            "cluesSha256": clues_sha256(row.get("clues") or []),
                            "artifactPath": row.get("_artifactPath"),
                        })
    return findings


def bank_index(entries: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(entry.get("word", "")).upper(): entry for entry in entries}


def source_value(entry: dict[str, Any], finding: dict[str, Any]) -> str:
    source_field = finding.get("sourceField")
    source_index = finding.get("sourceIndex")
    if source_field == "clues" and isinstance(source_index, int):
        clues = entry.get("clues") or []
        if 0 <= source_index < len(clues):
            return str(clues[source_index]).strip()
    if source_field in {"text", "hard_text", "hardText"}:
        value = entry.get(source_field)
        if isinstance(value, str) and value.strip():
            return value.strip()

    # Deterministic source fallback preserves the generator's normal field
    # selection without guessing an arbitrary historical clue variant.
    if finding["kind"] == "daily":
        return str(entry["text"] if finding["channel"] == "text" else entry["clues"][0]).strip()
    return str(entry["clues"][0] if finding["channel"] == "text" else entry.get("hard_text", entry.get("hardText", ""))).strip()


def build_updates(
    rows_by_kind: dict[str, list[dict[str, Any]]],
    findings: list[dict[str, Any]],
    entries: list[dict[str, Any]],
    certification: dict[str, Any],
) -> dict[str, Any]:
    by_answer = bank_index(entries)
    certified = certified_values(certification)
    updates = []
    for finding in findings:
        entry = by_answer.get(finding["answer"])
        if not entry:
            updates.append({**finding, "status": "manual_review", "replacement": None, "reason": "answer_missing_from_word_bank"})
            continue
        replacement = source_value(entry, finding)
        if not replacement or (finding["answer"], replacement) not in certified:
            updates.append({**finding, "status": "manual_review", "replacement": replacement, "reason": "replacement_not_certified"})
            continue
        updates.append({**finding, "status": "pending_review", "replacement": replacement})
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "scope": "strictly after local execution-day date",
        "updates": updates,
    }


def changed_active_values(
    previous_entries: list[dict[str, Any]],
    current_entries: list[dict[str, Any]],
    certification: dict[str, Any],
) -> dict[tuple[str, str, int | None], tuple[str, str]]:
    """Return exact old-to-certified-new mappings for active bank fields."""
    certified = certified_values(certification)
    current_by_answer = bank_index(current_entries)
    mappings: dict[tuple[str, str, int | None], tuple[str, str]] = {}
    for previous in previous_entries:
        answer = str(previous.get("word", "")).upper()
        current = current_by_answer.get(answer)
        if not answer or not current:
            continue
        for field in ("text", "hard_text", "hardText"):
            old = previous.get(field)
            new = current.get(field)
            if isinstance(old, str) and isinstance(new, str) and old.strip() and old != new:
                if (answer, new.strip()) in certified:
                    mappings[(answer, field, None)] = (old.strip(), new.strip())
        old_clues = previous.get("clues") or []
        new_clues = current.get("clues") or []
        for index, old in enumerate(old_clues):
            new = new_clues[index] if index < len(new_clues) else None
            if isinstance(old, str) and isinstance(new, str) and old.strip() and old != new:
                if (answer, new.strip()) in certified:
                    mappings[(answer, "clues", index)] = (old.strip(), new.strip())
    return mappings


def historical_repair_for_clue(
    clue: dict[str, Any],
    channel: str,
    mappings: dict[tuple[str, str, int | None], tuple[str, str]],
) -> tuple[str, str] | None:
    """Find a single exact certified repair for one stored puzzle clue."""
    answer = str(clue.get("answer", "")).upper().strip()
    value = str(clue.get(channel, "")).strip()
    source_field = clue.get(f"{channel}SourceField")
    source_index = clue.get(f"{channel}SourceIndex")
    if source_field:
        match = mappings.get((answer, str(source_field), source_index if isinstance(source_index, int) else None))
        return match if match and match[0] == value else None

    # Older payloads lacked source metadata. An exact old value is safe to
    # repair only when it identifies one source field uniquely.
    matches = [mapping for (mapped_answer, _field, _index), mapping in mappings.items()
               if mapped_answer == answer and mapping[0] == value]
    return matches[0] if len(matches) == 1 else None


def build_historical_updates(
    rows_by_kind: dict[str, list[dict[str, Any]]],
    previous_entries: list[dict[str, Any]],
    current_entries: list[dict[str, Any]],
    certification: dict[str, Any],
) -> dict[str, Any]:
    """Build exact source-mapped repairs for released puzzle rows."""
    mappings = changed_active_values(previous_entries, current_entries, certification)
    updates = []
    for kind, rows in rows_by_kind.items():
        for row in rows:
            row_hash = clues_sha256(row.get("clues") or [])
            for clue in row.get("clues") or []:
                for channel in ("text", "hint"):
                    repair = historical_repair_for_clue(clue, channel, mappings)
                    if not repair:
                        continue
                    old, replacement = repair
                    updates.append({
                        "kind": kind,
                        "rowId": row.get("id"),
                        "date": row.get("date"),
                        "puzzleNumber": row.get("puzzle_number"),
                        "clueId": clue.get("id"),
                        "answer": str(clue.get("answer", "")).upper().strip(),
                        "channel": channel,
                        "current": old,
                        "replacement": replacement,
                        "sourceField": clue.get(f"{channel}SourceField"),
                        "sourceIndex": clue.get(f"{channel}SourceIndex"),
                        "cluesSha256": row_hash,
                        "status": "approved",
                        "approval": "exact_certified_historical_repair",
                    })
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "scope": "released rows strictly before local execution-day date; exact certified repairs only",
        "updates": updates,
    }


def apply_updates_to_rows(rows_by_kind: dict[str, list[dict[str, Any]]], package: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    updated = deepcopy(rows_by_kind)
    by_row = {
        (kind, row.get("id"), row.get("date"), row.get("puzzle_number")): row
        for kind, rows in updated.items()
        for row in rows
    }
    original_hashes = {key: clues_sha256(row.get("clues") or []) for key, row in by_row.items()}
    for item in package.get("updates", []):
        if item.get("status") != "approved":
            continue
        key = (item.get("kind"), item.get("rowId"), item.get("date"), item.get("puzzleNumber"))
        row = by_row.get(key)
        if not row or original_hashes[key] != item.get("cluesSha256"):
            raise ValueError(f"Puzzle row changed since update export: {key}")
        matches = [clue for clue in row.get("clues") or [] if clue.get("id") == item.get("clueId") and str(clue.get("answer", "")).upper() == item.get("answer")]
        if len(matches) != 1 or matches[0].get(item.get("channel")) != item.get("current"):
            raise ValueError(f"Puzzle clue changed since update export: {key} {item.get('clueId')}")
        matches[0][item["channel"]] = item["replacement"]
    return updated


def apply_remote(package: dict[str, Any]) -> int:
    changed = 0
    grouped: dict[tuple[str, Any], list[dict[str, Any]]] = {}
    for item in package.get("updates", []):
        if item.get("status") == "approved" and item.get("rowId") is not None:
            grouped.setdefault((item["kind"], item["rowId"]), []).append(item)
    for (kind, row_id), items in grouped.items():
        table = TABLES[kind]
        fetched = supabase_request("GET", table, {"select": "id,date,puzzle_number,clues", "id": f"eq.{row_id}"})
        row = fetched[0] if isinstance(fetched, list) and len(fetched) == 1 else None
        if not row:
            raise ValueError(f"Supabase row missing: {row_id}")
        rows = apply_updates_to_rows({kind: [row]}, {"updates": items})
        supabase_request("PATCH", table, {"id": f"eq.{row_id}"}, {"clues": rows[kind][0]["clues"]})
        changed += 1
    return changed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit and safely patch crossword payloads against word-bank certification")
    parser.add_argument("command", choices=["audit-local", "audit-remote", "build-updates", "audit-history-remote", "build-history-updates", "apply-remote"])
    parser.add_argument("--artifact-dir", type=Path, default=BACKEND_DIR)
    parser.add_argument("--as-of", type=date.fromisoformat, default=date.today())
    parser.add_argument("--report", type=Path, default=REPORT_PATH)
    parser.add_argument("--package", type=Path, default=UPDATE_PATH)
    parser.add_argument("--previous-bank", type=Path, help="Pre-repair bank snapshot for build-history-updates")
    parser.add_argument("--previous-bank-revision", help="Pre-repair Git revision for build-history-updates")
    parser.add_argument("--bank", type=Path, default=BANK_PATH, help="Certified repaired bank for build-history-updates")
    parser.add_argument("--bank-revision", help="Certified repaired Git revision for build-history-updates")
    parser.add_argument("--yes", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    certification = load_certification(CERTIFICATION_PATH)
    entries = load_bank_revision(args.bank_revision) if args.bank_revision else load_json(args.bank)
    if args.command in {"audit-local", "audit-remote", "audit-history-remote"}:
        if args.command == "audit-local":
            rows = load_artifacts(args.artifact_dir, args.as_of)
        elif args.command == "audit-remote":
            rows = fetch_unreleased(args.as_of)
        else:
            rows = fetch_released(args.as_of)
        report = {
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "asOf": args.as_of.isoformat(),
            "source": args.command,
            "rows": rows,
            "findings": audit_rows(rows, certification),
        }
        write_json(args.report, report)
        scope = "released" if args.command == "audit-history-remote" else "unreleased"
        print(f"Audited {sum(len(value) for value in rows.values())} {scope} puzzle rows; {len(report['findings'])} findings.")
        return 0
    if args.command == "build-updates":
        report = load_json(args.report)
        package = build_updates(report["rows"], report["findings"], entries, certification)
        write_json(args.package, package)
        print(f"Wrote {len(package['updates'])} pending unreleased-puzzle updates.")
        return 0
    if args.command == "build-history-updates":
        if bool(args.previous_bank) == bool(args.previous_bank_revision):
            raise ValueError("build-history-updates requires exactly one of --previous-bank or --previous-bank-revision")
        report = load_json(args.report)
        previous_entries = load_bank_revision(args.previous_bank_revision) if args.previous_bank_revision else load_json(args.previous_bank)
        package = build_historical_updates(report["rows"], previous_entries, entries, certification)
        write_json(args.package, package)
        print(f"Wrote {len(package['updates'])} exact certified historical repairs.")
        return 0
    if not args.yes:
        raise ValueError("apply-remote requires --yes")
    package = load_json(args.package)
    print(f"Applied {apply_remote(package)} approved Supabase clue updates.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as error:
        print(f"ERROR: {error}")
        raise SystemExit(2)
