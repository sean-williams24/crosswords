"""Generate, independently review, and atomically publish a Midword buffer."""

from __future__ import annotations

import argparse
from datetime import date, timedelta
import json
import os
from pathlib import Path
import random
import sys
from typing import Callable

from build_midword_bank import discover
from generate_midword import ROOT, fetch_existing, load_inventory


DEFAULT_MODEL = "gpt-5.4"
MAX_ATTEMPTS = 8
BATCH_SIZE = 60
LEXICAL_REVIEW = """Review Midword puzzles for a family-friendly daily word game.
Each candidate supplies FIRST, ANSWER, SECOND and two concatenated compounds.
Accept only if all three words are familiar standalone English words and BOTH
concatenations are established, familiar CLOSED compounds with exactly these
meanings and spellings. Both components must contribute their ordinary meanings.
Reject arbitrary splits, names, brands, inflections masquerading as compounds,
obscure or offensive words, and normally spaced or hyphenated expressions.
For example BANK NOTE BOOK works: banknote and notebook. CHAIR MAN AGE fails:
manage is not a compound of MAN and AGE. Reject mere prefixes or suffixes.
Look for other familiar 3-6 letter answers that link FIRST and SECOND, beyond
the supplied dictionary, and reject ambiguous or uncertain puzzles. Prefer
moderately challenging but fair puzzles over strained or trivial constructions.
Rate difficulty as easy, moderate, or too_hard. Target moderate: familiar words
with a less immediate connection, often because the link has different senses
in the two compounds. RAIN BOW TIE is easy; HAND BOOK STORE is moderate.
Do not equate rarity or longer words with difficulty. Obscure, specialist, or
strained links are too_hard and must not be accepted.
Return JSON only: {"reviews":[{"id":"FIRST ANSWER SECOND","accept":true,
"firstMeaning":"explain the first compound and its two components",
"secondMeaning":"explain the second compound and its two components",
"competingAnswers":[],"difficulty":"moderate","reason":"why the puzzle is fair and this difficulty"}]}.
Return exactly one review per supplied id. Do not alter or add candidates."""
ADVERSARIAL_REVIEW = """Independently challenge these proposed Midword puzzles.
Do not assume dictionary membership proves that a split is meaningful. Reject
false etymological splits (MAN+AGE in MANAGE), affixes, proper names, rare words,
inflections, offensive material, or compounds usually written with spaces or
hyphens. Both FIRST+ANSWER and ANSWER+SECOND must be familiar closed compounds
whose components retain their ordinary meanings. Explain each compound and
explicitly search for competing familiar 3-6 letter answers, including words
absent from the supplied dictionary. Reject any ambiguity or uncertainty.
Independently rate difficulty as easy, moderate, or too_hard. Target a little
thought using familiar compounds and less obvious links, including different
ordinary senses of the same linking word. RAIN BOW TIE is easy; HAND BOOK STORE
is moderate. Unfamiliar vocabulary, specialist knowledge, and strained meanings
are too_hard: reject them even if the compounds technically exist.
Return JSON only: {"reviews":[{"id":"FIRST ANSWER SECOND","accept":true,
"firstMeaning":"explain first compound and both components",
"secondMeaning":"explain second compound and both components",
"competingAnswers":[],"difficulty":"moderate","reason":"why it survives and this difficulty"}]}.
Return exactly one review per supplied id; never change the candidates."""

REVIEW_FORMAT = {
    "type": "json_schema",
    "json_schema": {
        "name": "midword_review", "strict": True,
        "schema": {
            "type": "object", "additionalProperties": False,
            "properties": {"reviews": {
                "type": "array", "items": {
                    "type": "object", "additionalProperties": False,
                    "properties": {
                        "id": {"type": "string"}, "accept": {"type": "boolean"},
                        "firstMeaning": {"type": "string"}, "secondMeaning": {"type": "string"},
                        "competingAnswers": {"type": "array", "items": {"type": "string"}},
                        "difficulty": {"type": "string", "enum": ["easy", "moderate", "too_hard"]},
                        "reason": {"type": "string"},
                    },
                    "required": ["id", "accept", "firstMeaning", "secondMeaning", "competingAnswers", "difficulty", "reason"],
                },
            }},
            "required": ["reviews"],
        },
    },
}


def candidate_id(item: dict) -> str:
    return f"{item['first_word']} {item['answer']} {item['second_word']}"


