"""Curate and optionally publish a 30-day Anagram buffer.

The two model reviews provide editorial evidence. Structural checks, source
membership, release order, and the 365-day repeat rule remain deterministic.
"""

from __future__ import annotations

import argparse
from datetime import date, datetime, timedelta, timezone
import hashlib
from importlib.metadata import version
import json
import os
from pathlib import Path
import random
from typing import Callable

from generate_anagram import BANK, POOL, make_row, read_published_rows, signature, validate_rows

POLICY_VERSION = 1
BUFFER_DAYS = 30
REPEAT_DAYS = 365
MIN_PRIMARY_ZIPF = 3.5
MIN_EXTERNAL_ZIPF = 3.0
MAX_ATTEMPTS = 8
CANDIDATE_BATCH_SIZE = 42
DEFAULT_MODEL = "gpt-5.4"  # Backword's current validator model.

LEXICAL_REVIEW = """You review Anagram answer sets for a family-friendly daily game.
For every supplied group classify EVERY supplied word. Set accept=true only for
a familiar, correctly spelled, standalone English word suitable for all ages.
Reject names, brands, places, nationality adjectives, abbreviations, slang,
clinical terms, sexual content, and obscure or questionable forms. The primary
must be accepted. Set complete=false if another common valid word with the same
letters is missing from the supplied words, or if you cannot judge the group.
Return JSON only: {"groups":[{"signature":"...","complete":true,
"reason":"...","words":[{"word":"...","accept":true,"reason":"..."}]}]}.
Return one group for every input group, and one word for every input word.
Do not add words or change the primary."""

ADVERSARIAL_REVIEW = """Independently audit these Anagram answer sets. Search
for accepted words that are names, rare, offensive, incorrectly spelled, or not
standalone English words. Search for common valid rearrangements that were
omitted, including words listed as external to the bank. Classify EVERY word.
Set complete=false if the supplied list is incomplete or uncertain. Prefer
rejecting a doubtful group over publishing an unfair puzzle. Return JSON only:
{"groups":[{"signature":"...","complete":true,"reason":"...",
"words":[{"word":"...","accept":true,"reason":"..."}]}]}.
Return one group for every input group, and one word for every input word.
Do not add words or change the primary."""

REVIEW_FORMAT = {
    "type": "json_schema",
    "json_schema": {
        "name": "anagram_review",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {"groups": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "signature": {"type": "string"},
                        "complete": {"type": "boolean"},
                        "reason": {"type": "string"},
                        "words": {"type": "array", "items": {
                            "type": "object",
                            "properties": {"word": {"type": "string"},
                                           "accept": {"type": "boolean"},
                                           "reason": {"type": "string"}},
                            "required": ["word", "accept", "reason"],
                            "additionalProperties": False,
                        }},
                    },
                    "required": ["signature", "complete", "reason", "words"],
                    "additionalProperties": False,
                },
            }},
            "required": ["groups"],
            "additionalProperties": False,
        },
    },
}


def canonical_digest(value: dict) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=True).encode()).hexdigest()


def source_digest() -> str:
    return hashlib.sha256(BANK.read_bytes() + b"\0" + POOL.read_bytes()).hexdigest()


