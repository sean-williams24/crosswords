#!/usr/bin/env python3
"""Review-first audit and replacement workflow for easy daily crossword clues.

The daily crossword uses ``text`` as its main clue and accepts answers whose
stored length is between three and eight characters. This tool classifies only
those fields, keeps the word bank immutable during review, and applies changes
only after every confirmed replacement has an approved proposal.

Usage:
    python3 Backend/audit_easy_daily_clues.py init
    python3 Backend/audit_easy_daily_clues.py export-classification-batch --limit 100
    python3 Backend/audit_easy_daily_clues.py record-classifications decisions.json
    python3 Backend/audit_easy_daily_clues.py triage-local
    python3 Backend/audit_easy_daily_clues.py export-proposal-batch --limit 20
    python3 Backend/audit_easy_daily_clues.py record-proposals proposals.json
    python3 Backend/audit_easy_daily_clues.py set-status --status accepted 115 128
    python3 Backend/audit_easy_daily_clues.py rebase-removed-entry --old-bank old.json --removed-index 5136
    python3 Backend/audit_easy_daily_clues.py validate
    python3 Backend/audit_easy_daily_clues.py apply
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from answer_leakage import clue_ideas_may_be_redundant, normalize_clue_idea
from fix_duplicate_clues import (
    DISCOURAGED_QUALIFIER_RE,
    field_values,
    is_antonym_only_clue,
    replacement_issue,
)
from inflection_safety import scan_clue


BACKEND_DIR = Path(__file__).resolve().parent
BANK_PATH = BACKEND_DIR / "word_bank.json"
AUDIT_PATH = BACKEND_DIR / "easy_daily_clue_audit.json"
PROPOSALS_PATH = BACKEND_DIR / "easy_daily_clue_replacements.json"
SCHEMA_VERSION = 1
MIN_DAILY_LENGTH = 3
MAX_DAILY_LENGTH = 8
VALID_DECISIONS = {"keep", "replace", "borderline"}
VALID_PROPOSAL_STATUSES = {"pending", "accepted", "rejected"}

SPECIALIST_CLUE_RE = re.compile(
    r"\b(?:unit|chemical|musical|legal|naval|military|medical|greek|roman|"
    r"language|currency|species|genus|abbreviat|abbr|myth|biblical|bible|"
    r"geometry|mathemat|comput|software|electrical|scientific|physics|anatomy|"
    r"philosoph|literary|poetry|religious|historical|surname|given name|capital of)\b",
    re.IGNORECASE,
)
GENERIC_DEFINITION_RE = re.compile(
    r"^(?:a |an |the )?(?:where|person|one|someone|something|part|color|colour|"
    r"room|place|tool|device|food|drink|large|small|young|male|female|not|very|"
    r"having|to)\b|\b(?:used for|you might|who |that |of the)\b",
    re.IGNORECASE,
)
LOCAL_KEEP_THRESHOLD = 0.70
LOCAL_REPLACE_THRESHOLD = 0.80


# The complete 150-entry calibration reviewed in chat. Every omitted item was
# explicitly treated as a replacement; CONFIRMED_KEEP_WORDS contains the 31
# exceptions the user approved unchanged.
REVIEWED_WORDS = """
BLUE BONE BRANCH BRUSH BUTTERFLY CAMERA CITY CLAW CORNER DWARF ELBOW ELEPHANT
EXIT FLOWER FOREST GRAPE GRAVEL GRAY HAMMER HILL HOME HORSE IGUANA ISLE KITCHEN
LAKE LARGE LEAF MOOSE MOUSE MUSEUM OLIVE PIXEL POCKET PRISON PURSE RAINBOW RAVEN
RIVER SANDWICH SHARK STADIUM STAMP STREAM TEACHER THIEF BED BIG EAT RED
AIRY ARID AWAY AXED BASH BENT BOAR BONK BUCK BULL CALF CHOW CHUG DINE DOZE DRAG
DUNG FLAP FLEA FOAL ABASE ABATE ABODE ACTOR ADMIT ADOPT ADORE ADORN AGREE ALLOW
AMAZE AMBLE AMEND AMUSE ANNOY APPLE ARISE ASIDE ASKEW AWAKE AWFUL BAKER BATHE
BEGIN BEIGE BERRY BIRTH BISON BLUES BLUFF BOTCH BOWEL BRAKE BREAK BROKE BROOK
BROOM BROWN BUDDY BUDGE BULLY BUNCH BUNNY BURST BUYER DANE HERD IRIS LIAR ROAD
SALT SEAT SEND SHUT TALL THIN TOAD TOOL TRIO UNDO FRET GNAT HERB HOOF INCH KIDS
KILO MAIL MALL MINT MOLE NEWT NOPE OBOE ORCA PESO PILL PINT POND PURR
""".split()

CONFIRMED_KEEP_WORDS = set("""
CITY PIXEL BUCK BULL CHOW CHUG ABASE ABATE ADMIT ADORN AGREE ARISE ASKEW BISON
BLUES BROOK BUDGE BURST IRIS TOAD FRET GNAT HOOF INCH BLUFF BOTCH BOWEL MINT
NEWT OBOE ORCA
""".split())


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_json(path: Path) -> Any:
    with path.open() as handle:
        return json.load(handle)


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def write_word_bank(path: Path, entries: list[dict[str, Any]]) -> None:
    """Preserve the established four-space formatting of word_bank.json."""
    path.write_text(json.dumps(entries, indent=4, ensure_ascii=False) + "\n")


def load_entries(path: Path) -> list[dict[str, Any]]:
    value = load_json(path)
    if not isinstance(value, list):
        raise ValueError(f"Expected a top-level JSON array in {path}")
    return value


def bank_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit_sha256(report: dict[str, Any]) -> str:
    return hashlib.sha256(
        json.dumps(report, sort_keys=True, ensure_ascii=False).encode()
    ).hexdigest()


def is_daily_eligible(entry: dict[str, Any]) -> bool:
    word = entry.get("word")
    text = entry.get("text")
    return (
        isinstance(word, str)
        and MIN_DAILY_LENGTH <= len(word) <= MAX_DAILY_LENGTH
        and isinstance(text, str)
        and bool(text.strip())
    )


def eligible_records(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {"index": index, "word": entry["word"], "currentText": entry["text"]}
        for index, entry in enumerate(entries)
        if is_daily_eligible(entry)
    ]


def build_calibration(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_word: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for index, entry in enumerate(entries):
        word = str(entry.get("word", "")).upper()
        by_word.setdefault(word, []).append((index, entry))

    calibration: list[dict[str, Any]] = []
    for reviewed_word in REVIEWED_WORDS:
        matches = by_word.get(reviewed_word, [])
        if len(matches) != 1:
            raise ValueError(
                f"Calibration word {reviewed_word} must match exactly one bank entry; found {len(matches)}"
            )
        index, entry = matches[0]
        calibration.append({
            "index": index,
            "word": entry["word"],
            "currentText": entry["text"],
            "decision": "keep" if reviewed_word in CONFIRMED_KEEP_WORDS else "replace",
            "reason": "User-reviewed calibration decision",
            "source": "calibration",
            "inDailyScope": is_daily_eligible(entry),
        })

    if len(calibration) != 150:
        raise ValueError(f"Expected 150 calibration entries, found {len(calibration)}")
    keep_count = sum(item["decision"] == "keep" for item in calibration)
    if keep_count != 31:
        raise ValueError(f"Expected 31 calibration keeps, found {keep_count}")
    return calibration


def validate_classification_response(
    batch: list[dict[str, Any]],
    response: Any,
) -> list[dict[str, Any]]:
    if not isinstance(response, dict) or not isinstance(response.get("classifications"), list):
        raise ValueError("Expected an object containing a classifications array")
    expected = {item["index"]: item for item in batch}
    seen: set[int] = set()
    validated: list[dict[str, Any]] = []
    for item in response["classifications"]:
        if not isinstance(item, dict):
            raise ValueError("Every classification must be an object")
        index = item.get("index")
        if not isinstance(index, int) or index not in expected:
            raise ValueError(f"Unexpected classification index: {index}")
        if index in seen:
            raise ValueError(f"Duplicate classification index: {index}")
        seen.add(index)
        source = expected[index]
        if item.get("word") != source["word"] or item.get("currentText") != source["currentText"]:
            raise ValueError(f"Classification precondition mismatch at index {index}")
        decision = item.get("decision")
        reason = item.get("reason")
        if decision not in VALID_DECISIONS:
            raise ValueError(f"Invalid decision at index {index}: {decision}")
        if not isinstance(reason, str) or not reason.strip():
            raise ValueError(f"Missing classification reason at index {index}")
        validated.append({
            "index": index,
            "word": source["word"],
            "currentText": source["currentText"],
            "decision": decision,
            "reason": reason.strip(),
        })
    missing = set(expected) - seen
    if missing:
        raise ValueError(f"Missing classification indexes: {sorted(missing)[:10]}")
    return sorted(validated, key=lambda item: item["index"])


def new_audit_report(entries: list[dict[str, Any]], bank_path: Path) -> dict[str, Any]:
    calibration = build_calibration(entries)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": utc_now(),
        "updatedAt": utc_now(),
        "sourceBank": str(bank_path),
        "bankSha256": bank_sha256(bank_path),
        "eligibleEntryCount": len(eligible_records(entries)),
        "calibrationEntryCount": len(calibration),
        "calibrationKeepCount": 31,
        "calibrationReplaceCount": 119,
        "inScopeCalibrationEntryCount": sum(item["inDailyScope"] for item in calibration),
        "outOfScopeCalibrationEntryCount": sum(not item["inDailyScope"] for item in calibration),
        "reviewMethod": "Codex chat classification calibrated by 150 user-reviewed examples",
        "policy": "Approachable but not immediate; borderline entries require a second independent pass",
        "classifications": calibration,
    }


def validate_bank_preconditions(
    entries: list[dict[str, Any]],
    report: dict[str, Any],
    bank_path: Path,
) -> None:
    if report.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError("Unsupported report schema")
    actual_hash = bank_sha256(bank_path)
    if report.get("bankSha256") != actual_hash:
        raise ValueError(f"Stale report: expected bank hash {report.get('bankSha256')}, found {actual_hash}")
    for item in report.get("classifications", []):
        index = item.get("index")
        if not isinstance(index, int) or not 0 <= index < len(entries):
            raise ValueError(f"Classification index out of range: {index}")
        entry = entries[index]
        if entry.get("word") != item.get("word") or entry.get("text") != item.get("currentText"):
            raise ValueError(f"Stale classification precondition at index {index}")


def pending_first_pass(entries: list[dict[str, Any]], report: dict[str, Any]) -> list[dict[str, Any]]:
    completed = {item["index"] for item in report.get("classifications", [])}
    return [item for item in eligible_records(entries) if item["index"] not in completed]


def pending_second_pass(report: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {"index": item["index"], "word": item["word"], "currentText": item["currentText"]}
        for item in report.get("classifications", [])
        if item.get("source") == "firstPass"
        and item.get("decision") == "borderline"
        and "secondPassDecision" not in item
    ]


def merge_first_pass(report: dict[str, Any], results: list[dict[str, Any]]) -> None:
    for result in results:
        report["classifications"].append({**result, "source": "firstPass"})
    report["classifications"].sort(key=lambda item: item["index"])
    report["updatedAt"] = utc_now()


def merge_second_pass(report: dict[str, Any], results: list[dict[str, Any]]) -> None:
    by_index = {item["index"]: item for item in report["classifications"]}
    for result in results:
        item = by_index[result["index"]]
        item["firstPassDecision"] = item["decision"]
        item["firstPassReason"] = item["reason"]
        item["secondPassDecision"] = result["decision"]
        item["secondPassReason"] = result["reason"]
        item["decision"] = result["decision"]
        item["reason"] = result["reason"]
        item["source"] = "secondPass"
    report["updatedAt"] = utc_now()


def update_audit_summary(report: dict[str, Any]) -> None:
    classifications = report.get("classifications", [])
    report["classifiedEntryCount"] = len(classifications)
    in_scope = [item for item in classifications if item.get("inDailyScope", True)]
    report["classifiedEligibleEntryCount"] = len(in_scope)
    report["summary"] = {
        decision: sum(item.get("decision") == decision for item in in_scope)
        for decision in ("keep", "replace", "borderline")
    }


def classification_batch(
    entries: list[dict[str, Any]],
    report: dict[str, Any],
    *,
    second_pass: bool,
    limit: int,
) -> list[dict[str, Any]]:
    pending = pending_second_pass(report) if second_pass else pending_first_pass(entries, report)
    return pending[:limit]


def record_classifications(
    entries: list[dict[str, Any]],
    report: dict[str, Any],
    response: Any,
    *,
    second_pass: bool,
) -> int:
    pending = pending_second_pass(report) if second_pass else pending_first_pass(entries, report)
    pending_by_index = {item["index"]: item for item in pending}
    raw_items = response.get("classifications") if isinstance(response, dict) else None
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError("Classification import must contain a non-empty classifications array")
    indexes = [item.get("index") for item in raw_items if isinstance(item, dict)]
    unexpected = {index for index in indexes if index not in pending_by_index}
    if unexpected:
        raise ValueError(f"Classification indexes are not pending: {sorted(unexpected)[:10]}")
    batch = [pending_by_index[index] for index in indexes]
    enriched_items: list[dict[str, Any]] = []
    for raw in raw_items:
        source = pending_by_index[raw["index"]]
        decision = raw.get("decision")
        default_reason = {
            "keep": "Independent semantic review: clue retains a fair retrieval step",
            "replace": "Independent semantic review: direct clue is too immediate",
            "borderline": "Independent semantic review remains uncertain",
        }.get(decision, "Independent semantic review decision")
        enriched_items.append({
            **raw,
            "word": raw.get("word", source["word"]),
            "currentText": raw.get("currentText", source["currentText"]),
            "reason": raw.get("reason", default_reason),
        })
    results = validate_classification_response(batch, {"classifications": enriched_items})
    if second_pass:
        merge_second_pass(report, results)
    else:
        merge_first_pass(report, results)
    update_audit_summary(report)
    return len(results)


def local_difficulty_score(record: dict[str, Any], *, zipf: float | None = None) -> float:
    """Estimate immediacy using local, explainable features calibrated in chat.

    A higher score means the clue is more likely to reveal a familiar answer
    immediately. The intentionally narrow gap between thresholds is exported as
    borderline for an independent semantic pass instead of being auto-decided.
    """
    if zipf is None:
        try:
            from wordfreq import zipf_frequency
        except ImportError as error:
            raise SystemExit(
                "Install local dependencies with Backend/.venv/bin/pip install -r Backend/requirements.txt"
            ) from error
        zipf = zipf_frequency(str(record["word"]).lower(), "en")

    word = str(record["word"])
    text = str(record["currentText"])
    clue_word_count = len(re.findall(r"[A-Za-z0-9']+", text))
    score = 1.4 * (zipf - 3.5)
    score += 0.8 if clue_word_count <= 3 else 0.4 if clue_word_count <= 5 else 0.0
    score += 0.6 if GENERIC_DEFINITION_RE.search(text) else 0.0
    score += 0.8 if "___" in text else 0.0
    score -= 0.9 if re.search(r"\bor\b", text, re.IGNORECASE) else 0.0
    score -= 0.9 if SPECIALIST_CLUE_RE.search(text) else 0.0
    score += 0.2 if len(word) <= 4 else -0.2 if len(word) >= 7 else 0.0
    return score


def local_first_pass_response(
    entries: list[dict[str, Any]],
    report: dict[str, Any],
) -> dict[str, list[dict[str, Any]]]:
    classifications: list[dict[str, Any]] = []
    for item in pending_first_pass(entries, report):
        score = local_difficulty_score(item)
        if score >= LOCAL_REPLACE_THRESHOLD:
            decision = "replace"
            reason = "Common answer and direct definition make retrieval too immediate"
        elif score <= LOCAL_KEEP_THRESHOLD:
            decision = "keep"
            reason = "Specific or less familiar term retains a retrieval step"
        else:
            decision = "borderline"
            reason = "Local calibrated signals are too close for an automatic decision"
        classifications.append({**item, "decision": decision, "reason": reason})
    return {"classifications": classifications}


def active_comparison_values(entry: dict[str, Any]) -> Iterable[tuple[str, str]]:
    return ((field, value) for field, value in field_values(entry) if field != "text")


def validate_proposed_text(entry: dict[str, Any], candidate: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(candidate, str) or not candidate.strip():
        return ["replacement text is empty"]
    candidate = re.sub(r"\s+", " ", candidate).strip().rstrip(".")
    word = str(entry.get("word", ""))
    if len(candidate.split()) > 12:
        errors.append("replacement exceeds 12 words")
    if normalize_clue_idea(candidate) == normalize_clue_idea(str(entry.get("text", ""))):
        errors.append("replacement repeats the current text clue")
    issue = replacement_issue(word, candidate)
    if issue:
        errors.append(f"answer leakage: {','.join(issue.get('reasons', ['UNKNOWN']))}")
    if DISCOURAGED_QUALIFIER_RE.search(candidate):
        errors.append("replacement uses a discouraged qualifier")
    if is_antonym_only_clue(candidate):
        errors.append("replacement is antonym-only")
    for field, value in active_comparison_values(entry):
        if clue_ideas_may_be_redundant(candidate, value):
            errors.append(f"replacement repeats the idea in {field}")
    for issue in scan_clue(word, candidate):
        errors.append(f"inflection mismatch: {issue.reason}")
    return errors


def validate_proposal_response(
    entries: list[dict[str, Any]],
    batch: list[dict[str, Any]],
    response: Any,
) -> list[dict[str, Any]]:
    if not isinstance(response, dict) or not isinstance(response.get("replacements"), list):
        raise ValueError("Expected an object containing a replacements array")
    expected = {item["index"]: item for item in batch}
    seen: set[int] = set()
    validated: list[dict[str, Any]] = []
    for item in response["replacements"]:
        if not isinstance(item, dict):
            raise ValueError("Every replacement must be an object")
        index = item.get("index")
        if not isinstance(index, int) or index not in expected:
            raise ValueError(f"Unexpected replacement index: {index}")
        if index in seen:
            raise ValueError(f"Duplicate replacement index: {index}")
        seen.add(index)
        source = expected[index]
        if item.get("word") != source["word"] or item.get("currentText") != source["currentText"]:
            raise ValueError(f"Replacement precondition mismatch at index {index}")
        proposed = item.get("proposedText")
        errors = validate_proposed_text(entries[index], proposed)
        if errors:
            raise ValueError(f"Invalid replacement for {source['word']}: {errors}")
        validated.append({
            "index": index,
            "word": source["word"],
            "currentText": source["currentText"],
            "proposedText": re.sub(r"\s+", " ", proposed).strip().rstrip("."),
        })
    missing = set(expected) - seen
    if missing:
        raise ValueError(f"Missing replacement indexes: {sorted(missing)[:10]}")
    return sorted(validated, key=lambda item: item["index"])


def validate_audit_report(entries: list[dict[str, Any]], report: dict[str, Any], bank_path: Path) -> None:
    validate_bank_preconditions(entries, report, bank_path)
    eligible = eligible_records(entries)
    classifications = report.get("classifications")
    if not isinstance(classifications, list):
        raise ValueError("Audit report is missing classifications")
    by_index: dict[int, dict[str, Any]] = {}
    in_scope_indexes: set[int] = set()
    for item in classifications:
        index = item["index"]
        if index in by_index:
            raise ValueError(f"Duplicate classification index: {index}")
        if item.get("decision") not in VALID_DECISIONS:
            raise ValueError(f"Invalid audit decision at index {index}")
        by_index[index] = item
        if item.get("inDailyScope", True):
            in_scope_indexes.add(index)
        elif item.get("source") != "calibration":
            raise ValueError(f"Only calibration entries may be retained outside daily scope: {index}")
    eligible_indexes = {item["index"] for item in eligible}
    missing = eligible_indexes - in_scope_indexes
    extra = in_scope_indexes - eligible_indexes
    if missing or extra:
        raise ValueError(f"Audit coverage mismatch: {len(missing)} missing, {len(extra)} extra")
    pending_second = pending_second_pass(report)
    if pending_second:
        raise ValueError(f"Audit has {len(pending_second)} borderline entries awaiting a second pass")


def new_proposal_report(audit: dict[str, Any], bank_path: Path) -> dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": utc_now(),
        "updatedAt": utc_now(),
        "sourceBank": str(bank_path),
        "bankSha256": audit["bankSha256"],
        "auditSha256": audit_sha256(audit),
        "generationMethod": "Codex chat-authored clues with deterministic local validation",
        "instructions": "Set each proposal status to accepted or rejected after review; word_bank.json remains unchanged until apply.",
        "proposals": [],
    }


def proposal_targets(
    audit: dict[str, Any],
    proposal_report: dict[str, Any],
    *,
    limit: int | None,
    regenerate_rejected: bool,
) -> list[dict[str, Any]]:
    existing = {item["index"]: item for item in proposal_report.get("proposals", [])}
    targets: list[dict[str, Any]] = []
    for item in audit["classifications"]:
        if item["decision"] != "replace" or not item.get("inDailyScope", True):
            continue
        current = existing.get(item["index"])
        if current is None or (regenerate_rejected and current.get("status") == "rejected"):
            targets.append({
                "index": item["index"],
                "word": item["word"],
                "currentText": item["currentText"],
            })
    targets.sort(key=lambda item: item["index"])
    return targets[:limit] if limit is not None else targets


def proposal_batch(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    proposal_report: dict[str, Any],
    *,
    limit: int,
    regenerate_rejected: bool,
) -> list[dict[str, Any]]:
    targets = proposal_targets(
        audit,
        proposal_report,
        limit=limit,
        regenerate_rejected=regenerate_rejected,
    )
    result: list[dict[str, Any]] = []
    for item in targets:
        entry = entries[item["index"]]
        result.append({
            **item,
            "hardText": entry.get("hard_text") or entry.get("hardText"),
            "clues": entry.get("clues") or [],
        })
    return result


def merge_proposals(report: dict[str, Any], generated: list[dict[str, Any]]) -> None:
    by_index = {item["index"]: item for item in report["proposals"]}
    for result in generated:
        current = by_index.get(result["index"])
        if current is None:
            result["status"] = "pending"
            result["history"] = []
            report["proposals"].append(result)
            continue
        if current.get("status") != "rejected":
            raise ValueError(f"Refusing to overwrite non-rejected proposal at index {result['index']}")
        current.setdefault("history", []).append({
            "proposedText": current["proposedText"],
            "status": current["status"],
            "replacedAt": utc_now(),
        })
        current["proposedText"] = result["proposedText"]
        current["status"] = "pending"
    report["proposals"].sort(key=lambda item: item["index"])
    report["updatedAt"] = utc_now()


def record_proposals(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    report: dict[str, Any],
    response: Any,
) -> int:
    raw_items = response.get("replacements") if isinstance(response, dict) else None
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError("Proposal import must contain a non-empty replacements array")
    classifications = {item["index"]: item for item in audit["classifications"]}
    existing = {item["index"]: item for item in report["proposals"]}
    batch: list[dict[str, Any]] = []
    enriched_items: list[dict[str, Any]] = []
    for raw in raw_items:
        if not isinstance(raw, dict) or not isinstance(raw.get("index"), int):
            raise ValueError("Every imported proposal must have an integer index")
        index = raw["index"]
        classified = classifications.get(index)
        if (
            not classified
            or classified.get("decision") != "replace"
            or not classified.get("inDailyScope", True)
        ):
            raise ValueError(f"Proposal is not a confirmed replacement: {index}")
        current = existing.get(index)
        if current is not None and current.get("status") != "rejected":
            raise ValueError(f"Proposal index is not pending generation: {index}")
        batch.append({
            "index": index,
            "word": classified["word"],
            "currentText": classified["currentText"],
        })
        enriched_items.append({
            **raw,
            "word": raw.get("word", classified["word"]),
            "currentText": raw.get("currentText", classified["currentText"]),
        })
    generated = validate_proposal_response(
        entries, batch, {"replacements": enriched_items}
    )
    merge_proposals(report, generated)
    return len(generated)


def validate_proposal_report(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    report: dict[str, Any],
    bank_path: Path,
    *,
    require_complete: bool,
) -> None:
    validate_audit_report(entries, audit, bank_path)
    if report.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError("Unsupported proposal report schema")
    if report.get("bankSha256") != audit.get("bankSha256"):
        raise ValueError("Proposal report was built from a different word bank")
    if report.get("auditSha256") != audit_sha256(audit):
        raise ValueError("Proposal report was built from a different audit")
    replacement_indexes = {
        item["index"]
        for item in audit["classifications"]
        if item["decision"] == "replace" and item.get("inDailyScope", True)
    }
    seen: set[int] = set()
    accepted: set[int] = set()
    for proposal in report.get("proposals", []):
        index = proposal.get("index")
        if not isinstance(index, int) or index not in replacement_indexes:
            raise ValueError(f"Proposal is not a confirmed replacement: {index}")
        if index in seen:
            raise ValueError(f"Duplicate proposal index: {index}")
        seen.add(index)
        entry = entries[index]
        if entry.get("word") != proposal.get("word") or entry.get("text") != proposal.get("currentText"):
            raise ValueError(f"Stale proposal precondition at index {index}")
        if proposal.get("status") not in VALID_PROPOSAL_STATUSES:
            raise ValueError(f"Invalid proposal status at index {index}")
        errors = validate_proposed_text(entry, proposal.get("proposedText"))
        if errors:
            raise ValueError(f"Invalid proposal at index {index}: {errors}")
        if proposal["status"] == "accepted":
            accepted.add(index)
    if require_complete and accepted != replacement_indexes:
        missing = replacement_indexes - accepted
        raise ValueError(
            f"Apply requires one accepted proposal for every replacement; {len(missing)} remain unapproved"
        )


def apply_approved(
    entries: list[dict[str, Any]],
    audit: dict[str, Any],
    proposal_report: dict[str, Any],
    bank_path: Path,
) -> list[dict[str, Any]]:
    validate_proposal_report(entries, audit, proposal_report, bank_path, require_complete=True)
    updated = deepcopy(entries)
    for proposal in proposal_report["proposals"]:
        if proposal["status"] == "accepted":
            updated[proposal["index"]]["text"] = proposal["proposedText"]
    return updated


def keep_original_clues(
    audit: dict[str, Any],
    proposal_report: dict[str, Any],
    indexes: set[int],
) -> None:
    classifications = {item["index"]: item for item in audit["classifications"]}
    unknown = indexes - set(classifications)
    if unknown:
        raise ValueError(f"Classification indexes not found: {sorted(unknown)}")

    withdrawn = proposal_report.setdefault("withdrawnProposals", [])
    retained_proposals: list[dict[str, Any]] = []
    for proposal in proposal_report.get("proposals", []):
        if proposal["index"] not in indexes:
            retained_proposals.append(proposal)
            continue
        withdrawn.append({
            **proposal,
            "withdrawnAt": utc_now(),
            "withdrawalReason": "User confirmed the original text clue should remain",
        })
    proposal_report["proposals"] = retained_proposals

    for index in indexes:
        item = classifications[index]
        item.setdefault("reviewHistory", []).append({
            "decision": item["decision"],
            "reason": item["reason"],
            "source": item.get("source"),
            "changedAt": utc_now(),
        })
        item["decision"] = "keep"
        item["reason"] = "User confirmed the original text clue is acceptable"
        item["source"] = "userOverride"

    audit["updatedAt"] = utc_now()
    update_audit_summary(audit)
    proposal_report["auditSha256"] = audit_sha256(audit)
    proposal_report["updatedAt"] = utc_now()


def rebase_after_removed_entry(
    old_entries: list[dict[str, Any]],
    new_entries: list[dict[str, Any]],
    audit: dict[str, Any],
    proposal_report: dict[str, Any],
    old_bank_path: Path,
    new_bank_path: Path,
    removed_index: int,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Rebase reports only when the bank changed by one exact entry deletion."""
    validate_audit_report(old_entries, audit, old_bank_path)
    validate_proposal_report(
        old_entries,
        audit,
        proposal_report,
        old_bank_path,
        require_complete=False,
    )
    if not 0 <= removed_index < len(old_entries):
        raise ValueError(f"Removed index out of range: {removed_index}")
    if len(new_entries) != len(old_entries) - 1:
        raise ValueError("Rebase requires the new bank to contain exactly one fewer entry")
    if old_entries[:removed_index] != new_entries[:removed_index]:
        raise ValueError("New bank differs before the claimed removed index")
    if old_entries[removed_index + 1:] != new_entries[removed_index:]:
        raise ValueError("New bank contains changes beyond the claimed entry deletion")

    rebased_audit = deepcopy(audit)
    rebased_proposals = deepcopy(proposal_report)
    removed_classifications = [
        item for item in rebased_audit["classifications"]
        if item["index"] == removed_index
    ]
    if len(removed_classifications) > 1:
        raise ValueError("Audit contains duplicate classifications at the removed index")
    for collection_name in ("proposals", "withdrawnProposals"):
        if any(
            item["index"] == removed_index
            for item in rebased_proposals.get(collection_name, [])
        ):
            raise ValueError(
                f"Cannot remove an entry referenced by {collection_name}"
            )

    rebased_audit["classifications"] = [
        item for item in rebased_audit["classifications"]
        if item["index"] != removed_index
    ]
    for item in rebased_audit["classifications"]:
        if item["index"] > removed_index:
            item["index"] -= 1
    for collection_name in ("proposals", "withdrawnProposals"):
        for item in rebased_proposals.get(collection_name, []):
            if item["index"] > removed_index:
                item["index"] -= 1

    new_hash = bank_sha256(new_bank_path)
    rebased_audit["sourceBank"] = str(new_bank_path)
    rebased_audit["bankSha256"] = new_hash
    rebased_audit["eligibleEntryCount"] = len(eligible_records(new_entries))
    rebased_audit["updatedAt"] = utc_now()
    update_audit_summary(rebased_audit)

    rebased_proposals["sourceBank"] = str(new_bank_path)
    rebased_proposals["bankSha256"] = new_hash
    rebased_proposals["auditSha256"] = audit_sha256(rebased_audit)
    rebased_proposals["updatedAt"] = utc_now()

    validate_audit_report(new_entries, rebased_audit, new_bank_path)
    validate_proposal_report(
        new_entries,
        rebased_audit,
        rebased_proposals,
        new_bank_path,
        require_complete=False,
    )
    return rebased_audit, rebased_proposals


