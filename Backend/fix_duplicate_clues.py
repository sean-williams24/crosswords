#!/usr/bin/env python3
"""
Fix duplicate clue strings in word_bank.json.

The script is intentionally local-only: it never calls an LLM or external API.
It reuses the deterministic answer-derivability scanner to reject replacement
clues that give away the answer through exact, morphological, or tense variants.

Usage:
    python3 fix_duplicate_clues.py scan
    python3 fix_duplicate_clues.py export --output duplicate_clue_batches.json
    python3 fix_duplicate_clues.py repair --dry-run
    python3 fix_duplicate_clues.py repair
    python3 fix_duplicate_clues.py apply replacements.json
    python3 fix_duplicate_clues.py validate
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from copy import deepcopy
from pathlib import Path
from typing import Any

from audit_answer_derivability import (
    DEFAULT_HIGH_THRESHOLD,
    DEFAULT_REVIEW_THRESHOLD,
    scan_field,
)


BANK_PATH = Path(__file__).parent / "word_bank.json"
EXPORT_PATH = Path(__file__).parent / "duplicate_clue_batches.json"
PROPOSALS_PATH = Path(__file__).parent / "duplicate_clue_replacements.json"
MIN_CONSTITUENT_LEN = 3


def load_entries(path: Path) -> list[dict[str, Any]]:
    with path.open() as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"Expected top-level JSON array in {path}")
    return data


def save_entries(path: Path, entries: list[dict[str, Any]]) -> None:
    path.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")


def field_values(entry: dict[str, Any]) -> list[tuple[str, str]]:
    values: list[tuple[str, str]] = []
    for name in ("text", "hint", "hard_text", "hardText"):
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


def replacement_fields(fields: list[str]) -> list[str]:
    clue_fields = [field for field in fields if field.startswith("clues[")]
    scalar_fields = [field for field in fields if not field.startswith("clues[")]
    if clue_fields:
        return clue_fields
    if "hint" in scalar_fields:
        return ["hint"]
    if "hard_text" in scalar_fields:
        return ["hard_text"]
    if "hardText" in scalar_fields:
        return ["hardText"]
    return scalar_fields[1:]


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
    return scan_field(answer, text, DEFAULT_REVIEW_THRESHOLD, DEFAULT_HIGH_THRESHOLD)


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


def normalize_sentence(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    return text.rstrip(" .")


def lower_first(text: str) -> str:
    return text[:1].lower() + text[1:] if text else text


def clueish_variants(seed: str, salt: int) -> list[str]:
    seed = normalize_sentence(seed)
    if not seed:
        return []
    lowered = lower_first(seed)
    capped = seed[:1].upper() + seed[1:]
    variants = [
        f"{capped}, perhaps",
        f"Maybe {lowered}",
        f"Often {lowered}",
        f"Think {lowered}",
        f"{capped}, sometimes",
        f"Seen as {lowered}",
        f"{capped}?",
        f"Associated with {lowered}",
        f"{capped}, for one",
        f"A sign of {lowered}",
        f"{capped}, loosely",
    ]
    if salt % 12 == 0:
        variants.insert(0, f"Could be {lowered}")
    return variants


def candidate_replacements(entry: dict[str, Any]) -> list[str]:
    candidates: list[str] = []

    salt = sum(ord(char) for char in str(entry.get("word", "")))

    for field_index, field in enumerate(("hint", "text", "hard_text", "hardText")):
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
    for candidate in candidate_replacements(entry):
        if candidate in blocked:
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


def apply_replacements(entries: list[dict[str, Any]], replacements: list[dict[str, Any]]) -> None:
    for item in replacements:
        index = item["index"]
        word = item["word"]
        if index >= len(entries):
            raise IndexError(f"Replacement index out of range: {index}")
        entry = entries[index]
        if entry.get("word") != word:
            raise ValueError(f"Word mismatch at index {index}: expected {word}, found {entry.get('word')}")
        for field, value in item.get("replacements", {}).items():
            if replacement_issue(str(word), value):
                raise ValueError(f"Unsafe replacement for {word} {field}: {value}")
            if value in existing_values(entry, replacing=field):
                raise ValueError(f"Duplicate replacement for {word} {field}: {value}")
            set_field(entry, field, value)


def validation_errors(entries: list[dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", ""))
        for value, fields in duplicate_groups(entry).items():
            errors.append(f"{index} {word}: duplicate {fields} -> {value!r}")
        for field, value in field_values(entry):
            issue = derivability_issue(word, value)
            if issue:
                reasons = ",".join(issue.get("reasons", ["UNKNOWN"]))
                errors.append(f"{index} {word}: {field} derivable ({reasons}) -> {value!r}")
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fix duplicate word-bank clue strings")
    parser.add_argument("command", choices=["scan", "export", "repair", "apply", "validate"])
    parser.add_argument("replacement_file", nargs="?", type=Path)
    parser.add_argument("--bank", type=Path, default=BANK_PATH)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    entries = load_entries(args.bank)

    if args.command == "scan":
        print_scan_report(scan_duplicates(entries))
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
        print("Validation passed: no duplicates, exact leakage, or derivability issues.")


if __name__ == "__main__":
    main()
