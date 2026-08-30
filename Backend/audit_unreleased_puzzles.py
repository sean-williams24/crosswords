#!/usr/bin/env python3
"""Audit and safely patch unreleased crossword clue payloads.

The tool reads future local artifacts and Supabase rows, comparing every shown
answer/clue pair to the active word-bank certification.  Remote writes require
an explicitly approved package and ``--yes``.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
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


def client():
    from supabase import create_client

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        raise ValueError("SUPABASE_URL and SUPABASE_KEY are required for remote puzzle audit")
    return create_client(url, key)


def fetch_unreleased(after: date) -> dict[str, list[dict[str, Any]]]:
    result = {}
    for kind, table in TABLES.items():
        response = (
            client()
            .table(table)
            .select("id,date,puzzle_number,clues")
            .gt("date", after.isoformat())
            .order("date")
            .execute()
        )
        result[kind] = response.data or []
    return result


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


def apply_updates_to_rows(rows_by_kind: dict[str, list[dict[str, Any]]], package: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    updated = deepcopy(rows_by_kind)
    by_row = {
        (kind, row.get("id"), row.get("date"), row.get("puzzle_number")): row
        for kind, rows in updated.items()
        for row in rows
    }
    for item in package.get("updates", []):
        if item.get("status") != "approved":
            continue
        key = (item.get("kind"), item.get("rowId"), item.get("date"), item.get("puzzleNumber"))
        row = by_row.get(key)
        if not row or clues_sha256(row.get("clues") or []) != item.get("cluesSha256"):
            raise ValueError(f"Puzzle row changed since update export: {key}")
        matches = [clue for clue in row.get("clues") or [] if clue.get("id") == item.get("clueId") and str(clue.get("answer", "")).upper() == item.get("answer")]
        if len(matches) != 1 or matches[0].get(item.get("channel")) != item.get("current"):
            raise ValueError(f"Puzzle clue changed since update export: {key} {item.get('clueId')}")
        matches[0][item["channel"]] = item["replacement"]
    return updated


def apply_remote(package: dict[str, Any]) -> int:
    changed = 0
    for item in package.get("updates", []):
        if item.get("status") != "approved" or item.get("rowId") is None:
            continue
        table = TABLES[item["kind"]]
        response = client().table(table).select("id,date,puzzle_number,clues").eq("id", item["rowId"]).single().execute()
        row = response.data
        if not row or clues_sha256(row.get("clues") or []) != item.get("cluesSha256"):
            raise ValueError(f"Supabase row changed since update export: {item['rowId']}")
        rows = apply_updates_to_rows({item["kind"]: [row]}, {"updates": [item]})
        client().table(table).update({"clues": rows[item["kind"]][0]["clues"]}).eq("id", item["rowId"]).execute()
        changed += 1
    return changed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit only unreleased crossword payloads against word-bank certification")
    parser.add_argument("command", choices=["audit-local", "audit-remote", "build-updates", "apply-remote"])
    parser.add_argument("--artifact-dir", type=Path, default=BACKEND_DIR)
    parser.add_argument("--as-of", type=date.fromisoformat, default=date.today())
    parser.add_argument("--report", type=Path, default=REPORT_PATH)
    parser.add_argument("--package", type=Path, default=UPDATE_PATH)
    parser.add_argument("--yes", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    certification = load_certification(CERTIFICATION_PATH)
    entries = load_json(BANK_PATH)
    if args.command in {"audit-local", "audit-remote"}:
        rows = load_artifacts(args.artifact_dir, args.as_of) if args.command == "audit-local" else fetch_unreleased(args.as_of)
        report = {
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "asOf": args.as_of.isoformat(),
            "source": args.command,
            "rows": rows,
            "findings": audit_rows(rows, certification),
        }
        write_json(args.report, report)
        print(f"Audited {sum(len(value) for value in rows.values())} unreleased puzzle rows; {len(report['findings'])} findings.")
        return 0
    report = load_json(args.report)
    if args.command == "build-updates":
        package = build_updates(report["rows"], report["findings"], entries, certification)
        write_json(args.package, package)
        print(f"Wrote {len(package['updates'])} pending unreleased-puzzle updates.")
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
