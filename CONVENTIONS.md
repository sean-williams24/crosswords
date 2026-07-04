# App Conventions

Key logic decisions, rules, and non-obvious behaviours across the codebase. Add a section whenever a meaningful decision is made that future contributors (or AI) should understand.

---

## Crossword Configuration & Word Repeat Prevention

### Daily crossword (9×9)

- **Grid:** 9×9, ~15 clues, `is_free: true`
- **Generator:** `Backend/generate_puzzle.py`
- **Clue selection:** uses `text` as the main clue; picks randomly from `clues[]` as the in-game hint (falls back to `hint` if `clues` is empty).
- **Scheduling:** generated weekly in batches of 7 via the `generate-puzzles` GitHub Actions workflow.

### Weekly crossword (13×13)

- **Grid:** 13×13, ~35 clues, `is_free: false` (pro-only)
- **Generator:** `Backend/generate_weekly_puzzle.py`
- **Clue selection:** picks randomly from `clues[]` as the main clue (falls back to `text`); uses `hard_text` as the in-game hint (falls back to `hint`).
- **Scheduling:** generated in batches of 10 via the `generate-weekly-puzzles` GitHub Actions workflow, triggered every Monday at 06:00 UTC. Weekly puzzle row dates are Sunday release dates, and generation is skipped if 5+ future weekly rows already exist in Supabase.

### Word repeat prevention

Both generators share the same exclusion mechanism to avoid repeating answers across puzzles.

**At generation time (via `--exclude-words`):**
- The GitHub Actions workflow fetches an exclusion list from Supabase before calling the generator:
  - **Weekly generator:** last 13 weekly puzzles only (from `weekly_puzzles` table). Daily puzzle words are intentionally *not* excluded — cross-excluding them depletes the small short-word bank (only ~289 3-letter words) and causes the 13×13 solver to fail to find valid fills.
  - **Daily generator:** last 90 daily puzzles + last 13 weekly puzzles (from both tables).
- Answers are extracted from each puzzle's `clues` array, uppercased, deduplicated, and written to a temporary JSON file (`/tmp/used_words.json`).
- The file is passed via `--exclude-words`, which strips matching words from the word bank before the constraint solver runs.

**Within a batch run:**
- Each puzzle in a batch records its answers into a `batch_used` set.
- Every subsequent puzzle in the same batch adds `batch_used` to the exclusion set, so no word appears twice within a single generation run regardless of the Supabase history.

## Crossword Correct Highlight Locking

When `AppSettings.crosswordCorrectHighlight` is enabled, cells belonging to completed crossword clues are treated as locked input. `GameViewModel` must reject deletion and typed replacement for those cells, because the green highlight is the user's signal that the answer has been accepted and should no longer be editable. Retyping the same letter already in a locked cell is allowed as navigation input and advances to the next cell without changing the answer.

When the setting is disabled, completed cells remain editable and deletable for the harder non-locking experience.

---

## Archive Month Caching

The archive loads playable full-game payloads by release-calendar month, not metadata-only rows. The current month is fetched when the archive opens; older months are fetched lazily when the user expands them. Each fetched month is cached by game type and `yyyy-MM` key so previously opened months remain playable offline.

Do not fetch the full year of archive game payloads up front. A lightweight month index is acceptable, but full puzzle/Backword data should stay month-scoped.

---

## Timezone & Date Handling

### Puzzle dates are plain calendar dates

All puzzle dates are stored and queried as plain `yyyy-MM-dd` strings with no time or timezone component. Supabase stores them as a Postgres `date` column. The `lte` filter in queries is a pure calendar-date string comparison — no timestamp arithmetic involved.

### Local release calendar as canonical "today"

All services (`PuzzleService`, `WOTDService`, `BackwordService`, `OverallRatingService`) derive active release dates from `ContentReleaseCalendar`, using the device timezone:

- Daily content flips at **local midnight**.
- Weekly crossword flips at **local Sunday midnight**.
- Date strings remain plain `yyyy-MM-dd` values and are used directly in Supabase `date` filters and cache keys.

This means US, Canada, Europe, and Australia each see the puzzle for their own local calendar day. Australian users no longer wait until UTC midnight reaches their morning.

### Midnight refresh task (`HomeView`)

`HomeView` runs a background `Task` that sleeps until local midnight then triggers a full refresh of all content. The same local-midnight refresh also loads a new weekly puzzle when the user's local calendar reaches Sunday:

```swift
private func secondsUntilMidnight() -> TimeInterval? {
    ContentReleaseCalendar().secondsUntilDailyRefresh()
}
```

### "TODAY" label (`RatingDetailSheet`)

Scores are stored against local release-calendar date keys, and the "TODAY" label uses the same `ContentReleaseCalendar` date:

```swift
let isToday = day.date == ContentReleaseCalendar().dailyDateString
```

### Formatter reference table

