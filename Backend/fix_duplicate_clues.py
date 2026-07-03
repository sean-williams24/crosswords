#!/usr/bin/env python3
"""
Fix duplicate clue strings in word_bank.json.

Deterministic scan/repair modes are local-only. The repair-similar command can
call OpenAI for fresh clue ideas, then validates every replacement locally before
saving it.

Usage:
    python3 fix_duplicate_clues.py scan
    python3 fix_duplicate_clues.py scan-leaks
    python3 fix_duplicate_clues.py scan-similar
    python3 fix_duplicate_clues.py export --output duplicate_clue_batches.json
    python3 fix_duplicate_clues.py repair --dry-run
    python3 fix_duplicate_clues.py repair-leaks --dry-run
    python3 fix_duplicate_clues.py repair-similar --dry-run --limit 25
    python3 fix_duplicate_clues.py repair-leaks
    python3 fix_duplicate_clues.py repair-similar
    python3 fix_duplicate_clues.py repair
    python3 fix_duplicate_clues.py apply replacements.json
    python3 fix_duplicate_clues.py validate
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict
from copy import deepcopy
from pathlib import Path
from typing import Any

from answer_leakage import clue_ideas_are_redundant, normalize_clue_idea, scan_text


BANK_PATH = Path(__file__).parent / "word_bank.json"
EXPORT_PATH = Path(__file__).parent / "duplicate_clue_batches.json"
PROPOSALS_PATH = Path(__file__).parent / "duplicate_clue_replacements.json"
LEAK_PROPOSALS_PATH = Path(__file__).parent / "leaking_clue_replacements.json"
SIMILAR_PROPOSALS_PATH = Path(__file__).parent / "similar_clue_replacements.json"
MIN_CONSTITUENT_LEN = 3
REWRITE_PRIORITY = {
    "hard_text": 1,
    "hardText": 1,
    "clues": 2,
    "text": 3,
}
ACTIVE_SCALAR_FIELDS = ("text", "hard_text", "hardText")
DISCOURAGED_QUALIFIER_RE = re.compile(
    r"\b(?:perhaps|maybe|possibly|sometimes|loosely)\b",
    re.IGNORECASE,
)

_env_file = Path(__file__).parent / ".env"
if _env_file.exists():
    for _line in _env_file.read_text().splitlines():
        _line = _line.strip()
        if _line and not _line.startswith("#") and "=" in _line:
            _key, _, _val = _line.partition("=")
            os.environ.setdefault(_key.strip(), _val.strip())


def load_entries(path: Path) -> list[dict[str, Any]]:
    with path.open() as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"Expected top-level JSON array in {path}")
    return data


def save_entries(path: Path, entries: list[dict[str, Any]]) -> None:
    path.write_text(json.dumps(entries, indent=4, ensure_ascii=False) + "\n")


def field_values(entry: dict[str, Any]) -> list[tuple[str, str]]:
    values: list[tuple[str, str]] = []
    for name in ACTIVE_SCALAR_FIELDS:
        value = entry.get(name)
        if isinstance(value, str) and value.strip():
            values.append((name, value))
    for index, clue in enumerate(entry.get("clues") or []):
        if isinstance(clue, str) and clue.strip():
            values.append((f"clues[{index}]", clue))
    return values


def get_field(entry: dict[str, Any], field: str) -> str:
    match = re.fullmatch(r"clues\[(\d+)\]", field)
    if match:
        clues = entry.get("clues") or []
        index = int(match.group(1))
        return clues[index] if index < len(clues) else ""
    value = entry.get(field)
    return value if isinstance(value, str) else ""


def set_field(entry: dict[str, Any], field: str, value: str) -> None:
    match = re.fullmatch(r"clues\[(\d+)\]", field)
    if match:
        index = int(match.group(1))
        clues = entry.setdefault("clues", [])
        if index >= len(clues):
            raise IndexError(f"{field} does not exist for {entry.get('word')}")
        clues[index] = value
        return
    entry[field] = value


def duplicate_groups(entry: dict[str, Any]) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = defaultdict(list)
    for field, value in field_values(entry):
        grouped[value].append(field)
    return {value: fields for value, fields in grouped.items() if len(fields) > 1}


def field_family(field: str) -> str:
    return "clues" if field.startswith("clues[") else field


def replacement_fields(fields: list[str]) -> list[str]:
    clue_fields = [field for field in fields if field.startswith("clues[")]
    scalar_fields = [field for field in fields if not field.startswith("clues[")]
    if clue_fields:
        return clue_fields
    if "hard_text" in scalar_fields:
        return ["hard_text"]
    if "hardText" in scalar_fields:
        return ["hardText"]
    return scalar_fields[1:]


def redundant_replacement_fields(fields: list[str]) -> list[str]:
    sorted_fields = sorted(
        fields,
        key=lambda field: (REWRITE_PRIORITY.get(field_family(field), 9), fields.index(field)),
    )
    return sorted_fields[:-1]


def similar_groups(entry: dict[str, Any]) -> dict[str, list[tuple[str, str]]]:
    values = field_values(entry)
    if len(values) < 2:
        return {}

    parent = list(range(len(values)))

    def find(index: int) -> int:
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    def union(left: int, right: int) -> None:
        left_root = find(left)
        right_root = find(right)
        if left_root != right_root:
            parent[right_root] = left_root

    for left_index, (_, left_value) in enumerate(values):
        for right_index, (_, right_value) in enumerate(values):
            if right_index <= left_index:
                continue
            if clue_ideas_are_redundant(left_value, right_value):
                union(left_index, right_index)

    grouped_indexes: dict[int, list[int]] = defaultdict(list)
    for index in range(len(values)):
        grouped_indexes[find(index)].append(index)

    groups: dict[str, list[tuple[str, str]]] = {}
    for indexes in grouped_indexes.values():
        if len(indexes) < 2:
            continue
        group_values = [values[index] for index in indexes]
        key = normalize_clue_idea(group_values[0][1])
        suffix = 2
        unique_key = key
        while unique_key in groups:
            unique_key = f"{key} #{suffix}"
            suffix += 1
        groups[unique_key] = group_values
    return groups


def scan_duplicates(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    findings = []
    for index, entry in enumerate(entries):
        groups = duplicate_groups(entry)
        if not groups:
            continue
        fixes = []
        for value, fields in groups.items():
            fixes.append({
                "value": value,
                "fields": fields,
                "replace": replacement_fields(fields),
            })
        findings.append({
            "index": index,
            "word": entry.get("word", ""),
            "fixes": fixes,
            "entry": entry,
        })
    return findings


def scan_similar(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    findings = []
    for index, entry in enumerate(entries):
        groups = similar_groups(entry)
        if not groups:
            continue
        fixes = []
        for key, values in groups.items():
            fields = [field for field, _ in values]
            fixes.append({
                "normalized": key,
                "fields": fields,
                "values": [{"field": field, "value": value} for field, value in values],
                "replace": redundant_replacement_fields(fields),
            })
        findings.append({
            "index": index,
            "word": entry.get("word", ""),
            "fixes": fixes,
            "entry": entry,
        })
    return findings


def scan_leaks(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    findings = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", ""))
        issues: dict[str, dict[str, Any]] = {}
        for field, value in field_values(entry):
            issue = replacement_issue(word, value)
            if issue:
                issues[field] = {
                    "original": value,
                    "reasons": issue.get("reasons", ["UNKNOWN"]),
                }
        if issues:
            findings.append({
                "index": index,
                "word": word,
                "issues": issues,
                "entry": entry,
            })
    return findings


def check_terms(answer: str) -> list[str]:
    normalized = re.sub(r"[^A-Za-z0-9]+", " ", answer).strip()
    parts = normalized.split()
    if not parts:
        return []
    terms = [normalized]
    if len(parts) > 1:
        terms.extend(part for part in parts if len(part) >= MIN_CONSTITUENT_LEN)
    return terms


def contains_whole_word(text: str, word: str) -> bool:
    return bool(re.search(r"\b" + re.escape(word) + r"\b", text, re.IGNORECASE))


def leaks_exact_answer(answer: str, text: str) -> bool:
    return any(contains_whole_word(text, term) for term in check_terms(answer))


def leaks_answer_fragment(answer: str, text: str) -> bool:
    compact_text = re.sub(r"[^a-z0-9]+", "", text.lower())
    for term in check_terms(answer):
        compact_term = re.sub(r"[^a-z0-9]+", "", term.lower())
        if compact_term and compact_term in compact_text:
            return True
    return False


def derivability_issue(answer: str, text: str) -> dict[str, Any] | None:
    if leaks_exact_answer(answer, text):
        return {"reasons": ["EXACT_ANSWER"]}
    issues = scan_text(answer, text)
    if not issues:
        return None
    return {"reasons": sorted({issue.reason for issue in issues})}


def replacement_issue(answer: str, text: str) -> dict[str, Any] | None:
    if leaks_answer_fragment(answer, text):
        return {"reasons": ["ANSWER_FRAGMENT"]}
    return derivability_issue(answer, text)


def existing_values(entry: dict[str, Any], replacing: str | None = None) -> set[str]:
    return {
        value
        for field, value in field_values(entry)
        if field != replacing
    }


def existing_ideas(entry: dict[str, Any], replacing: str | None = None) -> set[str]:
    return {
        normalize_clue_idea(value)
        for field, value in field_values(entry)
        if field != replacing
    }


def repeats_existing_idea(entry: dict[str, Any], candidate: str, replacing: str | None = None) -> bool:
    return any(
        clue_ideas_are_redundant(candidate, value)
        for field, value in field_values(entry)
        if field != replacing
    )


def normalize_sentence(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    text = text.rstrip(" .")
    text = re.sub(r"^(Could be|Maybe|Often|Seen as|Associated with|A sign of)\s+", "", text, flags=re.IGNORECASE)
    text = re.sub(r",\s*(perhaps|sometimes|loosely|for one)$", "", text, flags=re.IGNORECASE)
    text = text.rstrip("?")
    return text.strip()


def lower_first(text: str) -> str:
    return text[:1].lower() + text[1:] if text else text


def clueish_variants(seed: str, salt: int) -> list[str]:
    seed = normalize_sentence(seed)
    if not seed:
        return []
    capped = seed[:1].upper() + seed[1:]
    variants = [capped]
    if salt % 12 == 0:
        variants.append(f"{capped}?")
    return variants


def candidate_replacements(entry: dict[str, Any]) -> list[str]:
    candidates: list[str] = []

    salt = sum(ord(char) for char in str(entry.get("word", "")))

    for field_index, field in enumerate(ACTIVE_SCALAR_FIELDS):
        value = get_field(entry, field)
        candidates.extend(clueish_variants(value, salt + field_index))

    for clue_index, clue in enumerate(entry.get("clues") or []):
        candidates.extend(clueish_variants(clue, salt + 10 + clue_index))

    word = str(entry.get("word", ""))
    length = len(word.replace(" ", ""))
    if length:
        candidates.extend([
            f"{length}-letter crossword entry",
            f"Answer with {length} letters",
            f"Entry of {length} letters",
        ])

    seen = set()
    unique = []
    for candidate in candidates:
        candidate = re.sub(r"\s+", " ", candidate).strip()
        candidate = candidate.rstrip(".")
        if not candidate or candidate in seen:
            continue
        seen.add(candidate)
        unique.append(candidate)
    return unique


def first_valid_replacement(entry: dict[str, Any], field: str) -> str:
    answer = str(entry.get("word", ""))
    blocked = existing_values(entry, replacing=field)
    blocked_ideas = existing_ideas(entry, replacing=field)
    for candidate in candidate_replacements(entry):
        if candidate in blocked:
            continue
        if normalize_clue_idea(candidate) in blocked_ideas:
            continue
        if repeats_existing_idea(entry, candidate, replacing=field):
            continue
        if replacement_issue(answer, candidate):
            continue
        return candidate
    raise ValueError(f"No safe replacement found for {answer} {field}")


def build_replacements(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    proposals = []
    for finding in scan_duplicates(entries):
        entry = deepcopy(finding["entry"])
        replacements: dict[str, str] = {}
        for fix in finding["fixes"]:
            for field in fix["replace"]:
                replacement = first_valid_replacement(entry, field)
                set_field(entry, field, replacement)
                replacements[field] = replacement
        proposals.append({
            "index": finding["index"],
            "word": finding["word"],
            "replacements": replacements,
        })
    return proposals


def build_leak_replacements(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    proposals = []
    for finding in scan_leaks(entries):
        entry = deepcopy(finding["entry"])
        replacements: dict[str, str] = {}
        for field in finding["issues"]:
            replacement = first_valid_replacement(entry, field)
            set_field(entry, field, replacement)
            replacements[field] = replacement
        proposals.append({
            "index": finding["index"],
            "word": finding["word"],
            "issues": finding["issues"],
            "replacements": replacements,
        })
    return proposals


SIMILAR_FIX_SYSTEM_PROMPT = """You are an expert crossword clue editor.