def candidate_pool(existing: list[dict], approved: list[tuple]) -> list[dict]:
    """Discover fresh dictionary-backed pairs; discovery alone never approves."""
    from wordfreq import top_n_list

    words = {row["word"] for row in json.loads((ROOT / "word_bank.json").read_text())}
    words.update(word.upper() for word in top_n_list("en", 100_000)
                 if word.isascii() and word.isalpha())
    used_pairs = {(row["first_word"], row["second_word"]) for row in existing}
    # Approved triples are a separate reserve, not automatically generated evidence.
    rows = discover(words, set(approved))
    return [{**row, "id": candidate_id(row)} for row in rows
            if (row["first_word"], row["second_word"]) not in used_pairs]


def model_review(batch: list[dict], prompt: str, model: str) -> dict:
    from openai import OpenAI

    if not os.environ.get("OPENAI_API_KEY"):
        raise RuntimeError("OPENAI_API_KEY is required for automatic Midword generation")
    response = OpenAI(timeout=90).chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": prompt},
                  {"role": "user", "content": json.dumps({"candidates": batch})}],
        temperature=0,
        response_format=REVIEW_FORMAT,
    )
    if response.choices[0].finish_reason != "stop":
        raise ValueError("Reviewer response was incomplete or refused")
    return json.loads(response.choices[0].message.content)


def validate_review(response: dict, batch: list[dict]) -> dict[str, dict]:
    """Reject missing, duplicate, invented, or loosely typed reviewer decisions."""
    if not isinstance(response, dict) or not isinstance(response.get("reviews"), list):
        raise ValueError("Missing reviewer decisions")
    expected = {item["id"] for item in batch}
    if len(expected) != len(batch):
        raise ValueError("Duplicate input candidates")
    decisions = {}
    for item in response["reviews"]:
        if not isinstance(item, dict) or not isinstance(item.get("id"), str):
            raise ValueError("Invalid reviewer decision")
        key = item["id"]
        if key not in expected or key in decisions or type(item.get("accept")) is not bool:
            raise ValueError("Reviewer decisions do not exactly match candidates")
        if (any(not isinstance(item.get(field), str)
                for field in ("firstMeaning", "secondMeaning", "reason"))
                or not item["reason"].strip()
                or (item["accept"] and any(not item[field].strip()
                                          for field in ("firstMeaning", "secondMeaning")))):
            raise ValueError("Reviewer must explain both compounds and the verdict")
        competitors = item.get("competingAnswers")
        if not isinstance(competitors, list) or any(not isinstance(word, str) for word in competitors):
            raise ValueError("Reviewer must explicitly check competing answers")
        if item.get("difficulty") not in ("easy", "moderate", "too_hard"):
            raise ValueError("Reviewer must explicitly rate difficulty")
        decisions[key] = item
    if decisions.keys() != expected:
        raise ValueError("Reviewer omitted candidates")
    return decisions


def missing_dates(existing: list[dict], today: date, target_days: int) -> list[date]:
    if target_days < 1:
        raise ValueError("target_days must be positive")
    published = {row["date"] for row in existing}
    return [today + timedelta(days=offset) for offset in range(target_days)
            if (today + timedelta(days=offset)).isoformat() not in published]


def assign_rows(bundles: list[dict], existing: list[dict], days: list[date]) -> list[dict]:
    # Stable ties retain the day's shuffle. Moderate reserve beats easy new rows.
    bundles = sorted(bundles, key=lambda bundle: (
        bundle["difficulty"] != "moderate", bundle["source"] != "automated"))
    rows = []
    used = {(row["first_word"], row["second_word"]) for row in existing}
    next_number = max((row["puzzle_number"] for row in existing), default=0) + 1
    for day in days:
        nearby = {row["answer"] for row in existing + rows
                  if abs((date.fromisoformat(row["date"]) - day).days) <= 7}
        choice = next((bundle["candidate"] for bundle in bundles
                       if (bundle["candidate"]["first_word"], bundle["candidate"]["second_word"]) not in used
                       and bundle["candidate"]["answer"] not in nearby), None)
        if choice is None:
            break
        rows.append({"date": day.isoformat(), "puzzle_number": next_number,
                     "first_word": choice["first_word"], "answer": choice["answer"],
                     "second_word": choice["second_word"], "alternatives": []})
        used.add((choice["first_word"], choice["second_word"]))
        next_number += 1
    return rows


