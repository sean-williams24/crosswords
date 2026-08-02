#!/usr/bin/env python3
"""Generate review-only replacement clue packages for marked word-bank repairs."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from answer_leakage import leaks_answer, normalize_clue_idea


BACKEND_DIR = Path(__file__).resolve().parent
BANK_PATH = BACKEND_DIR / "word_bank.json"
REMOVALS_PATH = BACKEND_DIR / "word_bank_clue_alignment_removals.json"
PROPOSALS_PATH = BACKEND_DIR / "word_bank_clue_repair_proposals.json"
AUDIT_PATH = BACKEND_DIR / "word_bank_clue_repair_audit.json"
MODEL = "gpt-5.6-terra"
REQUIRED_FIELDS = ("text", "hint", "hard_text", "clues")

SYSTEM_PROMPT = """You are a meticulous crossword editor repairing a clue bank.
Write accurate, concise, general-audience clues for the exact answer given.
Never use the answer, an inflection of it, or a transparent substring of it in
a clue. Do not add answer-length enumeration. Preserve the answer's exact part
of speech and sense. Do not make factual claims unless they are correct.

For each answer, provide a direct text clue, a short hint, a slightly harder
clue, and three distinct crossword clues. Return JSON only."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_path(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> Any:
    with path.open() as handle:
        return json.load(handle)


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def current_fields(entry: dict[str, Any]) -> list[dict[str, str]]:
    fields: list[dict[str, str]] = []
    for name in ("text", "hint", "hard_text", "hardText"):
        value = entry.get(name)
        if isinstance(value, str) and value.strip():
            fields.append({"field": name, "current": value})
    for index, value in enumerate(entry.get("clues") or []):
        if isinstance(value, str) and value.strip():
            fields.append({"field": f"clues[{index}]", "current": value})
    return fields


def repair_targets(entries: list[dict[str, Any]], review: dict[str, Any]) -> list[dict[str, Any]]:
    by_word: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for index, entry in enumerate(entries):
        word = entry.get("word")
        if isinstance(word, str):
            by_word.setdefault(word, []).append((index, entry))

    targets = []
    for item in review.get("removals") or []:
        if item.get("status") != "repair":
            continue
        word = item.get("word")
        matches = by_word.get(word) if isinstance(word, str) else None
        if not matches or len(matches) != 1:
            raise ValueError(f"Repair word {word!r} is missing or ambiguous in word_bank.json")
        index, entry = matches[0]
        if item.get("fields") != current_fields(entry):
            raise ValueError(f"Repair word {word!r} has changed since review")
        targets.append({
            "index": index,
            "word": word,
            "current": {
                "text": entry.get("text", ""),
                "hint": entry.get("hint", ""),
                "hard_text": entry.get("hard_text", entry.get("hardText", "")),
                "clues": entry.get("clues") or [],
            },
        })
    if not targets:
        raise ValueError("No repair entries are marked in the review file")
    return targets


def repair_prompt(targets: list[dict[str, Any]]) -> str:
    payload = [{"word": target["word"], "current": target["current"]} for target in targets]
    return """Return exactly this JSON shape:
{"repairs":[{"word":"EXACTANSWER","text":"...","hint":"...","hard_text":"...","clues":["...","...","..."]}]}

Repair these entries. Existing clues are context only and may be inaccurate:
""" + json.dumps(payload, ensure_ascii=False)


def validate_repairs(targets: list[dict[str, Any]], response: dict[str, Any]) -> list[dict[str, Any]]:
    repairs = response.get("repairs") if isinstance(response, dict) else None
    if not isinstance(repairs, list):
        raise ValueError("Repair response must contain a repairs array")
    expected = {target["word"]: target for target in targets}
    validated: dict[str, dict[str, Any]] = {}
    for repair in repairs:
        if not isinstance(repair, dict):
            raise ValueError("Repair item must be an object")
        word = repair.get("word")
        if not isinstance(word, str) or word not in expected or word in validated:
            raise ValueError("Repair response has an unexpected or duplicate word")
        values: dict[str, Any] = {}
        for field in ("text", "hint", "hard_text"):
            value = repair.get(field)
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"{word} has an invalid {field} replacement")
            values[field] = value.strip()
        clues = repair.get("clues")
        if not isinstance(clues, list) or len(clues) != 3 or not all(isinstance(value, str) and value.strip() for value in clues):
            raise ValueError(f"{word} must have exactly three non-empty clues")
        values["clues"] = [value.strip() for value in clues]
        all_values = [values["text"], values["hint"], values["hard_text"], *values["clues"]]
        if any(leaks_answer(word, value) for value in all_values):
            raise ValueError(f"{word} replacement leaks the answer")
        normalized = [normalize_clue_idea(value) for value in all_values]
        if len(set(normalized)) != len(normalized):
            raise ValueError(f"{word} replacement repeats a clue idea")
        validated[word] = {
            "index": expected[word]["index"],
            "word": word,
            "current": expected[word]["current"],
            "proposed": values,
            "status": "pending_review",
        }
    if set(validated) != set(expected):
        raise ValueError("Repair response does not cover every requested word")
    return [validated[target["word"]] for target in targets]


