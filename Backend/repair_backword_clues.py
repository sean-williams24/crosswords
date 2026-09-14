#!/usr/bin/env python3
"""Review-first repair workflow for released historical Backword clues.

Usage:
  # No OpenAI key: export the released source rows for interactive Codex authoring.
  python3 Backend/repair_backword_clues.py export-codex \
    --output Backend/backword_clue_codex_input.json

  # Requires OPENAI_API_KEY and read credentials.  This only writes a local report.
  python3 Backend/repair_backword_clues.py propose \
    --output Backend/backword_clue_repair_review.json

  # Review the report: change every "proposed" status to "approved" or "skipped".
  # Applying or rolling back requires SUPABASE_URL plus a service-role SUPABASE_KEY.
  python3 Backend/repair_backword_clues.py apply \
    --input Backend/backword_clue_repair_review.json
  python3 Backend/repair_backword_clues.py rollback \
    --input Backend/backword_clue_repair_review.json

``propose`` intentionally limits its source rows to dates no later than today.
It migrates pre-2026-05-21 category records to the current one-word clue format,
and only replaces later clues when a dedicated morphology review finds a clear
wrong-form issue.  The review artifact retains each complete source payload and
is safe to resume: apply and rollback recognise rows already in their intended
state and leave divergent rows untouched.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlencode
from urllib.request import Request, urlopen
from copy import deepcopy
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

import generate_backword


SCHEMA_VERSION = 1
TABLE_NAME = "backword_words"
DEFAULT_CUTOFF = date(2026, 5, 21)
DEFAULT_REPORT = Path(__file__).parent / "backword_clue_repair_review.json"
DEFAULT_CODEX_INPUT = Path(__file__).parent / "backword_clue_codex_input.json"
PROPOSAL_STATUSES = {"proposed", "approved", "skipped", "unchanged", "unresolved"}
PATCH_ACTIONS = {"add", "replace"}
MORPHOLOGY_DECISIONS = {"KEEP", "REPLACE", "UNRESOLVED"}
CODEX_DECISIONS = {"KEEP", "REPLACE", "UNRESOLVED"}

MORPHOLOGY_REVIEW_SYSTEM = """You are a strict Backword clue morphology reviewer.
Each item contains a six-letter answer and its existing one-word lateral clue.

Review only whether the literal clue is compatible with the answer's exact
grammatical form: number, tense, inflection, derivation, spelling, and part of
speech. Do not reject a valid lateral association merely because answer and clue
are different concepts. A clue such as CASTLE/CHESS is allowed. Reject only if
the pair requires a player to silently change either word to a nearby form.

Return JSON with a "reviews" array. Every input must appear exactly once with:
  - "word": supplied uppercase answer
  - "clue": supplied uppercase clue
  - "decision": one of "KEEP", "REPLACE", or "UNRESOLVED"
  - "reason": concise explanation

Use KEEP when the existing clue's form is correct. Use REPLACE only for a clear
form mismatch. Use UNRESOLVED when the answer or clue is genuinely ambiguous;
never guess. Examples: CHEESY/CORN is REPLACE because CORN only works after
changing it to CORNY; CHEESY/CORNY is KEEP; ACHIEVE/EXCELS is REPLACE.
Return only the JSON object."""

MORPHOLOGY_REVIEW_USER = """Review these existing Backword clue pairs:
{pairs}

Return {{"reviews": [{{"word": "CASTLE", "clue": "CHESS", "decision": "KEEP", "reason": "Exact forms are compatible."}}]}}"""


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def json_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode()).hexdigest()


def utc_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_backend_env() -> None:
    """Load the optional private Backend env file without replacing explicit env."""
    env_file = Path(__file__).parent / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())


def jwt_role(api_key: str) -> str | None:
    """Read the untrusted role claim solely to reject obvious public keys."""
    parts = api_key.split(".")
    if len(parts) != 3:
        return None
    try:
        encoded = parts[1] + "=" * (-len(parts[1]) % 4)
        payload = json.loads(base64.urlsafe_b64decode(encoded).decode())
    except (ValueError, UnicodeDecodeError):
        return None
    role = payload.get("role") if isinstance(payload, dict) else None
    return role if isinstance(role, str) else None


def is_service_role_key(api_key: str) -> bool:
    """Accept legacy service-role JWTs and Supabase's server-only secret keys."""
    return api_key.startswith("sb_secret_") or jwt_role(api_key) == "service_role"


