#!/usr/bin/env python3
"""
Audit and repair word-bank clue inflection mismatches.

Review-first workflow:
  python3 Backend/audit_word_bank_inflections.py sample --count 50
  python3 Backend/audit_word_bank_inflections.py export
  python3 Backend/audit_word_bank_inflections.py apply --input Backend/word_bank_inflection_replacements.json
  python3 Backend/audit_word_bank_inflections.py validate

Exhaustive Codex-chat workflow:
  python3 Backend/audit_word_bank_inflections.py init-chat-review
  python3 Backend/audit_word_bank_inflections.py export-chat-batch --limit 100
  python3 Backend/audit_word_bank_inflections.py record-chat-batch decisions.json
  python3 Backend/audit_word_bank_inflections.py validate-chat-review
  python3 Backend/audit_word_bank_inflections.py apply-chat-review

The sample/export commands never modify word_bank.json. The apply command only
uses a reviewed replacement file and validates word/index/current-value matches.
The chat workflow never calls a network service and does not modify the bank
until a complete, validated review is applied.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from audit_answer_derivability import (
    DEFAULT_HIGH_THRESHOLD,
    DEFAULT_REVIEW_THRESHOLD,
    scan_field,
)
from fix_duplicate_clues import (
    DISCOURAGED_QUALIFIER_RE,
    is_antonym_only_clue,
    replacement_issue,
    validate_entry,
)
from inflection_safety import (
    get_field,
    is_past_or_participle,
    is_pluralish_answer,
    looks_like_base_verb,
    scan_clue,
    set_field,
)


BANK_PATH = Path(__file__).parent / "word_bank.json"
REPLACEMENTS_PATH = Path(__file__).parent / "word_bank_inflection_replacements.json"
SAMPLE_PATH = Path(__file__).parent / "word_bank_inflection_sample_50.json"
WIDE_PATH = Path(__file__).parent / "word_bank_inflection_wide_review.json"
CHAT_AUDIT_PATH = Path(__file__).parent / "word_bank_inflection_chat_audit.json"
CHAT_BATCH_PATH = Path(__file__).parent / "word_bank_inflection_chat_batch.json"
CHAT_REPLACEMENTS_PATH = Path(__file__).parent / "word_bank_inflection_replacements.json"
CHAT_SCHEMA_VERSION = 1
ACTIVE_SCALAR_FIELDS = ("text", "hard_text", "hardText")
ACCEPTED_REPLACEMENT_STATUSES = {"accepted"}

PLURAL_HEAD_RE = re.compile(
    r"^(?:people|things|items|messages|passes|discs|garments|clothes|structures|units|traits|"
    r"tools|objects|parts|pieces|actions|qualities|devices|workers|players|friends|partners)\b",
    re.IGNORECASE,
)
SINGULAR_ARTICLE_RE = re.compile(r"^(?:a|an)\s+([a-z][a-z-]+)\b", re.IGNORECASE)
PAST_REF_RE = re.compile(r"\bpast\s+(?:tense|participle)\s+of\b", re.IGNORECASE)
GERUND_START_RE = re.compile(
    r"^(?:being|becoming|causing|creating|doing|giving|holding|keeping|leaving|making|moving|"
    r"requesting|running|taking|using)\b",
    re.IGNORECASE,
)
FALSE_PLURALISH_WORDS = {
    "alias", "always", "ananas", "bahamas", "barbados", "barclays", "bathos",
    "blues", "bowls", "charles", "christmas", "collins", "corps", "dickens",
    "divers", "downstairs", "grits", "helios", "iroquois", "james", "judas",
    "jules", "lots", "madras", "maldives", "molasses", "morales", "news",
    "oodles", "pathos", "philips", "physics", "pilates", "politics", "scads",
    "series", "siemens", "snickers", "species", "summons", "upstairs", "walgreens",
}


def load_entries(path: Path) -> list[dict[str, Any]]:
    with path.open() as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"Expected top-level JSON array in {path}")
    return data


def save_entries(path: Path, entries: list[dict[str, Any]]) -> None:
    path.write_text(json.dumps(entries, indent=4, ensure_ascii=False) + "\n")


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def bank_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def json_sha256(value: Any) -> str:
    encoded = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode()
    return hashlib.sha256(encoded).hexdigest()


def active_field_values(entry: dict[str, Any]) -> list[dict[str, Any]]:
    """Return puzzle-active clue fields; dormant ``hint`` is intentionally excluded."""
    values: list[dict[str, Any]] = []
    for field in ACTIVE_SCALAR_FIELDS:
        value = entry.get(field)
        if isinstance(value, str) and value.strip():
            values.append({"field": field, "current": value})
    for clue_index, clue in enumerate(entry.get("clues") or []):
        if isinstance(clue, str) and clue.strip():
            values.append({"field": f"clues[{clue_index}]", "current": clue})
    return values


def chat_review_records(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", "")).strip()
        fields = active_field_values(entry)
        if word and fields:
            records.append({
                "index": index,
                "word": word,
                "fields": fields,
                "reviewed": False,
            })
    return records


def update_chat_summary(report: dict[str, Any]) -> None:
    records = report.get("records", [])
    reviewed = [record for record in records if record.get("reviewed") is True]
    report["reviewedEntryCount"] = len(reviewed)
    report["reviewedFieldCount"] = sum(len(record.get("fields", [])) for record in reviewed)
    report["remainingEntryCount"] = len(records) - len(reviewed)
    report["remainingFieldCount"] = (
        report.get("activeFieldCount", 0) - report["reviewedFieldCount"]
    )
    report["updatedAt"] = datetime.now(timezone.utc).isoformat()


def new_chat_audit(entries: list[dict[str, Any]], bank_path: Path) -> dict[str, Any]:
    records = chat_review_records(entries)
    report = {
        "schemaVersion": CHAT_SCHEMA_VERSION,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "sourceBank": str(bank_path),
        "bankSha256": bank_sha256(bank_path),
        "entryCount": len(entries),
        "inScopeEntryCount": len(records),
        "activeFieldCount": sum(len(record["fields"]) for record in records),
        "scope": ["text", "hard_text", "hardText", "clues[]"],
        "reviewMethod": "Exhaustive Codex chat review; no LLM API or network service",
        "records": records,
        "batches": [],
    }
    update_chat_summary(report)
    return report


def new_chat_replacements(audit: dict[str, Any]) -> dict[str, Any]:
    return {
        "schemaVersion": CHAT_SCHEMA_VERSION,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "updatedAt": datetime.now(timezone.utc).isoformat(),
        "sourceBank": audit["sourceBank"],
        "bankSha256": audit["bankSha256"],
        "activeFieldCount": audit["activeFieldCount"],
        "batchHashes": {},
        "replacements": [],
    }


def scan_entries(entries: list[dict[str, Any]], limit: int | None = None) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", "")).strip()
        if not word:
            continue

        fields = []
        for field in active_field_values(entry):
            issues = scan_clue(word, field["current"])
            if not issues:
                continue
            fields.append({
                "field": field["field"],
                "current": field["current"],
                "reasons": [issue.reason for issue in issues],
                "details": [issue.detail for issue in issues],
                "proposed": proposed_replacement(word, field["current"], issues[0].proposed),
            })

        if fields:
            findings.append({
                "id": f"word_bank:{index}:{word.lower()}",
                "index": index,
                "word": word,
                "fields": fields,
            })
            if limit is not None and len(findings) >= limit:
                break
    return findings


def wide_scan_entries(entries: list[dict[str, Any]], limit: int | None = None) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", "")).strip()
        if not word:
            continue

        fields = []
        for field in active_field_values(entry):
            for issue in wide_issues(word, field["current"]):
                fields.append({
                    "field": field["field"],
                    "current": field["current"],
                    "reasons": [issue["reason"]],
                    "details": [issue["detail"]],
                    "reviewHint": issue["reviewHint"],
                    "confidence": issue["confidence"],
                })

        if fields:
            findings.append({
                "id": f"word_bank:{index}:{word.lower()}",
                "index": index,
                "word": word,
                "fields": fields,
            })
            if limit is not None and len(findings) >= limit:
                break
    return findings


def wide_issues(word: str, clue: str) -> list[dict[str, str]]:
    clue_text = clue.strip()
    clue_l = clue_text.lower()
    word_l = word.lower()
    issues: list[dict[str, str]] = []

    answer_is_plural = is_pluralish_answer(word) and word_l not in FALSE_PLURALISH_WORDS

    if answer_is_plural:
        match = SINGULAR_ARTICLE_RE.match(clue_text)
        if match:
            head = match.group(1).lower()
            if (
                head not in {"pair", "set", "group", "series", "collection", "kind", "type", "sign", "word"}
                and not clue_l.startswith(("a sign of ", "a word for "))
            ):
                issues.append({
                    "reason": "WIDE_PLURAL_ANSWER_SINGULAR_CLUE",
                    "detail": "Plural-looking answer has a clue that begins with a singular article.",
                    "reviewHint": "Confirm the clue describes multiple things, or rewrite to plural wording.",
                    "confidence": "medium",
                })

    if not answer_is_plural and PLURAL_HEAD_RE.search(clue_text):
        issues.append({
            "reason": "WIDE_SINGULAR_ANSWER_PLURAL_CLUE",
            "detail": "Singular-looking answer has a clue that begins with a plural head noun.",
            "reviewHint": "Check whether the answer is a collective/mass noun; otherwise rewrite singular.",
            "confidence": "medium",
        })

    if PAST_REF_RE.search(clue_text) and not is_past_or_participle(word):
        issues.append({
            "reason": "WIDE_PAST_REFERENCE_FOR_NON_PAST",
            "detail": "Clue explicitly references a past form, but the answer is not recognized as past/participle.",
            "reviewHint": "If the answer is a valid irregular past form, add it to the irregular list; otherwise rewrite.",
            "confidence": "high",
        })

    if is_past_or_participle(word) and re.search(r"\bwhat\s+.+\s+does\b", clue_l):
        issues.append({
            "reason": "WIDE_PRESENT_ACTION_FOR_PAST_ANSWER",
            "detail": "Past/participle answer has a present-action clue.",
            "reviewHint": "Rewrite as a past/participle clue, e.g. 'already ...' or a state/result clue.",
            "confidence": "high",
        })

    if looks_like_base_verb(word, clue_text) and GERUND_START_RE.search(clue_text):
        issues.append({
            "reason": "WIDE_GERUND_FOR_BASE_VERB",
            "detail": "Base-verb-looking answer has a clue starting with an -ING form.",
            "reviewHint": "Rewrite as an imperative/base-form clue if the answer is a base verb.",
            "confidence": "medium",
        })

    return issues


def proposed_replacement(word: str, current: str, fallback: str) -> str:
    key = (word.lower(), current.lower().strip().rstrip(".?!"))
    targeted = {
        ("absorb", "what a sponge does, perhaps"): "Take in liquid, perhaps.",
        ("absorb", "what a sponge does"): "Take in like a sponge.",
        ("aged", "what cheese does to improve, loosely"): "Old or matured, loosely.",
        ("aged", "what cheese does to improve"): "Old or matured, as cheese can be.",
        ("bite", "what a mosquito does, sometimes"): "Use teeth or a stinger, sometimes.",
        ("bite", "what a mosquito does"): "Use teeth or a stinger.",
        ("established", "what a tradition does to its roots"): "Founded or accepted over time.",
        ("sank", "what a ship does during a storm"): "Went below the surface.",
        ("tuned", "what a musician does before a show"): "Adjusted to pitch.",
        ("spilt", "what a careless cook does"): "No longer kept in the container.",
        ("taxed", "what a government does to you"): "Subject to a levy.",
        ("imbed", "what a seed does in soil"): "Set firmly into surrounding material.",
        ("hurled", "what a quarterback does with a football"): "Thrown forcefully.",
        ("rolled", "what dough does before baking"): "Turned over and over.",
        ("togs", "a word for garments that might include swimwear"): "Garments that might include swimwear.",
        ("miles", "a unit that counts travel, not just steps"): "Travel units, not just steps.",
        ("hoofed", "what a horse does on the track"): "Danced or walked heavily.",
        ("melted", "what ice does in warm weather"): "Changed from solid to liquid.",
        ("chilled", "what ice does to a drink"): "Made cold.",
        ("declared", "what a king does to his subjects"): "Stated officially.",
        ("administered", "what a doctor does with care"): "Dispensed or managed carefully.",
        ("chewed", "what food does to your teeth"): "Masticated.",
    }
    return targeted.get(key, fallback)


def build_review_file(entries: list[dict[str, Any]], findings: list[dict[str, Any]], source: Path) -> dict[str, Any]:
    by_reason = Counter(reason for finding in findings for field in finding["fields"] for reason in field["reasons"])
    by_field = Counter(field["field"].split("[")[0] for finding in findings for field in finding["fields"])
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "source": str(source),
        "entryCount": len(entries),
        "flaggedEntryCount": len(findings),
        "flaggedFieldCount": sum(len(finding["fields"]) for finding in findings),
        "summary": {
            "byReason": dict(by_reason),
            "byField": dict(by_field),
        },
        "strictRule": "Every clue must naturally resolve to the exact stored answer form, including tense, number, inflection, and part of speech.",
        "replacements": findings,
    }


def build_wide_review_file(entries: list[dict[str, Any]], findings: list[dict[str, Any]], source: Path) -> dict[str, Any]:
    by_reason = Counter(reason for finding in findings for field in finding["fields"] for reason in field["reasons"])
    by_field = Counter(field["field"].split("[")[0] for finding in findings for field in finding["fields"])
    by_confidence = Counter(field["confidence"] for finding in findings for field in finding["fields"])
    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "source": str(source),
        "entryCount": len(entries),
        "candidateEntryCount": len(findings),
        "candidateFieldCount": sum(len(finding["fields"]) for finding in findings),
        "summary": {
            "byReason": dict(by_reason),
            "byField": dict(by_field),
            "byConfidence": dict(by_confidence),
        },
        "note": "Wide-net review candidates only. This file is intentionally noisier than the high-confidence replacement export and should not be applied directly.",
        "candidates": findings,
    }


def print_wide_report(report: dict[str, Any]) -> None:
    print(f"Candidate entries: {report['candidateEntryCount']}")
    print(f"Candidate fields: {report['candidateFieldCount']}")
    print(f"Summary: {json.dumps(report['summary'], ensure_ascii=False)}")
    print()
    for item in report["candidates"][:50]:
        print(f"{item['index']} {item['word']}")
        for field in item["fields"]:
            print(f"  {field['field']} ({field['confidence']})")
            print(f"    current: {field['current']}")
            print(f"    reason:  {', '.join(field['reasons'])}")
            print(f"    hint:    {field['reviewHint']}")
        print()


def print_sample(report: dict[str, Any]) -> None:
    print(f"Flagged entries in sample: {report['flaggedEntryCount']}")
    print(f"Flagged fields in sample: {report['flaggedFieldCount']}")
    print(f"Summary: {json.dumps(report['summary'], ensure_ascii=False)}")
    print()
    for item in report["replacements"]:
        print(f"{item['index']} {item['word']}")
        for field in item["fields"]:
            print(f"  {field['field']}")
            print(f"    current:  {field['current']}")
            print(f"    reason:   {', '.join(field['reasons'])}")
            print(f"    proposed: {field['proposed']}")
        print()


def validate_chat_preconditions(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    replacements: dict[str, Any],
    bank_path: Path,
) -> None:
    if audit.get("schemaVersion") != CHAT_SCHEMA_VERSION:
        raise ValueError("Unsupported chat-audit schema")
    if replacements.get("schemaVersion") != CHAT_SCHEMA_VERSION:
        raise ValueError("Unsupported chat-replacement schema")
    actual_hash = bank_sha256(bank_path)
    for label, report in (("audit", audit), ("replacement", replacements)):
        if report.get("bankSha256") != actual_hash:
            raise ValueError(
                f"Stale {label} report: expected bank hash "
                f"{report.get('bankSha256')}, found {actual_hash}"
            )
    expected_records = chat_review_records(entries)
    records = audit.get("records")
    if not isinstance(records, list) or len(records) != len(expected_records):
        raise ValueError("Chat audit does not cover the current in-scope entries")
    for actual, expected in zip(records, expected_records):
        comparable = {
            "index": actual.get("index"),
            "word": actual.get("word"),
            "fields": actual.get("fields"),
        }
        expected_comparable = {
            "index": expected["index"],
            "word": expected["word"],
            "fields": expected["fields"],
        }
        if comparable != expected_comparable:
            raise ValueError(
                f"Stale chat-audit precondition at index {expected['index']}"
            )
    active_count = sum(len(record["fields"]) for record in expected_records)
    if audit.get("activeFieldCount") != active_count:
        raise ValueError("Chat audit active-field count is inconsistent")
    if replacements.get("activeFieldCount") != active_count:
        raise ValueError("Chat replacement active-field count is inconsistent")
    expected_batch_hashes = {
        batch["batchId"]: batch["batchHash"]
        for batch in audit.get("batches", [])
    }
    if replacements.get("batchHashes", {}) != expected_batch_hashes:
        raise ValueError("Chat replacement batch-hash map is inconsistent")


def pending_chat_records(audit: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        record for record in audit.get("records", [])
        if record.get("reviewed") is not True
    ]


def build_chat_batch(audit: dict[str, Any], limit: int) -> dict[str, Any]:
    if limit <= 0:
        raise ValueError("Chat batch limit must be positive")
    records = pending_chat_records(audit)[:limit]
    entries = [
        {
            "index": record["index"],
            "word": record["word"],
            "fields": record["fields"],
        }
        for record in records
    ]
    batch_id = (
        f"{entries[0]['index']}-{entries[-1]['index']}-{len(entries)}"
        if entries else "complete"
    )
    hash_payload = {
        "schemaVersion": CHAT_SCHEMA_VERSION,
        "bankSha256": audit["bankSha256"],
        "batchId": batch_id,
        "entries": entries,
    }
    return {
        **hash_payload,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "batchHash": json_sha256(hash_payload),
        "entryCount": len(entries),
        "fieldCount": sum(len(entry["fields"]) for entry in entries),
        "instructions": (
            "Review every field for exact tense, number, inflection, and part of "
            "speech. In the decision file, set confirmedAllOtherFieldsMatch=true "
            "and list only fields requiring replacement."
        ),
    }


def validate_chat_batch(
    audit: dict[str, Any],
    batch: dict[str, Any],
) -> list[dict[str, Any]]:
    if batch.get("schemaVersion") != CHAT_SCHEMA_VERSION:
        raise ValueError("Unsupported chat-batch schema")
    if batch.get("bankSha256") != audit.get("bankSha256"):
        raise ValueError("Chat batch bank hash does not match the audit")
    expected = build_chat_batch(audit, int(batch.get("entryCount", 0)))
    for key in ("batchId", "batchHash", "entryCount", "fieldCount", "entries"):
        if batch.get(key) != expected.get(key):
            raise ValueError(f"Chat batch does not match pending audit state: {key}")
    return expected["entries"]


def replacement_validation_errors(
    entry: dict[str, Any],
    field: str,
    proposed: Any,
) -> list[str]:
    if not isinstance(proposed, str) or not proposed.strip():
        return ["replacement is empty"]
    proposed = re.sub(r"\s+", " ", proposed).strip()
    word = str(entry.get("word", ""))
    errors: list[str] = []
    leakage = replacement_issue(word, proposed)
    if leakage:
        errors.append(
            f"answer leakage: {','.join(leakage.get('reasons', ['UNKNOWN']))}"
        )
    if DISCOURAGED_QUALIFIER_RE.search(proposed):
        errors.append("replacement uses a discouraged qualifier")
    if is_antonym_only_clue(proposed):
        errors.append("replacement is antonym-only")
    for issue in scan_clue(word, proposed):
        errors.append(f"inflection mismatch: {issue.reason}")
    return errors


def validate_chat_decisions(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    batch: dict[str, Any],
    decisions: dict[str, Any],
) -> list[dict[str, Any]]:
    batch_entries = validate_chat_batch(audit, batch)
    if decisions.get("schemaVersion") != CHAT_SCHEMA_VERSION:
        raise ValueError("Unsupported chat-decision schema")
    for key in ("bankSha256", "batchId", "batchHash"):
        if decisions.get(key) != batch.get(key):
            raise ValueError(f"Chat decision precondition mismatch: {key}")
    if decisions.get("confirmedAllOtherFieldsMatch") is not True:
        raise ValueError("Chat decisions must explicitly confirm all omitted fields")
    raw_replacements = decisions.get("replacements")
    if not isinstance(raw_replacements, list):
        raise ValueError("Chat decisions must contain a replacements array")

    batch_by_index = {item["index"]: item for item in batch_entries}
    seen: set[tuple[int, str]] = set()
    validated: list[dict[str, Any]] = []
    trials: dict[int, dict[str, Any]] = {}
    for item in raw_replacements:
        if not isinstance(item, dict):
            raise ValueError("Every chat replacement must be an object")
        index = item.get("index")
        field = item.get("field")
        if not isinstance(index, int) or index not in batch_by_index:
            raise ValueError(f"Replacement index is not in the current batch: {index}")
        if not isinstance(field, str):
            raise ValueError(f"Replacement field is invalid at index {index}")
        key = (index, field)
        if key in seen:
            raise ValueError(f"Duplicate chat replacement for index {index} {field}")
        seen.add(key)

        source = batch_by_index[index]
        source_fields = {value["field"]: value["current"] for value in source["fields"]}
        if item.get("word") != source["word"]:
            raise ValueError(f"Replacement word mismatch at index {index}")
        if field not in source_fields:
            raise ValueError(f"Replacement field is not in the batch: {field}")
        if item.get("current") != source_fields[field]:
            raise ValueError(f"Replacement current-value mismatch for {source['word']} {field}")
        status = item.get("status", "accepted")
        if status not in {"accepted", "pending"}:
            raise ValueError(f"Invalid replacement status for {source['word']} {field}: {status}")
        reason = item.get("reason")
        if not isinstance(reason, str) or not reason.strip():
            raise ValueError(f"Replacement reason is required for {source['word']} {field}")
        proposed = item.get("proposed")
        errors = replacement_validation_errors(entries[index], field, proposed)
        if errors:
            raise ValueError(
                f"Invalid replacement for {source['word']} {field}: {errors}"
            )

        trial = trials.setdefault(index, deepcopy(entries[index]))
        set_field(trial, field, re.sub(r"\s+", " ", proposed).strip())
        validated.append({
            "index": index,
            "word": source["word"],
            "field": field,
            "current": source_fields[field],
            "proposed": re.sub(r"\s+", " ", proposed).strip(),
            "reason": reason.strip(),
            "status": status,
            "batchId": batch["batchId"],
        })

    for index, trial in trials.items():
        errors = validate_entry(trial)
        if errors:
            raise ValueError(
                f"Replacement leaves invalid entry for {trial.get('word')}: {errors[:5]}"
            )
        strict_errors = [
            f"{field['field']}: {issue.reason}"
            for field in active_field_values(trial)
            for issue in scan_clue(str(trial.get("word", "")), field["current"])
        ]
        if strict_errors:
            raise ValueError(
                f"Replacement leaves inflection issues for {trial.get('word')}: "
                f"{strict_errors[:5]}"
            )
    return validated


def record_chat_batch(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    replacements: dict[str, Any],
    batch: dict[str, Any],
    decisions: dict[str, Any],
) -> int:
    validated = validate_chat_decisions(entries, audit, batch, decisions)
    existing_keys = {
        (item["index"], item["field"])
        for item in replacements.get("replacements", [])
    }
    for item in validated:
        key = (item["index"], item["field"])
        if key in existing_keys:
            raise ValueError(f"Replacement was already recorded: {key}")
        existing_keys.add(key)
        replacements["replacements"].append(item)

    reviewed_indexes = {item["index"] for item in batch["entries"]}
    for record in audit["records"]:
        if record["index"] in reviewed_indexes:
            if record.get("reviewed") is True:
                raise ValueError(f"Entry was already reviewed: {record['index']}")
            record["reviewed"] = True
            record["reviewedInBatch"] = batch["batchId"]
    audit["batches"].append({
        "batchId": batch["batchId"],
        "batchHash": batch["batchHash"],
        "reviewedAt": datetime.now(timezone.utc).isoformat(),
        "entryCount": batch["entryCount"],
        "fieldCount": batch["fieldCount"],
        "replacementCount": len(validated),
    })
    update_chat_summary(audit)
    replacements["updatedAt"] = datetime.now(timezone.utc).isoformat()
    replacements["reviewedFieldCount"] = audit["reviewedFieldCount"]
    replacements.setdefault("batchHashes", {})[batch["batchId"]] = batch["batchHash"]
    return len(validated)


def apply_chat_replacements_in_memory(
    entries: list[dict[str, Any]],
    replacements: dict[str, Any],
) -> list[dict[str, Any]]:
    updated = deepcopy(entries)
    seen: set[tuple[int, str]] = set()
    for item in replacements.get("replacements", []):
        index = item.get("index")
        field = item.get("field")
        key = (index, field)
        if key in seen:
            raise ValueError(f"Duplicate replacement in report: {key}")
        seen.add(key)
        if item.get("status") not in ACCEPTED_REPLACEMENT_STATUSES:
            raise ValueError(f"Unresolved replacement in report: {key}")
        if not isinstance(index, int) or not 0 <= index < len(updated):
            raise ValueError(f"Replacement index out of range: {index}")
        entry = updated[index]
        if entry.get("word") != item.get("word"):
            raise ValueError(f"Replacement word mismatch at index {index}")
        if get_field(entry, str(field)) != item.get("current"):
            raise ValueError(
                f"Replacement current-value mismatch for {entry.get('word')} {field}"
            )
        errors = replacement_validation_errors(entry, str(field), item.get("proposed"))
        if errors:
            raise ValueError(
                f"Invalid replacement for {entry.get('word')} {field}: {errors}"
            )
        set_field(entry, str(field), item["proposed"])
    return updated


def validate_complete_chat_review(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    replacements: dict[str, Any],
    bank_path: Path,
) -> list[dict[str, Any]]:
    validate_chat_preconditions(entries, audit, replacements, bank_path)
    update_chat_summary(audit)
    if audit["remainingEntryCount"] or audit["remainingFieldCount"]:
        raise ValueError(
            f"Chat review is incomplete: {audit['remainingEntryCount']} entries / "
            f"{audit['remainingFieldCount']} fields remain"
        )
    if audit["reviewedFieldCount"] != audit["activeFieldCount"]:
        raise ValueError("Reviewed field count does not equal active field count")
    updated = apply_chat_replacements_in_memory(entries, replacements)
    strict = scan_entries(updated)
    if strict:
        raise ValueError(
            f"Reviewed bank still has {sum(len(item['fields']) for item in strict)} "
            "known inflection mismatch(es)"
        )
    quality = [
        (index, errors)
        for index, entry in enumerate(updated)
        if (errors := validate_entry(entry))
    ]
    if quality:
        index, errors = quality[0]
        raise ValueError(
            f"Reviewed bank has clue-quality errors at index {index}: {errors[:5]}"
        )
    return updated


def apply_replacements(entries: list[dict[str, Any]], replacement_file: dict[str, Any]) -> int:
    changed = 0
    for item in replacement_file.get("replacements", []):
        index = int(item["index"])
        word = item["word"]
        if index >= len(entries):
            raise IndexError(f"Replacement index out of range: {index}")
        entry = entries[index]
        if entry.get("word") != word:
            raise ValueError(f"Word mismatch at index {index}: expected {word}, found {entry.get('word')}")

        for field in item.get("fields", []):
            label = field["field"]
            current = field["current"]
            proposed = field["proposed"]
            actual = get_field(entry, label)
            if actual != current:
                raise ValueError(f"{word} {label} changed since export: expected {current!r}, found {actual!r}")
            remaining = scan_clue(word, proposed)
            if remaining:
                reasons = ", ".join(issue.reason for issue in remaining)
                raise ValueError(f"Replacement still fails inflection scan for {word} {label}: {reasons} -> {proposed!r}")
            derivability = scan_field(str(word), proposed, DEFAULT_REVIEW_THRESHOLD, DEFAULT_HIGH_THRESHOLD)
            if derivability:
                reasons = ", ".join(derivability.get("reasons", ["UNKNOWN"]))
                raise ValueError(f"Replacement fails answer-safety scan for {word} {label}: {reasons} -> {proposed!r}")
            set_field(entry, label, proposed)
            changed += 1
    return changed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit strict word-bank clue inflections.")
    parser.add_argument("command", choices=[
        "sample",
        "wide",
        "export",
        "apply",
        "validate",
        "init-chat-review",
        "export-chat-batch",
        "record-chat-batch",
        "validate-chat-review",
        "apply-chat-review",
    ])
    parser.add_argument("decision_path", nargs="?", type=Path)
    parser.add_argument("--bank", type=Path, default=BANK_PATH)
    parser.add_argument("--count", type=int, help="Limit output count. sample defaults to 50; wide defaults to all candidates.")
    parser.add_argument("--limit", type=int, default=100, help="Maximum entries in a chat-review batch.")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--input", type=Path, dest="input_path")
    parser.add_argument("--audit", type=Path, default=CHAT_AUDIT_PATH)
    parser.add_argument("--batch", type=Path, default=CHAT_BATCH_PATH)
    parser.add_argument("--replacements", type=Path, default=CHAT_REPLACEMENTS_PATH)
    parser.add_argument("--force", action="store_true", help="Replace existing chat-review checkpoints during initialization.")
    parser.add_argument("--high-only", action="store_true", help="For wide scans, include only high-confidence candidates.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    entries = load_entries(args.bank)

    if args.command == "init-chat-review":
        existing = [path for path in (args.audit, args.replacements) if path.exists()]
        if existing and not args.force:
            names = ", ".join(str(path) for path in existing)
            raise SystemExit(
                f"Chat-review state already exists: {names}. Use --force to replace it."
            )
        audit = new_chat_audit(entries, args.bank)
        replacements = new_chat_replacements(audit)
        write_json(args.audit, audit)
        write_json(args.replacements, replacements)
        print(
            f"Initialized chat review for {audit['inScopeEntryCount']} entries / "
            f"{audit['activeFieldCount']} active fields."
        )
        return

    if args.command in {
        "export-chat-batch",
        "record-chat-batch",
        "validate-chat-review",
        "apply-chat-review",
    }:
        if not args.audit.exists() or not args.replacements.exists():
            raise SystemExit("Chat-review state is missing; run init-chat-review first.")
        audit = json.loads(args.audit.read_text())
        replacements = json.loads(args.replacements.read_text())
        validate_chat_preconditions(entries, audit, replacements, args.bank)

        if args.command == "export-chat-batch":
            batch = build_chat_batch(audit, args.limit)
            write_json(args.batch, batch)
            print(
                f"Exported {batch['entryCount']} entries / {batch['fieldCount']} fields "
                f"to {args.batch}; {audit['remainingFieldCount']} fields remain before recording."
            )
            return

        if args.command == "record-chat-batch":
            if args.decision_path is None:
                raise SystemExit("record-chat-batch requires a decisions JSON path")
            if not args.batch.exists():
                raise SystemExit(f"Chat batch does not exist: {args.batch}")
            if not args.decision_path.exists():
                raise SystemExit(f"Chat decisions do not exist: {args.decision_path}")
            batch = json.loads(args.batch.read_text())
            decisions = json.loads(args.decision_path.read_text())
            changed = record_chat_batch(
                entries,
                audit,
                replacements,
                batch,
                decisions,
            )
            write_json(args.audit, audit)
            write_json(args.replacements, replacements)
            print(
                f"Recorded batch {batch['batchId']} with {changed} replacement(s); "
                f"{audit['remainingEntryCount']} entries / "
                f"{audit['remainingFieldCount']} fields remain."
            )
            return

        updated = validate_complete_chat_review(
            entries,
            audit,
            replacements,
            args.bank,
        )
        if args.command == "validate-chat-review":
            print(
                f"Chat review is complete: {audit['reviewedEntryCount']} entries / "
                f"{audit['reviewedFieldCount']} fields reviewed, "
                f"{len(replacements['replacements'])} replacement(s) approved."
            )
            return
        save_entries(args.bank, updated)
        print(
            f"Applied {len(replacements['replacements'])} approved chat-reviewed "
            f"replacement(s) to {args.bank}."
        )
        return

    if args.command == "sample":
        output = args.output or SAMPLE_PATH
        findings = scan_entries(entries, limit=args.count or 50)
        report = build_review_file(entries, findings, args.bank)
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        print_sample(report)
        print(f"Sample review file written to {output}")
        return

    if args.command == "wide":
        output = args.output or WIDE_PATH
        findings = wide_scan_entries(entries)
        if args.high_only:
            findings = [
                finding for finding in findings
                if any(field["confidence"] == "high" for field in finding["fields"])
            ]
        if args.count is not None:
            findings = findings[:args.count]
        report = build_wide_review_file(entries, findings, args.bank)
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        print_wide_report(report)
        print(f"Wide review file written to {output}")
        return

    if args.command == "export":
        output = args.output or REPLACEMENTS_PATH
        findings = scan_entries(entries)
        report = build_review_file(entries, findings, args.bank)
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        print(f"Exported {report['flaggedEntryCount']} flagged entries ({report['flaggedFieldCount']} fields) to {output}")
        return

    if args.command == "apply":
        input_path = args.input_path or REPLACEMENTS_PATH
        if not input_path.exists():
            print(f"Replacement file not found: {input_path}", file=sys.stderr)
            raise SystemExit(1)
        replacements = json.loads(input_path.read_text())
        changed = apply_replacements(entries, replacements)
        save_entries(args.bank, entries)
        print(f"Applied {changed} reviewed field replacement(s) to {args.bank}")
        return

    if args.command == "validate":
        findings = scan_entries(entries)
        if findings:
            report = build_review_file(entries, findings, args.bank)
            print(f"Validation failed: {report['flaggedEntryCount']} entries require review.", file=sys.stderr)
            print(json.dumps(report["summary"], indent=2), file=sys.stderr)
            raise SystemExit(1)
        print("Validation passed: no known strict-inflection mismatches found.")


if __name__ == "__main__":
    main()
