# App Conventions

Key logic decisions, rules, and non-obvious behaviours across the codebase. Add a section whenever a meaningful decision is made that future contributors (or AI) should understand.

---

## Accounts, Cloud Sync, and Pro Entitlements

Accounts are optional. Guest records retain the historical local persistence
location; a signed-in account uses a UUID-namespaced local cache so signing out
does not expose another account's data. On sign-in, Backword and crossword
records are uploaded and compared as whole records: solved wins, then a terminal
record, then the furthest valid progress; two solved records use their release
score and finally their latest update as tie-breakers. Grids and guesses are
never merged cell-by-cell.

Supabase `game_progress` is the cloud source of truth for cross-device progress;
statistics, streaks, and ratings are derived from active progress rather than
merged as aggregate counters. Local saves always complete first and cloud writes
are retried on later account syncs.

Crossword progress carries a `releaseDateScore` snapshot. iOS captures it only
while the puzzle is in its own local release window and never changes it during
later Archive play. On a first account sign-in, legacy guest aggregate rating
points are copied onto their corresponding progress records before upload, so
existing game state and earned scores remain available on every signed-in
device. Accounts created before this snapshot existed receive the same one-time
conversion from their account-scoped aggregate file on first refresh. A cloud
conflict still selects one whole crossword grid, but preserves the higher
release-window score snapshot as independent historical metadata; this stops
later Archive progress on another device from erasing already-earned points.

StoreKit remains a valid Pro source while signed out. Signed-in purchases pass
the Supabase user UUID as StoreKit's `appAccountToken`; verified Apple
transactions are then associated with a single Backword account. The server
updates that account's entitlement from Apple transaction lookups and App Store
Server Notifications. A locally cached expiry can only bridge initial app
startup; after `Transaction.currentEntitlements` completes with no active Pro
transaction, the cache is cleared and cannot keep Pro unlocked. Account
deletion removes the Backword association and cloud gameplay data but never
cancels the Apple subscription.

---

## Website Backword Parity

The browser Backword game lives at `/` as an immersive route outside the
marketing site's header and footer. Its game dashboard lives at `/home`, while
the marketing page lives at `/info`. The game uses the same daily Supabase row,
five-guess scoring, connected-suffix reveal rules, Normal/Easy modes, and local
release-date rules as the iOS game.

Browser guest progress is stored in versioned `localStorage`; signed-in web
progress is isolated by Supabase user UUID and synchronised with the canonical
whole-record cloud payload. Settings and cached daily content remain
device-local. Progress is the source of truth for browser statistics, so
cross-device sync never reconciles a separate set of aggregate counters. Only
results completed on their browser-local release date contribute to points and
aggregate statistics.

The browser accepts any alphabetic six-letter guess, matching the current iOS
implementation. It supports both the in-page keyboard and physical keyboard
input. Ads, Pro-only letter feedback, and archives are not part of the browser
Backword parity surface yet. The web dashboard reads today's Backword and
Quick Crossword progress to present card status; the weekly card still directs
players to the iOS App Store rather than implying browser Pro access. The web
dashboard reads the released Word of the Day row for the browser's local
calendar date. It has no browser fallback:
during loading and when the row is unavailable, the WOTD section is not shown.
On viewports up to 680px, the compact WOTD card toggles an animated detail
drawer; larger viewports show the same content immediately in two columns.

The browser's slide-out navigation drawer is rendered on every web route. It
keeps the game destinations prominent and places Privacy and Terms in a
secondary group, so players can navigate without leaving the immersive game
surface for marketing-page chrome.

### Browser feedback

The browser contact page opens a blank `mailto:` message addressed to
`backword.support@gmail.com`. It does not collect, submit, retain, or process
feedback; the sender's configured email app delivers it instead.

### Browser daily crossword parity

`/crossword` is the browser-local version of the released 9×9 daily puzzle.
It reads the matching `puzzles` row from Supabase, caches valid payloads by
plain local calendar date, and falls back to that cache offline. Per-puzzle
entries, completed clues, timestamps, answer-feedback preference, onboarding,
and release-date score are versioned local records. Signed-in progress is
synced to iOS and other browsers; settings and puzzle caches remain local.

The grid follows the iOS interaction model: tapping a selected cell switches
direction, the clue bar navigates/toggles direction, correctly completed
answers are green and input-locked by default, and turning Answer Feedback off
keeps the harder editable mode. Hints, ads, archive access, and paywalls are
intentionally absent from the browser crossword; account progress sync is not.

Crossword points are captured only while the puzzle is the browser's local
calendar-day release. The score remains in its historical progress record at
midnight; late completion does not overwrite it. The rolling 14-day score,
history, and streaks are all derived from saved per-date progress.

