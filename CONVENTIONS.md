# App Conventions

Key logic decisions, rules, and non-obvious behaviours across the codebase. Add a section whenever a meaningful decision is made that future contributors (or AI) should understand.

---

## Crossword Configuration & Word Repeat Prevention

### Daily crossword (9×9)

- **Grid:** 9×9, 18–22 clues, `is_free: true`
- **Generator:** `Backend/generate_puzzle.py`
- **Answer lengths:** the 12 eligible layouts contain at most four 3-letter
  slots and at least six slots of 5+ letters. Nine layouts include 7- or
  8-letter answers; eight letters is the daily maximum.
- **Layout rotation:** layouts are filtered before the solver runs, so the 13
  retained legacy layouts that fail the length profile are never attempted.
  A generation batch uses every eligible layout once before starting a new
  cycle, which prevents repeats in the normal seven-puzzle workflow run.
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

### Supabase edit sync and generation artifacts

Generated daily and weekly crossword payloads are uploaded as GitHub Actions artifacts as well as inserted into Supabase. These JSON artifacts preserve the original generated `text`/`hint` values before any manual Supabase edits, making later word-bank sync review easier.

Use `Backend/sync_supabase_crossword_edits.py export` to compare reviewed Supabase rows with `Backend/word_bank.json`. Historical rows generated before clue-source metadata may require manual `clues[N]` selection; future rows include `textSourceField`/`textSourceIndex` and `hintSourceField`/`hintSourceIndex` inside each clue JSON object so the sync script can target the original word-bank field deterministically.

For rows that have matching generated JSON artifacts, prefer `export-from-artifacts`. This compares each artifact's original generated clue values against the current Supabase row, so only actual Supabase edits become proposed word-bank replacements:

```bash
Backend/.venv/bin/python3 Backend/sync_supabase_crossword_edits.py export-from-artifacts \
  --artifact-dir Backend/generated_puzzle_artifacts \
  --start-date 2026-07-01 \
  --end-date 2026-07-07 \
  --tables daily,weekly
```

The artifact-backed export still writes the normal `Backend/supabase_crossword_edit_replacements.json`, so the existing `validate` and `apply` commands remain the final safety gate. If an artifact does not contain clue-source metadata for a `clues[]` update, the script fails closed by exporting a manual-review item instead of guessing.

### Released weekly duplicate-clue repair

Use `Backend/repair_weekly_duplicate_clues.py` when historical weekly puzzle rows have identical `text` and `hint` values. The export is limited to rows whose release `date` is on or before the local execution date; scheduled future puzzles are intentionally excluded. For each duplicate, the first non-identical value in the answer's current `word_bank.clues[]` becomes the proposed `text`, while `hint` remains unchanged.

```bash
Backend/.venv/bin/python3 Backend/repair_weekly_duplicate_clues.py export
Backend/.venv/bin/python3 Backend/repair_weekly_duplicate_clues.py validate
Backend/.venv/bin/python3 Backend/repair_weekly_duplicate_clues.py apply
```

The workflow is review-first: `export` and `validate` never mutate Supabase, and `apply` re-fetches every ready row and fails closed if either the Supabase clue or selected word-bank source changed. Missing word-bank answers remain unresolved in the report and are never updated automatically. Successful repairs also set `textSourceField: "clues"` and the matching `textSourceIndex` for future traceability.

## Crossword Correct Highlight Locking

When `AppSettings.crosswordCorrectHighlight` is enabled, cells belonging to completed crossword clues are treated as locked input. `GameViewModel` must reject deletion and typed replacement for those cells, because the green highlight is the user's signal that the answer has been accepted and should no longer be editable. Retyping the same letter already in a locked cell is allowed as navigation input and advances to the next cell without changing the answer.

When the setting is disabled, completed cells remain editable and deletable for the harder non-locking experience.

## Daily Game Ad Explainer

Non-Pro users can see a full-screen explainer before the Backword or daily crossword interstitial. The opt-out preference is shared across both games. The explainer is only shown when that game's once-per-day interstitial slot is still eligible; same-day repeat opens skip both the advert and the explainer.

Backword keeps its onboarding-first behaviour: the Backword ad gate is skipped until the user has seen Backword onboarding.

## Home Card Stats Rows

Daily and weekly crossword cards display summary scores from `HomeViewModel`, not by reading progress files directly in the view. Cards ask the view model to refresh saved `UserProgress` when they appear; scores fall back to the loaded puzzle's clue count if legacy progress has no `totalClues` metadata. Weekly cards use `UserStats.currentStreak(isWeekly: true)` for their streak display.

The Backword card uses the same stats row shape, but its score is hidden until `BackwordProgress.isComplete` because Backword only awards points at the end of a game. In the completed state, the Backword status label is centered over the score/streak row at regular Dynamic Type sizes and falls back above that row for accessibility Dynamic Type sizes.

Backword archive rows keep the guess-count status label after a win. On-time wins use the same solved gold as on-time crossword archive completions, while wins finished on a later local release date use the normal correct green. Only Backwords completed on their local release date contribute points or update Backword statistics; archive completions remain visible in progress but score zero.