def supabase_credentials(*, require_service_role: bool) -> tuple[str, str]:
    """Resolve credentials without ever writing a public web key."""
    load_backend_env()
    if require_service_role:
        url = os.environ.get("SUPABASE_URL")
        api_key = os.environ.get("SUPABASE_KEY")
    else:
        url = os.environ.get("SUPABASE_URL") or os.environ.get("VITE_SUPABASE_URL")
        api_key = os.environ.get("SUPABASE_KEY") or os.environ.get("VITE_SUPABASE_ANON_KEY")

    # VS Code's env-file expansion can leave copied terminal line endings as
    # percent-encoded URL suffixes. Decode only the URL, then trim whitespace.
    url = unquote(str(url or "")).strip()
    api_key = str(api_key or "").strip()

    if not url or not api_key:
        raise ValueError(
            "SUPABASE_URL and SUPABASE_KEY are required "
            "(a read-only proposal may instead use VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY)."
        )
    if require_service_role and not is_service_role_key(api_key):
        raise ValueError(
            "apply and rollback require a service-role SUPABASE_KEY; anonymous web credentials are read-only."
        )
    return url, api_key


def supabase_client(*, require_service_role: bool):
    """Create an SDK client for mutations and API-backed proposal runs."""
    url, api_key = supabase_credentials(require_service_role=require_service_role)
    try:
        from supabase import create_client
    except ImportError as error:
        raise ValueError("supabase package not installed. Run: pip install -r Backend/requirements.txt") from error
    return create_client(url, api_key)


