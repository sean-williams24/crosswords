#!/usr/bin/env python3
"""
Expand word bank with pre-validated words.

Unlike the old expand_word_bank scripts, this validates candidates with GPT
BEFORE adding them — so only crossword-appropriate words make it in.

Pipeline per batch:
  1. Pull candidates from source (system dictionary or wordfreq)
  2. Filter with GPT: keep only well-known, crossword-suitable words
  3. Generate clues for approved words
  4. Append to word_bank.json

Usage:
    python expand_validated.py                          # Add up to 5000 words (system dict)
    python expand_validated.py --source wordfreq        # Use frequency-ranked word list (better quality)
    python expand_validated.py --source wordfreq --lengths 6 7 8 9  # Target specific lengths
    python expand_validated.py --limit 2000             # Add up to 2000 words
    python expand_validated.py --batch-size 40          # 40 candidates per API call
    python expand_validated.py --model gpt-4o-mini      # Model to use
    python expand_validated.py --dry-run                # Preview without saving

Environment Variables:
    OPENAI_API_KEY — Required
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

BANK_PATH = Path(__file__).parent / "word_bank.json"
DICT_PATH = Path("/usr/share/dict/words")

# ── Prompts (same criteria as clean_word_bank.py) ─────────────────────────

FILTER_SYSTEM_PROMPT = """You are a crossword puzzle editor deciding which words belong in a 
general-audience crossword puzzle (like the NYT or a quality newspaper crossword).

A word is GOOD if:
- Most educated English speakers would recognise it
- It appears in everyday conversation, news, books, or pop culture
- It could reasonably appear in a quality newspaper crossword
- Common abbreviations are OK (e.g., NASA, FBI, DNA)
- Well-known proper nouns that have become common words are OK (e.g., CHAMPAGNE)

A word should be REMOVED if:
- It's a highly technical or specialised term most people wouldn't know
- It's archaic or obsolete (not used in modern English)
- It's a very obscure variant spelling
- It's a fragment that isn't a real standalone word
- It's slang so regional/niche that most English speakers wouldn't recognise it
- It's a prefix or suffix that isn't used as a standalone word
- It looks like a foreign word that hasn't been adopted into English

Be SELECTIVE — when in doubt, remove it. We'd rather have a smaller bank of 
good, well-known words than a large bank full of obscure ones."""

FILTER_USER_PROMPT = """Classify each word below as either "keep" (well-known, suitable for a crossword) 
or "remove" (too obscure, archaic, or unusual).

Words: {words_list}

Return a JSON object with two arrays:
{{"keep": ["WORD1", "WORD2", ...], "remove": ["WORD3", "WORD4", ...]}}

Return ONLY the JSON, no other text."""

CLUE_SYSTEM_PROMPT = """You are an expert crossword puzzle clue writer. Generate high-quality 
crossword clues for each word.

For each word, provide:
1. "text" — A straightforward definition clue (clear, concise)
2. "hint" — A short 1-3 word hint/synonym  
3. "hard_text" — A trickier clue using wordplay, double meanings, or misdirection
4. "clues" — 3 different harder clues, each using a different technique

Rules:
- Each clue must be concise (under 10 words ideally)
- Clues must be fair — a knowledgeable solver should be able to get it
- Don't include the answer word in the clue
- Make clues feel like they belong in a quality newspaper crossword"""

CLUE_USER_PROMPT = """Generate crossword clues for each of the {word_count} words below.
You MUST return clues for ALL {word_count} words.

Words: {words_list}

Return a JSON object with a "words" key containing an array of ALL {word_count} words:
{{"words": [{{"word": "WORD", "text": "straightforward clue", "hint": "short hint", "hard_text": "tricky clue", "clues": ["clue1", "clue2", "clue3"]}}, ...]}}