def candidate_groups() -> tuple[dict[str, dict], list[str]]:
    """Find bank-backed primary groups and common external alternatives."""
    from wordfreq import top_n_list, zipf_frequency

    bank = json.loads(BANK.read_text())
    pool = json.loads(POOL.read_text())
    if pool.get("schemaVersion") != 1 or pool.get("source") != "Backend/word_bank.json":
        raise ValueError("Unsupported Anagram seed pool")
    bank_words = {
        row["word"].upper() for row in bank
        if isinstance(row.get("word"), str)
        and 7 <= len(row["word"]) <= 9
        and row["word"].isascii() and row["word"].isalpha()
    }
    bank_by_signature: dict[str, set[str]] = {}
    for word in bank_words:
        bank_by_signature.setdefault(signature(word), set()).add(word)

    ranked = {
        word.upper(): rank for rank, word in enumerate(top_n_list("en", 200_000), 1)
        if 7 <= len(word) <= 9 and word.isascii() and word.isalpha()
    }
    raw_scores = {word: zipf_frequency(word.lower(), "en")
                  for word in bank_words | set(ranked)}
    external_by_signature: dict[str, set[str]] = {}
    for word in ranked:
        if word not in bank_words and raw_scores[word] >= MIN_EXTERNAL_ZIPF:
            key = signature(word)
            if key in bank_by_signature:
                external_by_signature.setdefault(key, set()).add(word)

    seed_order: list[str] = []
    seed_primary: dict[str, str] = {}
    for entry in pool["entries"]:
        word = entry["answer"]
        key = signature(word)
        if word not in bank_words or key in seed_primary:
            raise ValueError(f"Invalid or duplicate Anagram seed: {word}")
        seed_primary[key] = word
        seed_order.append(key)

    def word_info(word: str) -> dict:
        return {"word": word, "zipf": round(raw_scores[word], 2),
                "top200kRank": ranked.get(word)}

    groups: dict[str, dict] = {}
    for key, words in bank_by_signature.items():
        ordered = sorted(words, key=lambda word: (-raw_scores[word], word))
        seeded = seed_primary.get(key)
        primary = seeded if seeded and raw_scores[seeded] >= MIN_PRIMARY_ZIPF else ordered[0]
        if raw_scores[primary] < MIN_PRIMARY_ZIPF:
            continue
        external = sorted(external_by_signature.get(key, ()),
                          key=lambda word: (-raw_scores[word], word))
        groups[key] = {
            "signature": key,
            "primary": primary,
            "seed": key in seed_primary,
            "bankWords": [word_info(word) for word in ordered],
            "externalWords": [word_info(word) for word in external],
        }
    return groups, seed_order


def buffer_plan(existing: list[dict], today: date) -> tuple[date, int, int]:
    if not existing:
        raise ValueError("No published Anagram rows; publish the launch batch first")
    validate_rows([], existing)
    latest = max(existing, key=lambda row: row["date"])
    start = date.fromisoformat(latest["date"]) + timedelta(days=1)
    target = today + timedelta(days=BUFFER_DAYS)
    return start, latest["puzzle_number"] + 1, max(0, (target - start).days + 1)


def previous_releases(existing: list[dict]) -> dict[str, date]:
    releases: dict[str, date] = {}
    for row in existing:
        key = signature(row["puzzle_data"]["answer"])
        releases[key] = date.fromisoformat(row["date"])
    return releases


def order_candidates(groups: dict[str, dict], seed_order: list[str],
                     releases: dict[str, date], first_issue: int,
                     first_date: date, last_date: date) -> tuple[list[dict], list[dict]]:
    never_used = {key for key in groups if key not in releases}
    seeded = [key for key in seed_order if key in never_used and key in groups]
    others = sorted(never_used - set(seeded))
    rng = random.Random(f"anagram-auto-v1:{first_issue}")
    rng.shuffle(others)
    reused = sorted(
        (key for key in groups if key in releases
         and (last_date - releases[key]).days >= REPEAT_DAYS),
        key=lambda key: (releases[key], key),
    )
    return ([groups[key] for key in seeded + others],
            [groups[key] for key in reused])


