"""
Backword Daily Word Generator
==============================

Generates 6-letter daily words for the Backword game and uploads them to Supabase.

Pipeline:
  1. Extract 6-letter words from wordfreq (frequency-ranked, mid-frequency band)
  2. Enrich with GPT-4o-mini: add clue
  3. Upload to Supabase `backword_words` table

Usage:
    python generate_backword.py --count 14                  # Generate 14 words
    python generate_backword.py --date 2026-04-07           # Start from specific date
    python generate_backword.py --dry-run                   # Generate without uploading
    python generate_backword.py --count 7 --dry-run         # Preview 7 words

Environment Variables (only needed for upload):
    SUPABASE_URL  — Your Supabase project URL
    SUPABASE_KEY  — Your Supabase service-role key (NOT anon key)
    OPENAI_API_KEY — Required for word enrichment
"""

import argparse
import json
import os
import random
import sys
import time
from datetime import date, timedelta

try:
    from wordfreq import top_n_list
    HAS_WORDFREQ = True
except ImportError:
    HAS_WORDFREQ = False

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not installed. Run: pip install openai", file=sys.stderr)
    sys.exit(1)

try:
    from supabase import create_client
except ImportError:
    create_client = None


# ── Constants ──────────────────────────────────────────────────────────────

# Mid-frequency band: common enough to know, rare enough to not be trivial.
# wordfreq top_n_list('en', N) returns words sorted by frequency descending.
# We skip the very top (too easy) and stop before very rare words.
WORDFREQ_TOP_N     = 100_000   # Pull from top 100k English words
WORDFREQ_SKIP_TOP  = 3_000     # Skip the 3k most common (trivial)
WORD_LENGTH        = 6

# Fallback seed words if wordfreq is unavailable
FALLBACK_WORDS = [
    "CASTLE", "BRIDGE", "FOREST", "PLANET", "MARKET", "SILENT",
    "FLIGHT", "WINTER", "GARDEN", "CANDLE", "MIRROR", "BRONZE",
    "SILVER", "TEMPLE", "HARBOR", "SHIELD", "VIOLET", "BREEZE",
    "GRAVEL", "LOCKET", "PILLAR", "TURKEY", "FALCON", "WALRUS",
    "LIZARD", "ORCHID", "GINGER", "PEPPER", "MANGO", "COBALT",
]


# ── Word Pool ──────────────────────────────────────────────────────────────

def build_word_pool() -> list[str]:
    """Return a deduplicated list of candidate 6-letter English words."""
    if not HAS_WORDFREQ:
        print("⚠  wordfreq not available — using fallback word list", file=sys.stderr)
        return FALLBACK_WORDS[:]

    words = top_n_list("en", WORDFREQ_TOP_N)
    candidates = []
    for word in words[WORDFREQ_SKIP_TOP:]:
        clean = word.upper()
        if (
            len(clean) == WORD_LENGTH
            and clean.isalpha()
            and clean.isascii()
        ):
            candidates.append(clean)
        if len(candidates) >= 5_000:
            break

    # Shuffle so repeated runs don't always pick same words
    random.shuffle(candidates)
    return candidates


def get_used_words(client) -> set[str]:
    """Fetch words already in the Supabase table."""
    try:
        rows = client.table("backword_words").select("word_data").execute()
        used = set()
        for row in rows.data:
            wd = row.get("word_data", {})
            if isinstance(wd, dict) and "word" in wd:
                used.add(wd["word"].upper())
        return used
    except Exception as e:
        print(f"⚠  Could not fetch used words: {e}", file=sys.stderr)
        return set()


# ── LLM Enrichment ────────────────────────────────────────────────────────