| Use case | Timezone |
|---|---|
| Querying Supabase / cache keys | Local release calendar |
| Storing scores (`OverallRating`) | Local release calendar |
| "TODAY" label detection | Local release calendar |
| Human-readable date strings (e.g. "Wed, May 6") | Local (DateFormatter default) |

---

## Word Bank

### Structure

`Backend/word_bank.json` is a JSON array of objects. Each object represents one crossword answer:

```json
{
    "word": "LESLIE",
    "text": "Common female first name.",
    "hint": "Parks and Recreation character",
    "hard_text": "A female name, perhaps less than a lot.",
    "clues": [
        "Famous actress, first name only.",
        "Name of a character in 'The Parent Trap'.",
        "Knope of Pawnee, familiarly"
    ]
}
```

### How each field is used

| Field | Used by | Purpose |
|---|---|---|
| `word` | Everything | The answer (always uppercase) |
| `clues` | `generate_puzzle.py` | **Primary clue source.** One item is randomly selected at puzzle-generation time and becomes the `text` field in the final puzzle JSON. Randomisation means the same word can have different clues across puzzles. |
| `hard_text` | `generate_puzzle.py` | Fallback clue if `clues[]` is empty or missing. |
| `text` | `generate_puzzle.py` | Last-resort fallback if both `clues[]` and `hard_text` are absent. |
| `hint` | `GameViewModel` | Shown to the user when they tap the hint button in-game (costs hint tokens). Should give **genuinely new context** not already present in the clue — e.g. a category, a cultural reference, or a synonym. Never just a generic label like "name" when the clue already says it's a name. |

### Clue selection logic

**Daily (`generate_puzzle.py`):**
```python
clue_variants = entry.get("clues", [])
text = entry["text"]                                          # always the main clue
hint = rng.choice(clue_variants) if clue_variants else entry.get("hint", "")
```

**Weekly (`generate_weekly_puzzle.py`):**
```python
clue_variants = entry.get("clues", [])
text = rng.choice(clue_variants) if clue_variants else entry["text"]   # random pick from clues[]
hint = entry.get("hard_text", entry.get("hint", ""))                   # hard_text as hint
```

### Answer leakage rule

**No clue or hint field may contain the answer word (case-insensitive, whole-word match).** For multi-word answers (e.g. `ICE CREAM`), constituent words ≥ 3 characters are also checked individually.

Run `Backend/fix_answer_leakage.py` to scan for violations and regenerate affected fields via OpenAI. All clue-generation scripts (`clean_word_bank.py`, `upgrade_clues.py`, `expand_short_words.py`) enforce this rule at generation time via `_leaks_answer()`.

### Inflection review workflow

Clues should resolve to the exact stored answer form: tense, number, inflection, and part of speech should match the `word` value. Review suspected mismatches with:

```bash
python3 Backend/audit_word_bank_inflections.py sample --count 50
python3 Backend/audit_word_bank_inflections.py export
python3 Backend/audit_word_bank_inflections.py apply --input Backend/word_bank_inflection_replacements.json
```

`sample` and `export` are review-only and never modify `word_bank.json`. The full bank should only be changed by applying an approved replacement file.

Backword uses the same review-first pattern for existing Supabase rows:

```bash
python3 Backend/audit_backword_inflections.py export
python3 Backend/audit_backword_inflections.py apply --input Backend/backword_inflection_replacements.json
```

### Backword clue semantic fit

Backword clues are one-word lateral associations, but they must still be directly defensible for the exact answer. Do not use adjacent-process clues where the answer is only a stage, participant, result, product, tool, container, or neighboring concept of the clue. For example, `LARVAE` should not be clued as `TRANSFORMATION`: larvae are a stage within metamorphosis, not transformation itself.

---

## Backend Python Scripts

The `Backend/` folder is organised into two tiers:

### Active scripts (tracked in git)

**Automated — run by GitHub Actions workflows (Monday cron):**

| Script | Workflow | Purpose |
|---|---|---|
| `generate_puzzle.py` | `generate-puzzles.yml` | Generates 7 daily crossword puzzles and uploads to Supabase |
| `generate_weekly_puzzle.py` | `generate-weekly-puzzles.yml` | Generates 10 weekly 13×13 puzzles when < 5 remain queued |
| `generate_wotd.py` | `generate-wotd.yml` | Generates 7 Words of the Day and uploads to Supabase |
| `generate_backword.py` | `generate-backword.yml` | Generates 7 Backword words and uploads to Supabase |

**Utility — run manually as needed:**