def fetch_released_rows_via_rest(through_date: date) -> list[dict[str, Any]]:
    """Read released rows without requiring the optional Python Supabase SDK."""
    url, api_key = supabase_credentials(require_service_role=False)
    query = urlencode({
        "select": "id,date,word_data",
        "date": f"lte.{through_date.isoformat()}",
        "order": "date.asc",
    })
    request = Request(
        f"{url.rstrip('/')}/rest/v1/{TABLE_NAME}?{query}",
        headers={"apikey": api_key, "Authorization": f"Bearer {api_key}"},
    )
    try:
        with urlopen(request, timeout=30) as response:
            rows = json.loads(response.read().decode())
    except (HTTPError, URLError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError(f"Could not read released Backword rows: {error}") from error
    if not isinstance(rows, list):
        raise ValueError("Supabase returned an invalid Backword row payload")
    return [row for row in rows if isinstance(row, dict) and isinstance(row.get("word_data"), dict)]


@dataclass(frozen=True)
class RestSupabaseClient:
    url: str
    api_key: str


def service_rest_client() -> RestSupabaseClient:
    """Return a service-role REST client for safe apply/rollback mutations."""
    url, api_key = supabase_credentials(require_service_role=True)
    return RestSupabaseClient(url.rstrip("/"), api_key)


def rest_request(client: RestSupabaseClient, method: str, path: str, *, body: dict[str, Any] | None = None) -> bytes:
    headers = {
        "apikey": client.api_key,
        "Authorization": f"Bearer {client.api_key}",
    }
    data = None
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode()
        headers["Content-Type"] = "application/json"
        headers["Prefer"] = "return=minimal"
    request = Request(f"{client.url}/rest/v1/{path}", data=data, headers=headers, method=method)
    try:
        with urlopen(request, timeout=30) as response:
            return response.read()
    except (HTTPError, URLError) as error:
        raise ValueError(f"Supabase {method} request failed: {error}") from error


def fetch_rows_by_ids_via_rest(client: RestSupabaseClient, ids: list[str]) -> list[dict[str, Any]]:
    if not ids:
        return []
    query = urlencode({
        "select": "id,date,word_data",
        "id": f"in.({','.join(ids)})",
    })
    payload = rest_request(client, "GET", f"{TABLE_NAME}?{query}")
    try:
        rows = json.loads(payload.decode())
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError("Supabase returned an invalid apply preflight payload") from error
    if not isinstance(rows, list):
        raise ValueError("Supabase returned an invalid apply preflight payload")
    return [row for row in rows if isinstance(row, dict)]


def update_word_data_via_rest(client: RestSupabaseClient, row_id: str, word_data: dict[str, Any]) -> None:
    query = urlencode({"id": f"eq.{row_id}"})
    rest_request(client, "PATCH", f"{TABLE_NAME}?{query}", body={"word_data": word_data})


def fetch_released_rows(client: Any, through_date: date) -> list[dict[str, Any]]:
    """Fetch the released archive, ordered deterministically for review."""
    rows = (
        client.table(TABLE_NAME)
        .select("id,date,word_data")
        .lte("date", through_date.isoformat())
        .order("date")
        .execute()
        .data
        or []
    )
    return [row for row in rows if isinstance(row.get("word_data"), dict)]


def fetch_rows_by_ids(client: Any, ids: list[str]) -> list[dict[str, Any]]:
    if not ids:
        return []
    if isinstance(client, RestSupabaseClient):
        return fetch_rows_by_ids_via_rest(client, ids)
    return (
        client.table(TABLE_NAME)
        .select("id,date,word_data")
        .in_("id", ids)
        .execute()
        .data
        or []
    )


def update_word_data(client: Any, row_id: str, word_data: dict[str, Any]) -> None:
    if isinstance(client, RestSupabaseClient):
        update_word_data_via_rest(client, row_id, word_data)
        return
    client.table(TABLE_NAME).update({"word_data": word_data}).eq("id", row_id).execute()


def normalise_clue(value: Any) -> str:
    return str(value or "").strip().upper()


def generated_candidate(word: str, enrichment_model: str, api_key: str) -> tuple[dict[str, Any] | None, dict[str, Any]]:
    """Generate exactly one current-style clue, retaining enough evidence for review."""
    generated = generate_backword.enrich_words([word], enrichment_model, api_key)
    matches = [item for item in generated if str(item.get("word", "")).upper() == word]
    evidence: dict[str, Any] = {
        "pipeline": "generate_backword.enrich_words",
        "model": enrichment_model,
        "responses": matches,
    }
    if len(matches) != 1:
        evidence["failure"] = "Expected exactly one generated response for the answer."
        return None, evidence
    item = matches[0]
    if item.get("reject"):
        evidence["failure"] = "Current generator rejected this historical answer."
        return None, evidence
    clue = normalise_clue(item.get("clue"))
    if not clue:
        evidence["failure"] = "Generator returned no clue."
        return None, evidence
    return {"word": word, "clue": clue}, evidence


def validate_candidate(candidate: dict[str, str], validator_model: str, api_key: str) -> tuple[bool, dict[str, Any]]:
    """Run the same local, semantic, and adversarial gates as new Backword words."""
    local_reason = generate_backword.local_rejection_reason(candidate)
    evidence: dict[str, Any] = {
        "pipeline": "generate_backword local + semantic + adversarial validation",
        "model": validator_model,
        "localReason": local_reason,
    }
    if local_reason:
        return False, evidence

    client = generate_backword.OpenAI(api_key=api_key)
    semantic = generate_backword.validation_verdicts(
        client, [candidate], validator_model, generate_backword.VALIDATE_SYSTEM
    )
    if semantic is None:
        evidence["semantic"] = "invalid_or_incomplete_review"
        return False, evidence
    key = (candidate["word"].upper(), candidate["clue"].upper())
    semantic_result = semantic[key]
    evidence["semantic"] = semantic_result
    if not semantic_result["accept"]:
        return False, evidence

    adversarial = generate_backword.validation_verdicts(
        client, [candidate], validator_model, generate_backword.ADVERSARIAL_VALIDATE_SYSTEM
    )
    if adversarial is None:
        evidence["adversarial"] = "invalid_or_incomplete_review"
        return False, evidence
    adversarial_result = adversarial[key]
    evidence["adversarial"] = adversarial_result
    return bool(adversarial_result["accept"]), evidence


def propose_validated_clue(
    word: str,
    enrichment_model: str,
    validator_model: str,
    api_key: str,
) -> tuple[str | None, dict[str, Any]]:
    candidate, generation_evidence = generated_candidate(word, enrichment_model, api_key)
    evidence: dict[str, Any] = {"generation": generation_evidence}
    if candidate is None:
        return None, evidence
    accepted, validation_evidence = validate_candidate(candidate, validator_model, api_key)
    evidence["validation"] = validation_evidence
    if not accepted:
        evidence["failure"] = "Generated clue did not pass every current validation gate."
        return None, evidence
    evidence["validatedClue"] = candidate["clue"]
    return candidate["clue"], evidence


def morphology_verdicts(
    entries: list[dict[str, Any]], validator_model: str, api_key: str
) -> dict[str, dict[str, str]]:
    """Return one strict morphology verdict per row ID, failing closed by batch."""
    if not entries:
        return {}
    client = generate_backword.OpenAI(api_key=api_key)
    results: dict[str, dict[str, str]] = {}
    batch_size = 20

    for start in range(0, len(entries), batch_size):
        batch = entries[start : start + batch_size]
        grouped: dict[tuple[str, str], list[str]] = {}
        for entry in batch:
            grouped.setdefault((entry["word"], entry["currentClue"]), []).append(entry["id"])
        pairs = [{"word": word, "clue": clue} for word, clue in grouped]
        try:
            response = client.chat.completions.create(
                model=validator_model,
                messages=[
                    {"role": "system", "content": MORPHOLOGY_REVIEW_SYSTEM},
                    {"role": "user", "content": MORPHOLOGY_REVIEW_USER.format(pairs=json.dumps(pairs))},
                ],
                temperature=0,
                response_format={"type": "json_object"},
            )
            payload = json.loads(response.choices[0].message.content.strip())
            reviews = payload.get("reviews") if isinstance(payload, dict) else None
            if not isinstance(reviews, list):
                raise ValueError("Missing reviews array")
            verdict_by_pair: dict[tuple[str, str], dict[str, str]] = {}
            expected = set(grouped)
            for review in reviews:
                if not isinstance(review, dict):
                    raise ValueError("Review entry is not an object")
                key = (normalise_clue(review.get("word")), normalise_clue(review.get("clue")))
                decision = review.get("decision")
                reason = review.get("reason")
                if (
                    key not in expected
                    or key in verdict_by_pair
                    or decision not in MORPHOLOGY_DECISIONS
                    or not isinstance(reason, str)
                    or not reason.strip()
                ):
                    raise ValueError("Malformed, duplicate, or unexpected morphology review")
                verdict_by_pair[key] = {"decision": decision, "reason": reason.strip()}
            if set(verdict_by_pair) != expected:
                raise ValueError("Incomplete morphology review")
            for key, ids in grouped.items():
                results.update({row_id: verdict_by_pair[key] for row_id in ids})
        except Exception as error:
            message = f"Morphology review failed closed: {error}"
            for entry in batch:
                results[entry["id"]] = {"decision": "UNRESOLVED", "reason": message}
    return results


def source_entry(row: dict[str, Any], cutoff: date) -> dict[str, Any]:
    word_data = deepcopy(row["word_data"])
    word = normalise_clue(word_data.get("word"))
    if not word:
        raise ValueError(f"{row.get('id')} has no Backword answer")
    row_date = date.fromisoformat(str(row["date"]))
    current_clue = normalise_clue(word_data.get("clue"))
    return {
        "id": str(row["id"]),
        "date": row_date.isoformat(),
        "word": word,
        "era": "legacy_category" if row_date < cutoff else "existing_clue",
        "sourceWordData": word_data,
        "sourceWordDataSha256": json_sha256(word_data),
        "currentClue": current_clue or None,
    }


def proposed_entry(base: dict[str, Any], action: str, clue: str, evidence: dict[str, Any]) -> dict[str, Any]:
    return {
        **base,
        "action": action,
        "proposedClue": clue,
        "status": "proposed",
        "evidence": evidence,
    }


def unresolved_entry(base: dict[str, Any], reason: str, evidence: dict[str, Any]) -> dict[str, Any]:
    return {
        **base,
        "action": "unresolved",
        "proposedClue": None,
        "status": "unresolved",
        "evidence": {**evidence, "failure": reason},
    }


def build_report(
    rows: list[dict[str, Any]],
    *,
    cutoff: date,
    through_date: date,
    enrichment_model: str,
    validator_model: str,
    api_key: str,
) -> dict[str, Any]:
    """Build the complete review artifact without mutating Supabase."""
    bases = [source_entry(row, cutoff) for row in rows]
    legacy = [entry for entry in bases if entry["era"] == "legacy_category"]
    post_cutover = [entry for entry in bases if entry["era"] == "existing_clue"]
    entries: list[dict[str, Any]] = []

    for base in legacy:
        clue, evidence = propose_validated_clue(
            base["word"], enrichment_model, validator_model, api_key
        )
        if clue is None:
            entries.append(unresolved_entry(base, "Could not generate a fully validated current-style clue.", evidence))
        else:
            action = "replace" if base["currentClue"] else "add"
            entries.append(proposed_entry(base, action, clue, evidence))

    review_inputs = [
        entry for entry in post_cutover
        if entry["currentClue"]
    ]
    reviews = morphology_verdicts(review_inputs, validator_model, api_key)
    for base in post_cutover:
        if not base["currentClue"]:
            entries.append(unresolved_entry(base, "Post-cutover row has no clue to review.", {}))
            continue
        review = reviews.get(base["id"])
        if review is None or review["decision"] == "UNRESOLVED":
            entries.append(unresolved_entry(base, (review or {}).get("reason", "No morphology verdict."), {
                "morphologyReview": review,
            }))
        elif review["decision"] == "KEEP":
            entries.append({
                **base,
                "action": "unchanged",
                "proposedClue": None,
                "status": "unchanged",
                "evidence": {"morphologyReview": review},
            })
        else:
            clue, evidence = propose_validated_clue(
                base["word"], enrichment_model, validator_model, api_key
            )
            evidence["morphologyReview"] = review
            if clue is None:
                entries.append(unresolved_entry(base, "Could not generate a fully validated morphology repair.", evidence))
            else:
                entries.append(proposed_entry(base, "replace", clue, evidence))

    entries.sort(key=lambda entry: (entry["date"], entry["id"]))
    return {
        "schemaVersion": SCHEMA_VERSION,
        "kind": "backword_clue_repair",
        "generatedAt": utc_timestamp(),
        "table": TABLE_NAME,
        "cutoffDate": cutoff.isoformat(),
        "throughDate": through_date.isoformat(),
        "models": {"enrichment": enrichment_model, "validator": validator_model},
        "source": {
            "rowCount": len(rows),
            "rowsSha256": json_sha256([
                {"id": entry["id"], "wordDataSha256": entry["sourceWordDataSha256"]}
                for entry in entries
            ]),
        },
        "summary": {
            "legacyCategoryRows": len(legacy),
            "existingClueRows": len(post_cutover),
            "proposed": sum(entry["status"] == "proposed" for entry in entries),
            "unchanged": sum(entry["status"] == "unchanged" for entry in entries),
            "unresolved": sum(entry["status"] == "unresolved" for entry in entries),
        },
        "entries": entries,
        "applyHistory": [],
    }


def build_codex_input(
    rows: list[dict[str, Any]], *, cutoff: date, through_date: date
) -> dict[str, Any]:
    """Export a complete, read-only hand-off package for interactive Codex review."""
    entries = [source_entry(row, cutoff) for row in rows]
    for entry in entries:
        entry["reviewTask"] = (
            "generate_current_style_clue" if entry["era"] == "legacy_category"
            else "review_existing_clue_morphology"
        )
    entries.sort(key=lambda entry: (entry["date"], entry["id"]))
    return {
        "schemaVersion": SCHEMA_VERSION,
        "kind": "backword_clue_repair_codex_input",
        "generatedAt": utc_timestamp(),
        "table": TABLE_NAME,
        "cutoffDate": cutoff.isoformat(),
        "throughDate": through_date.isoformat(),
        "source": {
            "rowCount": len(rows),
            "rowsSha256": json_sha256([
                {"id": entry["id"], "wordDataSha256": entry["sourceWordDataSha256"]}
                for entry in entries
            ]),
        },
        "summary": {
            "legacyCategoryRows": sum(entry["era"] == "legacy_category" for entry in entries),
            "existingClueRows": sum(entry["era"] == "existing_clue" for entry in entries),
        },
        "entries": entries,
    }


def validate_codex_input(handoff: dict[str, Any]) -> None:
    if handoff.get("schemaVersion") != SCHEMA_VERSION or handoff.get("kind") != "backword_clue_repair_codex_input":
        raise ValueError("Unsupported Codex hand-off artifact")
    entries = handoff.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ValueError("Codex hand-off has no entries")
    expected_manifest = json_sha256([
        {"id": entry.get("id"), "wordDataSha256": entry.get("sourceWordDataSha256")}
        for entry in entries
        if isinstance(entry, dict)
    ])
    if handoff.get("source", {}).get("rowsSha256") != expected_manifest:
        raise ValueError("Codex hand-off source row manifest does not match")
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("sourceWordData"), dict):
            raise ValueError("Codex hand-off contains an invalid source entry")
        if entry.get("sourceWordDataSha256") != json_sha256(entry["sourceWordData"]):
            raise ValueError(f"{entry.get('id')} source payload hash does not match")


