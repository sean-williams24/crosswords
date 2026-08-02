#!/usr/bin/env python3
"""Review-first semantic audit for the crossword word bank.

This tool exports answer/clue batches for review in Codex chat, or can run a
bounded Terra API calibration. Neither workflow changes ``word_bank.json``.
A separate, explicit apply step can remove only human-approved,
checksum-protected proposals.

Usage:
  python3 audit_clue_answer_alignment.py init
  python3 audit_clue_answer_alignment.py export-terra-batch --limit 25
  python3 audit_clue_answer_alignment.py record-terra decisions.json
  python3 audit_clue_answer_alignment.py export-sol-batch --limit 50
  python3 audit_clue_answer_alignment.py record-sol decisions.json
  python3 audit_clue_answer_alignment.py calibrate-terra --limit 100
  python3 audit_clue_answer_alignment.py summary
  python3 audit_clue_answer_alignment.py propose-removals
  python3 audit_clue_answer_alignment.py validate-removals
  python3 audit_clue_answer_alignment.py apply-removals --yes
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


BACKEND_DIR = Path(__file__).resolve().parent
BANK_PATH = BACKEND_DIR / "word_bank.json"
AUDIT_PATH = BACKEND_DIR / "word_bank_clue_alignment_audit.json"
BATCH_PATH = BACKEND_DIR / "word_bank_clue_alignment_chat_batch.json"
REMOVALS_PATH = BACKEND_DIR / "word_bank_clue_alignment_removals.json"
CALIBRATION_PATH = BACKEND_DIR / "word_bank_clue_alignment_calibration.json"
BATCH_INPUT_PATH = BACKEND_DIR / "word_bank_clue_alignment_terra_batch.jsonl"
BATCH_STATE_PATH = BACKEND_DIR / "word_bank_clue_alignment_terra_batch_state.json"
BATCH_OUTPUT_PATH = BACKEND_DIR / "word_bank_clue_alignment_terra_batch_output.jsonl"
BATCH_ERRORS_PATH = BACKEND_DIR / "word_bank_clue_alignment_terra_batch_errors.json"
SCHEMA_VERSION = 1
TERRA_MODEL = "gpt-5.6-terra"
TERRA_INPUT_PER_MILLION = 2.50
TERRA_CACHED_INPUT_PER_MILLION = 0.25
TERRA_OUTPUT_PER_MILLION = 15.00
# Medium-reasoning responses occasionally require more than 2,400 tokens before
# emitting JSON.  140 requests with this ceiling remain below the 900k queued
# token limit for the account.
DEFAULT_TERRA_BATCH_MAX_REQUESTS = 140
TERRA_BATCH_MAX_OUTPUT_TOKENS = 4000
VALID_VERDICTS = {"match", "mismatch", "needs_review"}
VALID_CONFIDENCES = {"high", "medium", "low"}

API_SYSTEM_PROMPT = """You are a meticulous general-audience crossword editor.
Judge whether each clue actually and directly describes its exact answer.

Treat factual claims strictly: a named character must be in the stated work;
a person, place, title, date, or historical claim must be accurate. Do not
silently substitute a similar word, character, work, spelling, inflection, or
association. A clue may be difficult but still be a match. If you lack enough
confidence to call it correct or wrong, use needs_review.