Return ONLY the JSON object, no other text."""


def parse_json(content: str):
    if "```json" in content:
        content = content.split("```json")[1].split("```")[0]
    elif "```" in content:
        content = content.split("```")[1].split("```")[0]
    return json.loads(content.strip())


def call_openai(system_prompt: str, user_prompt: str, model: str, temperature: float = 0.3) -> str:
    import openai
    client = openai.OpenAI()
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=temperature,
    )
    return response.choices[0].message.content or ""


def load_candidates_dict(existing_words: set[str], lengths: list[int] | None = None) -> list[str]:
    """Load system dictionary candidates not already in the bank."""
    with open(DICT_PATH) as f:
        raw = [line.strip() for line in f]

    min_len = min(lengths) if lengths else 3
    max_len = max(lengths) if lengths else 13

    candidates = []
    for w in raw:
        upper = w.upper()
        if upper in existing_words:
            continue
        lower = w.lower()
        if len(lower) < min_len or len(lower) > max_len:
            continue
        if lengths and len(lower) not in lengths:
            continue
        if not re.match(r'^[a-z]+$', lower):
            continue
        candidates.append(upper)

    # Sort by "crossword friendliness" proxy: prefer common letter distributions
    common_letters = set("ETAOINSHRDLU")
    candidates.sort(key=lambda w: (-sum(1 for c in w if c in common_letters) / len(w), len(w)))

    return candidates


def load_candidates_wordfreq(existing_words: set[str], lengths: list[int] | None = None, top_n: int = 200000) -> list[str]:
    """Load frequency-ranked English words not already in the bank."""
    try:
        from wordfreq import top_n_list
    except ImportError:
        print("Install wordfreq: pip install wordfreq")
        sys.exit(1)

    target_lengths = set(lengths) if lengths else set(range(3, 14))
    raw = top_n_list('en', top_n)

    candidates = []
    for w in raw:
        if not w.isalpha():
            continue
        upper = w.upper()
        if upper in existing_words:
            continue
        if len(w) not in target_lengths:
            continue
        candidates.append(upper)

    # wordfreq already returns in frequency order (most common first) — that's our sorting
    return candidates


def main():
    parser = argparse.ArgumentParser(description="Expand word bank with pre-validated words")
    parser.add_argument("--source", choices=["dict", "wordfreq"], default="dict",
                        help="Word source: system dictionary or wordfreq frequency list (default: dict)")
    parser.add_argument("--lengths", type=int, nargs="+", metavar="N",
                        help="Only target specific word lengths e.g. --lengths 6 7 8 9")
    parser.add_argument("--model", default="gpt-4o-mini", help="OpenAI model (default: gpt-4o-mini)")
    parser.add_argument("--batch-size", type=int, default=40, help="Candidates per API call (default: 40)")
    parser.add_argument("--limit", type=int, default=5000, help="Max new words to add (default: 5000)")
    parser.add_argument("--dry-run", action="store_true", help="Preview without saving")
    args = parser.parse_args()

    if not os.environ.get("OPENAI_API_KEY"):
        print("Set OPENAI_API_KEY environment variable")
        sys.exit(1)

    # Load word bank
    with open(BANK_PATH) as f:
        words = json.load(f)
    existing_words = {w["word"].upper() for w in words}
    print(f"Current bank: {len(words)} words")

    # Load candidates
    if args.source == "wordfreq":
        candidates = load_candidates_wordfreq(existing_words, args.lengths)
        source_label = "wordfreq"
    else:
        candidates = load_candidates_dict(existing_words, args.lengths)
        source_label = "system dictionary"

    print(f"Source: {source_label}")
    if args.lengths:
        print(f"Target lengths: {args.lengths}")
    print(f"Candidates available: {len(candidates)}")
    print(f"Target: add up to {args.limit} new words")
    print(f"Model: {args.model}, batch size: {args.batch_size}\n")

    added_count = 0
    total_candidates_processed = 0
    total_batches = (min(len(candidates), args.limit * 3) + args.batch_size - 1) // args.batch_size  # rough estimate

    for i in range(0, len(candidates), args.batch_size):
        if added_count >= args.limit:
            print(f"\nReached limit of {args.limit} words. Done.")
            break

        batch = candidates[i:i + args.batch_size]
        total_candidates_processed += len(batch)
        batch_num = i // args.batch_size + 1

        print(f"Batch {batch_num} ({len(batch)} candidates, {added_count}/{args.limit} added so far)...")

        # Phase 1: Filter
        try:
            filter_prompt = FILTER_USER_PROMPT.format(words_list=json.dumps(batch))
            filter_response = call_openai(FILTER_SYSTEM_PROMPT, filter_prompt, args.model)
            filter_result = parse_json(filter_response)

            kept = [w.upper() for w in filter_result.get("keep", [])]
            removed_count = len(batch) - len(kept)
            print(f"  Filter: {len(kept)} kept, {removed_count} removed")

            if not kept:
                time.sleep(0.5)
                continue

        except Exception as e:
            print(f"  Filter ERROR: {e} — skipping batch")
            continue

        # Phase 2: Generate clues for approved words
        # Limit to how many we still need
        remaining = args.limit - added_count
        kept = kept[:remaining]

        try:
            clue_prompt = CLUE_USER_PROMPT.format(
                word_count=len(kept),
                words_list=json.dumps(kept)
            )
            clue_response = call_openai(CLUE_SYSTEM_PROMPT, clue_prompt, args.model, temperature=0.7)
            clue_result = parse_json(clue_response)

            new_entries = clue_result.get("words", [])
            # Validate entries have required fields
            valid_entries = [
                e for e in new_entries
                if e.get("word") and e.get("text") and e["word"].upper() not in existing_words
            ]

            if args.dry_run:
                for e in valid_entries[:3]:
                    print(f"    {e['word']}: {e['text']}")
                if len(valid_entries) > 3:
                    print(f"    ... and {len(valid_entries) - 3} more")
            else:
                # Normalise word to uppercase
                for e in valid_entries:
                    e["word"] = e["word"].upper()
                    existing_words.add(e["word"])

                words.extend(valid_entries)
                added_count += len(valid_entries)

                # Save after each batch
                with open(BANK_PATH, "w") as f:
                    json.dump(words, f, indent=2, ensure_ascii=False)

                print(f"  Clues generated: {len(valid_entries)} words added (total bank: {len(words)})")

        except Exception as e:
            print(f"  Clue generation ERROR: {e} — skipping clues for this batch")
            # Still add words with placeholder clues so they're not lost
            if not args.dry_run and kept:
                for word in kept:
                    if word not in existing_words:
                        entry = {
                            "word": word,
                            "text": f"Definition of {word.lower()}",
                            "hint": word.lower(),
                        }
                        words.append(entry)
                        existing_words.add(word)
                        added_count += 1
                with open(BANK_PATH, "w") as f:
                    json.dump(words, f, indent=2, ensure_ascii=False)
                print(f"  Saved {len(kept)} with placeholder clues")

        time.sleep(0.5)

    print(f"\n=== Done ===")
    print(f"Candidates processed: {total_candidates_processed}")
    print(f"New words added: {added_count}")
    print(f"Final bank size: {len(words)}")


if __name__ == "__main__":
    main()