def build_report_from_codex_decisions(
    handoff: dict[str, Any], decisions: dict[str, Any]
) -> dict[str, Any]:
    """Convert this chat's fully reviewed decisions into the normal apply artifact."""
    validate_codex_input(handoff)
    if isinstance(decisions, dict) and "decisions" not in decisions:
        decisions = expand_compact_codex_decisions(handoff, decisions)
    raw_decisions = decisions.get("decisions") if isinstance(decisions, dict) else None
    if not isinstance(raw_decisions, list):
        raise ValueError("Codex decisions must contain a decisions array")
    decision_by_id: dict[str, dict[str, Any]] = {}
    for decision in raw_decisions:
        if not isinstance(decision, dict) or not isinstance(decision.get("id"), str):
            raise ValueError("Codex decision is missing a row ID")
        row_id = decision["id"]
        if row_id in decision_by_id:
            raise ValueError(f"Duplicate Codex decision for {row_id}")
        if decision.get("decision") not in CODEX_DECISIONS:
            raise ValueError(f"{row_id} has an invalid Codex decision")
        if not isinstance(decision.get("reason"), str) or not decision["reason"].strip():
            raise ValueError(f"{row_id} is missing Codex review reasoning")
        decision_by_id[row_id] = decision

    sources = handoff["entries"]
    if set(decision_by_id) != {entry["id"] for entry in sources}:
        raise ValueError("Codex decisions must cover every source row exactly once")
    entries: list[dict[str, Any]] = []
    for source in sources:
        decision = decision_by_id[source["id"]]
        if decision.get("sourceWordDataSha256") != source["sourceWordDataSha256"]:
            raise ValueError(f"{source['id']} decision does not match its source snapshot")
        decision_type = decision["decision"]
        evidence: dict[str, Any] = {
            "codexReview": {
                "reason": decision["reason"].strip(),
                "semantic": decision.get("semanticReview", "accepted"),
                "adversarial": decision.get("adversarialReview", "accepted"),
            }
        }
        if decision_type == "KEEP":
            if source["era"] != "existing_clue":
                raise ValueError(f"{source['id']} legacy entries require a new clue, not KEEP")
            entries.append({
                **source,
                "action": "unchanged",
                "proposedClue": None,
                "status": "unchanged",
                "evidence": evidence,
            })
            continue
        if decision_type == "UNRESOLVED":
            entries.append(unresolved_entry(source, decision["reason"], evidence))
            continue

        clue = normalise_clue(decision.get("proposedClue"))
        candidate = {"word": source["word"], "clue": clue}
        local_reason = generate_backword.local_rejection_reason(candidate)
        if local_reason:
            raise ValueError(f"{source['id']} Codex proposal fails local safety: {local_reason}")
        evidence["validatedClue"] = clue
        evidence["localReason"] = None
        action = "replace" if source["currentClue"] else "add"
        entries.append(proposed_entry(source, action, clue, evidence))

    entries.sort(key=lambda entry: (entry["date"], entry["id"]))
    report = {
        "schemaVersion": SCHEMA_VERSION,
        "kind": "backword_clue_repair",
        "generatedAt": utc_timestamp(),
        "table": TABLE_NAME,
        "cutoffDate": handoff["cutoffDate"],
        "throughDate": handoff["throughDate"],
        "models": {"enrichment": "interactive_codex", "validator": "interactive_codex"},
        "source": deepcopy(handoff["source"]),
        "summary": {
            "legacyCategoryRows": sum(entry["era"] == "legacy_category" for entry in entries),
            "existingClueRows": sum(entry["era"] == "existing_clue" for entry in entries),
            "proposed": sum(entry["status"] == "proposed" for entry in entries),
            "unchanged": sum(entry["status"] == "unchanged" for entry in entries),
            "unresolved": sum(entry["status"] == "unresolved" for entry in entries),
        },
        "entries": entries,
        "applyHistory": [],
    }
    validate_report(report, require_reviewed=False)
    return report


