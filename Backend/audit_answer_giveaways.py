#!/usr/bin/env python3
"""Review-first, no-API workflow for mechanical crossword answer giveaways.

The local scanner creates a high-recall candidate set.  Terra reviews exported
JSON batches in Codex; this script only validates and records those decisions.
It never calls an OpenAI API.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from answer_leakage import giveaway_candidates, scan_text
from word_bank_safety import (
    BACKEND_DIR,
    CERTIFICATION_PATH,
    DETERMINISTIC_PROVENANCE,
    POLICY_VERSION,
    SCANNER_VERSION,
    TERRA_PROVENANCE,
    active_fields,
    certification_errors,
    current_pairs,
    new_certification,
    pair_fingerprint,
)


BANK_PATH = BACKEND_DIR / "word_bank.json"
AUDIT_PATH = BACKEND_DIR / "word_bank_answer_giveaway_audit.json"
BATCH_PATH = BACKEND_DIR / "word_bank_answer_giveaway_terra_batch.json"
REPAIRS_PATH = BACKEND_DIR / "word_bank_answer_giveaway_repairs.json"
REPLACEMENT_BATCH_PATH = BACKEND_DIR / "word_bank_answer_giveaway_replacement_terra_batch.json"
AUTHORING_BATCH_PATH = BACKEND_DIR / ".cache" / "word_bank_answer_giveaway_authoring_batch.json"
REPAIR_REPORT_PATH = BACKEND_DIR / "word_bank_answer_giveaway_repair_report.md"
PROPOSAL_REPORT_PATH = BACKEND_DIR / "word_bank_answer_giveaway_generated_proposals.md"
SCHEMA_VERSION = 1
VALID_VERDICTS = {"safe", "giveaway", "needs_review"}
ENUMERATION_SUFFIX_RE = re.compile(r"\s*(\((?:\d+\s*[, -]\s*)*\d+\))\s*$")


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_json(path: Path) -> Any:
    with path.open() as handle:
        return json.load(handle)


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def bank_sha256(path: Path = BANK_PATH) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stable_hash(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def load_entries(path: Path = BANK_PATH) -> list[dict[str, Any]]:
    value = load_json(path)
    if not isinstance(value, list):
        raise ValueError("word_bank.json must be a JSON array")
    return value


def candidate_record(index: int, word: str, field: str, clue: str) -> dict[str, Any]:
    candidates = [issue.as_dict() for issue in giveaway_candidates(word, clue)]
    deterministic = [issue.as_dict() for issue in scan_text(word, clue)]
    return {
        "field": field,
        "current": clue,
        "fingerprint": pair_fingerprint(word, field, clue),
        "candidates": candidates,
        "deterministicIssues": deterministic,
        # High-confidence mechanical forms are already policy failures. Terra
        # is reserved for the deliberately broader spelling-family candidates
        # that can legitimately be ordinary synonyms or unrelated words.
        "status": (
            "confirmed_deterministic_giveaway"
            if deterministic
            else "pending_terra"
            if candidates
            else "deterministic_safe"
        ),
        "terraPrimary": None,
        "terraVerifier": None,
    }


def new_audit(entries: list[dict[str, Any]], bank_path: Path = BANK_PATH) -> dict[str, Any]:
    records = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", "")).strip().upper()
        if not word:
            continue
        fields = [candidate_record(index, word, field, clue) for field, clue in active_fields(entry)]
        records.append({"index": index, "word": word, "fields": fields})
    return {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": now(),
        "updatedAt": now(),
        "bankSha256": bank_sha256(bank_path),
        "policyVersion": POLICY_VERSION,
        "scannerVersion": SCANNER_VERSION,
        "reviewer": "Terra in Codex; no API calls",
        "records": records,
    }


def refresh_audit_after_repairs(
    entries: list[dict[str, Any]],
    previous_audit: dict[str, Any],
    bank_path: Path = BANK_PATH,
) -> dict[str, Any]:
    """Rescan changed fields while retaining review decisions for identical pairs."""
    refreshed = new_audit(entries, bank_path)
    previous_fields = {
        field["fingerprint"]: field
        for record in previous_audit.get("records", [])
        for field in record.get("fields", [])
        if isinstance(field, dict) and isinstance(field.get("fingerprint"), str)
    }
    for record in refreshed["records"]:
        for field in record["fields"]:
            previous = previous_fields.get(field["fingerprint"])
            # The live deterministic scan is authoritative.  In particular,
            # never carry a historical safe verdict across a field which the
            # current policy now identifies as a mechanical giveaway.
            if previous is None or field["deterministicIssues"]:
                continue
            field["status"] = previous.get("status", field["status"])
            field["terraPrimary"] = previous.get("terraPrimary")
            field["terraVerifier"] = previous.get("terraVerifier")
    refreshed["reviewer"] = previous_audit.get("reviewer", refreshed["reviewer"])
    return refreshed


def validate_audit(entries: list[dict[str, Any]], audit: dict[str, Any], bank_path: Path = BANK_PATH) -> None:
    if audit.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError("unsupported giveaway-audit schema")
    if audit.get("bankSha256") != bank_sha256(bank_path):
        raise ValueError("stale giveaway audit: word_bank.json changed")
    if audit.get("policyVersion") != POLICY_VERSION or audit.get("scannerVersion") != SCANNER_VERSION:
        raise ValueError("giveaway audit uses an obsolete policy or scanner")
    records = audit.get("records")
    if not isinstance(records, list) or len(records) != len(entries):
        raise ValueError("giveaway audit does not cover every word-bank entry")
    for index, (entry, record) in enumerate(zip(entries, records)):
        word = str(entry.get("word", "")).strip().upper()
        if record.get("index") != index or record.get("word") != word:
            raise ValueError(f"giveaway audit entry mismatch at index {index}")
        expected = {(field, clue, pair_fingerprint(word, field, clue)) for field, clue in active_fields(entry)}
        actual = {
            (item.get("field"), item.get("current"), item.get("fingerprint"))
            for item in record.get("fields", [])
            if isinstance(item, dict)
        }
        if expected != actual:
            raise ValueError(f"giveaway audit active fields changed for {word}")


def pending_fields(audit: dict[str, Any], stage: str) -> list[dict[str, Any]]:
    result = []
    for record in audit["records"]:
        for field in record["fields"]:
            if stage == "primary" and field["status"] == "pending_terra":
                result.append({"index": record["index"], "word": record["word"], **field})
            if stage == "verify" and field["status"] == "pending_verification":
                result.append({"index": record["index"], "word": record["word"], **field})
    return result


def new_batch(audit: dict[str, Any], stage: str, limit: int) -> dict[str, Any]:
    if stage not in {"primary", "verify", "replacement_verify"}:
        raise ValueError("invalid Terra review stage")
    if limit < 1:
        raise ValueError("limit must be positive")
    fields = pending_fields(audit, stage)[:limit] if stage != "replacement_verify" else []
    batch = {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": now(),
        "bankSha256": audit["bankSha256"],
        "policyVersion": POLICY_VERSION,
        "scannerVersion": SCANNER_VERSION,
        "stage": stage,
        "records": fields,
    }
    batch["batchId"] = f"{stage}-{fields[0]['fingerprint'][:12] if fields else 'complete'}-{len(fields)}"
    batch["batchHash"] = stable_hash({key: value for key, value in batch.items() if key not in {"generatedAt", "batchHash"}})
    return batch


def validate_decisions(batch: dict[str, Any], decisions: dict[str, Any]) -> dict[str, dict[str, str]]:
    for key in ("schemaVersion", "bankSha256", "policyVersion", "scannerVersion", "stage", "batchId", "batchHash"):
        if decisions.get(key) != batch.get(key):
            raise ValueError(f"decision {key} does not match the exported batch")
    expected = {record["fingerprint"] for record in batch["records"]}
    received: dict[str, dict[str, str]] = {}
    for item in decisions.get("decisions", []):
        fingerprint = item.get("fingerprint") if isinstance(item, dict) else None
        verdict = item.get("verdict") if isinstance(item, dict) else None
        reason = item.get("reason") if isinstance(item, dict) else None
        if not isinstance(fingerprint, str) or fingerprint not in expected or fingerprint in received:
            raise ValueError("decision has an invalid or duplicate fingerprint")
        if verdict not in VALID_VERDICTS or not isinstance(reason, str) or not reason.strip():
            raise ValueError("decision has an invalid verdict or reason")
        received[fingerprint] = {"verdict": verdict, "reason": reason.strip()}
    if set(received) != expected:
        raise ValueError("Terra decisions must cover every exported field")
    return received


def record_decisions(audit: dict[str, Any], batch: dict[str, Any], decisions: dict[str, Any]) -> int:
    verdicts = validate_decisions(batch, decisions)
    field_map = {field["fingerprint"]: field for record in audit["records"] for field in record["fields"]}
    for fingerprint, verdict in verdicts.items():
        field = field_map[fingerprint]
        if batch["stage"] == "primary":
            field["terraPrimary"] = verdict
            field["status"] = "terra_safe" if verdict["verdict"] == "safe" else "pending_verification"
        elif batch["stage"] == "verify":
            field["terraVerifier"] = verdict
            primary = (field.get("terraPrimary") or {}).get("verdict")
            if primary == "giveaway" and verdict["verdict"] == "giveaway":
                field["status"] = "confirmed_giveaway"
            elif primary == "needs_review" or verdict["verdict"] == "needs_review" or primary != verdict["verdict"]:
                field["status"] = "manual_review"
            else:
                field["status"] = "terra_safe"
        else:
            raise ValueError("replacement verification is recorded in its repair package")
    audit["updatedAt"] = now()
    return len(verdicts)


def summary(audit: dict[str, Any]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for record in audit["records"]:
        for field in record["fields"]:
            status = field["status"]
            counts[status] = counts.get(status, 0) + 1
    return counts


def build_repair_package(audit: dict[str, Any]) -> dict[str, Any]:
    repairs = []
    for record in audit["records"]:
        for field in record["fields"]:
            if field["status"] not in {"confirmed_giveaway", "confirmed_deterministic_giveaway"}:
                continue
            repairs.append({
                "index": record["index"],
                "word": record["word"],
                "field": field["field"],
                "before": field["current"],
                "fingerprint": field["fingerprint"],
                "reasons": field["candidates"],
                "status": "pending_replacement",
                "after": None,
                "verification": None,
            })
    return {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": now(),
        "bankSha256": audit["bankSha256"],
        "policyVersion": POLICY_VERSION,
        "scannerVersion": SCANNER_VERSION,
        "repairs": repairs,
    }


def replacement_fingerprint(repair: dict[str, Any]) -> str:
    """Bind one proposed clue to both its original pair and replacement text."""
    return stable_hash({
        "word": repair.get("word"),
        "field": repair.get("field"),
        "before": repair.get("before"),
        "pairFingerprint": repair.get("fingerprint"),
        "after": repair.get("after"),
    })


def normalized_clue(value: str) -> str:
    return " ".join(value.casefold().split())


def proposed_hint_collision_errors(entries: list[dict[str, Any]], package: dict[str, Any], statuses: set[str]) -> list[str]:
    """Ensure a new hint never duplicates a sibling active clue for its answer."""
    repairs_by_index: dict[int, list[dict[str, Any]]] = {}
    for repair in package.get("repairs", []):
        if repair.get("status") in statuses and isinstance(repair.get("index"), int) and isinstance(repair.get("after"), str):
            repairs_by_index.setdefault(repair["index"], []).append(repair)
    errors = []
    for index, repairs in repairs_by_index.items():
        if not 0 <= index < len(entries):
            continue
        entry = json.loads(json.dumps(entries[index]))
        for repair in repairs:
            set_field(entry, repair["field"], repair["after"].strip())
        fields = active_fields(entry)
        by_value: dict[str, list[str]] = {}
        for field, clue in fields:
            by_value.setdefault(normalized_clue(clue), []).append(field)
        for value, fields_with_value in by_value.items():
            if len(fields_with_value) < 2:
                continue
            touched = {repair["field"] for repair in repairs}
            if touched.intersection(fields_with_value):
                errors.append(
                    f"{str(entry.get('word', '')).upper()} proposed hint duplicates {', '.join(fields_with_value)}: {value}"
                )
    return errors


def replacement_verification_batch(entries: list[dict[str, Any]], package: dict[str, Any], limit: int) -> dict[str, Any]:
    if limit < 1:
        raise ValueError("limit must be positive")
    errors = proposed_hint_collision_errors(entries, package, {"proposed"})
    if errors:
        raise ValueError("Cannot verify duplicate hint proposals:\n" + "\n".join(errors[:20]))
    records = []
    for repair in package.get("repairs", []):
        if repair.get("status") != "proposed" or not isinstance(repair.get("after"), str) or not repair["after"].strip():
            continue
        records.append({
            "index": repair.get("index"),
            "word": repair.get("word"),
            "field": repair.get("field"),
            "before": repair.get("before"),
            "after": repair["after"].strip(),
            "pairFingerprint": repair.get("fingerprint"),
            "proposalFingerprint": replacement_fingerprint(repair),
            "reasons": repair.get("reasons", []),
        })
        if len(records) == limit:
            break
    batch = {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": now(),
        "bankSha256": package.get("bankSha256"),
        "policyVersion": package.get("policyVersion"),
        "scannerVersion": package.get("scannerVersion"),
        "stage": "replacement_verify",
        "records": records,
    }
    batch["batchId"] = f"replacement_verify-{records[0]['proposalFingerprint'][:12] if records else 'complete'}-{len(records)}"
    batch["batchHash"] = stable_hash({key: value for key, value in batch.items() if key not in {"generatedAt", "batchHash"}})
    return batch


def validate_replacement_decisions(batch: dict[str, Any], decisions: dict[str, Any]) -> dict[str, dict[str, str]]:
    for key in ("schemaVersion", "bankSha256", "policyVersion", "scannerVersion", "stage", "batchId", "batchHash"):
        if decisions.get(key) != batch.get(key):
            raise ValueError(f"decision {key} does not match the exported batch")
    expected = {record["proposalFingerprint"] for record in batch["records"]}
    received: dict[str, dict[str, str]] = {}
    for item in decisions.get("decisions", []):
        fingerprint = item.get("proposalFingerprint") if isinstance(item, dict) else None
        verdict = item.get("verdict") if isinstance(item, dict) else None
        reason = item.get("reason") if isinstance(item, dict) else None
        if not isinstance(fingerprint, str) or fingerprint not in expected or fingerprint in received:
            raise ValueError("replacement decision has an invalid or duplicate proposal fingerprint")
        if verdict not in VALID_VERDICTS or not isinstance(reason, str) or not reason.strip():
            raise ValueError("replacement decision has an invalid verdict or reason")
        received[fingerprint] = {"verdict": verdict, "reason": reason.strip()}
    if set(received) != expected:
        raise ValueError("Terra decisions must cover every exported replacement")
    return received


def record_replacement_decisions(package: dict[str, Any], batch: dict[str, Any], decisions: dict[str, Any]) -> int:
    verdicts = validate_replacement_decisions(batch, decisions)
    repairs = {replacement_fingerprint(repair): repair for repair in package.get("repairs", [])}
    for fingerprint, verdict in verdicts.items():
        repair = repairs.get(fingerprint)
        if repair is None or repair.get("status") != "proposed":
            raise ValueError("replacement changed since Terra verification export")
        repair["verification"] = {**verdict, "proposalFingerprint": fingerprint}
        repair["status"] = "verified" if verdict["verdict"] == "safe" else "manual_review"
    return len(verdicts)


def approve_verified_repairs(package: dict[str, Any]) -> int:
    """Promote only already blind-verified, hash-bound proposals for application."""
    changed = 0
    for repair in package.get("repairs", []):
        if repair.get("status") != "verified":
            continue
        verification = repair.get("verification") or {}
        if verification.get("verdict") != "safe" or verification.get("proposalFingerprint") != replacement_fingerprint(repair):
            raise ValueError(f"{repair.get('word')} {repair.get('field')} cannot be approved with stale verification")
        repair["status"] = "approved"
        changed += 1
    return changed


def repair_report(package: dict[str, Any]) -> str:
    repairs = package.get("repairs", [])
    counts: dict[str, int] = {}
    for repair in repairs:
        status = str(repair.get("status", "invalid"))
        counts[status] = counts.get(status, 0) + 1
    lines = [
        "# Mechanical Answer Giveaway Repair Review",
        "",
        f"Bank SHA-256: `{package.get('bankSha256', '')}`",
        "",
        "## Status",
        "",
        "| Status | Fields |",
        "| --- | ---: |",
    ]
    lines.extend(f"| {status} | {count} |" for status, count in sorted(counts.items()))
    reviewable = [repair for repair in repairs if repair.get("after")]
    if reviewable:
        lines.extend(["", "## Proposed changes", "", "| Answer | Field | Before | Proposed | Blind Terra |", "| --- | --- | --- | --- | --- |"])
        for repair in reviewable:
            verification = repair.get("verification") or {}
            verdict = verification.get("verdict", "pending")
            before = str(repair.get("before", "")).replace("|", "\\|")
            after = str(repair.get("after", "")).replace("|", "\\|")
            lines.append(f"| {repair.get('word')} | {repair.get('field')} | {before} | {after} | {verdict} |")
    return "\n".join(lines) + "\n"


def proposal_report(batch: dict[str, Any], proposals: list[dict[str, Any]]) -> str:
    """Render a review-only before/after table for an exact authoring batch."""
    records = batch.get("records")
    if not isinstance(records, list) or len(records) != len(proposals):
        raise ValueError("proposal report must cover every authoring-batch record")
    lines = [
        "# Word-Bank Giveaway Replacement Proposals",
        "",
        f"{len(records)} current, hash-bound proposals. Review only; none have been imported or applied.",
        "",
        "| Answer | Field | Current clue | Proposed replacement |",
        "| --- | --- | --- | --- |",
    ]
    for record, proposal in zip(records, proposals, strict=True):
        if not isinstance(proposal, dict) or any(proposal.get(key) != record.get(key) for key in ("fingerprint", "word", "field")):
            raise ValueError("proposal report has a missing, reordered, or mismatched authoring record")
        after = proposal.get("after")
        if not isinstance(after, str) or not after.strip():
            raise ValueError(f"{record['word']} {record['field']} has no proposed replacement")
        def cell(value: Any) -> str:
            return str(value).replace("|", "\\|").replace("\n", " ")
        lines.append(
            f"| {cell(record['word'])} | {cell(record['field'])} | {cell(record['before'])} | {cell(after.strip())} |"
        )
    return "\n".join(lines) + "\n"


def normalize_proposals(
    batch: dict[str, Any], proposals: list[dict[str, Any]], overrides: dict[str, str],
) -> list[dict[str, Any]]:
    """Restore batch fingerprints and apply explicit, reviewable wording corrections."""
    records = batch.get("records")
    if not isinstance(records, list) or len(records) != len(proposals):
        raise ValueError("proposal normalization must cover every authoring-batch record")
    records_by_identity = {(record["word"], record["field"]): record for record in records}
    if len(records_by_identity) != len(records):
        raise ValueError("authoring batch has ambiguous word/field identities")
    normalized: list[dict[str, Any]] = []
    for proposal in proposals:
        if not isinstance(proposal, dict):
            raise ValueError("proposal normalization received an invalid proposal")
        identity = (proposal.get("word"), proposal.get("field"))
        record = records_by_identity.get(identity)
        if record is None:
            raise ValueError("proposal normalization has an unknown word/field identity")
        after = proposal.get("after")
        if not isinstance(after, str) or not after.strip():
            raise ValueError(f"{record['word']} {record['field']} has no proposed replacement")
        key = f"{record['word']} {record['field']}"
        normalized.append({
            "fingerprint": record["fingerprint"],
            "word": record["word"],
            "field": record["field"],
            "after": overrides.get(key, after.strip()),
        })
    return normalized


def get_field(entry: dict[str, Any], field: str) -> str:
    if field.startswith("clues[") and field.endswith("]"):
        index = int(field[6:-1])
        return str((entry.get("clues") or [])[index])
    return str(entry.get(field, ""))


def set_field(entry: dict[str, Any], field: str, value: str) -> None:
    if field.startswith("clues[") and field.endswith("]"):
        index = int(field[6:-1])
        entry["clues"][index] = value
    else:
        entry[field] = value


def preserve_enumeration(before: str, after: str) -> str:
    """Keep a source clue's displayed letter-count suffix on its rewrite."""
    match = ENUMERATION_SUFFIX_RE.search(before)
    if not match or ENUMERATION_SUFFIX_RE.search(after):
        return after.strip()
    return f"{after.strip()} {match.group(1)}"


