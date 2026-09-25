"""Export wordfreq evidence for editorial review of the finite Anagram pool.

Requires the existing wordfreq dependency from Backend/requirements.txt. This
report informs human curation; no automatic frequency cutoff admits words.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from generate_anagram import load_pool


def build_report() -> dict:
    try:
        from wordfreq import top_n_list, zipf_frequency
    except ImportError as error:
        raise RuntimeError("Install Backend/requirements.txt to generate wordfreq evidence") from error
    pool = load_pool()
    ranks = {word.upper(): rank for rank, word in enumerate(top_n_list("en", 200_000), 1)}
    return {
        "source": "wordfreq English top 200,000 and zipf_frequency",
        "reviewStatus": "requires_editorial_signoff_before_publication",
        "entries": [
            {
                "issue": number,
                "answer": entry["answer"],
                "zipf": round(zipf_frequency(entry["answer"].lower(), "en"), 2),
                "top200kRank": ranks.get(entry["answer"]),
                "acceptedAnswers": [
                    {
                        "word": word,
                        "zipf": round(zipf_frequency(word.lower(), "en"), 2),
                        "top200kRank": ranks.get(word),
                    }
                    for word in entry["acceptedAnswers"]
                ],
            }
            for number, entry in enumerate(pool, 1)
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(json.dumps(build_report(), indent=2) + "\n")
    print(f"Wrote wordfreq review evidence to {args.output}")


if __name__ == "__main__":
    main()