def parse_indexes(values: list[str]) -> list[int]:
    try:
        return [int(value) for value in values]
    except ValueError as error:
        raise argparse.ArgumentTypeError("Indexes must be integers") from error


def emit_json(value: Any, output: Path | None) -> None:
    if output is None:
        print(json.dumps(value, indent=2, ensure_ascii=False))
    else:
        write_json(output, value)
        print(f"Batch written to {output}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit and replace overly easy daily text clues")
    parser.add_argument("--bank", type=Path, default=BANK_PATH)
    parser.add_argument("--audit", type=Path, default=AUDIT_PATH)
    parser.add_argument("--proposals", type=Path, default=PROPOSALS_PATH)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("init")

    export_classification_parser = subparsers.add_parser("export-classification-batch")
    export_classification_parser.add_argument("--limit", type=int, default=100)
    export_classification_parser.add_argument("--second-pass", action="store_true")
    export_classification_parser.add_argument("--output", type=Path)

    record_classification_parser = subparsers.add_parser("record-classifications")
    record_classification_parser.add_argument("input", type=Path)
    record_classification_parser.add_argument("--second-pass", action="store_true")

    subparsers.add_parser("triage-local")

    export_proposal_parser = subparsers.add_parser("export-proposal-batch")
    export_proposal_parser.add_argument("--limit", type=int, default=20)
    export_proposal_parser.add_argument("--regenerate-rejected", action="store_true")
    export_proposal_parser.add_argument("--output", type=Path)

    record_proposal_parser = subparsers.add_parser("record-proposals")
    record_proposal_parser.add_argument("input", type=Path)

    status_parser = subparsers.add_parser("set-status")
    status_parser.add_argument("--status", choices=sorted(VALID_PROPOSAL_STATUSES), required=True)
    status_parser.add_argument("indexes", nargs="+")

    keep_parser = subparsers.add_parser("keep-original")
    keep_parser.add_argument("indexes", nargs="+")

    rebase_parser = subparsers.add_parser("rebase-removed-entry")
    rebase_parser.add_argument("--old-bank", type=Path, required=True)
    rebase_parser.add_argument("--removed-index", type=int, required=True)

    subparsers.add_parser("validate")
    subparsers.add_parser("apply")
    args = parser.parse_args()

    entries = load_entries(args.bank)

    if args.command == "init":
        if args.audit.exists():
            raise SystemExit(f"Audit report already exists: {args.audit}")
        audit = new_audit_report(entries, args.bank)
        update_audit_summary(audit)
        write_json(args.audit, audit)
        print(f"Initialized chat audit with 150 calibration entries in {args.audit}")
        return

    if not args.audit.exists():
        raise SystemExit(f"Audit report does not exist: {args.audit}")
    audit = load_json(args.audit)

    if args.command == "rebase-removed-entry":
        if not args.proposals.exists():
            raise SystemExit(f"Proposal report does not exist: {args.proposals}")
        proposals = load_json(args.proposals)
        rebased_audit, rebased_proposals = rebase_after_removed_entry(
            load_entries(args.old_bank),
            entries,
            audit,
            proposals,
            args.old_bank,
            args.bank,
            args.removed_index,
        )
        write_json(args.audit, rebased_audit)
        write_json(args.proposals, rebased_proposals)
        print(
            f"Rebased reports after removing index {args.removed_index}; "
            f"{len(rebased_proposals['proposals'])} proposals preserved"
        )
        return

    validate_bank_preconditions(entries, audit, args.bank)

    if args.command == "export-classification-batch":
        if args.limit < 1:
            raise SystemExit("--limit must be positive")
        batch = classification_batch(
            entries, audit, second_pass=args.second_pass, limit=args.limit
        )
        emit_json({"classifications": batch}, args.output)
        return

    if args.command == "record-classifications":
        count = record_classifications(
            entries,
            audit,
            load_json(args.input),
            second_pass=args.second_pass,
        )
        write_json(args.audit, audit)
        print(f"Recorded {count} chat classifications in {args.audit}")
        return

    if args.command == "triage-local":
        response = local_first_pass_response(entries, audit)
        if not response["classifications"]:
            print("No first-pass classifications are pending.")
            return
        count = record_classifications(entries, audit, response, second_pass=False)
        audit["localTriage"] = {
            "method": "Chat-calibrated local scoring; no network or API calls",
            "keepThreshold": LOCAL_KEEP_THRESHOLD,
            "replaceThreshold": LOCAL_REPLACE_THRESHOLD,
            "recordedAt": utc_now(),
        }
        write_json(args.audit, audit)
        print(f"Recorded {count} local first-pass classifications in {args.audit}")
        return

    validate_audit_report(entries, audit, args.bank)

    if args.command in {"export-proposal-batch", "record-proposals"}:
        if args.proposals.exists():
            proposals = load_json(args.proposals)
            validate_proposal_report(entries, audit, proposals, args.bank, require_complete=False)
        else:
            proposals = new_proposal_report(audit, args.bank)

        if args.command == "export-proposal-batch":
            if args.limit < 1:
                raise SystemExit("--limit must be positive")
            batch = proposal_batch(
                entries,
                audit,
                proposals,
                limit=args.limit,
                regenerate_rejected=args.regenerate_rejected,
            )
            emit_json({"replacements": batch}, args.output)
            return

        count = record_proposals(entries, audit, proposals, load_json(args.input))
        write_json(args.proposals, proposals)
        print(f"Recorded {count} chat-authored proposals in {args.proposals}")
        return

    if args.command == "set-status":
        if not args.proposals.exists():
            raise SystemExit(f"Proposal report does not exist: {args.proposals}")
        proposals = load_json(args.proposals)
        validate_proposal_report(entries, audit, proposals, args.bank, require_complete=False)
        indexes = set(parse_indexes(args.indexes))
        found: set[int] = set()
        for proposal in proposals["proposals"]:
            if proposal["index"] in indexes:
                proposal["status"] = args.status
                found.add(proposal["index"])
        missing = indexes - found
        if missing:
            raise SystemExit(f"Proposal indexes not found: {sorted(missing)}")
        proposals["updatedAt"] = utc_now()
        write_json(args.proposals, proposals)
        print(f"Marked {len(found)} proposals as {args.status}")
        return

    if args.command == "keep-original":
        if not args.proposals.exists():
            raise SystemExit(f"Proposal report does not exist: {args.proposals}")
        proposals = load_json(args.proposals)
        validate_proposal_report(entries, audit, proposals, args.bank, require_complete=False)
        indexes = set(parse_indexes(args.indexes))
        keep_original_clues(audit, proposals, indexes)
        write_json(args.audit, audit)
        write_json(args.proposals, proposals)
        print(f"Kept {len(indexes)} original text clues and withdrew their proposals")
        return

    if not args.proposals.exists():
        raise SystemExit(f"Proposal report does not exist: {args.proposals}")
    proposals = load_json(args.proposals)

    if args.command == "validate":
        validate_proposal_report(entries, audit, proposals, args.bank, require_complete=False)
        counts = {
            status: sum(item["status"] == status for item in proposals["proposals"])
            for status in sorted(VALID_PROPOSAL_STATUSES)
        }
        print(f"Audit and proposal reports are valid: {counts}")
        return

    if args.command == "apply":
        updated = apply_approved(entries, audit, proposals, args.bank)
        write_word_bank(args.bank, updated)
        print(f"Applied {len(proposals['proposals'])} approved text replacements to {args.bank}")
        return

    raise SystemExit(f"Unknown command: {args.command}")


if __name__ == "__main__":
    main()