def compact_clue(value: Any) -> tuple[str, str]:
    """Accept either a concise clue string or an object with authoring rationale."""
    if isinstance(value, str):
        return normalise_clue(value), "Interactive Codex reviewed the current clue style and exact word form."
    if isinstance(value, dict) and isinstance(value.get("clue"), str) and isinstance(value.get("reason"), str):
        return normalise_clue(value["clue"]), value["reason"].strip()
    raise ValueError("Compact Codex clues must be strings or {clue, reason} objects")


def expand_compact_codex_decisions(handoff: dict[str, Any], compact: dict[str, Any]) -> dict[str, Any]:
    """Expand this chat's concise date-keyed decisions into per-row reviewed records."""
    validate_codex_input(handoff)
    if compact.get("sourceRowsSha256") != handoff["source"]["rowsSha256"]:
        raise ValueError("Compact Codex decisions do not match the source row manifest")
    if compact.get("confirmedAllOtherPostCutoverCluesKeep") is not True:
        raise ValueError("Compact Codex decisions must confirm every non-replaced post-cutover clue was reviewed")
    legacy_clues = compact.get("legacyClues")
    replacements = compact.get("postCutoverReplacements", {})
    if not isinstance(legacy_clues, dict) or not isinstance(replacements, dict):
        raise ValueError("Compact Codex decisions require legacyClues and postCutoverReplacements objects")

    legacy_dates = {entry["date"] for entry in handoff["entries"] if entry["era"] == "legacy_category"}
    post_dates = {entry["date"] for entry in handoff["entries"] if entry["era"] == "existing_clue"}
    if set(legacy_clues) != legacy_dates:
        raise ValueError("Compact Codex decisions must provide exactly one clue for every legacy date")
    if not set(replacements).issubset(post_dates):
        raise ValueError("Compact Codex replacements include a non-post-cutover date")

    decisions: list[dict[str, Any]] = []
    for entry in handoff["entries"]:
        common = {"id": entry["id"], "sourceWordDataSha256": entry["sourceWordDataSha256"]}
        if entry["era"] == "legacy_category":
            clue, reason = compact_clue(legacy_clues[entry["date"]])
            decisions.append({**common, "decision": "REPLACE", "proposedClue": clue, "reason": reason})
        elif entry["date"] in replacements:
            clue, reason = compact_clue(replacements[entry["date"]])
            decisions.append({**common, "decision": "REPLACE", "proposedClue": clue, "reason": reason})
        else:
            decisions.append({
                **common,
                "decision": "KEEP",
                "reason": "Interactive Codex reviewed this lateral clue and found no clear inflection, morphology, plurality, or word-form mismatch.",
            })
    return {"decisions": decisions}