| Script | Purpose |
|---|---|
| `clean_word_bank.py` | Filter obscure words and generate clues for placeholder entries via LLM |
| `upgrade_clues.py` | Regenerate `clues[]` / `hard_text` for existing entries using a harder clue style |
| `expand_short_words.py` | Add high-frequency 3/4-letter words from the macOS system dictionary |
| `expand_validated.py` | Expand the word bank with GPT-validated candidates |
| `recategorise_backword.py` | Recategorise Backword word candidates (e.g. after scoring changes) |
| `fix_answer_leakage.py` | Scan for and fix answer leakage / redundant hints across all word bank entries |
| `upload_weekly_puzzles.py` | Manually upload pre-generated weekly puzzle JSON files to Supabase |
| `validate_puzzles.py` | Validate generated puzzles have no 2-cell runs |

### Archive scripts (`Backend/archive/`)

Historical one-off scripts kept for reference. These were used during initial development to generate crossword grid templates, iterate on solvers, and perform bulk word bank expansions. They are not tracked by git and should not be run without understanding their specific context.

Categories in `archive/`:
- **Template generation** — `gen_templates_*.py`, `gen_weekly_templates_*.py`, `generate_templates.py`, `craft_templates.py`
- **Solver testing** — `test_11x11_solver.py`, `test_13x13_solver.py`, `test_solver_quick.py`, `test_templates.py`, `test_weekly_solver.py`
- **Template validation/diagnostics** — `validate_templates.py`, `validate_weekly_templates.py`, `verify_templates.py`, `check_weekly_templates.py`, `diagnose_weekly.py`, `diag_13x13.py`
- **One-off word bank expansions** — `add_*.py`, `expand_word_bank.py`, `expand_word_bank_v2.py`, `upgrade_word_bank.py`, `restore_kept.py`
- **Miscellaneous** — `generate_icon.py`, `generate_puzzle_old.py`, `check_status.py`

---

## StoreKit Subscription State

`StoreService.purchase(_:)` returns an explicit purchase outcome. A verified monthly or annual transaction grants Pro immediately before finishing the transaction, so the paywall does not depend on `Transaction.currentEntitlements` refreshing synchronously before dismissal.

`updateSubscriptionStatus()` remains the source of truth for launch, renewal, revocation, expiration, and transaction-update refreshes. Entitlements only grant Pro when the product ID is one of the known subscription IDs, the transaction is not revoked, and its expiration date is either absent or in the future. Restore first trusts an already-visible active entitlement before calling `AppStore.sync()`, then checks entitlements again after sync only if needed.

In DEBUG builds, the Pro override is intentionally authoritative while set. `updateSubscriptionStatus()` must respect the override and return early; use the debug settings reset action to clear the override and re-check StoreKit.

Debug builds may also simulate one-shot pending purchase and restore outcomes from Debug Settings. These are UI test hooks only and must remain behind `#if DEBUG`.

Debug entitlement dumps may inspect `Transaction.currentEntitlements` and print details to the console to diagnose StoreKit restore issues. This diagnostic path must remain behind `#if DEBUG` and must not alter subscription state.

---

## Ads

Ads are served via Google AdMob and managed by `AdService`. Free-tier users only.

### Ad formats

| Format | Type | Purpose |
|---|---|---|
| Interstitial | `InterstitialAd` | Shown at natural transition points (game open, WOTD dismiss) |
| Rewarded | `RewardedAd` | Shown when the user requests a hint clue |

### Test IDs (DEBUG builds)

| Format | Test unit ID |
|---|---|
| Interstitial | `ca-app-pub-3940256099942544/4411468910` |
| Rewarded | `ca-app-pub-3940256099942544/1712485313` |

The test IDs must match the ad format exactly — using a Rewarded Interstitial ID for an `InterstitialAd.load(...)` call (or vice versa) will produce an "Ad unit doesn't match format" error at runtime.

### Once-per-day interstitial rule

Interstitials are shown **at most once per calendar day per slot** using `showInterstitialOnce(slot:)`. The method stores the last-shown date in `UserDefaults` under the key `AdService.lastShown.<slot>` and no-ops if the current day already has a recorded impression.

Current slots:

| Slot | Trigger |
|---|---|
| `daily_puzzle_open` | Free user navigates to the daily crossword for the first time today |
| `backword_open` | Free user navigates to Backword for the first time today |
| `wotd_dismiss` | Free user dismisses the WOTD sheet for the first time today |

Slots are independent — each resets at the next calendar midnight (device local time, via `Calendar.current`).

### Full-screen ad recovery

`AdService` treats a full-screen ad with no dismiss/failure callback after 45 seconds as possibly stuck. The watchdog logs `possible_stuck`, clears the app's in-progress presentation state, dismisses the visible Google ad controller if it is still top-most, and reloads the affected ad format. For once-per-day interstitials, the original continuation is allowed to proceed during this recovery so users are not trapped behind a missing SDK callback.

Avoid starting home-screen refresh work while `adService.isPresentingFullScreenAd` is true. Full-screen ads are SDK-owned view controllers, and unrelated SwiftUI/TipKit presentation churn while they are active can make lifecycle and touch handling harder to reason about.