def validate_review(response: dict, batch: list[dict]) -> dict[str, dict]:
    if not isinstance(response, dict) or not isinstance(response.get("groups"), list):
        raise ValueError("Reviewer returned malformed groups")
    expected = {group["signature"]: group for group in batch}
    if len(response["groups"]) != len(expected):
        raise ValueError("Reviewer returned an incomplete group set")
    result = {}
    for verdict in response["groups"]:
        if not isinstance(verdict, dict):
            raise ValueError("Reviewer returned malformed group")
        key = verdict.get("signature")
        if (key not in expected or key in result or
                type(verdict.get("complete")) is not bool or
                not isinstance(verdict.get("reason"), str) or
                not isinstance(verdict.get("words"), list)):
            raise ValueError("Reviewer returned mismatched group")
        words = expected[key]["bankWords"] + expected[key]["externalWords"]
        expected_words = {item["word"] for item in words}
        received = {}
        for item in verdict["words"]:
            if not isinstance(item, dict):
                raise ValueError("Reviewer returned malformed word")
            word = item.get("word")
            if (word not in expected_words or word in received or
                    type(item.get("accept")) is not bool or
                    not isinstance(item.get("reason"), str)):
                raise ValueError("Reviewer returned invented or malformed word")
            received[word] = item
        if set(received) != expected_words:
            raise ValueError("Reviewer omitted words")
        result[key] = verdict
    return result


def approved_answers(group: dict, lexical: dict, adversarial: dict) -> list[str] | None:
    checked = [validate_review({"groups": [review]}, [group])[group["signature"]]
               for review in (lexical, adversarial)]
    if not all(review["complete"] for review in checked):
        return None
    external = {item["word"] for item in group["externalWords"]}
    accepted = []
    for review in checked:
        words = {item["word"] for item in review["words"] if item["accept"]}
        if group["primary"] not in words or words & external:
            return None
        accepted.append(words)
    if accepted[0] != accepted[1]:
        return None
    return [item["word"] for item in group["bankWords"]
            if item["word"] in accepted[0] and item["word"] != group["primary"]]


def model_review(batch: list[dict], prompt: str, model: str) -> dict:
    from openai import OpenAI

    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        raise RuntimeError("OPENAI_API_KEY is required for Anagram curation")
    response = OpenAI(api_key=key).chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": prompt},
                  {"role": "user", "content": json.dumps({"groups": batch})}],
        temperature=0,
        response_format=REVIEW_FORMAT,
    )
    return json.loads(response.choices[0].message.content)


def assign_rows(approved: list[dict], releases: dict[str, date],
                start: date, issue: int, count: int) -> tuple[list[dict], list[dict]]:
    rows, selected = [], []
    used = set()
    for offset in range(count):
        release = start + timedelta(days=offset)
        choice = next((bundle for bundle in approved
                       if bundle["candidate"]["signature"] not in used
                       and (bundle["candidate"]["signature"] not in releases or
                            (release - releases[bundle["candidate"]["signature"]]).days
                            >= REPEAT_DAYS)), None)
        if choice is None:
            break
        group = choice["candidate"]
        alternatives = approved_answers(group, choice["lexical"], choice["adversarial"])
        if alternatives is None:
            raise ValueError("Approved evidence changed during row assignment")
        rows.append(make_row(release, issue + offset,
                             {"answer": group["primary"], "acceptedAnswers": alternatives}))
        selected.append(choice)
        used.add(group["signature"])
    return rows, selected


