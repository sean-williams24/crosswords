#!/usr/bin/env python3
"""
Fix Answer Leakage & Redundant Hints in Word Bank
===================================================

Scans word_bank.json for two issues:
  1. LEAKAGE       — The answer, a fragment, or a derived form appears in a clue field
                     (text, hard_text, or any item in clues[]). The dormant
                     hint fallback is intentionally ignored by this scanner.

For multi-word answers (e.g., "ICE CREAM") each constituent word ≥3 chars
is also checked individually. Clear derived forms are checked too, e.g.
TENTH → ten and BAGGED → bag.

Usage:
    python fix_answer_leakage.py              # Scan only — writes leaky_entries.json
    python fix_answer_leakage.py --fix        # Scan then fix with OpenAI
    python fix_answer_leakage.py --fix --resume  # Resume interrupted fix run
    python fix_answer_leakage.py --fix --dry-run # Preview fixes without saving
    python fix_answer_leakage.py --fix --limit 50  # Fix first 50 entries only

Output files:
    leaky_entries.json  — Scan results (overwritten on fresh scan)
    fix_progress.json   — Checkpoint for resuming interrupted runs

Environment Variables:
    OPENAI_API_KEY — Required for --fix mode
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

from answer_leakage import check_terms, leaks_answer, scan_text

# ── Paths ──────────────────────────────────────────────────────────────────

BANK_PATH = Path(__file__).parent / "word_bank.json"
LEAKY_PATH = Path(__file__).parent / "leaky_entries.json"
PROGRESS_PATH = Path(__file__).parent / "fix_progress.json"

# Load .env if present (so you don't need to export keys manually)
_env_file = Path(__file__).parent / ".env"
if _env_file.exists():
    for _line in _env_file.read_text().splitlines():
        _line = _line.strip()
        if _line and not _line.startswith("#") and "=" in _line:
            _key, _, _val = _line.partition("=")
            os.environ[_key.strip()] = _val.strip()

# ── Constants ─────────────────────────────────────────────────────────────

CHECKPOINT_EVERY = 50    # Save word_bank.json + fix_progress.json every N fixed entries
MAX_RETRIES = 3          # LLM retry attempts if leakage persists in regenerated fields
# ── Leakage detection helpers ─────────────────────────────────────────────


def _check_words(word: str) -> list[str]:
    """
    Return the words to search for when checking a given answer word.

    For single words (LESLIE) returns ["LESLIE"].
    For multi-word answers (ICE CREAM) returns ["ICE CREAM", "ICE", "CREAM"],
    skipping any constituent that is shorter than the shared leakage threshold.
    """
    return check_terms(word)


def _field_leaks(text: str, check_words: list[str]) -> bool:
    """True if the field leaks the answer or a derived giveaway form."""
    if not text:
        return False
    answer = check_words[0] if check_words else ""
    return leaks_answer(answer, text)


def _field_issue_reasons(answer: str, text: str) -> list[str]:
    return sorted({issue.reason for issue in scan_text(answer, text)})


# ── Scan ──────────────────────────────────────────────────────────────────


def scan_entry(entry: dict) -> dict | None:
    """
    Scan one word bank entry for issues.
    Returns a record dict if issues found, None if clean.
    """
    word = entry.get("word", "").strip()
    if not word:
        return None

    issues: dict = {}

    # text field
    text_reasons = _field_issue_reasons(word, entry.get("text", ""))
    if text_reasons:
        issues["text"] = text_reasons

    # hard_text field
    hard_text_reasons = _field_issue_reasons(word, entry.get("hard_text", ""))
    if hard_text_reasons:
        issues["hard_text"] = hard_text_reasons

    # clues array — record index of each offending clue
    clue_issues: dict = {}
    for i, clue in enumerate(entry.get("clues") or []):
        clue_reasons = _field_issue_reasons(word, clue)
        if clue_reasons:
            clue_issues[i] = clue_reasons
    if clue_issues:
        issues["clues"] = clue_issues

    if not issues:
        return None

    return {
        "word": word,
        "issues": issues,
        "entry": entry,
    }


def scan_all(words: list[dict]) -> list[dict]:
    """Scan every entry; return list of issue records (with 'index' added)."""
    results = []
    for idx, entry in enumerate(words):
        record = scan_entry(entry)
        if record:
            record["index"] = idx
            results.append(record)
    return results


def print_scan_report(results: list[dict]) -> None:
    if not results:
        print("\n✓ No issues found — word bank is clean!")
        return

    leakage_total = 0
    field_counts: dict[str, int] = {"text": 0, "hard_text": 0, "clues": 0}

    for r in results:
        for field, issue_list in r["issues"].items():
            if field == "clues":
                n = len(issue_list)   # issue_list is {index: [...]} here
                field_counts["clues"] += n
                leakage_total += n
            else:
                leakage_total += 1
                field_counts[field] += 1

    print(f"\n{'='*60}")
    print("SCAN RESULTS")
    print(f"{'='*60}")
    print(f"  Entries with issues:   {len(results)}")
    print(f"  Leakage issues:        {leakage_total}")
    print(f"\n  Breakdown by field:")
    for field, count in field_counts.items():
        if count:
            print(f"    {field}: {count}")
    print(f"\n  First 10 examples:")
    for r in results[:10]:
        word = r["word"]
        for field, ilist in r["issues"].items():
            if field == "clues":
                for ci, cl in ilist.items():
                    clue_text = (r["entry"].get("clues") or [])[ci] if ci < len(r["entry"].get("clues") or []) else "?"
                    print(f"    {word} | clues[{ci}] {','.join(cl)} → \"{clue_text}\"")
            else:
                print(f"    {word} | {field} {','.join(ilist)} → \"{r['entry'].get(field, '')}\"")
    if len(results) > 10:
        print(f"    … and {len(results) - 10} more")
    print(f"\n  Full results written to: {LEAKY_PATH}")


# ── Fix with OpenAI ────────────────────────────────────────────────────────

FIX_SYSTEM_PROMPT = """\
You are an expert crossword puzzle clue writer. Fix the word bank entry described below.

