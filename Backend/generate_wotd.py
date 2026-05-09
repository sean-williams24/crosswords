"""
Word of the Day Generator
==========================

Generates accessible, literary-quality words and uploads them to Supabase.

Targets words an educated reader would encounter in contemporary literary
fiction or quality journalism -- slightly above everyday vocabulary, but
never requiring a dictionary. Think: sanguine, languorous, insouciant,
mercurial, quotidian.

Usage:
    python generate_wotd.py --count 90                 # Generate a quarter's worth
    python generate_wotd.py --date 2026-06-01           # Start from specific date
    python generate_wotd.py --dry-run                   # Generate without uploading
    python generate_wotd.py --purge-future              # Delete Supabase rows with date > today
    python generate_wotd.py --purge-future --dry-run    # Preview which rows would be deleted

Environment Variables (only needed for upload/purge):
    SUPABASE_URL  -- Your Supabase project URL
    SUPABASE_KEY  -- Your Supabase service-role key (NOT anon key)
    OPENAI_API_KEY -- OpenAI key for word generation
"""

import argparse
import json
import os
import sys
from datetime import date, timedelta


# ---- Supabase helpers --------------------------------------------------------

def _supabase_client():
    try:
        from supabase import create_client
    except ImportError:
        print("Install supabase: pip install supabase-py")
        sys.exit(1)

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        print("Set SUPABASE_URL and SUPABASE_KEY environment variables")
        sys.exit(1)

    return create_client(url, key)


def get_used_words() -> set[str]:
    """Fetch all words already uploaded to Supabase."""
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        return set()

    try:
        client = _supabase_client()
        rows = client.table("words_of_the_day").select("word_data").execute()
        return {
            r["word_data"]["word"]
            for r in rows.data
            if r.get("word_data") and isinstance(r["word_data"], dict) and r["word_data"].get("word")
        }
    except Exception as e:
        print(f"  Warning: could not fetch used words: {e}")
        return set()


def purge_future_words(dry_run: bool = False):
    """Delete all Supabase rows where date > today."""
    today = date.today().isoformat()

    if dry_run:
        url = os.environ.get("SUPABASE_URL")
        key = os.environ.get("SUPABASE_KEY")
        if not url or not key:
            print("Set SUPABASE_URL and SUPABASE_KEY to preview purge.")
            return
        client = _supabase_client()
        rows = (
            client.table("words_of_the_day")
            .select("date, word_data")
            .gt("date", today)
            .order("date")
            .execute()
        )
        if not rows.data:
            print("  No future-dated rows found -- nothing to purge.")
        else:
            print(f"  [dry-run] Would delete {len(rows.data)} rows:")
            for r in rows.data:
                word = r.get("word_data", {}).get("word", "?")
                print(f"    {r['date']}  {word}")
        return

    client = _supabase_client()
    result = client.table("words_of_the_day").delete().gt("date", today).execute()
    count = len(result.data) if result.data else 0
    print(f"  Purged {count} future-dated rows from words_of_the_day.")


# ---- LLM word generation -----------------------------------------------------

_SYSTEM_PROMPT = (
    "You are a vocabulary curator for a daily word feature in a literary-minded iOS app. "
    "Your job is to select words that strike the perfect balance: slightly elevated above "
    "everyday speech, but familiar enough that an educated person could plausibly use them "
    "tomorrow. The target register is contemporary literary fiction and quality long-form "
    "journalism -- writers like Madeleine Gray, Sally Rooney, Zadie Smith, or columnists in "
    "The Guardian or The Atlantic.\n\n"
    "GOOD examples of the right level:\n"
    "  sanguine, languorous, insouciant, mercurial, quotidian, pernicious, effusive,\n"
    "  loquacious, ephemeral, wistful, tenuous, laconic, melancholy,\n"
    "  voluble, perfunctory, plaintive, reticent, candour, luminous, verdant, hapless\n\n"
    "FORBIDDEN -- do NOT include:\n"
    "  - Words coined by John Koenig's Dictionary of Obscure Sorrows (sonder, vellichor, chrysalism...)\n"
    "  - Extremely rare or dead words that virtually no contemporary author uses\n"
    "    (apricity, psithurism, aeipathy, mamihlapinatapai...)\n"
    "  - Technical jargon or scientific terms used only in specialist contexts\n"
    "  - Foreign loanwords so unassimilated that most English speakers would need a translation\n\n"
    "The word should feel like something a reader might underline in a novel, think "
    '"I should use that more", and actually be able to slip into a conversation the next day.'
)

_USER_PROMPT_TEMPLATE = (
    "Generate {count} Word of the Day entries.\n\n"
    "Already-used words to exclude (do NOT repeat any of these): {exclude_list}\n\n"
    "Rules:\n"
    "- Each word must be unique — no word may appear more than once in the array.\n"
    "- Spell every word correctly. Double-check before including it.\n"
    "- Do not include any word from the exclusion list above.\n\n"
    "For each word return a JSON object with exactly these fields:\n"
    "- word (string, title case)\n"
    "- pronunciation (string, e.g. \"SANG-gwin\")\n"
    "- partOfSpeech (string, e.g. \"adjective\")\n"
    "- definition (string, clear and engaging, 1-2 sentences)\n"
    "- etymology (string, interesting origin story, 1-2 sentences)\n"
    "- synonyms (array of 2-3 strings, plain everyday synonyms)\n"
    "- exampleSentence (string, natural usage in a sentence that could appear in contemporary fiction)\n\n"
    "Return ONLY a JSON array of {count} objects, no other text."
)