Total solved includes every successful crossword completion, including Archive
play. Current and best streaks, the Daily Stats average, and per-row times use
only successful completions made during that puzzle's own release window. An
archive completion must never extend a streak or inflate the release-day
average on either platform.

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
- **Scheduling:** the `generate-weekly-puzzles` GitHub Actions workflow runs every Monday at 06:00 UTC and maintains three future Sunday release rows. It validates number/date continuity before checking that buffer, always repairs the earliest recoverable missing weekly slot first, and never skips a failed number or date. A failed slot is retried with fresh seeds until the workflow generation deadline; later slots wait so releases remain contiguous.

### Word repeat prevention

Both generators share the same exclusion mechanism to avoid repeating answers across puzzles.

Within an individual puzzle, the shared `crossword_answer_similarity` rule also
rejects answers that would be confusingly related. It rejects exact duplicates,
one answer contained in another, and pairs of five or more letters sharing a
prefix of at least five letters that covers 70% of the shorter answer *and*
are within two spelling edits (for example, `INVERSE` and `INVERTER`). Three-
and four-letter answers are exempt from the near-match rule so the small
short-word bank remains viable.

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

### Backword home-card appearance

The home-screen Backword card always resolves its semantic colours in Dark Mode. Its dark crossword-colour backing is retained beneath the translucent Backword background, so the card background, border, logo, status, score, streak, loading/error, and completed-word states remain visually identical in Light and Dark Mode without changing the rest of the Home screen's appearance. Status labels keep their status-coloured icon and chip, while the label text uses the primary semantic colour for legibility. In Light Mode only, both daily-game card backgrounds receive a 10% primary-text-colour overlay; the contents retain the fixed Dark Mode palette.

The Daily Crossword card uses the same fixed Dark Mode palette. Its in-progress status keeps the accent-coloured icon and chip, but uses the primary semantic text colour for its label so it remains light against the dark card.

## Backword Letter Reveals

Backword starts with only the final letter visible. After every wrong guess, reveal the longest correctly positioned suffix connected to the end of the answer. The guess-count schedule supplies a minimum suffix length: the first wrong guess adds no automatic letter, the second guarantees the final two letters, the third guarantees the final three letters, and the fourth adds no automatic letter. A correctly guessed suffix can advance beyond that minimum at any point, and revealed letters never disappear on later guesses. Reveal state is derived from saved guesses, so unfinished games always use the current rule without a persistence migration.

Players can choose a persistent Backword mode in How to Play or Settings. Normal is the default and uses the schedule above. Easy restores the original minimum schedule: every wrong guess grows the revealed suffix by one letter, so the final two, three, four, and five letters are visible after the first through fourth wrong guesses. In either mode, a longer correctly positioned suffix can reveal earlier.

Changing mode during an unfinished game applies immediately by deriving the new reveal state from its saved guesses. Switching back to Normal may therefore hide letters revealed only by Easy. Any partially typed guess is cleared when the mode changes so its characters are not remapped to different cells. Mode remains a global preference rather than part of saved puzzle progress, and scoring and statistics are identical in both modes.

The clue explainer banner is shown only while the player has made no guesses. After one minute in the game with no guess, its short prompt changes to clarify that the clue may be an associated word or another connection to the answer. Making the first guess hides the banner and cancels its countdown. The white clue explainer container fills the available game width above the keyboard.

Each row in the previous-guesses history independently highlights its correctly positioned suffix. Those connected cells use semantic correct green for the letter and the same semantic accent blue as the main cells for a stronger border; disconnected correct letters do not receive this progress highlight. The optional Pro letter-feedback setting may also highlight letters that occur anywhere in the answer.

The previous-guesses history always lists every submitted guess after completion, including the winning guess even though the solved word is also displayed in the main letter row.

Backword rule changes use an integer rules version stored separately from the app version. New players see the current rules through normal onboarding and record that version when onboarding is dismissed. Returning players whose stored version is older automatically receive a one-time `Rules Updated` callout in the How to Play sheet on their next Backword entry; the version is recorded only when that sheet is dismissed. Manually opening How to Play never changes announcement state. Debug settings keep first-time onboarding reset separate from replaying the returning-player rules update.

## Backword Generation Quality Gate

Backword generation validates every one-word answer/clue pair with a semantic
reviewer and a separate adversarial word-form reviewer. Both must approve the
literal clue word for the exact answer form; a pair is invalid when it would
work only after silently changing a suffix, tense, number, derivative, or
spelling (for example, `CHEESY`/`CORN` is rejected while `CHEESY`/`CORNY` is
valid). Direct synonyms are allowed when they are the clearest natural clue,
although lateral associations remain preferred.

