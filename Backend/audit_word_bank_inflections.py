#!/usr/bin/env python3
"""
Audit and repair word-bank clue inflection mismatches.

Review-first workflow:
  python3 Backend/audit_word_bank_inflections.py sample --count 50
  python3 Backend/audit_word_bank_inflections.py export
  python3 Backend/audit_word_bank_inflections.py apply --input Backend/word_bank_inflection_replacements.json
  python3 Backend/audit_word_bank_inflections.py validate

The sample/export commands never modify word_bank.json. The apply command only
uses a reviewed replacement file and validates word/index/current-value matches.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from audit_answer_derivability import (
    DEFAULT_HIGH_THRESHOLD,
    DEFAULT_REVIEW_THRESHOLD,
    scan_field,
)
from inflection_safety import (
    field_label,
    field_values,
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
    path.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")


def scan_entries(entries: list[dict[str, Any]], limit: int | None = None) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    for index, entry in enumerate(entries):
        word = str(entry.get("word", "")).strip()
        if not word:
            continue

        fields = []
        for field in field_values(entry):
            issues = scan_clue(word, field["value"])
            if not issues:
                continue
            label = field_label(field["field"], field["clueIndex"])
            fields.append({
                "field": label,
                "current": field["value"],
                "reasons": [issue.reason for issue in issues],
                "details": [issue.detail for issue in issues],
                "proposed": proposed_replacement(word, field["value"], issues[0].proposed),
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
        for field in field_values(entry):
            label = field_label(field["field"], field["clueIndex"])
            for issue in wide_issues(word, field["value"]):
                fields.append({
                    "field": label,
                    "current": field["value"],
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
    parser.add_argument("command", choices=["sample", "wide", "export", "apply", "validate"])
    parser.add_argument("--bank", type=Path, default=BANK_PATH)
    parser.add_argument("--count", type=int, help="Limit output count. sample defaults to 50; wide defaults to all candidates.")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--input", type=Path, dest="input_path")
    parser.add_argument("--high-only", action="store_true", help="For wide scans, include only high-confidence candidates.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    entries = load_entries(args.bank)

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