def build_artifact(existing: list[dict], today: date, groups: dict[str, dict],
                   seed_order: list[str], reviewer: Callable = model_review,
                   model: str = DEFAULT_MODEL, report: dict | None = None,
                   max_attempts: int = MAX_ATTEMPTS,
                   batch_size: int = CANDIDATE_BATCH_SIZE) -> dict | None:
    start, issue, count = buffer_plan(existing, today)
    releases = previous_releases(existing)
    unused, reused = order_candidates(
        groups, seed_order, releases, issue, start,
        start + timedelta(days=max(count - 1, 0)))
    status = report if report is not None else {}
    status.update({"targetDate": (today + timedelta(days=BUFFER_DAYS)).isoformat(),
                   "startDate": start.isoformat(), "needed": count,
                   "candidateCountBefore": len(unused) + len(reused),
                   "eligibleCandidates": len(unused) + len(reused),
                   "attempts": [], "status": "buffer_full" if not count else "curating"})
    if not count:
        return None

    approved: list[dict] = []
    unused_cursor = reused_cursor = 0
    rows: list[dict] = []
    selected: list[dict] = []
    for attempt in range(max_attempts):
        # Reserve the final two attempts for eligible older combinations when
        # unused groups have not supplied enough approved answers.
        choose_reused = bool(reused) and (attempt >= max_attempts - 2 or
                                          unused_cursor >= len(unused))
        source = reused if choose_reused else unused
        cursor = reused_cursor if choose_reused else unused_cursor
        if cursor >= len(source):
            source = unused if source is reused else reused
            cursor = unused_cursor if source is unused else reused_cursor
        batch = source[cursor:cursor + batch_size]
        if not batch:
            break
        if source is unused:
            unused_cursor += len(batch)
        else:
            reused_cursor += len(batch)
        attempt_report = {"number": attempt + 1, "candidates": len(batch),
                          "accepted": 0, "rejected": 0, "reason": "",
                          "rejectedGroups": []}
        status["attempts"].append(attempt_report)
        try:
            lexical = validate_review(reviewer(batch, LEXICAL_REVIEW, model), batch)
            adversarial = validate_review(reviewer(batch, ADVERSARIAL_REVIEW, model), batch)
        except Exception as error:
            attempt_report["rejected"] = len(batch)
            attempt_report["reason"] = f"Reviewer batch failed: {error}"
            continue
        for group in batch:
            key = group["signature"]
            alternatives = approved_answers(group, lexical[key], adversarial[key])
            if alternatives is None:
                attempt_report["rejected"] += 1
                attempt_report["rejectedGroups"].append({
                    "signature": key, "lexical": lexical[key],
                    "adversarial": adversarial[key],
                })
                continue
            approved.append({"candidate": group, "lexical": lexical[key],
                             "adversarial": adversarial[key]})
            attempt_report["accepted"] += 1
        rows, selected = assign_rows(approved, releases, start, issue, count)
        if len(rows) == count:
            break
    if len(rows) != count:
        status["status"] = "failed"
        status["error"] = f"Approved only {len(rows)}/{count} required Anagram puzzles"
        raise ValueError(status["error"])

    validate_rows(rows, existing)
    status["status"] = "prepared"
    status["approved"] = len(rows)
    status["eligibleCandidates"] -= len(selected)
    artifact = {
        "schemaVersion": 2,
        "approvalMode": "automated",
        "policyVersion": POLICY_VERSION,
        "sourceDigest": source_digest(),
        "wordfreqVersion": version("wordfreq"),
        "model": model,
        "reviewPrompts": {"lexical": canonical_digest({"prompt": LEXICAL_REVIEW,
                                                      "format": REVIEW_FORMAT}),
                          "adversarial": canonical_digest({"prompt": ADVERSARIAL_REVIEW,
                                                          "format": REVIEW_FORMAT})},
        "firstReleaseDate": start.isoformat(),
        "targetDate": (today + timedelta(days=BUFFER_DAYS)).isoformat(),
        "rows": rows,
        "reviews": selected,
    }
    artifact["contentDigest"] = canonical_digest(artifact)
    return artifact