The gate fails closed. An API error, malformed response, missing verdict, or
mismatched reviewer response rejects that candidate batch. The generator tries
fresh candidates, then exits before uploading anything if it cannot fill the
requested batch with pairs that both reviewers accept.

## Backword Completion Moment

The completion sheet is presented after both wins and failures and receives the answer explicitly. Its title is `Solved!`, `Finished`, or `Failed`. Wins show an `... in N guesses` label directly above the cells; failures show `The answer was...`. A late `Finished` result shows the no-points message above the standard completed stats content. The cells reveal from right to left and perform a single whole-word bounce. Winning cells transition from correct green to accent blue during the glow; failed cells and their glow remain red. Reduce Motion skips the staged animation and shows the completed word immediately.

Backword keyboard letter entry and deletion use the same light impact as crossword letter input. Guess haptics reflect the result of each accepted submission. A non-winning guess gets a full-strength (`1.0`) impact only when it extends the correctly positioned suffix; automatic scheduled reveals alone retain the incorrect-guess feedback. Wins and final failures use distinct terminal patterns instead of also playing the intermediate guess pattern. During the completion animation, each right-to-left letter reveal plays one quick impact; Reduce Motion skips both the staged reveals and their per-letter impacts.

The completion sheet also shows a live `NEXT BACKWORD IN` countdown. It must derive the next release from `ContentReleaseCalendar` on every tick so it follows local midnight and remains correct across timezone and daylight-saving transitions.

In DEBUG builds, the Backword header includes a ladybug button that simulates a five-guess failure and presents the real failure completion flow. The simulation is intentionally in-memory only: it must not save progress or record player stats.

## Crossword Completion Moment

Daily and weekly crossword completion sheets use the solved grid as their visual centerpiece. Playable cells reveal in a diagonal wave; on-time solves finish with an accent bounce, glow, and restrained sparkle burst, late `Finished` solves use the wave and a softer bounce without sparkles, and `Gave up` reveals in red without a celebratory finish. Reduce Motion shows the final state immediately.

All crossword completion outcomes show a live release countdown derived from `ContentReleaseCalendar` on every tick. Daily puzzles count down to the next local midnight; weekly puzzles count down to the next local Sunday at midnight and include days in the display. A late `Finished` result shows its no-points message above the standard stats card and displays a score of zero.

Giving up from an eligible archive crossword completes and saves the revealed puzzle before setting the same `isComplete` presentation trigger used by a solve. This presents the red `Gave up` completion experience immediately without recording a successful completion.

## Crossword Rating Score Window

Daily and weekly crossword rating points are only awarded during the puzzle's own local release window. Daily crossword scores can be written only when `ContentReleaseCalendar.dailyDateString` equals the puzzle date; weekly crossword scores can be written only when `ContentReleaseCalendar.weeklyDateString` equals the puzzle date.

At local midnight, `HomeView` records the currently loaded puzzle scores using the pre-rollover release calendar before fetching the new daily puzzle. After that rollover, archive play can still update progress and solve status, but it must not add or improve rating points for an older puzzle date.

## Per-Game Rolling Score Bars

Game and stats screens show category-specific scores from the same rolling 14-day `OverallRating` window used by the Home rating. Backword and daily crossword each have a maximum of 70 points (14 releases × 5 points); weekly crossword has a maximum of 10 points because a 14-day window contains two weekly releases. Missing scores count as zero, and displayed progress is clamped to the category maximum.

Daily and weekly crossword bars update the shared `OverallRatingService` as the current score changes during play, including changes caused by completion-percentage thresholds and each three-hint penalty. The existing release-window checks still prevent archive or late play from changing rating points. Backword refreshes the shared rating after its completion result has been recorded.

Crossword stats histories are release-date based, so unplayed and in-progress puzzles remain visible rather than limiting the table to completions. Daily stats show all 14 releases in the rolling window. Weekly stats show the two releases in that same 14-day window under `Last 14 Days`, followed by the next five older weekly releases under `Previous Games`.

Backword stats use the same release-date-based 14-day history. Every daily release is shown, including unplayed and in-progress games. Rows show the saved guess count when play has started, distinguish solved and failed completions, and use the recorded Backword rating score with completed progress as a fallback.

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

### Clue suffixes

Every regenerated or repaired clue field for an abbreviation answer ends with
` (abbr)`. Answers that are represented without spaces in the bank but have an
established multi-word enumeration keep that enumeration at the end of each
regenerated or repaired clue field, for example ` (5,4)`. Preserve these
suffixes from the answer's existing clue fields rather than asking the model to
infer the answer format.

### Regional answer archive