## Backword Letter Reveals

Backword starts with only the final letter visible. After a wrong guess, reveal the longest correctly positioned suffix connected to the end of the answer; never extend that suffix merely because a guess was submitted. If the game remains active after three guesses, also reveal the third letter from the left as a disconnected extra hint. Other correct letters separated from the revealed suffix by an incorrect letter remain hidden, and revealed letters never disappear on later guesses. Reveal state is derived from saved guesses, so unfinished games always use the current rule without a persistence migration.

Each row in the previous-guesses history independently highlights its correctly positioned suffix. Those connected cells use semantic correct green for the letter and the same semantic accent blue as the main cells for a stronger border; disconnected correct letters do not receive this progress highlight.

Backword rule changes use an integer rules version stored separately from the app version. New players see the current rules through normal onboarding and record that version when onboarding is dismissed. Returning players whose stored version is older automatically receive a one-time `Rules Updated` callout in the How to Play sheet on their next Backword entry; the version is recorded only when that sheet is dismissed. Manually opening How to Play never changes announcement state. Debug settings keep first-time onboarding reset separate from replaying the returning-player rules update.

## Backword Completion Moment

The completion sheet is presented after both wins and failures and receives the answer explicitly. Its title is `Solved!`, `Finished`, or `Failed`. Wins show an `... in N guesses` label directly above the cells; failures show `The answer was...`. A late `Finished` result shows the no-points message above the standard completed stats content. The cells reveal from right to left and perform a single whole-word bounce. Winning cells transition from correct green to accent blue during the glow; failed cells and their glow remain red. Reduce Motion skips the staged animation and shows the completed word immediately.

The completion sheet also shows a live `NEXT BACKWORD IN` countdown. It must derive the next release from `ContentReleaseCalendar` on every tick so it follows local midnight and remains correct across timezone and daylight-saving transitions.

In DEBUG builds, the Backword header includes a ladybug button that simulates a five-guess failure and presents the real failure completion flow. The simulation is intentionally in-memory only: it must not save progress or record player stats.

## Crossword Completion Moment

Daily and weekly crossword completion sheets use the solved grid as their visual centerpiece. Playable cells reveal in a diagonal wave; on-time solves finish with an accent bounce, glow, and restrained sparkle burst, late `Finished` solves use the wave and a softer bounce without sparkles, and `Gave up` reveals in red without a celebratory finish. Reduce Motion shows the final state immediately.

All crossword completion outcomes show a live release countdown derived from `ContentReleaseCalendar` on every tick. Daily puzzles count down to the next local midnight; weekly puzzles count down to the next local Sunday at midnight and include days in the display. A late `Finished` result shows its no-points message above the standard stats card and displays a score of zero.

Giving up from an eligible archive crossword completes and saves the revealed puzzle before setting the same `isComplete` presentation trigger used by a solve. This presents the red `Gave up` completion experience immediately without recording a successful completion.

## Crossword Rating Score Window

Daily and weekly crossword rating points are only awarded during the puzzle's own local release window. Daily crossword scores can be written only when `ContentReleaseCalendar.dailyDateString` equals the puzzle date; weekly crossword scores can be written only when `ContentReleaseCalendar.weeklyDateString` equals the puzzle date.

At local midnight, `HomeView` records the currently loaded puzzle scores using the pre-rollover release calendar before fetching the new daily puzzle. After that rollover, archive play can still update progress and solve status, but it must not add or improve rating points for an older puzzle date.

---

## App Store Review Prompt

Backword requests the system App Store review prompt only after positive crossword completions. Backword word-game completions are intentionally excluded because that game has a faster loop and would make review prompts feel less earned.

`AppReviewPromptService` records unique completed crossword puzzle IDs locally. Give-up completions do not count. The first review request is eligible after 3 counted crossword wins; repeat requests require at least 90 days since the previous request and 5 additional counted crossword wins. Apple may still suppress any individual system prompt.

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
    "hard_text": "A female name with a Pawnee connection.",
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
| `hint` | Fallback metadata only | Dormant fallback clue text. It is not scanned as an active clue, but quality cleanup may copy a good hint into a flagged active field after validating it for leakage, repetition, and clue quality. |

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

**No active clue field may contain the answer, an answer fragment, or an obvious derived giveaway form.** Active clue fields are `text`, `hard_text`/`hardText`, and `clues[]`; `hint` is ignored because it is dormant fallback metadata. Checks are case-insensitive and token-aware. For multi-word answers (e.g. `ICE CREAM`), constituent words ≥ 3 characters are checked individually. Compact answer fragments of 4+ characters are also blocked (e.g. `CASE` in `Suitcase`), while incidental 3-letter substrings such as `ART` in `start` are not blocked unless produced by a clear derivation.

Derived forms are blocked when they are clear inflections or common ordinal/cardinal pairs, e.g. `BAGGED` must not be clued with `bag`, `SMOKER` with `smokes`, `RUNNER` with `runs`, and `TENTH` with `ten`.