def normalize_proposal_enumerations(package: dict[str, Any]) -> int:
    """Append missing source enumerations and invalidate altered verification."""
    changed = 0
    for repair in package.get("repairs", []):
        after = repair.get("after")
        if not isinstance(after, str):
            continue
        normalized = preserve_enumeration(str(repair.get("before", "")), after)
        if normalized != after:
            repair["after"] = normalized
            if repair.get("status") in {"proposed", "verified", "approved"}:
                repair["status"] = "proposed"
                repair.pop("verification", None)
            changed += 1
    return changed


def import_proposals(
    entries: list[dict[str, Any]],
    package: dict[str, Any],
    proposals: list[dict[str, Any]],
    *,
    skip_unmatched: bool = False,
) -> int:
    if package.get("bankSha256") != bank_sha256():
        raise ValueError("repair package is stale")
    # A blind-verification rejection is not terminal: a replacement author may
    # revise that exact source pair and send it through a fresh verification
    # cycle.  The fingerprint still binds the repair to its unchanged source.
    pending_repairs = [
        repair
        for repair in package.get("repairs", [])
        if repair.get("status") in {"pending_replacement", "manual_review"}
    ]
    pending_by_fingerprint: dict[str, list[dict[str, Any]]] = {}
    pending_by_identity: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for repair in pending_repairs:
        fingerprint = repair.get("fingerprint")
        if isinstance(fingerprint, str):
            pending_by_fingerprint.setdefault(fingerprint, []).append(repair)
        identity = (str(repair.get("word", "")).upper(), str(repair.get("field", "")))
        pending_by_identity.setdefault(identity, []).append(repair)
    received: set[str] = set()
    for proposal in proposals:
        if not isinstance(proposal, dict):
            raise ValueError("proposal has an unknown or duplicate pending fingerprint")
        fingerprint = proposal.get("fingerprint")
        if isinstance(fingerprint, str):
            matches = pending_by_fingerprint.get(fingerprint, [])
            repair = matches[0] if len(matches) == 1 else None
        else:
            word = proposal.get("word")
            field = proposal.get("field")
            matches = pending_by_identity.get((str(word).upper(), str(field)), []) if isinstance(word, str) and isinstance(field, str) else []
            if len(matches) != 1:
                raise ValueError("proposal has an unknown or ambiguous pending word/field pair")
            repair = matches[0]
            fingerprint = repair["fingerprint"]
        if repair is None and skip_unmatched:
            continue
        if fingerprint in received or repair is None:
            raise ValueError("proposal has an unknown or duplicate pending fingerprint")
        if (
            isinstance(proposal.get("word"), str)
            and str(proposal["word"]).upper() != repair["word"]
        ) or (
            isinstance(proposal.get("field"), str)
            and proposal["field"] != repair["field"]
        ):
            raise ValueError("proposal identity does not match its pending fingerprint")
        after = proposal.get("after")
        if not isinstance(after, str) or not after.strip():
            raise ValueError(f"{repair['word']} {repair['field']} has no replacement")
        after = preserve_enumeration(str(repair.get("before", "")), after)
        index = repair["index"]
        if not 0 <= index < len(entries) or get_field(entries[index], repair["field"]) != repair["before"]:
            raise ValueError(f"{repair['word']} {repair['field']} changed since repair export")
        if giveaway_candidates(repair["word"], after):
            raise ValueError(f"{repair['word']} {repair['field']} proposal has mechanical leakage")
        repair.update({"status": "proposed", "after": after.strip(), "verification": None})
        received.add(fingerprint)
    errors = proposed_hint_collision_errors(entries, package, {"proposed"})
    if errors:
        raise ValueError("proposal duplicates a sibling active clue:\n" + "\n".join(errors[:20]))
    return len(received)