def load_api_key() -> str:
    env_path = BACKEND_DIR / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            key, separator, value = line.strip().partition("=")
            if separator and key == "OPENAI_API_KEY" and value:
                os.environ.setdefault(key, value)
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY is required to generate repair proposals")
    return api_key


def call_model(targets: list[dict[str, Any]], api_key: str) -> list[dict[str, Any]]:
    from openai import OpenAI

    response = OpenAI(api_key=api_key, timeout=120, max_retries=2).responses.create(
        model=MODEL,
        reasoning={"effort": "medium"},
        input=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": repair_prompt(targets)},
        ],
        text={"format": {"type": "json_object"}, "verbosity": "low"},
        max_output_tokens=5000,
    )
    try:
        response_json = json.loads((response.output_text or "").strip())
    except json.JSONDecodeError as error:
        raise ValueError("Terra returned invalid repair JSON") from error
    return validate_repairs(targets, response_json)


def generate_repair_proposals(batch_size: int) -> dict[str, Any]:
    if batch_size <= 0:
        raise ValueError("batch-size must be positive")
    entries = load_json(BANK_PATH)
    review = load_json(REMOVALS_PATH)
    targets = repair_targets(entries, review)
    bank_hash = sha256_path(BANK_PATH)
    review_hash = sha256_path(REMOVALS_PATH)
    existing: dict[str, dict[str, Any]] = {}
    if PROPOSALS_PATH.exists():
        proposal = load_json(PROPOSALS_PATH)
        if proposal.get("bankSha256") == bank_hash and proposal.get("reviewSha256") == review_hash:
            existing = {item["word"]: item for item in proposal.get("repairs") or [] if isinstance(item, dict) and isinstance(item.get("word"), str)}
    api_key = load_api_key()
    for start in range(0, len(targets), batch_size):
        batch = [target for target in targets[start:start + batch_size] if target["word"] not in existing]
        if not batch:
            continue
        for repair in call_model(batch, api_key):
            existing[repair["word"]] = repair
        proposal = {
            "schemaVersion": 1,
            "generatedAt": utc_now(),
            "bankSha256": bank_hash,
            "reviewSha256": review_hash,
            "model": MODEL,
            "repairs": [existing[target["word"]] for target in targets if target["word"] in existing],
        }
        write_json(PROPOSALS_PATH, proposal)
    if len(existing) != len(targets):
        raise ValueError("Repair proposal generation did not complete")
    return load_json(PROPOSALS_PATH)


def validate_approved_repairs(entries: list[dict[str, Any]], proposal: dict[str, Any]) -> list[dict[str, Any]]:
    if proposal.get("bankSha256") != sha256_path(BANK_PATH):
        raise ValueError("Stale repair proposals: word_bank.json changed")
    by_word: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for index, entry in enumerate(entries):
        word = entry.get("word")
        if isinstance(word, str):
            by_word.setdefault(word, []).append((index, entry))
    approved = [item for item in proposal.get("repairs") or [] if item.get("status") == "approved"]
    targets = []
    for item in approved:
        word = item.get("word")
        matches = by_word.get(word) if isinstance(word, str) else None
        if not matches or len(matches) != 1:
            raise ValueError(f"Approved repair word {word!r} is missing or ambiguous")
        index, entry = matches[0]
        if item.get("index") != index or item.get("current") != {
            "text": entry.get("text", ""),
            "hint": entry.get("hint", ""),
            "hard_text": entry.get("hard_text", entry.get("hardText", "")),
            "clues": entry.get("clues") or [],
        }:
            raise ValueError(f"Approved repair word {word!r} has changed since proposal")
        targets.append({"index": index, "word": word, "current": item["current"]})
    response = {"repairs": [{"word": item["word"], **item.get("proposed", {})} for item in approved]}
    return validate_repairs(targets, response)


