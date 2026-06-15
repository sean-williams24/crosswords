#!/usr/bin/env python3
"""
Audit existing Supabase Backword rows for clue/answer inflection mismatches.

Review-first workflow:
  python3 Backend/audit_backword_inflections.py export
  python3 Backend/audit_backword_inflections.py apply --input Backend/backword_inflection_replacements.json

Export writes proposed updates only. Apply updates word_data.clue while preserving
all other word_data fields.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from inflection_safety import proposal_for_single_word_pair, scan_clue


OUTPUT_PATH = Path(__file__).parent / "backword_inflection_replacements.json"

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


def fetch_rows() -> list[dict[str, Any]]:
    rows = client().table("backword_words").select("id,date,word_data").order("date").execute()
    return rows.data or []


def scan_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    for row in rows:
        word_data = row.get("word_data") or {}
        if not isinstance(word_data, dict):
            continue
        word = str(word_data.get("word", "")).strip().upper()
        clue = str(word_data.get("clue") or word_data.get("category") or "").strip()
        if not word or not clue:
            continue

        issues = scan_clue(word, clue, single_word_pair=True)
        if not issues:
            continue

        proposed = issues[0].proposed or proposal_for_single_word_pair(word, clue)
        findings.append({
            "id": row.get("id"),
            "date": row.get("date"),
            "word": word,
            "currentClue": clue,
            "reasons": [issue.reason for issue in issues],
            "details": [issue.detail for issue in issues],
            "proposedClue": proposed.upper(),
            "wordData": word_data,
        })
    return findings


def build_report(rows: list[dict[str, Any]], findings: list[dict[str, Any]]) -> dict[str, Any]:
    reasons = Counter(reason for finding in findings for reason in finding["reasons"])
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "table": "backword_words",
        "rowCount": len(rows),
        "flaggedRowCount": len(findings),
        "summary": {"byReason": dict(reasons)},
        "strictRule": "Backword clue must not imply a different inflection, number, tense, or part of speech than the answer.",
        "replacements": findings,
    }


def apply_report(report: dict[str, Any]) -> int:
    sb = client()
    updated = 0
    for item in report.get("replacements", []):
        word_data = dict(item.get("wordData") or {})
        current = str(word_data.get("clue") or word_data.get("category") or "").strip()
        if current != item["currentClue"]:
            raise ValueError(f"{item['date']} {item['word']} changed since export: expected {item['currentClue']!r}, found {current!r}")
        proposed = str(item["proposedClue"]).strip().upper()
        remaining = scan_clue(str(item["word"]), proposed, single_word_pair=True)
        if remaining:
            reasons = ", ".join(issue.reason for issue in remaining)
            raise ValueError(f"Replacement still fails inflection scan for {item['date']} {item['word']}: {reasons}")
        word_data["clue"] = proposed
        sb.table("backword_words").update({"word_data": word_data}).eq("id", item["id"]).execute()
        updated += 1
    return updated


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit Backword clue inflections in Supabase.")
    parser.add_argument("command", choices=["export", "apply"])
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    parser.add_argument("--input", type=Path, dest="input_path")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "export":
        rows = fetch_rows()
        findings = scan_rows(rows)
        report = build_report(rows, findings)
        args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        print(f"Exported {report['flaggedRowCount']} flagged Backword row(s) to {args.output}")
        return

    input_path = args.input_path or args.output
    if not input_path.exists():
        print(f"Replacement file not found: {input_path}", file=sys.stderr)
        raise SystemExit(1)
    report = json.loads(input_path.read_text())
    updated = apply_report(report)
    print(f"Updated {updated} Backword row(s) from reviewed replacement file.")


if __name__ == "__main__":
    main()