def validate_automated_artifact(artifact: dict, existing: list[dict]) -> list[dict]:
    if (artifact.get("schemaVersion") != 2 or
            artifact.get("approvalMode") != "automated" or
            artifact.get("policyVersion") != POLICY_VERSION or
            artifact.get("sourceDigest") != source_digest() or
            artifact.get("wordfreqVersion") != version("wordfreq") or
            artifact.get("reviewPrompts") != {
                "lexical": canonical_digest({"prompt": LEXICAL_REVIEW,
                                             "format": REVIEW_FORMAT}),
                "adversarial": canonical_digest({"prompt": ADVERSARIAL_REVIEW,
                                                 "format": REVIEW_FORMAT})}):
        raise ValueError("Unsupported or stale automated Anagram evidence")
    digest = artifact.get("contentDigest")
    body = {key: value for key, value in artifact.items() if key != "contentDigest"}
    if digest != canonical_digest(body):
        raise ValueError("Automated Anagram artifact digest mismatch")
    rows = artifact.get("rows")
    reviews = artifact.get("reviews")
    if not isinstance(rows, list) or not rows or not isinstance(reviews, list) or len(rows) != len(reviews):
        raise ValueError("Automated Anagram artifact has missing rows or reviews")
    if not existing:
        raise ValueError("Automated Anagram publication requires a launch batch")
    expected_start = date.fromisoformat(max(existing, key=lambda row: row["date"])["date"]) + timedelta(days=1)
    if rows[0]["date"] != expected_start.isoformat() or rows[0]["puzzle_number"] != max(
            row["puzzle_number"] for row in existing) + 1:
        raise ValueError("Automated batch is stale or not contiguous with the remote queue")
    if (artifact.get("firstReleaseDate") != rows[0]["date"] or
            artifact.get("targetDate") != rows[-1]["date"] or
            not isinstance(artifact.get("model"), str) or not artifact["model"]):
        raise ValueError("Automated batch metadata differs from rows")
    validate_rows(rows, existing)
    groups, _ = candidate_groups()
    releases = previous_releases(existing)
    for row, bundle in zip(rows, reviews, strict=True):
        if not isinstance(bundle, dict):
            raise ValueError("Malformed automated review evidence")
        group = bundle.get("candidate")
        if not isinstance(group, dict) or groups.get(group.get("signature")) != group:
            raise ValueError("Automated answer differs from current word sources")
        alternatives = approved_answers(group, bundle.get("lexical"), bundle.get("adversarial"))
        if alternatives is None:
            raise ValueError("Automated reviewers did not agree")
        expected = make_row(date.fromisoformat(row["date"]), row["puzzle_number"],
                            {"answer": group["primary"], "acceptedAnswers": alternatives})
        if row != expected:
            raise ValueError("Automated puzzle differs from reviewed answer set")
        last = releases.get(group["signature"])
        if last and (date.fromisoformat(row["date"]) - last).days < REPEAT_DAYS:
            raise ValueError("Automated batch repeats a combination within 365 days")
        releases[group["signature"]] = date.fromisoformat(row["date"])
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true", help="Insert a fully approved batch")
    parser.add_argument("--dry-run", action="store_true", help="Prepare and check without inserting")
    parser.add_argument("--today", type=date.fromisoformat, default=datetime.now(timezone.utc).date())
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if args.publish == args.dry_run:
        parser.error("Choose exactly one of --publish or --dry-run")

    report: dict = {"status": "starting", "todayUTC": args.today.isoformat()}
    try:
        existing = read_published_rows()
        buffer_plan(existing, args.today)
        groups, seeds = candidate_groups()
        artifact = build_artifact(existing, args.today, groups, seeds,
                                  reviewer=model_review, model=args.model, report=report)
        report["publishedThrough"] = max(row["date"] for row in existing)
        if artifact is None:
            print(f"Anagram buffer full through {report['publishedThrough']}; no AI or upload needed")
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(artifact, indent=2) + "\n")
            if args.publish:
                from publish_anagram import publish_artifact
                publish_artifact(artifact)
                report["status"] = "published"
                report["publishedThrough"] = artifact["rows"][-1]["date"]
            print(f"Anagram {report['status']} through {artifact['rows'][-1]['date']}; "
                  f"{report['eligibleCandidates']} eligible candidate combinations remain")
        report["futureDays"] = max(0, (date.fromisoformat(report["publishedThrough"]) - args.today).days)
        print(f"Anagram future coverage: {report['futureDays']} days")
        output = os.environ.get("GITHUB_OUTPUT")
        if output:
            with open(output, "a") as handle:
                handle.write(f"candidate_remaining={report['eligibleCandidates']}\n")
                handle.write(f"published_through={report['publishedThrough']}\n")
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