Issue types you may be asked to address:
  LEAKAGE        — The answer, a fragment, or a derived form appears in the clue.
Rules for every field you write:
  - NEVER include the answer word, any constituent word, or obvious derived forms
  - "text": clear, direct definition clue (under 10 words)
  - "hard_text": trickier clue using wordplay, double meanings, or misdirection
  - "clues": exactly 3 varied clues using different techniques each
    (double meaning, misdirection, cultural reference, etc.)
  - Make clues feel like they belong in a quality newspaper crossword\
"""


def _build_fix_prompt(record: dict) -> str:
    entry = record["entry"]
    word = record["word"]
    issues = record["issues"]
    check_words = _check_words(word)

    lines = [
        f"Word: {word}",
        "",
        "Current entry:",
        json.dumps({
            "word": entry.get("word"),
            "text": entry.get("text"),
            "hint": entry.get("hint"),
            "hard_text": entry.get("hard_text"),
            "clues": entry.get("clues"),
        }, indent=2),
        "",
        "Issues found:",
    ]

    fields_to_regenerate: list[str] = []

    if "text" in issues:
        lines.append(f'  - text: {",".join(issues["text"])} — "{entry.get("text", "")}" gives away the answer')
        fields_to_regenerate.append("text")

    if "hard_text" in issues:
        lines.append(f'  - hard_text: {",".join(issues["hard_text"])} — "{entry.get("hard_text", "")}" gives away the answer')
        fields_to_regenerate.append("hard_text")

    if "clues" in issues:
        clue_list = entry.get("clues") or []
        for ci, ilist in issues["clues"].items():
            clue_text = clue_list[ci] if ci < len(clue_list) else "?"
            lines.append(f'  - clues[{ci}]: {",".join(ilist)} — "{clue_text}" gives away the answer')
        # Always regenerate all 3 clues if any one has an issue
        fields_to_regenerate.append("clues")

    example_response = {}
    for f in fields_to_regenerate:
        if f == "clues":
            example_response[f] = ["clue 1", "clue 2", "clue 3"]
        else:
            example_response[f] = "…"

    lines += [
        "",
        "Regenerate ONLY the flagged fields. Return a JSON object with ONLY those keys:",
        json.dumps(example_response, indent=2),
        "",
        f"IMPORTANT: Do NOT include the word '{word}' or obvious roots/inflections in any regenerated field.",
    ]

    if " " in word:
        parts = check_terms(word)[1:]
        if parts:
            lines.append(f"Also do NOT include any of its constituent words: {', '.join(parts)}")

    return "\n".join(lines)


def _call_openai(system: str, user: str, model: str) -> dict:
    """Call OpenAI chat completion and return parsed JSON dict."""
    import openai
    client = openai.OpenAI()
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.7,
        response_format={"type": "json_object"},
    )
    content = response.choices[0].message.content or ""
    if "```json" in content:
        content = content.split("```json")[1].split("```")[0]
    elif "```" in content:
        content = content.split("```")[1].split("```")[0]
    return json.loads(content.strip())


def _validate_fix(fix_data: dict, check_words: list[str]) -> list[str]:
    """
    Return a list of fields in fix_data that still contain leakage.
    Empty list = all clean.
    """
    still_leaking = []
    for field, value in fix_data.items():
        if field == "clues":
            for clue in (value or []):
                answer = check_words[0] if check_words else ""
                if leaks_answer(answer, str(clue)):
                    still_leaking.append(field)
                    break
        else:
            answer = check_words[0] if check_words else ""
            if leaks_answer(answer, str(value or "")):
                still_leaking.append(field)
    return still_leaking


def _apply_fix(entry: dict, fix_data: dict) -> dict:
    """Return a new entry dict with fix_data fields applied."""
    updated = dict(entry)
    for field, value in fix_data.items():
        if field in ("text", "hint", "hard_text", "clues"):
            updated[field] = value
    return updated


# ── Progress checkpointing ────────────────────────────────────────────────


def _load_progress() -> dict:
    if PROGRESS_PATH.exists():
        with open(PROGRESS_PATH) as f:
            return json.load(f)
    return {"fixed_indices": [], "skipped_indices": [], "timestamp": None}


def _save_progress(progress: dict) -> None:
    progress["timestamp"] = datetime.now().isoformat()
    with open(PROGRESS_PATH, "w") as f:
        json.dump(progress, f, indent=2)


# ── Fix orchestration ─────────────────────────────────────────────────────


def fix_all(
    leaky_records: list[dict],
    words: list[dict],
    model: str,
    dry_run: bool,
) -> None:
    progress = _load_progress()
    already_done = set(progress["fixed_indices"]) | set(progress["skipped_indices"])

    to_fix = [r for r in leaky_records if r["index"] not in already_done]
    total = len(leaky_records)

    print(f"\n{'='*60}")
    print("FIX MODE")
    print(f"{'='*60}")
    print(f"  Total entries flagged: {total}")
    print(f"  Already handled:       {len(already_done)}")
    print(f"  Remaining this run:    {len(to_fix)}")
    if dry_run:
        print("  DRY RUN — no files will be modified")
    print()

    fixed_count = 0
    skipped_count = 0
    since_last_checkpoint = 0

    for record in to_fix:
        idx = record["index"]
        word = record["word"]
        check_words = _check_words(word)
        done_so_far = len(progress["fixed_indices"]) + len(progress["skipped_indices"])
        print(f"  [{done_so_far + 1}/{total}] {word}  →  issues: {list(record['issues'].keys())}")

        user_prompt = _build_fix_prompt(record)
        success = False

        for attempt in range(1, MAX_RETRIES + 1):
            try:
                fix_data = _call_openai(FIX_SYSTEM_PROMPT, user_prompt, model)
            except Exception as exc:
                print(f"    ✗ LLM error (attempt {attempt}/{MAX_RETRIES}): {exc}")
                if attempt < MAX_RETRIES:
                    time.sleep(2)
                continue

            still_leaking = _validate_fix(fix_data, check_words)
            if still_leaking:
                print(f"    ⚠  Leakage remains in {still_leaking} (attempt {attempt}/{MAX_RETRIES}), retrying…")
                if attempt < MAX_RETRIES:
                    time.sleep(1)
                continue

            # Clean — accept the fix
            success = True
            if dry_run:
                print(f"    [dry-run] Would apply:")
                for f, v in fix_data.items():
                    print(f"      {f}: {json.dumps(v)}")
            else:
                words[idx] = _apply_fix(words[idx], fix_data)
            break

        if success:
            fixed_count += 1
            since_last_checkpoint += 1
            progress["fixed_indices"].append(idx)
            if not dry_run:
                print("    ✓ Fixed")
        else:
            skipped_count += 1
            progress["skipped_indices"].append(idx)
            print(f"    ✗ Skipped (still leaking after {MAX_RETRIES} attempts)")

        # Checkpoint
        if not dry_run and since_last_checkpoint >= CHECKPOINT_EVERY:
            total_fixed = len(progress["fixed_indices"])
            print(f"\n  💾 Checkpoint — saving ({total_fixed} entries fixed so far)…")
            with open(BANK_PATH, "w") as f:
                json.dump(words, f, indent=2, ensure_ascii=False)
            _save_progress(progress)
            since_last_checkpoint = 0
            print()

        time.sleep(0.5)  # gentle rate-limit pause

    # Final save
    if not dry_run:
        print(f"\n  💾 Final save to {BANK_PATH}…")
        with open(BANK_PATH, "w") as f:
            json.dump(words, f, indent=2, ensure_ascii=False)
        _save_progress(progress)

    print(f"\n{'='*60}")
    print(f"Done  —  {fixed_count} fixed, {skipped_count} skipped")
    print(f"{'='*60}")


# ── Entry point ────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Scan and fix answer leakage / redundant hints in word_bank.json"
    )
    parser.add_argument(
        "--fix", action="store_true",
        help="Fix issues using OpenAI (default: scan only)"
    )
    parser.add_argument(
        "--model", default="gpt-4o-mini",
        help="OpenAI model to use (default: gpt-4o-mini)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would change without modifying any files"
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="Skip already-fixed entries from a previous --fix run"
    )
    parser.add_argument(
        "--limit", type=int, default=None,
        help="Max entries to fix in this run (useful for testing)"
    )
    args = parser.parse_args()

    if args.fix and not args.dry_run and not os.environ.get("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY not set (required for --fix mode)")
        sys.exit(1)

    # Load word bank
    print(f"Loading {BANK_PATH}…")
    with open(BANK_PATH) as f:
        words = json.load(f)
    print(f"  {len(words)} entries loaded")

    # ── Scan ──────────────────────────────────────────────────────────────

    if args.fix and args.resume and LEAKY_PATH.exists():
        print(f"\nResuming — loading existing scan from {LEAKY_PATH}…")
        with open(LEAKY_PATH) as f:
            leaky_records = json.load(f)
        print(f"  {len(leaky_records)} entries with issues")
    else:
        print(f"\nScanning {len(words)} entries…")
        leaky_records = scan_all(words)
        print_scan_report(leaky_records)

        if not args.dry_run:
            with open(LEAKY_PATH, "w") as f:
                json.dump(leaky_records, f, indent=2, ensure_ascii=False)

        if not leaky_records:
            return

    if not args.fix:
        print("\nRun with --fix to regenerate affected fields using OpenAI.")
        return

    # ── Fix ───────────────────────────────────────────────────────────────

    records_to_fix = leaky_records
    if args.limit:
        records_to_fix = records_to_fix[: args.limit]
        print(f"\nLimited to first {args.limit} entries")

    fix_all(records_to_fix, words, args.model, args.dry_run)


if __name__ == "__main__":
    main()