def patched_word_data(entry: dict[str, Any]) -> dict[str, Any]:
    clue = normalise_clue(entry.get("proposedClue"))
    if not clue:
        raise ValueError(f"{entry.get('id')} has no proposed clue")
    word_data = deepcopy(entry["sourceWordData"])
    word_data["clue"] = clue
    return word_data


def validate_report(report: dict[str, Any], *, require_reviewed: bool) -> None:
    if report.get("schemaVersion") != SCHEMA_VERSION or report.get("kind") != "backword_clue_repair":
        raise ValueError("Unsupported Backword clue repair artifact")
    entries = report.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ValueError("Repair artifact has no entries")
    expected_rows_hash = json_sha256([
        {"id": entry.get("id"), "wordDataSha256": entry.get("sourceWordDataSha256")}
        for entry in entries
        if isinstance(entry, dict)
    ])
    if report.get("source", {}).get("rowsSha256") != expected_rows_hash:
        raise ValueError("Repair artifact source row manifest does not match")
    ids: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("Repair artifact entry is invalid")
        row_id = entry.get("id")
        source = entry.get("sourceWordData")
        if not isinstance(row_id, str) or row_id in ids or not isinstance(source, dict):
            raise ValueError("Repair artifact row IDs or source payloads are invalid")
        ids.add(row_id)
        if entry.get("sourceWordDataSha256") != json_sha256(source):
            raise ValueError(f"{row_id} source payload hash does not match")
        status = entry.get("status")
        action = entry.get("action")
        if status not in PROPOSAL_STATUSES:
            raise ValueError(f"{row_id} has an unsupported review status")
        if action not in PATCH_ACTIONS | {"unchanged", "unresolved"}:
            raise ValueError(f"{row_id} has an unsupported repair action")
        evidence = entry.get("evidence")
        if not isinstance(evidence, dict):
            raise ValueError(f"{row_id} has invalid review evidence")
        if action in PATCH_ACTIONS:
            expected = normalise_clue(evidence.get("validatedClue"))
            if not expected or normalise_clue(entry.get("proposedClue")) != expected:
                raise ValueError(f"{row_id} proposal does not match its validated clue")
        if require_reviewed:
            if status == "proposed":
                raise ValueError(f"{row_id} is still awaiting human review")
            if status == "unresolved" or action == "unresolved":
                raise ValueError(f"{row_id} remains unresolved and blocks apply")
            if action in PATCH_ACTIONS and status not in {"approved", "skipped"}:
                raise ValueError(f"{row_id} has an invalid patch review status")
            if action == "unchanged" and status != "unchanged":
                raise ValueError(f"{row_id} unchanged entry was modified")