def authoring_batch(package: dict[str, Any], limit: int) -> dict[str, Any]:
    """Export the current, hash-bound repair subset for local proposal authoring."""
    repairs = [
        {
            "fingerprint": repair["fingerprint"],
            "word": repair["word"],
            "field": repair["field"],
            "before": repair["before"],
        }
        for repair in package.get("repairs", [])
        if repair.get("status") == "pending_replacement"
    ][:limit]
    return {
        "schemaVersion": SCHEMA_VERSION,
        "bankSha256": package["bankSha256"],
        "policyVersion": package["policyVersion"],
        "scannerVersion": package["scannerVersion"],
        "stage": "replacement_authoring",
        "records": repairs,
        "batchHash": stable_hash(repairs),
    }


def validate_repair_package(
    entries: list[dict[str, Any]],
    package: dict[str, Any],
    bank_path: Path = BANK_PATH,
) -> list[str]:
    errors = []
    if package.get("schemaVersion") != SCHEMA_VERSION or package.get("bankSha256") != bank_sha256(bank_path):
        return ["repair package is stale or uses an unsupported schema"]
    if package.get("policyVersion") != POLICY_VERSION or package.get("scannerVersion") != SCANNER_VERSION:
        return ["repair package uses an obsolete policy or scanner"]
    for repair in package.get("repairs", []):
        if repair.get("status") != "approved":
            continue
        index = repair.get("index")
        if not isinstance(index, int) or not 0 <= index < len(entries):
            errors.append("approved repair has an invalid index")
            continue
        entry = entries[index]
        word = str(entry.get("word", "")).upper()
        before = repair.get("before")
        after = repair.get("after")
        field = repair.get("field")
        if word != repair.get("word") or not isinstance(field, str) or get_field(entry, field) != before:
            errors.append(f"{repair.get('word')} {field} changed since repair export")
            continue
        if not isinstance(after, str) or not after.strip():
            errors.append(f"{word} {field} has no replacement")
            continue
        if scan_text(word, after):
            errors.append(f"{word} {field} replacement has deterministic leakage")
        verification = repair.get("verification") or {}
        if verification.get("verdict") != "safe" or not isinstance(verification.get("reason"), str):
            errors.append(f"{word} {field} replacement lacks blind Terra approval")
        elif verification.get("proposalFingerprint") != replacement_fingerprint(repair):
            errors.append(f"{word} {field} replacement verification is stale")
    errors.extend(proposed_hint_collision_errors(entries, package, {"approved"}))
    return errors