ENRICH_SYSTEM = """You are a lateral puzzle designer creating clues for a word game.
For each 6-letter English word provided, return a JSON object with:
  - "word": the word in UPPERCASE
  - "reject": true if the word must be excluded (see criteria), false otherwise
  - "clue": exactly ONE single word — an abstract association, thematic link, or lateral hint

STRICT CONSTRAINTS for "clue":
  - Must NOT be a direct synonym of the word
  - Must NOT contain any part of the root word
  - Must be a single word only
  - Should require lateral thinking to connect to the word
  - Must match the answer's grammatical form when read as a clue/answer pair:
    * base verb answers need base-form clue associations, not third-person forms
    * plural answers need plural clue associations
    * nouns, adjectives, past tense, gerunds, comparatives, and superlatives must not be crossed
    * reject or rewrite mismatches like ACHIEVE/EXCELS, DUPLICATE/CLONES, CRUELTY/UNKIND

EXAMPLES of good clues (study these carefully):
  {"word": "WAITED", "clue": "PATIENCE"}   — hints at the state of mind required
  {"word": "SILENT", "clue": "VOLUME"}     — points to the absence of the concept
  {"word": "SHIELD", "clue": "KNIGHT"}     — thematic association
  {"word": "CASTLE", "clue": "CHESS"}      — lateral connection
  {"word": "CANDLE", "clue": "FLICKER"}    — focuses on a characteristic
  {"word": "WINTER", "clue": "FROST"}      — evokes the physical reality

EXAMPLES of bad inflection matches:
  {"word": "ACHIEVE", "clue": "EXCELS"}     — EXCELS is third-person; ACHIEVE is base verb
  {"word": "DUPLICATE", "clue": "CLONES"}   — CLONES is plural/third-person; DUPLICATE is base verb or adjective
  {"word": "CRUELTY", "clue": "UNKIND"}     — UNKIND is adjective; CRUELTY is noun

REJECT a word (set "reject": true) if it is:
  - A proper noun: personal names (Sharon, Ernest), brand/company names (Schwab), place names, nationality adjectives
  - A medical condition, disease, or clinical term (Herpes, Ulcers, Fungal when used clinically)
  - Vulgar, offensive, sexual, or inappropriate for all ages
  - An abbreviation, acronym, or slang term
  - Not a standalone common English noun, verb, or adjective

If rejected, still include all fields but "clue" may be empty.
Return ONLY a JSON array, no other text."""

ENRICH_USER = """Enrich these words: {words}

Return a JSON array like:
[
  {{"word": "CASTLE", "reject": false, "clue": "CHESS"}},
  {{"word": "SHARON", "reject": true, "clue": ""}},
  ...
]"""


def enrich_words(words: list[str], model: str, api_key: str) -> list[dict]:
    """Call GPT to add category + definition to each word."""
    client = OpenAI(api_key=api_key)
    results = []
    batch_size = 20

    for i in range(0, len(words), batch_size):
        batch = words[i : i + batch_size]
        words_str = ", ".join(batch)
        print(f"  Enriching words {i+1}–{i+len(batch)}: {words_str}")

        try:
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": ENRICH_SYSTEM},
                    {"role": "user", "content": ENRICH_USER.format(words=words_str)},
                ],
                temperature=0.3,
                response_format={"type": "json_object"},
            )
            content = response.choices[0].message.content.strip()
            # GPT may wrap in an object key — try to extract the array
            parsed = json.loads(content)
            if isinstance(parsed, list):
                items = parsed
            elif isinstance(parsed, dict):
                # Find first list value
                items = next((v for v in parsed.values() if isinstance(v, list)), [])
            else:
                items = []

            for item in items:
                if (
                    isinstance(item, dict)
                    and "word" in item
                    and "clue" in item
                ):
                    item["word"] = item["word"].upper()
                    if item.get("reject"):
                        print(f"    ✗ Rejected: {item['word']}")
                    results.append(item)

        except Exception as e:
            print(f"  ⚠  Enrichment failed for batch: {e}", file=sys.stderr)
            for w in batch:
                results.append({"word": w, "clue": "UNKNOWN"})

        if i + batch_size < len(words):
            time.sleep(1)

    return results


# ── Upload ─────────────────────────────────────────────────────────────────

def upload_words(words: list[dict], start_date: date, supabase_url: str, supabase_key: str) -> int:
    """Upload enriched words to Supabase, one per day starting from start_date."""
    if create_client is None:
        print("ERROR: supabase package not installed. Run: pip install supabase", file=sys.stderr)
        return 0

    client = create_client(supabase_url, supabase_key)
    uploaded = 0

    for i, word_data in enumerate(words):
        entry_date = (start_date + timedelta(days=i)).isoformat()
        payload = {
            "date": entry_date,
            "word_data": word_data,
        }
        try:
            client.table("backword_words").insert(payload).execute()
            print(f"  ✓ {entry_date}: {word_data['word']} [{word_data.get('clue', '')}]")
            uploaded += 1
        except Exception as e:
            print(f"  ✗ Failed to upload {entry_date}: {e}", file=sys.stderr)

    return uploaded


def get_next_date(supabase_url: str, supabase_key: str) -> date:
    """Find the next available date (day after last uploaded word)."""
    if create_client is None:
        return date.today() + timedelta(days=1)

    client = create_client(supabase_url, supabase_key)
    try:
        rows = client.table("backword_words").select("date").order("date", desc=True).limit(1).execute()
        if rows.data:
            last = date.fromisoformat(rows.data[0]["date"])
            return last + timedelta(days=1)
    except Exception:
        pass
    return date.today() + timedelta(days=1)


