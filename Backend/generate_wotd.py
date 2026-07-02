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
    "The following words show the approximate level, but they are overused WOTD cliches. "
    "They are examples of register only, and must NOT be returned:\n"
    "  sanguine, languorous, insouciant, mercurial, quotidian, pernicious, effusive,\n"
    "  loquacious, ephemeral, wistful, tenuous, laconic, melancholy,\n"
    "  voluble, perfunctory, plaintive, reticent, candour, luminous, verdant, hapless\n\n"
    "Prefer useful, underused contemporary words from ordinary life, criticism, relationships, "
    "work, politics, weather, cities, domestic detail, art, memory, movement, and perception. "
    "Avoid SAT-list staples and thesaurus-showoff words.\n\n"
    "FORBIDDEN -- do NOT include:\n"
    "  - Any word listed above as a register example\n"
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
    "This batch theme: {theme}\n\n"
    "Already-used words to exclude (do NOT repeat any of these): {exclude_list}\n\n"
    "Rules:\n"
    "- Each word must be unique — no word may appear more than once in the array.\n"
    "- Spell every word correctly. Double-check before including it.\n"
    "- Do not include any word from the exclusion list above.\n\n"
    "- Avoid familiar Word-of-the-Day staples even when they fit the theme.\n"
    "- Prefer words a reader may know passively but not reach for often.\n\n"
    "For each word return a JSON object with exactly these fields:\n"
    "- word (string, title case)\n"
    "- pronunciation (string, e.g. \"SANG-gwin\")\n"
    "- partOfSpeech (string, e.g. \"adjective\")\n"
    "- definition (string, clear and engaging, 1-2 sentences)\n"
    "- etymology (string, interesting origin story, 1-2 sentences)\n"
    "- synonyms (array of 2-3 strings, plain everyday synonyms)\n"
    "- exampleSentence (string, natural usage in a sentence that could appear in contemporary fiction)\n\n"
    "Return ONLY a JSON object with a \"words\" array containing {count} objects, no other text."
)


WOTD_CLICHE_WORDS = {
    "adept",
    "aplomb",
    "auspicious",
    "benevolent",
    "cacophony",
    "candid",
    "candor",
    "candour",
    "cognizant",
    "dichotomy",
    "disparate",
    "ebullient",
    "effulgent",
    "effusive",
    "ephemeral",
    "epiphany",
    "furtive",
    "garrulous",
    "gregarious",
    "hapless",
    "ineffable",
    "insouciant",
    "juxtaposition",
    "laconic",
    "lacuna",
    "languid",
    "languorous",
    "lament",
    "loquacious",
    "luminous",
    "melancholy",
    "mellifluous",
    "mercurial",
    "nostalgia",
    "obfuscate",
    "perfunctory",
    "pernicious",
    "pensive",
    "plaintive",
    "quintessential",
    "quixotic",
    "quotidian",
    "recalcitrant",
    "resilient",
    "reticent",
    "sagacious",
    "sanguine",
    "serendipity",
    "soporific",
    "sycophant",
    "taciturn",
    "tenacious",
    "tenuous",
    "transcendent",
    "trepidation",
    "ubiquitous",
    "vicarious",
    "voluble",
    "voracious",
    "wistful",
    "zealous",
}

WOTD_THEMES = [
    "emotional texture and subtle moods",
    "social behavior, conversation, and manners",
    "argument, writing, criticism, and rhetoric",
    "attention, perception, memory, and thought",
    "movement, change, hesitation, and effort",
    "weather, nature, light, and the built environment",
    "work, institutions, politics, and public life",
    "domestic life, objects, habits, and small rituals",
    "art, taste, style, and performance",
    "relationships, obligation, intimacy, and distance",
    "risk, judgment, uncertainty, and consequence",
    "city life, travel, crowds, and solitude",
]

REQUIRED_WORD_FIELDS = {
    "word",
    "pronunciation",
    "partOfSpeech",
    "definition",
    "etymology",
    "synonyms",
    "exampleSentence",
}


def words_from_response(content: str) -> list[dict]:
    """Parse WOTD entries from either the current object shape or the old array shape."""
    if "```json" in content:
        content = content.split("```json", 1)[1].split("```", 1)[0]
    elif "```" in content:
        content = content.split("```", 1)[1].split("```", 1)[0]

    result = json.loads(content.strip())
    if isinstance(result, list):
        return [item for item in result if isinstance(item, dict)]
    if isinstance(result, dict):
        words = result.get("words", [])
        if isinstance(words, list):
            return [item for item in words if isinstance(item, dict)]
    return []


def is_valid_word_entry(word_data: dict) -> bool:
    """Return true when an LLM entry has the fields the app expects."""
    if not REQUIRED_WORD_FIELDS.issubset(word_data):
        return False
    if not isinstance(word_data.get("synonyms"), list):
        return False
    return bool(str(word_data.get("word", "")).strip())