def approved_entries(report: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        entry for entry in report["entries"]
        if entry["action"] in PATCH_ACTIONS and entry["status"] == "approved"
    ]


def approve_all_proposals(report: dict[str, Any]) -> int:
    """Record an explicit human approval for every pending generated patch."""
    validate_report(report, require_reviewed=False)
    approved = 0
    for entry in report["entries"]:
        if entry["action"] in PATCH_ACTIONS and entry["status"] == "proposed":
            entry["status"] = "approved"
            approved += 1
    return approved


def apply_report(report: dict[str, Any], client: Any, *, rollback: bool = False, dry_run: bool = False) -> list[dict[str, str]]:
    """Apply approved repairs or restore their source payloads, safely resumable."""
    validate_report(report, require_reviewed=True)
    entries = approved_entries(report)
    current_by_id = {row["id"]: row for row in fetch_rows_by_ids(client, [entry["id"] for entry in entries])}
    outcomes: list[dict[str, str]] = []
    pending: list[tuple[dict[str, Any], dict[str, Any]]] = []

    for entry in entries:
        row_id = entry["id"]
        current = current_by_id.get(row_id)
        source = entry["sourceWordData"]
        patched = patched_word_data(entry)
        expected_current = patched if rollback else source
        already_target = source if rollback else patched
        if current is None or not isinstance(current.get("word_data"), dict):
            outcomes.append({"id": row_id, "outcome": "conflict", "detail": "Row no longer exists."})
        elif json_sha256(current["word_data"]) == json_sha256(already_target):
            outcomes.append({"id": row_id, "outcome": "already_applied", "detail": "Row already has target payload."})
        elif json_sha256(current["word_data"]) == json_sha256(expected_current):
            pending.append((entry, source if rollback else patched))
        else:
            outcomes.append({"id": row_id, "outcome": "conflict", "detail": "Row changed since the review snapshot."})

    for entry, target in pending:
        if dry_run:
            outcomes.append({"id": entry["id"], "outcome": "would_apply", "detail": "Preflight passed."})
            continue
        update_word_data(client, entry["id"], target)
        outcomes.append({"id": entry["id"], "outcome": "applied", "detail": "Updated word_data."})
    return outcomes