Run `Backend/fix_answer_leakage.py` or `python3 Backend/fix_duplicate_clues.py scan-quality` to scan for violations. Backend clue-generation scripts should enforce the same rule through `Backend/answer_leakage.py`.

### Clue redundancy rule

Active clue fields inside the same word-bank object must use genuinely different clue ideas. `hint` is ignored for this cleanup rule. Do not repair one active field by reusing another field with wrapper text such as "Maybe", "Could be", "Often", "Seen as", "Associated with", "A sign of", or suffixes such as "perhaps", "sometimes", "for one", or a trailing question mark. Active clue fields should also avoid filler qualifiers such as "perhaps", "maybe", "possibly", "sometimes", and "loosely" anywhere in the clue; remove the qualifier or write a fresh clue instead.

For example, `text: "Maybe burning fiercely"` is considered the same clue idea as `clues[0]: "Burning fiercely"` and must be replaced with a fresh angle. Run `python3 Backend/fix_duplicate_clues.py scan-similar` to find these cases, and `python3 Backend/fix_duplicate_clues.py validate` before shipping word-bank changes.

### Antonym-only clues and quality cleanup

Do not clue an answer solely as the opposite or antonym of another word, for example `"Opposite of cautious"`. Explanatory clues where opposition is the concept being defined, such as a description of irony, are allowed. An `or` clue is not automatically invalid, but it should be simplified or split when one branch merely repeats another active clue.

Quality repairs follow this order: copy a safe and distinct `hint`, simplify or split a useful `or` clue, write a genuinely fresh clue, then delete an unresolved `clues[]` item. `text` and `hard_text` must never be deleted. A `clues[]` array may shrink below three items, but must retain at least one item so the dormant hint fallback is not reactivated.

The review workflow is local and does not require an LLM API call:

```bash
python3 Backend/fix_duplicate_clues.py export-quality
python3 Backend/fix_duplicate_clues.py build-quality-report Backend/audit_quality_chat_decisions.json
python3 Backend/fix_duplicate_clues.py apply-quality Backend/clue_quality_replacements.json --dry-run
python3 Backend/fix_duplicate_clues.py apply-quality Backend/clue_quality_replacements.json
python3 Backend/fix_duplicate_clues.py validate
```

`export-quality` intentionally produces a broad, ignored candidate file for chat review. The retained replacement report includes original-value preconditions and a hash of the source word bank; applying it fails closed if either has changed. Hint text is copied into the active field and remains unchanged in `hint`.

### Daily main-clue difficulty audit

`Backend/audit_easy_daily_clues.py` manages the review-first cleanup of overly
easy daily `text` clues. Its scope exactly matches the daily generator: non-empty
`text` fields whose stored answers are 3–8 characters long. Longer weekly-only
answers and every other clue field are excluded.

The audit and replacement clues are authored through the Codex chat, not by a
backend API call. The tool only exports batches, records chat decisions, runs
the canonical leakage/redundancy/inflection checks, and applies a fully approved
replacement set. `word_bank.json` must remain unchanged until every confirmed
replacement has an accepted proposal. Audit and proposal artifacts store the
source bank hash plus exact index/word/current-value preconditions and fail
closed when stale.

If an intentional source commit removes exactly one bank entry during an
unfinished review, `rebase-removed-entry` can migrate later report indexes. It
requires the exact pre-change bank, verifies that deletion is the only semantic
change, refuses to remove an entry referenced by a proposal, and validates both
rebased reports before writing them.

After recording the human calibration batches, `triage-local` can apply the
chat-calibrated first pass across the remaining bank. It uses only explainable
local signals (word frequency, clue directness and length, specialist wording,
and dual meanings), never a network model. Scores in its deliberately narrow
uncertain band remain `borderline` for an independent chat review.

```bash
python3 Backend/audit_easy_daily_clues.py init
python3 Backend/audit_easy_daily_clues.py export-classification-batch --limit 100
python3 Backend/audit_easy_daily_clues.py record-classifications decisions.json
python3 Backend/audit_easy_daily_clues.py triage-local
python3 Backend/audit_easy_daily_clues.py export-classification-batch --second-pass
python3 Backend/audit_easy_daily_clues.py export-proposal-batch --limit 20
python3 Backend/audit_easy_daily_clues.py record-proposals proposals.json
python3 Backend/audit_easy_daily_clues.py rebase-removed-entry --old-bank old.json --removed-index 5136
python3 Backend/audit_easy_daily_clues.py validate
python3 Backend/audit_easy_daily_clues.py apply
```

The full audit report is a local checkpoint and is ignored by Git. The smaller
reviewed replacement report may be retained with the other word-bank repair
artifacts.

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

### Full-screen ad lifecycle

Full-screen ads are SDK-owned view controllers. `AdService` must not automatically dismiss interstitial or rewarded ads with app-owned timers; some real-world ads can take over a minute to fully show. Ad state should be cleared only from Google Mobile Ads delegate callbacks such as failure or dismissal.

Avoid starting home-screen refresh work while `adService.isPresentingFullScreenAd` is true. Unrelated SwiftUI/TipKit presentation churn while full-screen ads are active can make lifecycle and touch handling harder to reason about.
