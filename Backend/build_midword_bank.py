"""Discover Midword candidates for editorial review; never publishes them.

The word bank supplies possible compounds. wordfreq ranks familiarity, but
neither source proves that a split is a real, meaningful compound. The output
requires semantic review before entries are added to midword_approved.json.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

from wordfreq import zipf_frequency

from generate_midword import ROOT, load_approved


def discover(words: set[str], approved: set[tuple[str, str, str]]) -> list[dict]:
    left: dict[str, set[str]] = defaultdict(set)
    right: dict[str, set[str]] = defaultdict(set)
    for compound in words:
        for split in range(3, len(compound) - 2):
            first, second = compound[:split], compound[split:]
            if first not in words or second not in words:
                continue
            if 3 <= len(second) <= 6:
                left[second].add(first)
            if 3 <= len(first) <= 6:
                right[first].add(second)

    by_pair: dict[tuple[str, str], set[str]] = defaultdict(set)
    for middle in left.keys() & right.keys():
        for first in left[middle]:
            for second in right[middle]:
                if len({first, middle, second}) == 3:
                    by_pair[(first, second)].add(middle)

    rows = []
    for (first, second), answers in by_pair.items():
        if len(answers) != 1:
            continue
        middle = next(iter(answers))
        if (first, middle, second) in approved:
            continue
        compounds = [first + middle, middle + second]
        familiarity = min(zipf_frequency(word.lower(), "en") for word in [first, middle, second] + compounds)
        if familiarity < 3:
            continue
        rows.append({
            "first_word": first,
            "answer": middle,
            "second_word": second,
            "first_compound": compounds[0],
            "second_compound": compounds[1],
            "minimum_zipf": familiarity,
            "review_status": "unreviewed",
        })
    return sorted(rows, key=lambda row: (-row["minimum_zipf"], row["first_word"], row["second_word"]))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=200)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    words = {row["word"] for row in json.loads((ROOT / "word_bank.json").read_text())}
    candidates = discover(words, set(load_approved()))
    args.output.write_text(json.dumps(candidates[:args.limit], indent=2) + "\n")
    print(f"Wrote {min(args.limit, len(candidates))} unreviewed candidates to {args.output}")


if __name__ == "__main__":
    main()