def apply_repairs(entries: list[dict[str, Any]], repairs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    updated = [dict(entry) for entry in entries]
    for repair in repairs:
        entry = updated[repair["index"]]
        proposed = repair["proposed"]
        entry.update({
            "text": proposed["text"],
            "hint": proposed["hint"],
            "hard_text": proposed["hard_text"],
            "clues": proposed["clues"],
        })
        entry.pop("hardText", None)
    return updated


def audit_records(entries: list[dict[str, Any]], proposal: dict[str, Any]) -> list[dict[str, Any]]:
    by_word: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for index, entry in enumerate(entries):
        word = entry.get("word")
        if isinstance(word, str):
            by_word.setdefault(word, []).append((index, entry))
    records = []
    for item in proposal.get("repairs") or []:
        if item.get("status") != "approved":
            continue
        word = item.get("word")
        matches = by_word.get(word) if isinstance(word, str) else None
        if not matches or len(matches) != 1:
            raise ValueError(f"Approved repair word {word!r} is missing or ambiguous")
        index, entry = matches[0]
        proposed = item.get("proposed") or {}
        expected_current = {
            "text": proposed.get("text"),
            "hint": proposed.get("hint"),
            "hard_text": proposed.get("hard_text"),
            "clues": proposed.get("clues"),
        }
        actual_current = {
            "text": entry.get("text"),
            "hint": entry.get("hint"),
            "hard_text": entry.get("hard_text"),
            "clues": entry.get("clues"),
        }
        if expected_current != actual_current:
            raise ValueError(f"Approved repair word {word!r} has changed since application")
        records.append({"index": index, "word": word, "fields": current_fields(entry)})
    if not records:
        raise ValueError("No approved repairs are available to audit")
    return records


def audit_repaired_entries(batch_size: int) -> dict[str, Any]:
    if batch_size <= 0:
        raise ValueError("batch-size must be positive")
    from audit_clue_answer_alignment import call_terra, estimate_terra_cost

    entries = load_json(BANK_PATH)
    proposal = load_json(PROPOSALS_PATH)
    records = audit_records(entries, proposal)
    bank_hash = sha256_path(BANK_PATH)
    proposal_hash = sha256_path(PROPOSALS_PATH)
    report = {
        "schemaVersion": 1,
        "generatedAt": utc_now(),
        "bankSha256": bank_hash,
        "proposalSha256": proposal_hash,
        "model": MODEL,
        "records": [],
        "usage": {"inputTokens": 0, "cachedInputTokens": 0, "outputTokens": 0},
    }
    if AUDIT_PATH.exists():
        existing = load_json(AUDIT_PATH)
        if existing.get("bankSha256") == bank_hash and existing.get("proposalSha256") == proposal_hash:
            report = existing
            report.setdefault("usage", {"inputTokens": 0, "cachedInputTokens": 0, "outputTokens": 0})
    completed_words = {record.get("word") for record in report.get("records") or [] if isinstance(record, dict)}
    api_key = load_api_key()
    remaining = [record for record in records if record["word"] not in completed_words]
    for start in range(0, len(remaining), batch_size):
        batch = remaining[start:start + batch_size]
        results, usage = call_terra(batch, api_key)
        for record in batch:
            report["records"].append({
                **record,
                "verdicts": results[record["index"]],
            })
        for key, value in usage.items():
            report["usage"][key] += value
        write_json(AUDIT_PATH, report)
    counts: dict[str, int] = {}
    for record in report["records"]:
        for verdict in record["verdicts"].values():
            name = verdict["verdict"]
            counts[name] = counts.get(name, 0) + 1
    report["summary"] = counts
    report["costEstimateUSD"] = estimate_terra_cost(report["usage"])["directUSD"]
    write_json(AUDIT_PATH, report)
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate review-only clue repairs for marked word-bank entries")
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--apply", action="store_true", help="Apply only approved repair proposals")
    parser.add_argument("--audit", action="store_true", help="Run a focused semantic audit of approved repairs")
    parser.add_argument("--yes", action="store_true", help="Required acknowledgement for --apply")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.apply and args.audit:
        raise ValueError("Choose either --apply or --audit")
    if args.apply:
        if not args.yes:
            raise ValueError("--apply requires --yes")
        entries = load_json(BANK_PATH)
        proposal = load_json(PROPOSALS_PATH)
        approved = validate_approved_repairs(entries, proposal)
        BANK_PATH.write_text(json.dumps(apply_repairs(entries, approved), indent=4, ensure_ascii=False) + "\n")
        print(f"Applied {len(approved)} approved clue repairs.")
        return 0
    if args.audit:
        report = audit_repaired_entries(args.batch_size)
        print(json.dumps({
            "auditedEntries": len(report["records"]),
            "summary": report["summary"],
            "costEstimateUSD": report["costEstimateUSD"],
        }, sort_keys=True))
        return 0
    report = generate_repair_proposals(args.batch_size)
    print(f"Wrote {len(report['repairs'])} pending-review repair proposals to {PROPOSALS_PATH.name}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as error:
        print(f"ERROR: {error}")
        raise SystemExit(2)
