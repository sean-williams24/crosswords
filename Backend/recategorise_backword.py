"""
Recategorise Backword words currently tagged as "Other".

Fetches all rows from Supabase with category == "Other", asks GPT to assign a
proper category from the allowed list, then patches each row in-place.

Usage:
    python recategorise_backword.py           # Live run (updates Supabase)
    python recategorise_backword.py --dry-run # Preview only, no writes

Environment variables (from .env):
    SUPABASE_URL      — Supabase project URL
    SUPABASE_KEY      — Service-role key
    OPENAI_API_KEY    — OpenAI key
"""

import argparse
import json
import os
import sys

from openai import OpenAI
import requests

# ── Categories ────────────────────────────────────────────────────────────

VALID_CATEGORIES = [
    "Animal", "Food", "Nature", "Sport", "Music", "Science",
    "Travel", "Fashion", "History", "Body", "Weather", "Art",
    "Technology", "Business", "Literature", "Culture", "Language",
    # NOTE: "Other" is intentionally excluded — we want a real category for every word.
]

SYSTEM_PROMPT = """\
You are a word-classification assistant. For each word provided, assign the single
most fitting category from this list (pick the BEST match — do NOT use Other):

Animal, Food, Nature, Sport, Music, Science, Travel, Fashion, History, Body,
Weather, Art, Technology, Business, Literature, Culture, Language

Return ONLY a JSON array, no other text. Each element must have:
  "word"       — the word (uppercase)
  "category"   — one of the categories above
  "definition" — a short, clear one-sentence definition (max 15 words)

Example:
[
  {"word": "CASTLE",  "category": "History",  "definition": "A large medieval fortified building."},
  {"word": "BREECH",  "category": "Fashion",  "definition": "Short trousers fastened just below the knee."}
]"""

USER_PROMPT = "Classify these words:\n{words}"


# ── Supabase helpers ──────────────────────────────────────────────────────

def get_other_rows(base_url: str, api_key: str) -> list[dict]:
    """Return all backword_words rows whose word_data.category == 'Other'."""
    url = f"{base_url}/rest/v1/backword_words?select=id,date,word_data&order=date.asc"
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}",
    }
    r = requests.get(url, headers=headers)
    r.raise_for_status()
    rows = r.json()
    return [row for row in rows if row["word_data"].get("category") == "Other"]


def patch_row(base_url: str, api_key: str, row_id: str, word_data: dict) -> None:
    """PATCH a single row's word_data in Supabase."""
    url = f"{base_url}/rest/v1/backword_words?id=eq.{row_id}"
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    r = requests.patch(url, headers=headers, json={"word_data": word_data})
    r.raise_for_status()


# ── GPT enrichment ────────────────────────────────────────────────────────

def recategorise(words: list[str], api_key: str) -> dict[str, dict]:
    """
    Returns a mapping of WORD -> {"category": ..., "definition": ...}
    for each word in the input list.
    """
    client = OpenAI(api_key=api_key)
    words_str = ", ".join(words)
    print(f"  Asking GPT to categorise: {words_str}")

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": USER_PROMPT.format(words=words_str)},
        ],
        temperature=0.2,
        response_format={"type": "json_object"},
    )

    content = response.choices[0].message.content.strip()
    parsed = json.loads(content)

    # GPT may wrap the array in an object key
    if isinstance(parsed, list):
        items = parsed
    elif isinstance(parsed, dict):
        items = next((v for v in parsed.values() if isinstance(v, list)), [])
    else:
        items = []

    result = {}
    for item in items:
        if isinstance(item, dict) and "word" in item and "category" in item:
            word = item["word"].upper()
            category = item["category"]
            if category not in VALID_CATEGORIES:
                print(f"  ⚠  GPT returned invalid category '{category}' for {word}, defaulting to Nature")
                category = "Nature"
            result[word] = {
                "category": category,
                "definition": item.get("definition", ""),
            }
    return result


# ── Main ──────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Recategorise Backword 'Other' words")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing to Supabase")
    args = parser.parse_args()

    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_KEY")
    openai_key   = os.environ.get("OPENAI_API_KEY")

    if not supabase_url or not supabase_key:
        print("ERROR: SUPABASE_URL and SUPABASE_KEY must be set", file=sys.stderr)
        sys.exit(1)
    if not openai_key:
        print("ERROR: OPENAI_API_KEY must be set", file=sys.stderr)
        sys.exit(1)

    print("Fetching rows with category == 'Other'...")
    rows = get_other_rows(supabase_url, supabase_key)
    print(f"Found {len(rows)} row(s) to recategorise.\n")

    if not rows:
        print("Nothing to do.")
        return

    words = [row["word_data"]["word"].upper() for row in rows]
    classifications = recategorise(words, openai_key)

    print()
    updated = 0
    for row in rows:
        word = row["word_data"]["word"].upper()
        date = row["date"]
        hit = classifications.get(word)
        if not hit:
            print(f"  ✗ No result from GPT for {word} ({date}) — skipping")
            continue

        new_word_data = dict(row["word_data"])
        new_word_data["category"] = hit["category"]
        if hit["definition"]:
            new_word_data["definition"] = hit["definition"]

        print(f"  {'[DRY RUN] ' if args.dry_run else ''}{date}: {word}  Other → {hit['category']}")
        if hit["definition"]:
            print(f"           definition: {hit['definition']}")

        if not args.dry_run:
            patch_row(supabase_url, supabase_key, row["id"], new_word_data)
            updated += 1

    print()
    if args.dry_run:
        print("Dry run complete — no changes written.")
    else:
        print(f"Done. Updated {updated}/{len(rows)} rows.")


if __name__ == "__main__":
    main()
