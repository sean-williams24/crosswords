"""
Upgrade Word Bank Clues
========================

Uses an LLM (OpenAI GPT-4o or Claude Sonnet) to generate harder, more
lateral crossword clues for each word in the word bank.

Adds a "hard_text" field to each entry — a craftier clue that uses
misdirection, double meanings, or wordplay instead of a direct definition.

Usage:
    python upgrade_clues.py                         # Process all words
    python upgrade_clues.py --provider openai        # Use OpenAI (default)
    python upgrade_clues.py --provider anthropic      # Use Claude
    python upgrade_clues.py --model gpt-4o            # Specific model
    python upgrade_clues.py --batch-size 30           # Words per API call
    python upgrade_clues.py --dry-run                 # Preview without saving

Environment Variables:
    OPENAI_API_KEY    — Required if using OpenAI (default)
    ANTHROPIC_API_KEY — Required if using Anthropic/Claude
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

BANK_PATH = Path(__file__).parent / "word_bank.json"
OUTPUT_PATH = Path(__file__).parent / "word_bank.json"

SYSTEM_PROMPT = """You are an expert crossword puzzle clue writer. Your job is to write clever, 
laterally-thinking crossword clues that are harder than simple definitions.

Good crossword clues use techniques like:
- Double meanings: "Bank job?" for TELLER (bank employee, not robbery)
- Misdirection: "It has a head but no body" for NAIL
- Wordplay: "Flower that tells time?" for FOUR O'CLOCK
- Cryptic hints: "Ship's last resort?" for ABANDON
- Cultural references: "Garfield's weakness" for LASAGNA

Rules:
- Each clue must be concise (under 10 words ideally)
- The clue must be fair — a knowledgeable solver should be able to get it
- Avoid obscure references that only specialists would know
- Don't include the answer word in the clue
- Don't use quotation marks around the answer within the clue
- Make the clue feel like it belongs in a quality newspaper crossword"""

USER_PROMPT_TEMPLATE = """Generate 3 different harder, more lateral crossword clues for each word below.
The current "easy" clue is shown for context — your clues should be noticeably trickier.
Each of the 3 clues should use a different technique (double meaning, misdirection, wordplay, etc.)
so they feel distinct from each other.

Return a JSON array with objects like: {{"word": "...", "clues": ["clue1", "clue2", "clue3"]}}

Words:
{words_json}

Return ONLY the JSON array, no other text."""


def call_openai(words_batch: list[dict], model: str) -> list[dict]:
    """Call OpenAI API to generate hard clues."""
    try:
        import openai
    except ImportError:
        print("Install openai: pip install openai")
        sys.exit(1)

    client = openai.OpenAI()

    words_for_prompt = [{"word": w["word"], "current_clue": w["text"]} for w in words_batch]
    user_prompt = USER_PROMPT_TEMPLATE.format(words_json=json.dumps(words_for_prompt, indent=2))

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.8,
    )

    content = response.choices[0].message.content or ""
    # Strip markdown code fences if present
    if "```json" in content:
        content = content.split("```json")[1].split("```")[0]
    elif "```" in content:
        content = content.split("```")[1].split("```")[0]

    result = json.loads(content.strip())

    # Handle both {"words": [...]} and [...] formats
    if isinstance(result, dict):
        result = result.get("words", result.get("clues", list(result.values())[0] if result else []))

    return result


def call_anthropic(words_batch: list[dict], model: str) -> list[dict]:
    """Call Anthropic API to generate hard clues."""
    try:
        import anthropic
    except ImportError:
        print("Install anthropic: pip install anthropic")
        sys.exit(1)

    client = anthropic.Anthropic()

    words_for_prompt = [{"word": w["word"], "current_clue": w["text"]} for w in words_batch]
    user_prompt = USER_PROMPT_TEMPLATE.format(words_json=json.dumps(words_for_prompt, indent=2))

    response = client.messages.create(
        model=model,
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_prompt}],
        temperature=0.8,
    )

    content = response.content[0].text
    # Extract JSON from response (Claude may wrap in markdown)
    if "```json" in content:
        content = content.split("```json")[1].split("```")[0]
    elif "```" in content:
        content = content.split("```")[1].split("```")[0]

    result = json.loads(content)
    if isinstance(result, dict):
        result = result.get("words", result.get("clues", []))

    return result


def main():
    parser = argparse.ArgumentParser(description="Upgrade word bank with harder clues")
    parser.add_argument(
        "--provider", choices=["openai", "anthropic"], default="openai",
        help="LLM provider (default: openai)"
    )
    parser.add_argument(
        "--model", type=str, default=None,
        help="Model name (default: gpt-4o for OpenAI, claude-sonnet-4-20250514 for Anthropic)"
    )
    parser.add_argument(
        "--batch-size", type=int, default=30,
        help="Words per API call (default: 30)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Preview results without saving"
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="Skip words that already have hard_text"
    )
    args = parser.parse_args()

    # Default models
    if args.model is None:
        args.model = "gpt-4o" if args.provider == "openai" else "claude-sonnet-4-20250514"

    # Check API key
    if args.provider == "openai" and not os.environ.get("OPENAI_API_KEY"):
        print("Set OPENAI_API_KEY environment variable")
        sys.exit(1)
    elif args.provider == "anthropic" and not os.environ.get("ANTHROPIC_API_KEY"):
        print("Set ANTHROPIC_API_KEY environment variable")
        sys.exit(1)

    # Load word bank
    with open(BANK_PATH) as f:
        words = json.load(f)

    print(f"Loaded {len(words)} words from word bank")
    print(f"Using {args.provider} / {args.model}")

    # Filter to words needing processing
    if args.resume:
        to_process = [w for w in words if "clues" not in w]
        print(f"  {len(to_process)} words need clues ({len(words) - len(to_process)} already done)")
    else:
        to_process = words

    if not to_process:
        print("All words already have clues!")
        return

    # Build lookup for updating
    word_map = {w["word"]: w for w in words}

    # Process in batches
    call_fn = call_openai if args.provider == "openai" else call_anthropic
    total_batches = (len(to_process) + args.batch_size - 1) // args.batch_size
    success_count = 0
    fail_count = 0

    for i in range(0, len(to_process), args.batch_size):
        batch = to_process[i:i + args.batch_size]
        batch_num = i // args.batch_size + 1

        print(f"\n  Batch {batch_num}/{total_batches} ({len(batch)} words)...")

        try:
            results = call_fn(batch, args.model)

            batch_success = 0
            for item in results:
                word = item.get("word", "")
                clues = item.get("clues", [])
                if word in word_map and clues:
                    word_map[word]["clues"] = clues
                    # Keep hard_text as the first variant for backwards compat
                    word_map[word]["hard_text"] = clues[0]
                    success_count += 1
                    batch_success += 1
                    if args.dry_run:
                        print(f"    {word}: {clues}")
                else:
                    fail_count += 1
                    print(f"    WARNING: No match or empty clues for '{word}'")

            # Save after each batch so progress isn't lost on crash
            if not args.dry_run and batch_success > 0:
                updated_words = list(word_map.values())
                with open(OUTPUT_PATH, "w") as f:
                    json.dump(updated_words, f, indent=2, ensure_ascii=False)
                print(f"    Saved ({success_count} total done)")

            # Rate limiting
            if i + args.batch_size < len(to_process):
                time.sleep(1)

        except Exception as e:
            print(f"    ERROR in batch {batch_num}: {e}")
            fail_count += len(batch)
            continue

    print(f"\n  Done: {success_count} upgraded, {fail_count} failed")


if __name__ == "__main__":
    main()
