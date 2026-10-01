"""Fill current and future Midword dates from an approved compound inventory.

The scheduled path makes no AI calls. Expand midword_approved.json through an
editorial review before the pool falls below the configured coverage horizon.
"""

from __future__ import annotations

import argparse
import json
import os
import random
from datetime import date, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MidwordTriple = tuple[str, str, str]


def load_inventory(path: Path = ROOT / "midword_approved.json") -> tuple[list[MidwordTriple], set[MidwordTriple]]:
    raw = json.loads(path.read_text())
    triples = []
    for item in raw["triples"]:
        words = item.split()
        if len(words) != 3:
            raise ValueError(f"Bad triple: {item}")
        first, middle, second = words
        if not (3 <= len(middle) <= 6) or not all(w.isalpha() and w.isascii() and w.isupper() for w in words):
            raise ValueError(f"Bad Midword entry: {item}")
        if len({first, middle, second}) != 3:
            raise ValueError(f"Repeated component: {item}")
        triples.append((first, middle, second))
    if len(set(triples)) != len(triples):
        raise ValueError("Duplicate approved entry")
    if len({(first, second) for first, _, second in triples}) != len(triples):
        raise ValueError("Approved entries reuse a prompt pair")
    moderate_raw = raw.get("moderate_triples", [])
    if not isinstance(moderate_raw, list) or any(not isinstance(item, str) for item in moderate_raw):
        raise ValueError("Moderate Midword entries must be a list of triples")
    if len(set(moderate_raw)) != len(moderate_raw):
        raise ValueError("Duplicate moderate Midword entry")
    if not set(moderate_raw).issubset(set(raw["triples"])):
        raise ValueError("Moderate Midword entries must be approved triples")
    return triples, {tuple(item.split()) for item in moderate_raw}


def load_approved(path: Path = ROOT / "midword_approved.json") -> list[MidwordTriple]:
    return load_inventory(path)[0]


def select_puzzles(
    approved: list[MidwordTriple],
    existing: list[dict],
    start: date,
    target_days: int,
    seed: int = 0,
    moderate: set[MidwordTriple] | None = None,
) -> list[dict]:
    if target_days < 1:
        raise ValueError("target_days must be positive")
    existing_dates = {row["date"] for row in existing}
    used_pairs = {(row["first_word"], row["second_word"]) for row in existing}
    used_signatures = {(row["first_word"], row["answer"], row["second_word"]) for row in existing}
    next_number = max((row["puzzle_number"] for row in existing), default=0) + 1
    pool = [item for item in approved if (item[0], item[2]) not in used_pairs and item not in used_signatures]
    random.Random(seed).shuffle(pool)
    if moderate:
        pool.sort(key=lambda item: item not in moderate)
    planned = []
    recent_answers: list[str] = []
    for offset in range(target_days):
        day = (start + timedelta(days=offset)).isoformat()
        if day in existing_dates:
            continue
        choice_index = next((i for i, (_, answer, _) in enumerate(pool) if answer not in recent_answers[-7:]), None)
        if choice_index is None:
            raise ValueError(f"Approved Midword inventory exhausted before {day}; no rows published")
        first, answer, second = pool.pop(choice_index)
        if (first, second) in used_pairs:
            raise ValueError(f"Midword prompt pair selected twice: {first} / {second}")
        used_pairs.add((first, second))
        planned.append({
            "date": day,
            "puzzle_number": next_number,
            "first_word": first,
            "second_word": second,
            "answer": answer,
            "alternatives": [],
        })
        next_number += 1
        recent_answers.append(answer)
    return planned


def fetch_existing(client) -> list[dict]:
    rows = []
    for start in range(0, 100000, 1000):
        page = client.table("midword_puzzles").select(
            "date,puzzle_number,first_word,second_word,answer"
        ).order("date").range(start, start + 999).execute().data
        rows.extend(page)
        if len(page) < 1000:
            return rows
    raise RuntimeError("Midword history exceeded pagination limit")


def default_start_date(today: date | None = None) -> date:
    return today if today is not None else date.today()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", type=date.fromisoformat, default=default_start_date())
    parser.add_argument("--target-days", type=int, default=21)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--history", type=Path, help="Existing rows JSON for offline planning")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    client = None
    if args.history:
        existing = json.loads(args.history.read_text())
    elif args.dry_run:
        existing = []
    else:
        from supabase import create_client
        client = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
        existing = fetch_existing(client)

    approved, moderate = load_inventory()
    planned = select_puzzles(approved, existing, args.date, args.target_days, args.seed, moderate)
    used = existing + planned
    used_pairs = {(row["first_word"], row["second_word"]) for row in used}
    remaining = sum((first, second) not in used_pairs for first, _, second in approved)
    print(json.dumps({"planned": planned, "remaining": remaining}, indent=2))
    if args.dry_run or not planned:
        return
    if client is None:
        from supabase import create_client
        client = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
    # The RPC validates and inserts the whole batch in one database transaction.
    client.rpc("publish_midword_batch", {"p_rows": planned}).execute()


if __name__ == "__main__":
    main()
