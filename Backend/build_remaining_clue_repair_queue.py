#!/usr/bin/env python3
"""Reconcile the completed clue audit into a current field-level repair queue."""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from audit_clue_answer_alignment import field_values


BACKEND_DIR = Path(__file__).resolve().parent
BANK_PATH = BACKEND_DIR / "word_bank.json"
AUDIT_PATH = BACKEND_DIR / "word_bank_clue_alignment_audit.json"
QUEUE_PATH = BACKEND_DIR / "word_bank_remaining_clue_repair_queue.json"
FINDING_STATUSES = {"terra_mismatch", "needs_review", "pending_sol", "confirmed_mismatch", "needs_human_review"}


def sha256_path(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> Any:
    with path.open() as handle:
        return json.load(handle)


def current_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def build_queue(entries: list[dict[str, Any]], audit: dict[str, Any]) -> dict[str, Any]:
    by_word: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for index, entry in enumerate(entries):
        word = entry.get("word")
        if isinstance(word, str):
            by_word.setdefault(word, []).append((index, entry))

    records = []
    skipped_duplicate_words = []
    for audited in audit.get("records") or []:
        word = audited.get("word")
        matches = by_word.get(word) if isinstance(word, str) else None
        if not matches:
            continue  # The reviewed removal no longer needs repair.
        if len(matches) != 1:
            skipped_duplicate_words.append(word)
            continue
        index, entry = matches[0]
        current = {item["field"]: item["current"] for item in field_values(entry)}
        fields = []
        for audited_field in audited.get("fields") or []:
            name = audited_field.get("field")
            status = audited_field.get("status")
            if status not in FINDING_STATUSES or current.get(name) != audited_field.get("current"):
                continue
            verdict = audited_field.get("terra") or audited_field.get("sol") or {}
            fields.append({
                "field": name,
                "current": current[name],
                "auditStatus": status,
                "reason": verdict.get("reason", "Original audit finding"),
            })
        if fields:
            records.append({"index": index, "word": word, "fields": fields})
    return {
        "schemaVersion": 1,
        "generatedAt": current_iso(),
        "records": records,
        "skippedDuplicateWords": sorted(set(skipped_duplicate_words)),
    }


def main() -> int:
    entries = load_json(BANK_PATH)
    audit = load_json(AUDIT_PATH)
    queue = build_queue(entries, audit)
    queue["bankSha256"] = sha256_path(BANK_PATH)
    queue["sourceAuditSha256"] = sha256_path(AUDIT_PATH)
    QUEUE_PATH.write_text(json.dumps(queue, indent=2, ensure_ascii=False) + "\n")
    field_count = sum(len(record["fields"]) for record in queue["records"])
    print(json.dumps({
        "repairEntries": len(queue["records"]),
        "repairFields": field_count,
        "skippedDuplicateWords": queue["skippedDuplicateWords"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