def apply_repairs(entries: list[dict[str, Any]], package: dict[str, Any]) -> list[dict[str, Any]]:
    updated = json.loads(json.dumps(entries))
    for repair in package.get("repairs", []):
        if repair.get("status") == "approved":
            set_field(updated[repair["index"]], repair["field"], repair["after"].strip())
    return updated


def certify(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    bank_path: Path = BANK_PATH,
) -> dict[str, Any]:
    validate_audit(entries, audit, bank_path)
    records_by_fingerprint = {field["fingerprint"]: field for record in audit["records"] for field in record["fields"]}
    certificate_records = []
    unresolved = []
    for pair in current_pairs(entries):
        record = records_by_fingerprint[pair["fingerprint"]]
        status = record["status"]
        if status == "deterministic_safe":
            provenance = DETERMINISTIC_PROVENANCE
        elif status == "terra_safe":
            provenance = TERRA_PROVENANCE
        else:
            unresolved.append(f"{pair['answer']} {pair['field']} ({status})")
            continue
        certificate_records.append({
            **pair,
            "provenance": provenance,
            "auditStatus": status,
        })
    if unresolved:
        raise ValueError("Cannot certify unresolved giveaway fields:\n" + "\n".join(unresolved[:20]))
    certificate = new_certification(certificate_records)
    errors = certification_errors(entries, certificate)
    if errors:
        raise ValueError("Refusing invalid certification:\n" + "\n".join(errors[:20]))
    return certificate


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit mechanical crossword answer giveaways without an API")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("init", help="Create a new checksum-bound audit")
    commands.add_parser("refresh-audit", help="Refresh a stale audit while retaining unchanged review decisions")
    for command in ("export-primary", "export-verification"):
        item = commands.add_parser(command, help="Export a Terra review batch for Codex")
        item.add_argument("--limit", type=int, default=50)
    for command in ("record-primary", "record-verification"):
        item = commands.add_parser(command, help="Record a checksum-bound Terra decision file")
        item.add_argument("decisions", type=Path)
    replacement_export = commands.add_parser("export-replacement-verification", help="Export proposed repair clues for blind Terra verification")
    replacement_export.add_argument("package", nargs="?", type=Path, default=REPAIRS_PATH)
    replacement_export.add_argument("--limit", type=int, default=50)
    replacement_record = commands.add_parser("record-replacement-verification", help="Record blind Terra decisions for proposed repair clues")
    replacement_record.add_argument("decisions", type=Path)
    replacement_record.add_argument("package", nargs="?", type=Path, default=REPAIRS_PATH)
    commands.add_parser("summary", help="Show field-level audit progress")
    commands.add_parser("build-repairs", help="Export confirmed giveaway repairs for Terra authoring")
    authoring = commands.add_parser("export-repair-authoring", help="Export current, hash-bound repairs for Terra authoring")
    authoring.add_argument("package", nargs="?", type=Path, default=REPAIRS_PATH)
    authoring.add_argument("--limit", type=int, default=300)
    authoring.add_argument("--output", type=Path, default=AUTHORING_BATCH_PATH)
    proposal_import = commands.add_parser("import-proposals", help="Import local, hash-bound Terra replacement proposals")
    proposal_import.add_argument("proposals", type=Path)
    proposal_import.add_argument("package", nargs="?", type=Path, default=REPAIRS_PATH)
    proposal_import.add_argument(
        "--skip-unmatched",
        action="store_true",
        help="Resume after partial application by skipping proposals whose exact source pair is no longer pending",
    )
    approve = commands.add_parser("approve-verified-repairs", help="Mark all currently blind-verified replacements approved")
    approve.add_argument("package", nargs="?", type=Path, default=REPAIRS_PATH)
    approve.add_argument("--all-verified", action="store_true", help="Required acknowledgement for every currently verified proposal")
    report = commands.add_parser("report-repairs", help="Write a compact before/after repair review report")
    report.add_argument("package", nargs="?", type=Path, default=REPAIRS_PATH)
    report.add_argument("--output", type=Path, default=REPAIR_REPORT_PATH)
    proposal_report_command = commands.add_parser("report-proposals", help="Write a review-only before/after report for an authoring batch")
    proposal_report_command.add_argument("proposals", type=Path)
    proposal_report_command.add_argument("--batch", type=Path, default=AUTHORING_BATCH_PATH)
    proposal_report_command.add_argument("--output", type=Path, default=PROPOSAL_REPORT_PATH)
    normalize = commands.add_parser("normalize-proposals", help="Restore authoring metadata and apply explicit proposal corrections")
    normalize.add_argument("proposals", type=Path)
    normalize.add_argument("--batch", type=Path, required=True)
    normalize.add_argument("--overrides", type=Path, required=True)
    normalize.add_argument("--output", type=Path, required=True)
    validate = commands.add_parser("validate-repairs", help="Validate approved repair proposals without writing")
    validate.add_argument("package", nargs="?", type=Path, default=REPAIRS_PATH)
    apply = commands.add_parser("apply-repairs", help="Apply only approved and Terra-verified repair proposals")
    apply.add_argument("package", nargs="?", type=Path, default=REPAIRS_PATH)
    apply.add_argument("--yes", action="store_true")
    commands.add_parser("certify", help="Write the complete active-field certification")
    commands.add_parser("validate-certification", help="Validate the current certification without writing")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    entries = load_entries()
    if args.command == "init":
        write_json(AUDIT_PATH, new_audit(entries))
        print(f"Created {AUDIT_PATH.name} for {len(entries)} entries.")
        return 0
    if args.command == "refresh-audit":
        if not AUDIT_PATH.exists():
            raise ValueError(f"{AUDIT_PATH.name} does not exist; run init first")
        write_json(AUDIT_PATH, refresh_audit_after_repairs(entries, load_json(AUDIT_PATH)))
        print(f"Refreshed {AUDIT_PATH.name} for the current word bank.")
        return 0
    if args.command == "validate-certification":
        if not CERTIFICATION_PATH.exists():
            raise ValueError(
                f"Missing word-bank giveaway certification: {CERTIFICATION_PATH.name}. "
                "Generation must remain blocked until a current certification is created."
            )
        errors = certification_errors(entries, load_json(CERTIFICATION_PATH))
        if errors:
            raise ValueError("\n".join(errors))
        print("Word-bank giveaway certification is valid.")
        return 0
    if args.command == "export-replacement-verification":
        package = load_json(args.package)
        batch = replacement_verification_batch(entries, package, args.limit)
        write_json(REPLACEMENT_BATCH_PATH, batch)
        print(f"Exported {len(batch['records'])} replacement Terra verification records to {REPLACEMENT_BATCH_PATH.name}.")
        return 0
    if args.command == "record-replacement-verification":
        package = load_json(args.package)
        batch = load_json(REPLACEMENT_BATCH_PATH)
        if batch.get("stage") != "replacement_verify":
            raise ValueError(f"Batch is for {batch.get('stage')}, not replacement_verify")
        changed = record_replacement_decisions(package, batch, load_json(args.decisions))
        write_json(args.package, package)
        print(f"Recorded {changed} blind Terra replacement decisions.")
        return 0
    if not AUDIT_PATH.exists():
        raise ValueError(f"{AUDIT_PATH.name} does not exist; run init first")
    audit = load_json(AUDIT_PATH)
    validate_audit(entries, audit)
    if args.command in {"export-primary", "export-verification"}:
        stage = "primary" if args.command == "export-primary" else "verify"
        batch = new_batch(audit, stage, args.limit)
        write_json(BATCH_PATH, batch)
        print(f"Exported {len(batch['records'])} {stage} Terra review records to {BATCH_PATH.name}.")
        return 0
    if args.command in {"record-primary", "record-verification"}:
        batch = load_json(BATCH_PATH)
        expected = "primary" if args.command == "record-primary" else "verify"
        if batch.get("stage") != expected:
            raise ValueError(f"Batch is for {batch.get('stage')}, not {expected}")
        changed = record_decisions(audit, batch, load_json(args.decisions))
        write_json(AUDIT_PATH, audit)
        print(f"Recorded {changed} Terra {expected} decisions.")
        return 0
    if args.command == "summary":
        print(json.dumps(summary(audit), indent=2, sort_keys=True))
        return 0
    if args.command == "build-repairs":
        package = build_repair_package(audit)
        write_json(REPAIRS_PATH, package)
        print(f"Wrote {len(package['repairs'])} pending repair proposals to {REPAIRS_PATH.name}.")
        return 0
    if args.command == "export-repair-authoring":
        package = load_json(args.package)
        if package.get("bankSha256") != bank_sha256():
            raise ValueError("repair package is stale")
        batch = authoring_batch(package, args.limit)
        write_json(args.output, batch)
        print(f"Exported {len(batch['records'])} current Terra authoring records to {args.output.name}.")
        return 0
    if args.command == "import-proposals":
        package = load_json(args.package)
        payload = load_json(args.proposals)
        proposals = payload.get("proposals") if isinstance(payload, dict) else payload
        if not isinstance(proposals, list):
            raise ValueError("proposal file must be a JSON array or contain a proposals array")
        changed = import_proposals(entries, package, proposals, skip_unmatched=args.skip_unmatched)
        write_json(args.package, package)
        print(f"Imported {changed} Terra replacement proposals.")
        return 0
    if args.command == "approve-verified-repairs":
        if not args.all_verified:
            raise ValueError("approve-verified-repairs requires --all-verified")
        package = load_json(args.package)
        changed = approve_verified_repairs(package)
        write_json(args.package, package)
        print(f"Marked {changed} blind-verified repairs approved; word_bank.json is unchanged.")
        return 0
    if args.command == "report-repairs":
        args.output.write_text(repair_report(load_json(args.package)))
        print(f"Wrote {args.output.name}.")
        return 0
    if args.command == "report-proposals":
        payload = load_json(args.proposals)
        proposals = payload.get("proposals") if isinstance(payload, dict) else payload
        if not isinstance(proposals, list):
            raise ValueError("proposal file must be a JSON array or contain a proposals array")
        args.output.write_text(proposal_report(load_json(args.batch), proposals))
        print(f"Wrote {args.output.name}.")
        return 0
    if args.command == "normalize-proposals":
        payload = load_json(args.proposals)
        proposals = payload.get("proposals") if isinstance(payload, dict) else payload
        overrides = load_json(args.overrides)
        if not isinstance(proposals, list) or not isinstance(overrides, dict) or not all(
            isinstance(key, str) and isinstance(value, str) for key, value in overrides.items()
        ):
            raise ValueError("proposals must be an array and overrides must be a string map")
        write_json(args.output, normalize_proposals(load_json(args.batch), proposals, overrides))
        print(f"Wrote {args.output.name}.")
        return 0
    if args.command == "validate-repairs":
        errors = validate_repair_package(entries, load_json(args.package))
        if errors:
            raise ValueError("\n".join(errors))
        print("Approved repairs are valid; word_bank.json is unchanged.")
        return 0
    if args.command == "apply-repairs":
        if not args.yes:
            raise ValueError("apply-repairs requires --yes")
        package = load_json(args.package)
        errors = validate_repair_package(entries, package)
        if errors:
            raise ValueError("\n".join(errors))
        updated = apply_repairs(entries, package)
        BANK_PATH.write_text(json.dumps(updated, indent=4, ensure_ascii=False) + "\n")
        refreshed = refresh_audit_after_repairs(updated, audit)
        write_json(AUDIT_PATH, refreshed)
        write_json(REPAIRS_PATH, build_repair_package(refreshed))
        print("Applied approved giveaway repairs and refreshed the resumable audit. Certify after all findings are resolved.")
        return 0
    if args.command == "certify":
        write_json(CERTIFICATION_PATH, certify(entries, audit))
        print(f"Wrote {CERTIFICATION_PATH.name}.")
        return 0
    raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as error:
        print(f"ERROR: {error}")
        raise SystemExit(2)
