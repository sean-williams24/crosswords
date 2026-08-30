"""Certification and active-field helpers for the crossword word bank.

The certification is deliberately pair-based rather than bound to the whole
JSON file.  Updating dormant ``hint`` metadata does not invalidate an active
clue review, while any playable answer/clue change does.
"""

from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

from answer_leakage import giveaway_candidates, scan_text


BACKEND_DIR = Path(__file__).resolve().parent
CERTIFICATION_PATH = BACKEND_DIR / "word_bank_answer_giveaway_certification.json"
CERTIFICATION_SCHEMA_VERSION = 1
POLICY_VERSION = "mechanical-giveaway-v1"
SCANNER_VERSION = "2026-08-26"
TERRA_PROVENANCE = "terra"
DETERMINISTIC_PROVENANCE = "deterministic"
VALID_PROVENANCE = {TERRA_PROVENANCE, DETERMINISTIC_PROVENANCE}


def active_fields(entry: dict[str, Any]) -> list[tuple[str, str]]:
    """Return every currently playable clue field and its stable label."""
    fields: list[tuple[str, str]] = []
    for name in ("text", "hard_text", "hardText"):
        value = entry.get(name)
        if isinstance(value, str) and value.strip():
            fields.append((name, value.strip()))
    for index, value in enumerate(entry.get("clues") or []):
        if isinstance(value, str) and value.strip():
            fields.append((f"clues[{index}]", value.strip()))
    return fields


def structural_errors(entries: Iterable[dict[str, Any]]) -> list[str]:
    """Prevent dormant hint metadata from becoming an uncertified fallback."""
    errors: list[str] = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", "")).strip() or f"entry {index}"
        if not isinstance(entry.get("text"), str) or not entry["text"].strip():
            errors.append(f"{index} {word}: missing text")
        hard_text = entry.get("hard_text") or entry.get("hardText")
        if not isinstance(hard_text, str) or not hard_text.strip():
            errors.append(f"{index} {word}: missing hard_text")
        clues = entry.get("clues")
        if not isinstance(clues, list) or not any(isinstance(value, str) and value.strip() for value in clues):
            errors.append(f"{index} {word}: missing playable clues[]")
    return errors


def pair_fingerprint(answer: str, field: str, clue: str) -> str:
    payload = json.dumps(
        {"answer": answer.upper().strip(), "field": field, "clue": clue.strip()},
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode()
    return hashlib.sha256(payload).hexdigest()


def current_pairs(entries: Iterable[dict[str, Any]]) -> list[dict[str, str]]:
    pairs: list[dict[str, str]] = []
    for entry in entries:
        answer = str(entry.get("word", "")).strip().upper()
        for field, clue in active_fields(entry):
            pairs.append({
                "answer": answer,
                "field": field,
                "clue": clue,
                "fingerprint": pair_fingerprint(answer, field, clue),
            })
    return pairs


def new_certification(records: Iterable[dict[str, str]]) -> dict[str, Any]:
    return {
        "schemaVersion": CERTIFICATION_SCHEMA_VERSION,
        "policyVersion": POLICY_VERSION,
        "scannerVersion": SCANNER_VERSION,
        "scope": ["text", "hard_text", "hardText", "clues[]"],
        "pairs": list(records),
    }


def certification_errors(
    entries: list[dict[str, Any]],
    certification: dict[str, Any],
) -> list[str]:
    errors = structural_errors(entries)
    if certification.get("schemaVersion") != CERTIFICATION_SCHEMA_VERSION:
        errors.append("unsupported certification schema")
    if certification.get("policyVersion") != POLICY_VERSION:
        errors.append("certification policy version is stale")
    if certification.get("scannerVersion") != SCANNER_VERSION:
        errors.append("certification scanner version is stale")

    records = certification.get("pairs")
    if not isinstance(records, list):
        return errors + ["certification pairs are missing"]

    by_fingerprint: dict[str, dict[str, Any]] = {}
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("fingerprint"), str):
            errors.append("certification contains an invalid pair record")
            continue
        fingerprint = record["fingerprint"]
        if fingerprint in by_fingerprint:
            errors.append(f"certification repeats pair fingerprint {fingerprint}")
            continue
        provenance = record.get("provenance")
        if provenance not in VALID_PROVENANCE:
            errors.append(f"certification pair {fingerprint} has invalid provenance")
        by_fingerprint[fingerprint] = record

    pairs = current_pairs(entries)
    expected = Counter(pair["fingerprint"] for pair in pairs)
    actual = Counter(record.get("fingerprint") for record in records if isinstance(record, dict))
    if expected != actual:
        errors.append("certification does not exactly cover current active answer/clue pairs")

    for pair in pairs:
        record = by_fingerprint.get(pair["fingerprint"])
        if not record:
            continue
        deterministic = scan_text(pair["answer"], pair["clue"])
        if deterministic:
            errors.append(
                f"{pair['answer']} {pair['field']} has deterministic leakage: "
                + ",".join(issue.reason for issue in deterministic)
            )
            continue
        candidate = giveaway_candidates(pair["answer"], pair["clue"])
        if candidate and record.get("provenance") != TERRA_PROVENANCE:
            errors.append(f"{pair['answer']} {pair['field']} candidate lacks Terra review")
    return errors


def load_certification(path: Path = CERTIFICATION_PATH) -> dict[str, Any]:
    if not path.exists():
        raise ValueError(f"Missing word-bank giveaway certification: {path}")
    with path.open() as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError("Word-bank giveaway certification must be a JSON object")
    return value


def validate_certification(entries: list[dict[str, Any]], path: Path = CERTIFICATION_PATH) -> None:
    errors = certification_errors(entries, load_certification(path))
    if errors:
        preview = "\n".join(f"- {error}" for error in errors[:20])
        suffix = "" if len(errors) <= 20 else f"\n- … and {len(errors) - 20} more"
        raise ValueError(f"Word-bank safety certification failed:\n{preview}{suffix}")