`Backend/word_bank.json` contains only answers approved for region-neutral
generation. US- or UK-specific answer spellings and separated regional senses
are kept in `Backend/US_UK_regional_words.json`; the daily and weekly
generators intentionally do not load that archive.

Archived objects retain the normal word-bank clue fields and add:

- `region`: `US` or `UK`
- `counterpart`: the corresponding answer used by the other region
- `category`: `clear_spelling`, `context_split`, or `terminology`
- `sense`: required for context splits and terminology records, and whenever
  the same answer has multiple archived meanings

An answer may intentionally exist in both files when its spelling has a
region-neutral sense and a separate regional sense. The active record must
contain only neutral clues, while each archived record contains clues for one
named regional sense. `CHECKS`, `DRAFT`, and `DRAUGHTS` have multiple archived
records distinguished by `sense`.

The first regional audit archived 404 clear spelling records. It also separated
19 mixed-context answers, and moved `MOM` and the board-game sense of
`DRAUGHTS` out of active generation. Twenty-two terminology and word-form cases
remain active pending a separate review.

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

For an exhaustive review, use the resumable Codex-chat workflow. It covers only
active puzzle clue fields (`text`, `hard_text`/`hardText`, and every `clues[]`
item); dormant `hint` metadata is intentionally excluded. The audit tool only
manages local batches, hashes, review state, and validation. It never calls an
LLM API or any other network service.

```bash
python3 Backend/audit_word_bank_inflections.py init-chat-review
python3 Backend/audit_word_bank_inflections.py export-chat-batch --limit 100
python3 Backend/audit_word_bank_inflections.py record-chat-batch decisions.json
python3 Backend/audit_word_bank_inflections.py validate-chat-review
python3 Backend/audit_word_bank_inflections.py apply-chat-review
```

Each recorded batch must explicitly confirm that every omitted field already
matches the answer and list only required replacements. The audit records exact
index, word, field, current-value, batch-hash, and source-bank-hash
preconditions. Validation fails closed if any active field is unreviewed, a
replacement is unresolved or unsafe, or the source bank changes. The bank is
written only after the entire review validates.

Backword uses the same review-first pattern for existing Supabase rows:

```bash
python3 Backend/audit_backword_inflections.py export
python3 Backend/audit_backword_inflections.py apply --input Backend/backword_inflection_replacements.json
```

### Backword clue semantic fit

Backword clues are one-word lateral associations, but they must still be directly defensible for the exact answer. Do not use adjacent-process clues where the answer is only a stage, participant, result, product, tool, container, or neighboring concept of the clue. For example, `LARVAE` should not be clued as `TRANSFORMATION`: larvae are a stage within metamorphosis, not transformation itself.

### Full clue–answer alignment audit

`Backend/audit_clue_answer_alignment.py` reviews every stored clue field,
including dormant `hint`, for factual and semantic agreement with its exact
answer. It supports fixed, hash-bound Codex-chat batches and an explicitly
requested Terra Batch API mode. The API mode writes compact issue-only results,
splits work into queue-limit-safe batches, and never changes the word bank.

For the full-bank audit, Terra is the sole semantic reviewer. A Terra mismatch
only makes an entry a pending removal proposal when *all* of its stored clue
fields mismatch. Proposals still require explicit human approval, and the
source-bank checksum plus exact clue values must still match before application.

```bash
python3 Backend/audit_clue_answer_alignment.py init
python3 Backend/audit_clue_answer_alignment.py submit-terra-batch
python3 Backend/audit_clue_answer_alignment.py terra-batch-status
python3 Backend/audit_clue_answer_alignment.py collect-terra-batch
python3 Backend/audit_clue_answer_alignment.py run-terra-batches --prior-spend-usd <usd> --prior-attempted-entries <count> --cost-ceiling-usd <usd>
python3 Backend/audit_clue_answer_alignment.py propose-removals
```

Entries marked `repair` in the review file are not edited directly. Generate
the replacement packages into a separate, hash-bound review artifact first:

```bash
python3 Backend/generate_clue_repairs.py
```

That artifact contains proposed `text`, `hint`, `hard_text`, and three
crossword clues for each marked answer. It must be reviewed and approved before
any change to `word_bank.json`. Apply only records marked `approved` with:

```bash
python3 Backend/generate_clue_repairs.py --apply --yes
```

Then confirm the repaired packages with a focused semantic audit:

```bash
python3 Backend/generate_clue_repairs.py --audit
```

After an audit-driven repair changes the bank, rebuild a current queue before
starting another repair pass. The queue includes only audit findings whose exact
field values are still present in the live bank; it excludes removed entries and
flags duplicate answers for manual disambiguation.

```bash
python3 Backend/build_remaining_clue_repair_queue.py
```

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