Rewrite only the requested word-bank fields so each field in an entry gives a genuinely different clue idea.

Rules:
- Never include the answer word, answer fragments, or obvious roots/inflections.
- Do not reuse another field's clue with small wrappers like "maybe", "perhaps", "often", "seen as", or punctuation changes.
- Do not write a thesaurus-level rewrite of another field.
- Do not share two or more meaning-bearing words with any existing field in the same entry.
- The replacement must be fair, concise, and crossword-like.
- text should be a clear direct clue under 10 words.
- hard_text should be trickier than text.
- clues[] items should be varied and usable as main crossword clues.
- Preserve the requested field names exactly, including clues[index] keys.

Return JSON only: {"replacements":[{"index":0,"word":"WORD","fields":{"hard_text":"fresh clue"}}]}"""


def _call_openai_for_similar(records: list[dict[str, Any]], model: str, feedback: list[str] | None = None) -> list[dict[str, Any]]:
    import openai
    client = openai.OpenAI(timeout=45, max_retries=1)
    payload = []
    for finding in records:
        entry = finding["entry"]
        replace_fields = _fields_to_rewrite(finding)
        payload.append({
            "index": finding["index"],
            "word": finding["word"],
            "fieldsToRewrite": replace_fields,
            "requiredFieldsObject": {field: "REPLACE_WITH_FRESH_CLUE" for field in replace_fields},
            "current": {
                "text": entry.get("text"),
                "hint": entry.get("hint"),
                "hard_text": entry.get("hard_text"),
                "hardText": entry.get("hardText"),
                "clues": entry.get("clues"),
            },
            "similarGroups": [
                {
                    "normalized": fix["normalized"],
                    "values": fix["values"],
                    "replace": fix["replace"],
                }
                for fix in finding["fixes"]
            ],
        })
    response_skeleton = [
        {
            "index": item["index"],
            "word": item["word"],
            "fields": item["requiredFieldsObject"],
        }
        for item in payload
    ]
    user_prompt = (
        "Rewrite the requested fields for these entries. "
        "Every rewritten field must be a fresh clue idea distinct from every other field in the same entry. "
        "The hint field is dormant fallback metadata; do not rewrite it unless explicitly requested in the skeleton.\n\n"
        "You must return every key shown in this exact response skeleton. "
        "Do not rename clues[index] keys to clues.\n"
        + json.dumps({"replacements": response_skeleton}, indent=2, ensure_ascii=False)
        + "\n\nEntries:\n"
        + json.dumps(payload, indent=2, ensure_ascii=False)
    )
    if feedback:
        user_prompt += "\n\nPrevious attempt failed local validation. Fix these problems:\n"
        user_prompt += "\n".join(f"- {item}" for item in feedback)
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": SIMILAR_FIX_SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.8,
        response_format={"type": "json_object"},
    )
    content = response.choices[0].message.content or ""
    result = json.loads(content.strip())
    replacements = result.get("replacements", result)
    if not isinstance(replacements, list):
        raise ValueError("Expected replacements list from OpenAI response")
    return replacements


def validate_entry(entry: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    word = str(entry.get("word", ""))
    for value, fields in duplicate_groups(entry).items():
        errors.append(f"duplicate {fields} -> {value!r}")
    for key, values in similar_groups(entry).items():
        fields = [field for field, _ in values]
        errors.append(f"similar {fields} -> {key!r}")
    for field, value in field_values(entry):
        if DISCOURAGED_QUALIFIER_RE.search(value):
            errors.append(f"{field} uses discouraged qualifier -> {value!r}")
        issue = replacement_issue(word, value)
        if issue:
            reasons = ",".join(issue.get("reasons", ["UNKNOWN"]))
            errors.append(f"{field} derivable ({reasons}) -> {value!r}")
    return errors


def repair_similar_with_openai(
    entries: list[dict[str, Any]],
    findings: list[dict[str, Any]],
    model: str,
    batch_size: int,
    dry_run: bool,
    output: Path,
    bank_path: Path,
) -> None:
    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit("Set OPENAI_API_KEY or add it to Backend/.env")

    all_replacements: list[dict[str, Any]] = []
    total = len(findings)
    for start in range(0, total, batch_size):
        batch = findings[start:start + batch_size]
        print(f"Batch {start // batch_size + 1}/{(total + batch_size - 1) // batch_size}: {len(batch)} entries")
        accepted_batch = _generate_valid_similar_replacements(entries, batch, model)
        if accepted_batch is None and len(batch) > 1:
            print("  Splitting failed batch into individual entries")
            accepted_batch = []
            for finding in batch:
                accepted_item = _generate_valid_similar_replacements(entries, [finding], model, max_attempts=5)
                if accepted_item is None:
                    raise ValueError(f"Unable to generate valid replacements for {finding['index']} {finding['word']}")
                accepted_batch.extend(accepted_item)
        if accepted_batch is None:
            raise ValueError(f"Unable to generate valid replacements for batch starting at finding {start}")

        for item in accepted_batch:
            if not dry_run:
                entries[item["index"]] = item["entry"]
            all_replacements.append({
                "index": item["index"],
                "word": item["word"],
                "replacements": item["replacements"],
            })

        output.write_text(json.dumps(all_replacements, indent=2, ensure_ascii=False) + "\n")
        if not dry_run:
            save_entries(bank_path, entries)

    print(f"{'Dry run: ' if dry_run else ''}Built {len(all_replacements)} similar-clue replacement records.")
    print(f"Replacement report written to {output}")


def _validate_similar_replacements(
    entries: list[dict[str, Any]],
    batch: list[dict[str, Any]],
    replacements: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    accepted: list[dict[str, Any]] = []
    indexed_batch = {finding["index"]: finding for finding in batch}
    required_indexes = set(indexed_batch)
    seen_indexes: set[int] = set()

    for item in replacements:
        if not isinstance(item, dict):
            raise ValueError(f"Replacement item must be an object, got {type(item).__name__}")
        if "index" not in item:
            raise ValueError(f"Replacement item missing index: {item}")
        if "word" not in item:
            raise ValueError(f"Replacement item missing word: {item}")
        index = int(item["index"])
        word = item["word"]
        fields = item.get("fields", {})
        required_fields = _fields_to_rewrite(indexed_batch.get(index, {}))
        if index not in indexed_batch:
            raise ValueError(f"Unexpected replacement index: {index}")
        if index in seen_indexes:
            raise ValueError(f"Duplicate replacement index: {index}")
        seen_indexes.add(index)
        if entries[index].get("word") != word:
            raise ValueError(f"Word mismatch at index {index}: expected {entries[index].get('word')}, got {word}")
        if not isinstance(fields, dict):
            raise ValueError(f"Replacement fields for {word} must be an object")

        returned_fields = set(fields)
        required_field_set = set(required_fields)
        missing_fields = required_field_set - returned_fields
        if missing_fields:
            raise ValueError(f"Missing fields for {word}: {sorted(missing_fields)}")
        unexpected_fields = returned_fields - required_field_set
        if unexpected_fields:
            raise ValueError(f"Unexpected fields for {word}: {sorted(unexpected_fields)}")

        trial = deepcopy(entries[index])
        for field, value in fields.items():
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"Empty replacement for {word} {field}")
            set_field(trial, field, value.strip().rstrip("."))

        entry_errors = validate_entry(trial)
        if entry_errors:
            raise ValueError(f"Invalid replacement for {word}: {entry_errors[:5]}")
        accepted.append({
            "index": index,
            "word": word,
            "replacements": fields,
            "entry": trial,
        })

    missing = required_indexes - seen_indexes
    if missing:
        raise ValueError(f"Missing replacement indexes: {sorted(missing)[:10]}")
    return accepted


def _fields_to_rewrite(finding: dict[str, Any]) -> list[str]:
    fields: list[str] = []
    for fix in finding.get("fixes", []):
        fields.extend(fix["replace"])
    return sorted(set(fields), key=fields.index)


def _generate_valid_similar_replacements(
    entries: list[dict[str, Any]],
    batch: list[dict[str, Any]],
    model: str,
    max_attempts: int = 3,
) -> list[dict[str, Any]] | None:
    feedback: list[str] = []
    for attempt in range(1, max_attempts + 1):
        replacements = _call_openai_for_similar(batch, model, feedback=feedback)
        try:
            return _validate_similar_replacements(entries, batch, replacements)
        except ValueError as exc:
            feedback = [str(exc)]
            print(f"  Attempt {attempt}/{max_attempts} failed validation: {exc}")
    return None


def apply_replacements(entries: list[dict[str, Any]], replacements: list[dict[str, Any]]) -> None:
    for item in replacements:
        index = item["index"]
        word = item["word"]
        if index >= len(entries):
            raise IndexError(f"Replacement index out of range: {index}")
        entry = entries[index]
        if entry.get("word") != word:
            raise ValueError(f"Word mismatch at index {index}: expected {word}, found {entry.get('word')}")
        trial = deepcopy(entry)
        for field, value in item.get("replacements", {}).items():
            if replacement_issue(str(word), value):
                raise ValueError(f"Unsafe replacement for {word} {field}: {value}")
            if value in existing_values(entry, replacing=field):
                raise ValueError(f"Duplicate replacement for {word} {field}: {value}")
            if normalize_clue_idea(value) in existing_ideas(entry, replacing=field):
                raise ValueError(f"Similar replacement for {word} {field}: {value}")
            if repeats_existing_idea(entry, value, replacing=field):
                raise ValueError(f"Similar replacement for {word} {field}: {value}")
            set_field(trial, field, value)
        entry_errors = validate_entry(trial)
        if entry_errors:
            raise ValueError(f"Replacement leaves invalid entry for {word}: {entry_errors[:5]}")
        entries[index] = trial


def validation_errors(entries: list[dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", ""))
        for error in validate_entry(entry):
            errors.append(f"{index} {word}: {error}")
    return errors


def print_scan_report(findings: list[dict[str, Any]]) -> None:
    field_counts = Counter()
    pair_counts = Counter()
    for finding in findings:
        for fix in finding["fixes"]:
            fields = fix["fields"]
            for field in fields:
                field_counts[field.split("[")[0]] += 1
            for left_index, left in enumerate(fields):
                for right in fields[left_index + 1:]:
                    pair_counts[tuple(sorted((left.split("[")[0], right.split("[")[0])))] += 1
    print(f"Flagged entries: {len(findings)}")
    print(f"Duplicate string groups: {sum(len(f['fixes']) for f in findings)}")
    print(f"Field occurrences: {dict(field_counts)}")
    print(f"Pair counts: {dict(pair_counts)}")
    for finding in findings[:10]:
        print(f"  {finding['index']} {finding['word']}: {finding['fixes']}")


def print_leak_report(findings: list[dict[str, Any]]) -> None:
    field_counts = Counter()
    reason_counts = Counter()
    for finding in findings:
        for field, issue in finding["issues"].items():
            field_counts[field.split("[")[0]] += 1
            for reason in issue["reasons"]:
                reason_counts[reason] += 1
    print(f"Flagged entries: {len(findings)}")
    print(f"Leaking fields: {sum(len(f['issues']) for f in findings)}")
    print(f"Field occurrences: {dict(field_counts)}")
    print(f"Reason counts: {dict(reason_counts)}")
    for finding in findings[:10]:
        print(f"  {finding['index']} {finding['word']}: {finding['issues']}")


def print_similar_report(findings: list[dict[str, Any]]) -> None:
    field_counts = Counter()
    pair_counts = Counter()
    for finding in findings:
        for fix in finding["fixes"]:
            fields = fix["fields"]
            for field in fields:
                field_counts[field_family(field)] += 1
            for left_index, left in enumerate(fields):
                for right in fields[left_index + 1:]:
                    pair_counts[tuple(sorted((field_family(left), field_family(right))))] += 1
    print(f"Flagged entries: {len(findings)}")
    print(f"Similar clue groups: {sum(len(f['fixes']) for f in findings)}")
    print(f"Field occurrences: {dict(field_counts)}")
    print(f"Pair counts: {dict(pair_counts)}")
    for finding in findings[:10]:
        print(f"  {finding['index']} {finding['word']}: {finding['fixes']}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fix duplicate word-bank clue strings")
    parser.add_argument("command", choices=[
        "scan",
        "scan-leaks",
        "scan-similar",
        "export",
        "repair",
        "repair-leaks",
        "repair-similar",
        "apply",
        "validate",
    ])
    parser.add_argument("replacement_file", nargs="?", type=Path)
    parser.add_argument("--bank", type=Path, default=BANK_PATH)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--model", default="gpt-4o-mini")
    parser.add_argument("--batch-size", type=int, default=25)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--start-index", type=int, default=0)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    entries = load_entries(args.bank)

    if args.command == "scan":
        print_scan_report(scan_duplicates(entries))
        return

    if args.command == "scan-leaks":
        print_leak_report(scan_leaks(entries))
        return

    if args.command == "scan-similar":
        print_similar_report(scan_similar(entries))
        return

    if args.command == "export":
        output = args.output or EXPORT_PATH
        findings = scan_duplicates(entries)
        output.write_text(json.dumps(findings, indent=2, ensure_ascii=False) + "\n")
        print(f"Exported {len(findings)} flagged entries to {output}")
        return

    if args.command == "repair":
        output = args.output or PROPOSALS_PATH
        replacements = build_replacements(entries)
        output.write_text(json.dumps(replacements, indent=2, ensure_ascii=False) + "\n")
        apply_replacements(entries, replacements)
        errors = validation_errors(entries)
        if errors:
            print(f"Validation failed after repair ({len(errors)} errors):", file=sys.stderr)
            for error in errors[:50]:
                print(f"  {error}", file=sys.stderr)
            raise SystemExit(1)
        if args.dry_run:
            print(f"Dry run: built {len(replacements)} replacement records; no bank changes written.")
            print(f"Replacement report written to {output}")
            return
        save_entries(args.bank, entries)
        print(f"Applied {len(replacements)} replacement records to {args.bank}")
        print(f"Replacement report written to {output}")
        return

    if args.command == "repair-leaks":
        output = args.output or LEAK_PROPOSALS_PATH
        replacements = build_leak_replacements(entries)
        output.write_text(json.dumps(replacements, indent=2, ensure_ascii=False) + "\n")
        apply_replacements(entries, replacements)
        errors = validation_errors(entries)
        if errors:
            print(f"Validation failed after leak repair ({len(errors)} errors):", file=sys.stderr)
            for error in errors[:50]:
                print(f"  {error}", file=sys.stderr)
            raise SystemExit(1)
        if args.dry_run:
            print(f"Dry run: built {len(replacements)} leak replacement records; no bank changes written.")
            print(f"Leak replacement report written to {output}")
            return
        save_entries(args.bank, entries)
        print(f"Applied {len(replacements)} leak replacement records to {args.bank}")
        print(f"Leak replacement report written to {output}")
        return

    if args.command == "repair-similar":
        output = args.output or SIMILAR_PROPOSALS_PATH
        findings = [finding for finding in scan_similar(entries) if finding["index"] >= args.start_index]
        if args.limit is not None:
            findings = findings[:args.limit]
        repair_similar_with_openai(entries, findings, args.model, args.batch_size, args.dry_run, output, args.bank)
        if not args.dry_run and args.limit is None and args.start_index == 0:
            errors = validation_errors(entries)
            if errors:
                print(f"Validation failed after similar repair ({len(errors)} errors):", file=sys.stderr)
                for error in errors[:50]:
                    print(f"  {error}", file=sys.stderr)
                raise SystemExit(1)
        elif not args.dry_run:
            print("Partial repair complete; run validate after all similar findings are fixed.")
        return

    if args.command == "apply":
        if not args.replacement_file:
            raise SystemExit("apply requires a replacement JSON file")
        replacements = load_entries(args.replacement_file)
        apply_replacements(entries, replacements)
        errors = validation_errors(entries)
        if errors:
            print(f"Validation failed after apply ({len(errors)} errors):", file=sys.stderr)
            for error in errors[:50]:
                print(f"  {error}", file=sys.stderr)
            raise SystemExit(1)
        if args.dry_run:
            print(f"Dry run: {len(replacements)} replacement records validated; no bank changes written.")
            return
        save_entries(args.bank, entries)
        print(f"Applied {len(replacements)} replacement records to {args.bank}")
        return

    if args.command == "validate":
        errors = validation_errors(entries)
        if errors:
            print(f"Validation failed ({len(errors)} errors):", file=sys.stderr)
            for error in errors[:100]:
                print(f"  {error}", file=sys.stderr)
            raise SystemExit(1)
        print("Validation passed: no duplicates, similar clues, exact leakage, or derivability issues.")


if __name__ == "__main__":
    main()