def theme_for_attempt(attempt: int) -> str:
    """Return a rotating theme to keep WOTD batches from collapsing into one vocabulary cluster."""
    return WOTD_THEMES[(attempt - 1) % len(WOTD_THEMES)]


def generate_words_with_llm(
    count: int,
    used_words: set[str],
    max_retries: int = 3,
    theme: str = "general contemporary vocabulary",
) -> list[dict]:
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
    exclude_list = ", ".join(sorted(used_words, key=str.lower)) if used_words else "none yet"

    prompt = _USER_PROMPT_TEMPLATE.format(
        count=count,
        exclude_list=exclude_list,
        theme=theme,
    )

    for attempt in range(1, max_retries + 1):
        print(f"  Calling GPT-4o-mini for {count} words (try {attempt}/{max_retries})...")
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            temperature=0.7,
            response_format={"type": "json_object"},
        )

        content = response.choices[0].message.content or ""
        try:
            words = words_from_response(content)
            if words:
                print(f"  LLM returned {len(words)} words")
                return words
            print("  LLM response did not contain a words array")
        except Exception as e:
            print(f"  LLM response parse error: {e}")
            print(f"  Raw response:\n{content[:500]}")

    return []


def get_words(
    count: int,
    batch_size: int,
    exclude_used: bool = True,
    max_attempts: int = 16,
    llm_retries: int = 3,
) -> list[dict]:
    """Generate `count` unique, correctly-spelled words via LLM in batches of `batch_size`."""
    used = get_used_words() if exclude_used else set()
    blocked_lower = {word.lower() for word in WOTD_CLICHE_WORDS}

    all_words: list[dict] = []
    used_lower = {word.lower() for word in used} | blocked_lower

    for attempt in range(1, max_attempts + 1):
        if len(all_words) >= count:
            break
        needed = count - len(all_words)
        batch = min(count, batch_size)

        # Pass all already-accepted words as the exclusion set so the LLM
        # never repeats a word — both from Supabase and from this run.
        accepted_lower = {w["word"].lower() for w in all_words}
        exclude = used | WOTD_CLICHE_WORDS | {w["word"] for w in all_words}
        theme = theme_for_attempt(attempt)
        print(f"  Attempt {attempt}/{max_attempts}: need {needed} more WOTDs ({theme})")
        words = generate_words_with_llm(batch, exclude, max_retries=llm_retries, theme=theme)

        if not words:
            print("  No parseable words returned for this attempt.")
            continue

        # Filter duplicates from this batch (case-insensitive) before accepting
        for w in words:
            if len(all_words) >= count:
                break
            word_key = w.get("word", "").lower()
            if not word_key:
                continue
            if not is_valid_word_entry(w):
                print(f"  Skipping malformed WOTD entry: '{w.get('word', '?')}'")
                continue
            if word_key in blocked_lower:
                print(f"  Skipping overused WOTD staple: '{w.get('word')}'")
                continue
            if word_key in accepted_lower or word_key in used_lower:
                print(f"  Skipping duplicate from LLM response: '{w.get('word')}'")
                continue
            all_words.append(w)
            accepted_lower.add(word_key)

        print(f"  Accepted {len(all_words)}/{count} WOTDs so far")

    if len(all_words) < count:
        print(
            f"ERROR: Only generated {len(all_words)}/{count} unique WOTDs "
            f"after {max_attempts} attempt(s). No words were uploaded.",
            file=sys.stderr,
        )
        sys.exit(1)

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
        "--batch-size", type=int, default=60,
        help="Words per LLM call (default: 60)",
    )
    parser.add_argument(
        "--max-attempts", type=int, default=16,
        help="Maximum generation batches before failing (default: 16)",
    )
    parser.add_argument(
        "--llm-retries", type=int, default=3,
        help="Retries for malformed LLM JSON per batch (default: 3)",
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

    if args.count <= 0:
        print("ERROR: --count must be greater than 0", file=sys.stderr)
        sys.exit(1)

    if args.batch_size <= 0:
        print("ERROR: --batch-size must be greater than 0", file=sys.stderr)
        sys.exit(1)

    if args.max_attempts <= 0:
        print("ERROR: --max-attempts must be greater than 0", file=sys.stderr)
        sys.exit(1)

    if args.llm_retries <= 0:
        print("ERROR: --llm-retries must be greater than 0", file=sys.stderr)
        sys.exit(1)

    start_date = date.fromisoformat(args.date) if args.date else date.today() + timedelta(days=1)

    words = get_words(
        args.count,
        args.batch_size,
        exclude_used=not args.dry_run,
        max_attempts=args.max_attempts,
        llm_retries=args.llm_retries,
    )

    print(f"\nGenerating {args.count} WOTDs starting from {start_date.isoformat()}")

    uploaded = 0
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
            uploaded += 1

    if not args.dry_run and uploaded != args.count:
        print(
            f"ERROR: Uploaded {uploaded}/{args.count} requested WOTDs.",
            file=sys.stderr,
        )
        sys.exit(1)

    print("Done!")


if __name__ == "__main__":
    main()