def generate_words_with_llm(count: int, used_words: set[str]) -> list[dict]:
    """Use GPT-4o-mini to generate WOTD entries."""
    try:
        import openai
    except ImportError:
        print("  openai package not installed -- run: pip install openai")
        sys.exit(1)

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("  OPENAI_API_KEY not set")
        sys.exit(1)

    client = openai.OpenAI(api_key=api_key)
    # Keep exclusion list to 100 words max to avoid inflating the prompt
    exclude_sample = sorted(used_words)[:100]
    exclude_list = ", ".join(exclude_sample) if exclude_sample else "none yet"

    prompt = _USER_PROMPT_TEMPLATE.format(count=count, exclude_list=exclude_list)

    print(f"  Calling GPT-4o-mini for {count} words...")
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
        temperature=0.85,
    )

    content = response.choices[0].message.content or ""
    if "```json" in content:
        content = content.split("```json")[1].split("```")[0]
    elif "```" in content:
        content = content.split("```")[1].split("```")[0]

    try:
        result = json.loads(content.strip())
        if isinstance(result, list):
            print(f"  LLM returned {len(result)} words")
            return result
        print(f"  LLM response was not a list: {type(result)}")
    except Exception as e:
        print(f"  LLM response parse error: {e}")
        print(f"  Raw response:\n{content[:500]}")

    return []


def get_words(count: int, batch_size: int, exclude_used: bool = True) -> list[dict]:
    """Generate `count` unique, correctly-spelled words via LLM in batches of `batch_size`."""
    used = get_used_words() if exclude_used else set()

    all_words: list[dict] = []

    while len(all_words) < count:
        needed = count - len(all_words)
        batch = min(needed, batch_size)

        # Pass all already-accepted words as the exclusion set so the LLM
        # never repeats a word — both from Supabase and from this run.
        accepted_lower = {w["word"].lower() for w in all_words}
        exclude = used | {w["word"] for w in all_words}
        words = generate_words_with_llm(batch, exclude)

        if not words:
            print("ERROR: LLM generation failed.")
            sys.exit(1)

        # Filter duplicates from this batch (case-insensitive) before accepting
        for w in words:
            if len(all_words) >= count:
                break
            word_key = w.get("word", "").lower()
            if not word_key:
                continue
            if word_key in accepted_lower or word_key in {u.lower() for u in used}:
                print(f"  Skipping duplicate from LLM response: '{w.get('word')}'")
                continue
            all_words.append(w)
            accepted_lower.add(word_key)

    # Write generated count to GITHUB_OUTPUT if running in CI
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as f:
            f.write(f"generated={len(all_words)}\n")

    return all_words


# ---- Supabase Upload ---------------------------------------------------------

def upload_to_supabase(payload: dict):
    """Upload a word of the day to Supabase."""
    client = _supabase_client()
    result = client.table("words_of_the_day").insert(payload).execute()
    print(f"  Uploaded WOTD for {payload['date']}: {payload['word_data']['word']}")
    return result


# ---- CLI ---------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Generate Words of the Day")
    parser.add_argument(
        "--count", type=int, default=90,
        help="Number of words to generate (default: 90, roughly one quarter)",
    )
    parser.add_argument(
        "--batch-size", type=int, default=30,
        help="Words per LLM call (default: 30)",
    )
    parser.add_argument("--date", type=str, help="Start date (YYYY-MM-DD)")
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Generate without uploading (also used with --purge-future to preview)",
    )
    parser.add_argument(
        "--purge-future", action="store_true",
        help="Delete Supabase rows with date > today, then exit",
    )
    parser.add_argument(
        "--output", type=str,
        help="Save JSON files to this directory",
    )
    args = parser.parse_args()

    if args.purge_future:
        purge_future_words(dry_run=args.dry_run)
        return

    start_date = date.fromisoformat(args.date) if args.date else date.today() + timedelta(days=1)

    words = get_words(args.count, args.batch_size, exclude_used=not args.dry_run)

    print(f"\nGenerating {args.count} WOTDs starting from {start_date.isoformat()}")

    for i, word_data in enumerate(words):
        word_date = start_date + timedelta(days=i)
        payload = {
            "date": word_date.isoformat(),
            "word_data": word_data,
        }

        print(f"  [{i + 1}/{args.count}] {word_data.get('word', '?')} for {word_date.isoformat()}")

        if args.output:
            from pathlib import Path
            out_dir = Path(args.output)
            out_dir.mkdir(parents=True, exist_ok=True)
            out_file = out_dir / f"wotd_{word_date.isoformat()}.json"
            with open(out_file, "w") as f:
                json.dump(payload, f, indent=2)
            print(f"    Saved to {out_file}")

        if not args.dry_run:
            upload_to_supabase(payload)

    print("Done!")


if __name__ == "__main__":
    main()