# ── CLI ────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Generate Backword daily words")
    p.add_argument("--count",   type=int, default=7,    help="Number of words to generate (default: 7)")
    p.add_argument("--date",    type=str, default=None, help="Start date yyyy-MM-dd (default: day after last upload)")
    p.add_argument("--dry-run", action="store_true",    help="Generate without uploading to Supabase")
    p.add_argument("--model",     type=str, default="gpt-4o-mini", help="OpenAI model (default: gpt-4o-mini)")
    p.add_argument("--overwrite",  action="store_true",             help="Delete existing records for the target date range before uploading")
    return p.parse_args()


def main():
    args = parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY environment variable not set", file=sys.stderr)
        sys.exit(1)

    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_KEY")

    if not args.dry_run and (not supabase_url or not supabase_key):
        print("ERROR: SUPABASE_URL and SUPABASE_KEY required for upload (or use --dry-run)", file=sys.stderr)
        sys.exit(1)

    # Determine start date
    if args.date:
        try:
            start_date = date.fromisoformat(args.date)
        except ValueError:
            print(f"ERROR: Invalid date format '{args.date}'. Use yyyy-MM-dd", file=sys.stderr)
            sys.exit(1)
    elif not args.dry_run:
        start_date = get_next_date(supabase_url, supabase_key)
    else:
        start_date = date.today() + timedelta(days=1)

    print(f"\n📅  Start date: {start_date.isoformat()}")
    print(f"📊  Generating {args.count} words\n")

    # Build candidate pool
    print("🔍  Building word pool from wordfreq...")
    pool = build_word_pool()

    # Remove already-used words if uploading
    if not args.dry_run and supabase_url and supabase_key and create_client:
        client = create_client(supabase_url, supabase_key)
        used = get_used_words(client)
        pool = [w for w in pool if w not in used]
        print(f"    {len(pool)} candidates after removing {len(used)} already-used words")
    else:
        print(f"    {len(pool)} candidates available")

    # Over-fetch candidates (3x) to account for GPT rejections
    over_count = min(args.count * 3, len(pool))
    if over_count < args.count:
        print(f"⚠  Only {len(pool)} candidates available, requested {args.count}", file=sys.stderr)

    candidates = pool[:over_count]
    print(f"\n✏️   Enriching {over_count} candidates with GPT ({args.model}) (targeting {args.count} good words)...")
    enriched_all = enrich_words(candidates, args.model, api_key)

    # Filter out rejected words
    enriched = [w for w in enriched_all if not w.get("reject")]
    rejected_count = len(enriched_all) - len(enriched)
    if rejected_count:
        print(f"    Filtered out {rejected_count} rejected word(s), {len(enriched)} remain")

    if len(enriched) < args.count:
        print(f"⚠  Only {len(enriched)} suitable words after filtering (requested {args.count}). Consider re-running.", file=sys.stderr)

    enriched = enriched[: args.count]

    print(f"\n📝  Generated {len(enriched)} words:\n")
    for i, wd in enumerate(enriched):
        entry_date = start_date + timedelta(days=i)
        print(f"  {entry_date.isoformat()}  {wd['word']:<10} [{wd.get('clue', '')}]")
        print()

    if args.dry_run:
        print("✅  Dry run complete — nothing uploaded.")
        # Output JSON for inspection
        print("\n--- JSON output ---")
        print(json.dumps(enriched, indent=2, ensure_ascii=False))
        return

    # Optionally delete existing records for this date range
    if args.overwrite and create_client:
        client = create_client(supabase_url, supabase_key)
        end_date = (start_date + timedelta(days=len(enriched) - 1)).isoformat()
        print(f"🗑   Deleting existing records {start_date.isoformat()} – {end_date}...")
        try:
            client.table("backword_words") \
                .delete() \
                .gte("date", start_date.isoformat()) \
                .lte("date", end_date) \
                .execute()
            print("    Done.")
        except Exception as e:
            print(f"⚠  Could not delete existing records: {e}", file=sys.stderr)

    print(f"⬆️   Uploading to Supabase...")
    uploaded = upload_words(enriched, start_date, supabase_url, supabase_key)
    print(f"\n✅  Done — {uploaded}/{len(enriched)} words uploaded.")

    remaining = len(pool) - len(enriched)
    print(f"    ~{remaining} unused words remaining in pool.")
    # Output remaining count for GitHub Actions
    print(f"remaining={remaining}", flush=True)


if __name__ == "__main__":
    main()