def build_batch(existing: list[dict], today: date, target_days: int = 21,
                reviewer: Callable = model_review, model: str = DEFAULT_MODEL,
                report: dict | None = None, candidates: list[dict] | None = None,
                max_attempts: int = MAX_ATTEMPTS, batch_size: int = BATCH_SIZE) -> dict:
    days = missing_dates(existing, today, target_days)
    status = report if report is not None else {}
    status.update({"status": "reviewing" if days else "buffer_full", "needed": len(days),
                   "targetDate": (today + timedelta(days=target_days - 1)).isoformat(),
                   "attempts": [], "model": model})
    if not days:
        return {"rows": [], "reviews": []}
    approved, moderate = load_inventory()
    pool = candidates if candidates is not None else candidate_pool(existing, approved)
    pool = sorted(pool, key=lambda item: item["id"])
    random.Random(f"midword:{today.isoformat()}").shuffle(pool)
    status["candidateCount"] = len(pool)
    bundles = []
    rows = []
    for attempt in range(max_attempts):
        batch = pool[attempt * batch_size:(attempt + 1) * batch_size]
        if not batch:
            break
        evidence = {"number": attempt + 1, "candidates": batch, "accepted": 0}
        status["attempts"].append(evidence)
        print(f"Midword review {attempt + 1}: {len(batch)} candidates", file=sys.stderr, flush=True)
        try:
            lexical = validate_review(reviewer(batch, LEXICAL_REVIEW, model), batch)
            evidence["lexical"] = lexical
            adversarial = validate_review(reviewer(batch, ADVERSARIAL_REVIEW, model), batch)
        except ValueError as error:
            evidence["error"] = str(error)
            continue
        evidence["adversarial"] = adversarial
        for item in batch:
            first, second = lexical[item["id"]], adversarial[item["id"]]
            if (first["accept"] and second["accept"] and
                    first["difficulty"] != "too_hard" and second["difficulty"] != "too_hard" and
                    not first["competingAnswers"] and not second["competingAnswers"]):
                difficulty = "moderate" if first["difficulty"] == second["difficulty"] == "moderate" else "easy"
                bundles.append({"candidate": item, "source": "automated",
                                "difficulty": difficulty,
                                "lexical": first, "adversarial": second})
                evidence["accepted"] += 1
        # Keep looking for the target difficulty even if easy rows could fill it.
        rows = assign_rows([item for item in bundles if item["difficulty"] == "moderate"], existing, days)
        if len(rows) == len(days):
            break
    # The original reviewed list remains available when fresh candidates fall short.
    reserve = list(approved)
    random.Random(today.isoformat()).shuffle(reserve)
    bundles.extend({"candidate": {"first_word": first, "answer": answer, "second_word": second},
                    "source": "editorial",
                    "difficulty": "moderate" if (first, answer, second) in moderate else "easy"}
                   for first, answer, second in reserve)
    rows = assign_rows(bundles, existing, days)
    if len(rows) != len(days):
        raise ValueError(f"Midword validation supplied {len(rows)} of {len(days)} missing dates; no rows published")
    selected = {(row["first_word"], row["answer"], row["second_word"]) for row in rows}
    evidence = [bundle for bundle in bundles
                if (bundle["candidate"]["first_word"], bundle["candidate"]["answer"],
                    bundle["candidate"]["second_word"]) in selected]
    status.update({"status": "ready", "generated": sum(item["source"] == "automated" for item in evidence),
                   "editorial": sum(item["source"] == "editorial" for item in evidence),
                   "moderate": sum(item["difficulty"] == "moderate" for item in evidence),
                   "easyFallback": sum(item["difficulty"] == "easy" for item in evidence)})
    return {"rows": rows, "reviews": evidence,
            "reviewPrompts": {"lexical": LEXICAL_REVIEW, "adversarial": ADVERSARIAL_REVIEW},
            "model": model}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--publish", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    parser.add_argument("--date", type=date.fromisoformat, default=date.today())
    parser.add_argument("--target-days", type=int, default=21)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--history", type=Path, help="Offline history for --dry-run")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if args.history and args.publish:
        parser.error("--history is only supported with --dry-run")
    report = {"status": "starting"}
    try:
        client = None
        if args.history:
            existing = json.loads(args.history.read_text())
        else:
            from supabase import create_client
            client = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
            existing = fetch_existing(client)
        artifact = build_batch(existing, args.date, args.target_days, model=args.model, report=report)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(artifact, indent=2) + "\n")
        if artifact["rows"] and args.publish:
            client.rpc("publish_midword_batch", {"p_rows": artifact["rows"]}).execute()
            report["status"] = "published"
        elif artifact["rows"]:
            report["status"] = "dry_run"
        print(f"Midword {report['status']}: {len(artifact['rows'])} puzzles; "
              f"coverage target {report['targetDate']}")
        return 0
    except Exception as error:
        report.update({"status": "failed", "error": str(error)})
        print(f"Midword failed: {error}", file=sys.stderr)
        return 1
    finally:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