Return JSON only. Confirm every omitted field matches. Include only fields that
are mismatches or need review. Reasons must be short factual explanations.
"""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_json(path: Path) -> Any:
    with path.open() as handle:
        return json.load(handle)


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def bank_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def json_sha256(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return hashlib.sha256(encoded).hexdigest()


def load_entries(path: Path = BANK_PATH) -> list[dict[str, Any]]:
    entries = load_json(path)
    if not isinstance(entries, list):
        raise ValueError("Word bank must be a JSON array")
    return entries


def field_values(entry: dict[str, Any]) -> list[dict[str, str]]:
    """Return every stored clue field, including the legacy hint fallback."""
    fields: list[dict[str, str]] = []
    for field in ("text", "hint", "hard_text", "hardText"):
        value = entry.get(field)
        if isinstance(value, str) and value.strip():
            fields.append({"field": field, "current": value})
    for index, value in enumerate(entry.get("clues") or []):
        if isinstance(value, str) and value.strip():
            fields.append({"field": f"clues[{index}]", "current": value})
    return fields


def new_audit(entries: list[dict[str, Any]], bank_path: Path) -> dict[str, Any]:
    records = []
    for index, entry in enumerate(entries):
        word = entry.get("word")
        fields = field_values(entry)
        if not isinstance(word, str) or not word.strip() or not fields:
            continue
        records.append({
            "index": index,
            "word": word,
            "fields": [
                {
                    **field,
                    "terra": None,
                    "sol": None,
                    "status": "pending_terra",
                }
                for field in fields
            ],
        })
    return {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": utc_now(),
        "updatedAt": utc_now(),
        "sourceBank": str(bank_path),
        "bankSha256": bank_sha256(bank_path),
        "reviewMethod": "Codex chat or explicitly requested Terra API calibration",
        "recommendedModelRoles": {"terra": "primary semantic review", "sol": "independent mismatch verification"},
        "scope": ["text", "hint", "hard_text", "hardText", "clues[]"],
        "records": records,
    }


def validate_audit_preconditions(entries: list[dict[str, Any]], audit: dict[str, Any], bank_path: Path) -> None:
    if audit.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError("Unsupported audit schema")
    if audit.get("bankSha256") != bank_sha256(bank_path):
        raise ValueError("Stale audit report: word_bank.json changed; re-run init")
    records = audit.get("records")
    if not isinstance(records, list):
        raise ValueError("Audit report records are missing")
    for record in records:
        index = record.get("index")
        if not isinstance(index, int) or not 0 <= index < len(entries):
            raise ValueError("Audit record index is invalid")
        if record.get("word") != entries[index].get("word"):
            raise ValueError("Audit record word no longer matches the bank")
        expected = field_values(entries[index])
        actual = [{"field": item.get("field"), "current": item.get("current")} for item in record.get("fields", [])]
        if actual != expected:
            raise ValueError(f"Audit record fields changed for {record.get('word')}")


def model_payload(records: list[dict[str, Any]], only_mismatches: bool) -> list[dict[str, Any]]:
    payload = []
    for record in records:
        fields = []
        for field in record["fields"]:
            if only_mismatches and (field.get("terra") or {}).get("verdict") != "mismatch":
                continue
            fields.append({"field": field["field"], "clue": field["current"]})
        if fields:
            payload.append({"index": record["index"], "answer": record["word"], "fields": fields})
    return payload


def validate_model_response(batch: list[dict[str, Any]], response: dict[str, Any]) -> dict[int, dict[str, dict[str, str]]]:
    """Fail closed unless model coverage exactly matches the requested pairs."""
    results = response.get("results")
    if not isinstance(results, list):
        raise ValueError("Model response is missing results")
    expected = {
        record["index"]: {field["field"] for field in record["fields"]}
        for record in batch
    }
    verified: dict[int, dict[str, dict[str, str]]] = {}
    for result in results:
        if not isinstance(result, dict) or not isinstance(result.get("index"), int):
            raise ValueError("Model result is missing an integer index")
        index = result["index"]
        if index not in expected or index in verified:
            raise ValueError("Model returned an unexpected or duplicate index")
        verdicts = result.get("verdicts")
        if not isinstance(verdicts, list):
            raise ValueError("Model result is missing verdicts")
        by_field: dict[str, dict[str, str]] = {}
        for verdict in verdicts:
            if not isinstance(verdict, dict):
                raise ValueError("Model verdict is invalid")
            field = verdict.get("field")
            value = verdict.get("verdict")
            confidence = verdict.get("confidence")
            reason = verdict.get("reason")
            if (
                not isinstance(field, str)
                or field not in expected[index]
                or field in by_field
                or value not in VALID_VERDICTS
                or confidence not in VALID_CONFIDENCES
                or not isinstance(reason, str)
                or not reason.strip()
            ):
                raise ValueError("Model verdict has invalid or incomplete fields")
            by_field[field] = {
                "verdict": value,
                "confidence": confidence,
                "reason": reason.strip(),
            }
        if set(by_field) != expected[index]:
            raise ValueError("Model verdict coverage does not match the request")
        verified[index] = by_field
    if set(verified) != set(expected):
        raise ValueError("Model result coverage does not match the request")
    return verified


def apply_terra_verdicts(
    audit: dict[str, Any],
    results: dict[int, dict[str, dict[str, str]]],
    require_independent_verification: bool = True,
) -> None:
    for record in audit["records"]:
        verdicts = results.get(record["index"])
        if not verdicts:
            continue
        for field in record["fields"]:
            field["terra"] = verdicts[field["field"]]
            field["status"] = (
                "pending_sol"
                if require_independent_verification and field["terra"]["verdict"] == "mismatch"
                else "terra_mismatch"
                if field["terra"]["verdict"] == "mismatch"
                else field["terra"]["verdict"]
            )


def apply_sol_verdicts(audit: dict[str, Any], results: dict[int, dict[str, dict[str, str]]]) -> None:
    for record in audit["records"]:
        verdicts = results.get(record["index"])
        if not verdicts:
            continue
        for field in record["fields"]:
            if field["field"] not in verdicts:
                continue
            field["sol"] = verdicts[field["field"]]
            field["status"] = (
                "confirmed_mismatch"
                if field["sol"]["verdict"] == "mismatch"
                else "needs_human_review"
            )


def pending_records(audit: dict[str, Any], stage: str) -> list[dict[str, Any]]:
    if stage == "terra":
        return [record for record in audit["records"] if any(field["terra"] is None for field in record["fields"])]
    return [
        record for record in audit["records"]
        if any((field.get("terra") or {}).get("verdict") == "mismatch" and field["sol"] is None for field in record["fields"])
    ]


def batch_sha256(batch: dict[str, Any]) -> str:
    stable = {key: value for key, value in batch.items() if key not in {"generatedAt", "batchHash"}}
    return json_sha256(stable)


def new_chat_batch(audit: dict[str, Any], stage: str, limit: int) -> dict[str, Any]:
    if limit <= 0:
        raise ValueError("limit must be positive")
    records = pending_records(audit, stage)[:limit]
    payload = model_payload(records, only_mismatches=stage == "sol")
    batch = {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": utc_now(),
        "bankSha256": audit["bankSha256"],
        "stage": stage,
        "recommendedCodexModel": "gpt-5.6-terra" if stage == "terra" else "gpt-5.6-sol",
        "instructions": (
            "For every supplied field, decide match, mismatch, or needs_review. "
            "Treat factual claims strictly and do not silently substitute a similar word, person, work, spelling, or inflection. "
            "Return JSON only: {results:[{index, verdicts:[{field, verdict, confidence, reason}]}]}."
        ),
        "records": payload,
    }
    batch["batchId"] = f"{stage}-{payload[0]['index'] if payload else 'complete'}-{payload[-1]['index'] if payload else 'complete'}"
    batch["batchHash"] = batch_sha256(batch)
    return batch


def validate_chat_decisions(batch: dict[str, Any], decisions: dict[str, Any]) -> dict[int, dict[str, dict[str, str]]]:
    if decisions.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError("Decision schema version is invalid")
    for key in ("bankSha256", "batchId", "batchHash", "stage"):
        if decisions.get(key) != batch.get(key):
            raise ValueError(f"Decision {key} does not match the exported batch")
    if decisions.get("confirmedAllOtherFieldsMatch") is True:
        return validate_compact_results(batch["records"], decisions, "Codex batch review")
    if "confirmedAllOtherFieldsMatch" in decisions:
        raise ValueError("confirmedAllOtherFieldsMatch must be true when supplied")
    return validate_model_response(batch["records"], decisions)


def validate_compact_results(
    records: list[dict[str, Any]],
    decisions: dict[str, Any],
    default_reason: str,
) -> dict[int, dict[str, dict[str, str]]]:
    """Expand an issue-only decision response into a verdict for every field."""
    if decisions.get("confirmedAllOtherFieldsMatch") is not True:
        raise ValueError("Response must confirm every omitted field matches")
    expected = {
        record["index"]: {field["field"] for field in record["fields"]}
        for record in records
    }
    expanded = {
        index: {
            field: {"verdict": "match", "confidence": "high", "reason": default_reason}
            for field in fields
        }
        for index, fields in expected.items()
    }
    overrides = decisions.get("overrides", [])
    if not isinstance(overrides, list):
        raise ValueError("Compact response overrides must be an array")
    seen: set[tuple[int, str]] = set()
    for override in overrides:
        if not isinstance(override, dict):
            raise ValueError("Compact response override is invalid")
        index = override.get("index")
        field = override.get("field")
        verdict = override.get("verdict")
        confidence = override.get("confidence")
        reason = override.get("reason")
        key = (index, field)
        if (
            not isinstance(index, int)
            or not isinstance(field, str)
            or index not in expected
            or field not in expected[index]
            or key in seen
            or verdict not in VALID_VERDICTS
            or confidence not in VALID_CONFIDENCES
            or not isinstance(reason, str)
            or not reason.strip()
        ):
            raise ValueError("Compact response override has invalid or incomplete fields")
        expanded[index][field] = {
            "verdict": verdict,
            "confidence": confidence,
            "reason": reason.strip(),
        }
        seen.add(key)
    return expanded


def load_api_key() -> str:
    env_path = BACKEND_DIR / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            key, separator, value = line.strip().partition("=")
            if separator and key == "OPENAI_API_KEY" and value:
                os.environ.setdefault(key, value)
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY is required for Terra calibration")
    return api_key


def terra_prompt(records: list[dict[str, Any]]) -> str:
    payload = model_payload(records, only_mismatches=False)
    return """Audit these answer/clue records. Return exactly this JSON shape:
{"confirmedAllOtherFieldsMatch":true,"overrides":[{"index":0,"field":"clues[0]","verdict":"mismatch|needs_review","confidence":"high|medium|low","reason":"short explanation"}]}