def write_json(path: Path, value: Any, *, overwrite: bool = True) -> None:
    if path.exists() and not overwrite:
        raise ValueError(f"Refusing to overwrite existing report: {path}")
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def parse_date(value: str) -> date:
    try:
        return date.fromisoformat(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("Expected YYYY-MM-DD") from error


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Repair released historical Backword clues.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    propose = subparsers.add_parser("propose", help="Create a review artifact without updating Supabase.")
    propose.add_argument("--output", type=Path, default=DEFAULT_REPORT)
    propose.add_argument("--overwrite-output", action="store_true")
    propose.add_argument("--through", type=parse_date, default=date.today())
    propose.add_argument("--cutoff", type=parse_date, default=DEFAULT_CUTOFF)
    propose.add_argument("--model", default="gpt-4o-mini")
    propose.add_argument("--validator-model", default="gpt-5.4")

    codex_export = subparsers.add_parser(
        "export-codex", help="Export immutable source rows for interactive Codex clue authoring."
    )
    codex_export.add_argument("--output", type=Path, default=DEFAULT_CODEX_INPUT)
    codex_export.add_argument("--overwrite-output", action="store_true")
    codex_export.add_argument("--through", type=parse_date, default=date.today())
    codex_export.add_argument("--cutoff", type=parse_date, default=DEFAULT_CUTOFF)

    codex_record = subparsers.add_parser(
        "record-codex", help="Convert fully reviewed interactive Codex decisions into an apply artifact."
    )
    codex_record.add_argument("--input", type=Path, default=DEFAULT_CODEX_INPUT)
    codex_record.add_argument("--decisions", type=Path, required=True)
    codex_record.add_argument("--output", type=Path, default=DEFAULT_REPORT)
    codex_record.add_argument("--overwrite-output", action="store_true")

    approve = subparsers.add_parser("approve-all", help="Mark all pending clue proposals as human approved.")
    approve.add_argument("--input", type=Path, default=DEFAULT_REPORT)

    for command in ("apply", "rollback"):
        action = subparsers.add_parser(command, help=f"{command.title()} approved repairs from a reviewed artifact.")
        action.add_argument("--input", type=Path, default=DEFAULT_REPORT)
        action.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    load_backend_env()
    if args.command == "export-codex":
        if args.through > date.today():
            raise SystemExit("Refusing to include future scheduled rows; --through must not be later than today.")
        try:
            rows = fetch_released_rows_via_rest(args.through)
            handoff = build_codex_input(rows, cutoff=args.cutoff, through_date=args.through)
            write_json(args.output, handoff, overwrite=args.overwrite_output)
        except ValueError as error:
            raise SystemExit(str(error)) from error
        print(f"Wrote {handoff['source']['rowCount']} released rows for Codex authoring to {args.output}")
        return

    if args.command == "propose":
        if args.through > date.today():
            raise SystemExit("Refusing to include future scheduled rows; --through must not be later than today.")
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise SystemExit("OPENAI_API_KEY is required to propose current-style clue repairs.")
        try:
            client = supabase_client(require_service_role=False)
            rows = fetch_released_rows(client, args.through)
            report = build_report(
                rows,
                cutoff=args.cutoff,
                through_date=args.through,
                enrichment_model=args.model,
                validator_model=args.validator_model,
                api_key=api_key,
            )
            write_json(args.output, report, overwrite=args.overwrite_output)
        except ValueError as error:
            raise SystemExit(str(error)) from error
        print(f"Wrote {report['summary']['proposed']} proposals and {report['summary']['unresolved']} unresolved rows to {args.output}")
        return

    if args.command == "record-codex":
        try:
            handoff = json.loads(args.input.read_text())
            decisions = json.loads(args.decisions.read_text())
            report = build_report_from_codex_decisions(handoff, decisions)
            write_json(args.output, report, overwrite=args.overwrite_output)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            raise SystemExit(str(error)) from error
        print(f"Wrote {report['summary']['proposed']} Codex proposals to {args.output}")
        return

    if args.command == "approve-all":
        try:
            report = json.loads(args.input.read_text())
            approved = approve_all_proposals(report)
            report.setdefault("approvalHistory", []).append({
                "at": utc_timestamp(),
                "operation": "approve-all",
                "approvedCount": approved,
            })
            write_json(args.input, report)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            raise SystemExit(str(error)) from error
        print(f"Approved {approved} pending clue proposal(s).")
        return

    try:
        report = json.loads(args.input.read_text())
        client = service_rest_client()
        outcomes = apply_report(report, client, rollback=args.command == "rollback", dry_run=args.dry_run)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(str(error)) from error
    report.setdefault("applyHistory", []).append({
        "at": utc_timestamp(),
        "operation": args.command,
        "dryRun": args.dry_run,
        "outcomes": outcomes,
    })
    if not args.dry_run:
        write_json(args.input, report)
    summary: dict[str, int] = {}
    for outcome in outcomes:
        summary[outcome["outcome"]] = summary.get(outcome["outcome"], 0) + 1
    print(json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