Records:
""" + json.dumps(payload, ensure_ascii=False)


def response_usage(response: Any) -> dict[str, int]:
    usage = getattr(response, "usage", None)
    if usage is None:
        raise ValueError("Terra response did not include usage")
    input_details = getattr(usage, "input_tokens_details", None)
    return {
        "inputTokens": int(getattr(usage, "input_tokens", 0) or 0),
        "cachedInputTokens": int(getattr(input_details, "cached_tokens", 0) or 0),
        "outputTokens": int(getattr(usage, "output_tokens", 0) or 0),
    }


def estimate_terra_cost(usage: dict[str, int]) -> dict[str, float]:
    uncached_input = max(usage["inputTokens"] - usage["cachedInputTokens"], 0)
    direct = (
        uncached_input * TERRA_INPUT_PER_MILLION
        + usage["cachedInputTokens"] * TERRA_CACHED_INPUT_PER_MILLION
        + usage["outputTokens"] * TERRA_OUTPUT_PER_MILLION
    ) / 1_000_000
    return {"directUSD": direct, "batchUSD": direct / 2}


def call_terra(records: list[dict[str, Any]], api_key: str) -> tuple[dict[int, dict[str, dict[str, str]]], dict[str, int]]:
    from openai import OpenAI

    response = OpenAI(api_key=api_key, timeout=120, max_retries=2).responses.create(
        model=TERRA_MODEL,
        reasoning={"effort": "medium"},
        input=[
            {"role": "system", "content": API_SYSTEM_PROMPT},
            {"role": "user", "content": terra_prompt(records)},
        ],
        text={"format": {"type": "json_object"}, "verbosity": "low"},
    )
    try:
        decisions = json.loads((response.output_text or "").strip())
    except json.JSONDecodeError as error:
        raise ValueError("Terra returned invalid JSON") from error
    if not isinstance(decisions, dict):
        raise ValueError("Terra response must be a JSON object")
    return validate_compact_results(records, decisions, "Terra API calibration confirmed match."), response_usage(response)


def run_terra_calibration(audit: dict[str, Any], limit: int, batch_size: int) -> dict[str, Any]:
    if limit <= 0 or batch_size <= 0:
        raise ValueError("limit and batch-size must be positive")
    report: dict[str, Any]
    if CALIBRATION_PATH.exists():
        existing = load_json(CALIBRATION_PATH)
        if (
            isinstance(existing, dict)
            and existing.get("status") == "running"
            and existing.get("model") == TERRA_MODEL
            and isinstance(existing.get("processedEntryCount"), int)
            and isinstance(existing.get("usage"), dict)
        ):
            report = existing
        else:
            report = {}
    else:
        report = {}
    prior_processed = int(report.get("processedEntryCount", 0))
    records = pending_records(audit, "terra")[:max(limit - prior_processed, 0)]
    if prior_processed >= limit:
        return report
    api_key = load_api_key()
    usages: list[dict[str, int]] = []
    processed = prior_processed
    if not report:
        report = {
            "schemaVersion": SCHEMA_VERSION,
            "generatedAt": utc_now(),
            "model": TERRA_MODEL,
            "reasoningEffort": "medium",
            "usage": {"inputTokens": 0, "cachedInputTokens": 0, "outputTokens": 0},
        }
    report.update({"requestedEntryCount": limit, "batchSize": batch_size, "status": "running"})
    prior_usage = {
        key: int((report.get("usage") or {}).get(key, 0) or 0)
        for key in ("inputTokens", "cachedInputTokens", "outputTokens")
    }
    for start in range(0, len(records), batch_size):
        batch = records[start:start + batch_size]
        try:
            results, usage = call_terra(batch, api_key)
        except Exception as error:
            report["status"] = "failed"
            report["failedAfterEntryCount"] = processed
            report["error"] = str(error)
            write_json(CALIBRATION_PATH, report)
            raise
        apply_terra_verdicts(audit, results)
        write_json(AUDIT_PATH, audit)
        usages.append(usage)
        processed += len(batch)
        report["processedEntryCount"] = processed
        report["usage"] = {
            key: prior_usage[key] + sum(item[key] for item in usages)
            for key in ("inputTokens", "cachedInputTokens", "outputTokens")
        }
        report["actualDirectCostEstimateUSD"] = estimate_terra_cost(report["usage"])["directUSD"]
        write_json(CALIBRATION_PATH, report)
        print(f"Terra calibration: processed {processed}/{len(records)} entries.")
    totals = {
        key: prior_usage[key] + sum(usage[key] for usage in usages)
        for key in ("inputTokens", "cachedInputTokens", "outputTokens")
    }
    costs = estimate_terra_cost(totals)
    remaining_entries = len(pending_records(audit, "terra"))
    projected = {
        "remainingDirectUSD": costs["directUSD"] * remaining_entries / processed if processed else 0,
        "remainingBatchUSD": costs["batchUSD"] * remaining_entries / processed if processed else 0,
    }
    report.update({
        "status": "complete",
        "entryCount": processed,
        "usage": totals,
        "actualDirectCostEstimateUSD": costs["directUSD"],
        "projected": projected,
        "remainingEntryCount": remaining_entries,
        "note": "Batch API projections assume OpenAI's documented 50% Batch discount; exact billing is determined by OpenAI.",
    })
    write_json(CALIBRATION_PATH, report)
    return report


def terra_request_body(records: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "model": TERRA_MODEL,
        "reasoning": {"effort": "medium"},
        "input": [
            {"role": "system", "content": API_SYSTEM_PROMPT},
            {"role": "user", "content": terra_prompt(records)},
        ],
        "text": {"format": {"type": "json_object"}, "verbosity": "low"},
        "max_output_tokens": TERRA_BATCH_MAX_OUTPUT_TOKENS,
    }


def build_terra_batch_requests(records: list[dict[str, Any]], batch_size: int) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    if batch_size <= 0:
        raise ValueError("batch-size must be positive")
    requests: list[dict[str, Any]] = []
    manifest: list[dict[str, Any]] = []
    for start in range(0, len(records), batch_size):
        batch = records[start:start + batch_size]
        indexes = [record["index"] for record in batch]
        custom_id = f"terra-{indexes[0]}-{indexes[-1]}"
        requests.append({
            "custom_id": custom_id,
            "method": "POST",
            "url": "/v1/responses",
            "body": terra_request_body(batch),
        })
        manifest.append({"customId": custom_id, "indexes": indexes})
    return requests, manifest


def submit_terra_batch(audit: dict[str, Any], batch_size: int, max_requests: int) -> dict[str, Any]:
    if max_requests <= 0:
        raise ValueError("max-requests must be positive")
    if BATCH_STATE_PATH.exists():
        state = load_json(BATCH_STATE_PATH)
        if isinstance(state, dict) and state.get("status") not in {"completed", "failed", "cancelled", "expired"}:
            raise ValueError("A Terra batch is already active; check its status before submitting another")
    remaining_records = pending_records(audit, "terra")
    if not remaining_records:
        raise ValueError("No Terra records remain to submit")
    records = remaining_records[:batch_size * max_requests]
    requests, manifest = build_terra_batch_requests(records, batch_size)
    BATCH_INPUT_PATH.write_text("".join(json.dumps(request, ensure_ascii=False) + "\n" for request in requests))
    api_key = load_api_key()
    from openai import OpenAI

    client = OpenAI(api_key=api_key, timeout=120, max_retries=2)
    with BATCH_INPUT_PATH.open("rb") as handle:
        input_file = client.files.create(file=handle, purpose="batch")
    batch = client.batches.create(
        input_file_id=input_file.id,
        endpoint="/v1/responses",
        completion_window="24h",
        metadata={"purpose": "word-bank-clue-alignment", "model": TERRA_MODEL},
    )
    state = {
        "schemaVersion": SCHEMA_VERSION,
        "submittedAt": utc_now(),
        "bankSha256": audit["bankSha256"],
        "model": TERRA_MODEL,
        "status": batch.status,
        "batchId": batch.id,
        "inputFileId": input_file.id,
        "entryCount": len(records),
        "requestCount": len(requests),
        "requestBatchSize": batch_size,
        "maxRequests": max_requests,
        "remainingEntryCountAtSubmission": len(remaining_records),
        "requests": manifest,
    }
    write_json(BATCH_STATE_PATH, state)
    return state


def refresh_terra_batch_state() -> dict[str, Any]:
    if not BATCH_STATE_PATH.exists():
        raise ValueError("No Terra batch has been submitted")
    state = load_json(BATCH_STATE_PATH)
    api_key = load_api_key()
    from openai import OpenAI

    batch = OpenAI(api_key=api_key, timeout=120, max_retries=2).batches.retrieve(state["batchId"])
    state["status"] = batch.status
    state["requestCounts"] = batch.request_counts.model_dump() if batch.request_counts else None
    state["outputFileId"] = batch.output_file_id
    state["errorFileId"] = batch.error_file_id
    state["errors"] = batch.errors.model_dump() if batch.errors else None
    state["checkedAt"] = utc_now()
    write_json(BATCH_STATE_PATH, state)
    return state


def response_text(response_body: dict[str, Any]) -> str:
    if isinstance(response_body.get("output_text"), str):
        return response_body["output_text"]
    parts = []
    for item in response_body.get("output") or []:
        for content in item.get("content") or []:
            if content.get("type") == "output_text" and isinstance(content.get("text"), str):
                parts.append(content["text"])
    if not parts:
        raise ValueError("Batch response contains no output text")
    return "".join(parts)


def collect_terra_batch(audit: dict[str, Any]) -> dict[str, int]:
    state = refresh_terra_batch_state()
    if state.get("status") != "completed":
        raise ValueError(f"Terra batch is {state.get('status')}; output is not ready")
    if not state.get("outputFileId"):
        raise ValueError("Completed Terra batch has no output file")
    api_key = load_api_key()
    from openai import OpenAI

    client = OpenAI(api_key=api_key, timeout=120, max_retries=2)
    raw_output = client.files.content(state["outputFileId"]).text
    BATCH_OUTPUT_PATH.write_text(raw_output)
    by_index = {record["index"]: record for record in audit["records"]}
    request_records = {
        item["customId"]: [by_index[index] for index in item["indexes"]]
        for item in state["requests"]
    }
    processed = 0
    errors = []
    for line in raw_output.splitlines():
        output = json.loads(line)
        custom_id = output.get("custom_id")
        request = request_records.get(custom_id)
        response = output.get("response") or {}
        if request is None or response.get("status_code") != 200:
            errors.append({"customId": custom_id, "error": output.get("error") or response})
            continue
        try:
            decisions = json.loads(response_text(response.get("body") or {}))
            results = validate_compact_results(request, decisions, "Terra Batch confirmed match.")
            apply_terra_verdicts(audit, results, require_independent_verification=False)
            processed += len(request)
        except (ValueError, json.JSONDecodeError) as error:
            errors.append({"customId": custom_id, "error": str(error)})
        if processed and processed % 100 == 0:
            write_json(AUDIT_PATH, audit)
    write_json(AUDIT_PATH, audit)
    write_json(BATCH_ERRORS_PATH, errors)
    state.update({"collectedAt": utc_now(), "processedEntryCount": processed, "errorCount": len(errors)})
    write_json(BATCH_STATE_PATH, state)
    return {"processed": processed, "errors": len(errors)}


def batch_usage(raw_output: str) -> dict[str, int]:
    """Sum billable token usage from a downloaded Batch API output file."""
    totals = {"inputTokens": 0, "cachedInputTokens": 0, "outputTokens": 0}
    for line in raw_output.splitlines():
        body = (json.loads(line).get("response") or {}).get("body") or {}
        usage = body.get("usage") or {}
        details = usage.get("input_tokens_details") or {}
        totals["inputTokens"] += int(usage.get("input_tokens", 0) or 0)
        totals["cachedInputTokens"] += int(details.get("cached_tokens", 0) or 0)
        totals["outputTokens"] += int(usage.get("output_tokens", 0) or 0)
    return totals


def projected_total_cost(spent_usd: float, attempted_entries: int, remaining_entries: int) -> float:
    if attempted_entries <= 0:
        raise ValueError("attempted entries must be positive")
    return spent_usd + spent_usd * remaining_entries / attempted_entries


def run_terra_batches(
    audit: dict[str, Any],
    prior_spend_usd: float,
    prior_attempted_entries: int,
    cost_ceiling_usd: float,
    poll_seconds: int,
    resume_cancelled_batch: bool = False,
) -> dict[str, Any]:
    """Continue sequential jobs, stopping before the measured projection exceeds the guardrail."""
    if prior_spend_usd < 0 or cost_ceiling_usd <= 0 or poll_seconds <= 0:
        raise ValueError("spend, cost ceiling, and poll seconds must be positive")
    spent_usd = prior_spend_usd
    attempted_entries = prior_attempted_entries
    while True:
        state = refresh_terra_batch_state()
        status = state.get("status")
        if status in {"validating", "in_progress", "finalizing", "cancelling"}:
            print(json.dumps({"event": "waiting", **batch_status_summary(state)}, sort_keys=True), flush=True)
            time.sleep(poll_seconds)
            continue
        if status == "cancelled" and resume_cancelled_batch:
            # A deliberately cancelled duplicate has no trustworthy complete
            # output to collect; its records remain pending in the checkpoint.
            print(json.dumps({"event": "resuming_after_cancellation", **batch_status_summary(state)}, sort_keys=True), flush=True)
        elif status != "completed":
            return {"status": "stopped", "reason": f"Batch is {status}", "spentUSD": spent_usd}
        if status == "completed" and not state.get("collectedAt"):
            collection = collect_terra_batch(audit)
            spent_usd += estimate_terra_cost(batch_usage(BATCH_OUTPUT_PATH.read_text()))["batchUSD"]
            attempted_entries += int(state["entryCount"])
            print(json.dumps({"event": "collected", **collection, "spentUSD": spent_usd}, sort_keys=True), flush=True)

        # Reload the checkpoint because another process may have collected the
        # completed batch while this runner was polling it.
        audit = load_json(AUDIT_PATH)
        remaining_entries = len(pending_records(audit, "terra"))
        if not remaining_entries:
            return {"status": "complete", "spentUSD": spent_usd, "attemptedEntries": attempted_entries}
        projection = projected_total_cost(spent_usd, attempted_entries, remaining_entries)
        if projection > cost_ceiling_usd:
            return {
                "status": "stopped",
                "reason": "Projected cost exceeds ceiling",
                "spentUSD": spent_usd,
                "projectedTotalUSD": projection,
                "costCeilingUSD": cost_ceiling_usd,
                "remainingEntries": remaining_entries,
            }
        state = submit_terra_batch(audit, 10, DEFAULT_TERRA_BATCH_MAX_REQUESTS)
        print(json.dumps({"event": "submitted", "spentUSD": spent_usd, **batch_status_summary(state)}, sort_keys=True), flush=True)


def record_stage(audit: dict[str, Any], batch: dict[str, Any], decisions: dict[str, Any]) -> int:
    stage = batch.get("stage")
    if stage not in {"terra", "sol"}:
        raise ValueError("Batch stage is invalid")
    if batch.get("bankSha256") != audit.get("bankSha256") or batch.get("batchHash") != batch_sha256(batch):
        raise ValueError("Batch is stale or has been changed")
    results = validate_chat_decisions(batch, decisions)
    if stage == "terra":
        apply_terra_verdicts(audit, results)
    else:
        apply_sol_verdicts(audit, results)
    audit["updatedAt"] = utc_now()
    return len(results)


def summary(audit: dict[str, Any]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for record in audit.get("records", []):
        for field in record.get("fields", []):
            status = str(field.get("status", "unknown"))
            counts[status] = counts.get(status, 0) + 1
    return counts


def require_complete_audit(audit: dict[str, Any]) -> None:
    counts = summary(audit)
    if counts.get("pending_terra", 0):
        raise ValueError("Audit is incomplete; finish the Terra stage first")


def propose_removals(audit: dict[str, Any]) -> dict[str, Any]:
    require_complete_audit(audit)
    removals = []
    for record in audit["records"]:
        fields = record["fields"]
        if fields and all(field["status"] in {"confirmed_mismatch", "terra_mismatch", "pending_sol"} for field in fields):
            removals.append({
                "index": record["index"],
                "word": record["word"],
                "fields": [{"field": field["field"], "current": field["current"]} for field in fields],
                "reviewBasis": "terra_only",
                "status": "pending_review",
            })
    return {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": utc_now(),
        "sourceBank": audit["sourceBank"],
        "bankSha256": audit["bankSha256"],
        "auditSha256": json_sha256(audit),
        "removals": removals,
    }


def validate_removals(entries: list[dict[str, Any]], removals: dict[str, Any], bank_path: Path) -> list[dict[str, Any]]:
    if removals.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError("Unsupported removals schema")
    if removals.get("bankSha256") != bank_sha256(bank_path):
        raise ValueError("Stale removals report: word_bank.json changed")
    approved = []
    seen: set[int] = set()
    for removal in removals.get("removals", []):
        if removal.get("status") != "approved":
            continue
        index = removal.get("index")
        if not isinstance(index, int) or index in seen or not 0 <= index < len(entries):
            raise ValueError("Approved removal index is invalid")
        if removal.get("word") != entries[index].get("word"):
            raise ValueError("Approved removal word no longer matches the bank")
        current = field_values(entries[index])
        if removal.get("fields") != current:
            raise ValueError("Approved removal clue fields no longer match the bank")
        seen.add(index)
        approved.append(removal)
    return approved


def apply_removals(entries: list[dict[str, Any]], approved: list[dict[str, Any]]) -> list[dict[str, Any]]:
    indexes = {removal["index"] for removal in approved}
    return [entry for index, entry in enumerate(entries) if index not in indexes]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit word-bank clue/answer alignment through Codex chat review.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("init", help="Create a fresh immutable audit report")
    for command, help_text in (("export-terra-batch", "Export a primary-review batch for Codex chat"), ("export-sol-batch", "Export an independent-verification batch for Codex chat")):
        command_parser = subparsers.add_parser(command, help=help_text)
        command_parser.add_argument("--limit", type=int, default=25)
    for command, help_text in (("record-terra", "Record a Codex primary-review decision file"), ("record-sol", "Record a Codex independent-review decision file")):
        command_parser = subparsers.add_parser(command, help=help_text)
        command_parser.add_argument("decisions", type=Path)
    calibration_parser = subparsers.add_parser("calibrate-terra", help="Run a bounded live Terra API calibration and estimate Batch cost")
    calibration_parser.add_argument("--limit", type=int, default=100)
    calibration_parser.add_argument("--batch-size", type=int, default=10)
    submit_parser = subparsers.add_parser("submit-terra-batch", help="Submit all remaining Terra audit work through the Batch API")
    submit_parser.add_argument("--request-batch-size", type=int, default=10)
    submit_parser.add_argument("--max-requests", type=int, default=DEFAULT_TERRA_BATCH_MAX_REQUESTS)
    subparsers.add_parser("terra-batch-status", help="Fetch and save the current Terra Batch API status")
    subparsers.add_parser("collect-terra-batch", help="Validate and apply a completed Terra batch to the audit report")
    runner_parser = subparsers.add_parser("run-terra-batches", help="Continue completed Terra batches until the cost guardrail is reached")
    runner_parser.add_argument("--prior-spend-usd", type=float, required=True)
    runner_parser.add_argument("--prior-attempted-entries", type=int, required=True)
    runner_parser.add_argument("--cost-ceiling-usd", type=float, required=True)
    runner_parser.add_argument("--poll-seconds", type=int, default=60)
    runner_parser.add_argument("--resume-cancelled-batch", action="store_true")
    subparsers.add_parser("summary", help="Show field-level audit progress")
    subparsers.add_parser("propose-removals", help="Write reviewable removal proposals")
    subparsers.add_parser("validate-removals", help="Validate only approved removal proposals")
    apply_parser = subparsers.add_parser("apply-removals", help="Apply approved removals to word_bank.json")
    apply_parser.add_argument("--yes", action="store_true", help="Required acknowledgement for the destructive apply step")
    return parser.parse_args()


def batch_status_summary(state: dict[str, Any]) -> dict[str, Any]:
    """Keep CLI progress output useful without printing the full request manifest."""
    return {
        key: state.get(key)
        for key in (
            "batchId",
            "status",
            "entryCount",
            "requestCount",
            "requestBatchSize",
            "maxRequests",
            "remainingEntryCountAtSubmission",
            "requestCounts",
            "submittedAt",
            "checkedAt",
            "outputFileId",
            "errorFileId",
            "errors",
        )
        if state.get(key) is not None
    }


def main() -> int:
    args = parse_args()
    entries = load_entries()
    if args.command == "init":
        if AUDIT_PATH.exists():
            raise ValueError(f"{AUDIT_PATH.name} already exists; remove it only after preserving or reviewing it")
        write_json(AUDIT_PATH, new_audit(entries, BANK_PATH))
        print(f"Created {AUDIT_PATH.name} for {len(entries)} word-bank entries.")
        return 0

    if not AUDIT_PATH.exists():
        raise ValueError(f"{AUDIT_PATH.name} does not exist; run init first")
    audit = load_json(AUDIT_PATH)
    validate_audit_preconditions(entries, audit, BANK_PATH)

    if args.command == "calibrate-terra":
        report = run_terra_calibration(audit, args.limit, args.batch_size)
        print(json.dumps(report, indent=2, sort_keys=True))
        return 0
    if args.command == "submit-terra-batch":
        state = submit_terra_batch(audit, args.request_batch_size, args.max_requests)
        print(json.dumps(batch_status_summary(state), indent=2, sort_keys=True))
        return 0
    if args.command == "terra-batch-status":
        print(json.dumps(batch_status_summary(refresh_terra_batch_state()), indent=2, sort_keys=True))
        return 0
    if args.command == "collect-terra-batch":
        print(json.dumps(collect_terra_batch(audit), indent=2, sort_keys=True))
        return 0
    if args.command == "run-terra-batches":
        print(json.dumps(run_terra_batches(
            audit,
            args.prior_spend_usd,
            args.prior_attempted_entries,
            args.cost_ceiling_usd,
            args.poll_seconds,
            args.resume_cancelled_batch,
        ), indent=2, sort_keys=True))
        return 0
    if args.command in {"export-terra-batch", "export-sol-batch"}:
        stage = "terra" if args.command == "export-terra-batch" else "sol"
        batch = new_chat_batch(audit, stage, args.limit)
        write_json(BATCH_PATH, batch)
        print(f"Exported {len(batch['records'])} {stage} records to {BATCH_PATH.name}.")
        return 0
    if args.command in {"record-terra", "record-sol"}:
        if not BATCH_PATH.exists():
            raise ValueError(f"{BATCH_PATH.name} does not exist; export a batch first")
        batch = load_json(BATCH_PATH)
        expected_stage = "terra" if args.command == "record-terra" else "sol"
        if batch.get("stage") != expected_stage:
            raise ValueError(f"Exported batch is for {batch.get('stage')}, not {expected_stage}")
        changed = record_stage(audit, batch, load_json(args.decisions))
        write_json(AUDIT_PATH, audit)
        print(f"Recorded {changed} {expected_stage} decisions.")
        return 0
    if args.command == "summary":
        print(json.dumps(summary(audit), indent=2, sort_keys=True))
        return 0
    if args.command == "propose-removals":
        report = propose_removals(audit)
        write_json(REMOVALS_PATH, report)
        print(f"Wrote {len(report['removals'])} pending-review proposals to {REMOVALS_PATH.name}.")
        return 0

    if not REMOVALS_PATH.exists():
        raise ValueError(f"{REMOVALS_PATH.name} does not exist; run propose-removals first")
    removals = load_json(REMOVALS_PATH)
    approved = validate_removals(entries, removals, BANK_PATH)
    if args.command == "validate-removals":
        print(f"Validated {len(approved)} approved removal proposals; no files changed.")
        return 0
    if not args.yes:
        raise ValueError("apply-removals requires --yes")
    updated = apply_removals(entries, approved)
    BANK_PATH.write_text(json.dumps(updated, indent=4, ensure_ascii=False) + "\n")
    print(f"Removed {len(approved)} approved entries: {len(entries)} -> {len(updated)}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(2)
