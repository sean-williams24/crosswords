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

Shared payload decoders must accept an omitted optional timestamp from Swift's
`Codable` output as equivalent to the web's explicit `null`. In particular, an
unfinished iOS Backword record may omit `completedAt`; the web normalises it to
`null` so its partial guesses remain visible in history and can sync onward.

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

An Archive give-up is a grid reveal only. Rating rebuilds must continue to use
that record's `releaseDateScore` even after `gaveUpAt` is set, so revealing an
old puzzle never clears points earned on its release date.

StoreKit remains a valid Pro source while signed out. Signed-in purchases pass
the Supabase user UUID as StoreKit's `appAccountToken`; verified Apple
transactions are then associated with a single Backword account. The server
updates that account's entitlement from Apple transaction lookups and App Store
Server Notifications. A locally cached expiry can only bridge initial app
startup; after `Transaction.currentEntitlements` completes with no active Pro
transaction, the cache is cleared and cannot keep Pro unlocked. Account
deletion removes the Backword association and cloud gameplay data but never
cancels the Apple subscription.

Debug builds include a StoreKit refund-request action solely for testing an
external App Store refund and the resulting entitlement revocation. It requires
an active, verified Pro transaction with no Debug Pro Override, and must be
used with a genuine Sandbox purchase rather than the Xcode StoreKit
configuration. It is excluded from production builds and is not a customer
refund feature.

A verified StoreKit Pro revocation is reconciled with the authenticated account
immediately through the entitlement claim endpoint, then the account
entitlement is reloaded. This avoids leaving an iOS device or the next web
refresh unlocked solely because the cached account status has not yet observed
Apple's server notification.

Every App Store Server Notification creates a deduplicated, server-only summary
in `apple_subscription_events`, keyed by Apple's notification UUID. It records
event, transaction, account, environment, time, renewal, and resulting
entitlement information, but never the signed JWS payload. This is diagnostics
only: `user_entitlements` remains the sole entitlement snapshot, and an audit
write failure cannot prevent that snapshot from being refreshed.

Account-data refreshes can be requested by app startup, auth-state changes, and
the account sheet. They are coalesced into one in-flight operation so those
callers cannot race cloud sync and entitlement checks. `CancellationError` (or
an already-cancelled task) is expected SwiftUI task lifecycle behaviour and is
never presented as an account error or logged as a failure; real presented
account errors are recorded through the `account` OSLog category.

`delete-account` skips Supabase's platform JWT gate only so the browser's
unauthenticated CORS `OPTIONS` preflight can reach its handler. It returns the
same CORS headers on every outcome, while the actual deletion request remains
authenticated through the handler's bearer-token validation.

After a browser deletion succeeds, the player sees a non-dismissable summary
of the cloud account data removed and the Apple subscription and device-local
data retained. Only after acknowledgement does the browser clear its local
session and take the player to sign-in.

Account deletion also clears both the `user_id` and `app_account_token` from
the entitlement record before deleting the Supabase Auth user. Apple
transaction and notification audit records are retained only without a
Backword-account association, allowing a verified purchaser to reclaim an
eligible purchase while preventing the retained record from identifying the
deleted Backword account.

Web Pro subscriptions are sold through Stripe only after Apple or Google sign
in, and use the same account entitlement snapshot as StoreKit purchases. The
server, never the browser, selects a Stripe price, creates Checkout, and
accepts only signature-verified Stripe webhook updates. A signed-in account
with any active Pro source is never offered a second subscription; Stripe
customers use Stripe's portal while Apple customers remain Apple-managed.
Stripe trials are blocked after a recorded Apple or Stripe trial, although
Apple's separate Apple-ID introductory-offer eligibility means the reverse
direction is necessarily best-effort. Deleting an account schedules any Stripe
subscription to stop renewing, removes the Backword UUID from Stripe metadata,
and immediately removes account-linked Pro access; Apple subscriptions are
never cancelled by Backword account deletion.

iOS verifies its cached Supabase session with the Auth user endpoint during
startup and foreground account refreshes, before it uploads or downloads cloud
progress. A successful deletion initiated on that device, or a
server-confirmed missing or invalid account, clears that device's local session,
returns persistence to the guest namespace, and presents the same
cloud-versus-device-local deletion explanation. Offline or other transient
validation failures keep the cached session intact and retry on a later refresh;
iOS has no push channel that can wake a closed app at the instant a browser
deletes an account.

The web performs the same Auth user validation when a signed-in browser starts,
regains focus or visibility, reconnects, or moves to a different client-side
route. A server-confirmed unavailable account clears only that browser's
session, presents the deletion summary above the current route, and goes to
sign-in after acknowledgement. Transient network failures leave the cached
session intact.

Successful Apple and Google authentication dismisses the sign-in sheet as soon
as Supabase creates the local session. Guest-progress migration, cloud sync,
and entitlement checks run through that same coalesced account refresh in the
background, so slow network work never leaves the provider button in a loading
state. A repeated auth event for the active account must not restart guest
migration.

Sign in with Apple uses the native UIKit-branded button with an app-owned
authorization controller, rather than SwiftUI's wrapper. This prevents a
cancelled system flow from leaving that wrapper's in-progress indicator on the
sign-in sheet.

Sign-in failures have their own presentation state, separate from signed-in
account, entitlement, and sync errors. The signed-out account sheet shows only
safe, actionable Apple/Google or network retry copy; provider cancellations are
expected and remain silent. Low-level provider and Supabase details are logged,
while post-sign-in entitlement work is presented only from the signed-in
account surface when it is relevant. The browser follows the same separation:
provider and callback failures use local safe retry alerts, background sync
remains queued and silent, and an entitlement warning appears only in Player
Profile.

Google account entry points use Google-provided branded controls: iOS uses
Google's pre-approved sign-in logo asset in an account button whose geometry
matches Sign in with Apple, and the web uses Google's pre-approved web button
asset. Both use platform-native Google account flows and exchange Google ID
tokens directly with Supabase for session creation and progress sync. This
avoids exposing a Supabase project hostname during Google sign-in.

The signed-in account surface is the Overall Rating sheet. Home and Settings
send signed-in users there directly; a successful sign-in dismisses its
sign-in sheet before that sheet is presented. When sign-in starts from
Settings, Settings also dismisses first so Rating Details is always presented
from Home rather than stacked over another sheet. Account deletion is the
exception: it is deliberately the final signed-in Settings action, separate
from the Rating Details sign-out control.

---

## Home Card Appearance

The Backword card keeps its dark content palette for readable logo and status
content in either appearance. Its background follows the system colour scheme:
Light Mode uses a flat, opaque pastel lavender, while Dark Mode keeps the
existing darker purple. The card has no outline in either appearance.

The Light Mode Backword `New` status label and streak badge use the same
background as the `In Progress` label for contrast against the pastel card.
They have a one-point white outline in Light Mode; other Backword statuses
retain the shared status-label background.

The same Light Mode white outline applies to the Backword success badge and
the status and streak badges on both crossword home cards.

Won Backword cells on the Light Mode home card use a white surface fill with
the Backword game's Correct-green outline and dark primary text. Dark Mode
continues to use the in-game correct-cell appearance.

## App Appearance

The app's first-launch theme preference is System. Light and Dark remain
explicit user choices; System applies no preferred colour scheme so iOS follows
the device setting.

---

## Website Backword Parity

The browser Backword game lives at `/backword` as an immersive route outside the
marketing site's header and footer. Its game dashboard lives at `/`, while
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
Quick Crossword progress to present card status; non-Pro weekly and archive
entry points direct players to the web Pro page rather than a modal or the iOS
App Store. The web
dashboard reads the released Word of the Day row for the browser's local
calendar date. During initial loading, all four game cards remain non-interactive
outlined skeletons until account startup and the WOTD request settle. When the
row is unavailable, its place becomes an informational unavailable card while
the three playable game cards remain available.
On viewports up to 680px, the compact WOTD card toggles an animated detail
drawer; larger viewports show the same content immediately in two columns.

The browser archive lives at `/archive` and is available only to an active Pro
account. Non-Pro navigation links and direct archive URLs redirect to `/pro`
before archive data loads. It loads only released Backword, daily crossword,
and weekly crossword months, keeps fetched months in memory while the player
switches tabs, and uses the same local progress records as the game dashboard
for its entry statuses. Archive entries use dated routes
(`/backword/:date`, `/crossword/:date`, and `/weekly-crossword/:date`), while
the undated routes remain the rolling current-game entry points. Pro archive
entries keep the normal browser sign-in and entitlement gate.

The browser's slide-out navigation drawer is rendered on every web route. It
keeps the game destinations prominent and places Privacy and Terms in a
secondary group, so players can navigate without leaving the immersive game
surface for marketing-page chrome.

### Browser player profile

The signed-in browser account surface is `/player-profile`, matching the iOS
Overall Rating sheet. Its 14-day overall rating is built from canonical
`game_progress` release scores after refreshing the account's browser-playable
Backword and daily-crossword records. Pro weekly crossword history is read
directly from its `weekly_crossword` cloud rows: it contributes to the shared
150-point Pro rating and table, and its browser progress is persisted in the
separate weekly crossword storage namespace. Guests are
sent to sign-in with this route as their return destination. The account
entitlement refresh callback is stable for an unchanged session so profile
synchronisation is triggered by account changes, not by the entitlement result
it retrieves. On desktop, the profile summary and 14-day table are equal-height
panels; detailed scoring rules open in a modal so they do not expand the
dashboard. The summary places the rating and scoring guide first, then the
always-visible rolling-window explainer, account details, and signed-in-only
Sign Out and Delete Account actions. When the layout stacks below 901px, those
actions move beneath the 14-day table instead.

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
keeps the harder editable mode. The header Hint action reveals the selected
clue's alternate hint, records it in shared progress, and deducts one point
for every three hints, just as the Pro weekly crossword does. Ads, archive
access, and paywalls are intentionally absent from the browser daily crossword;
account progress sync is not.

Crossword points are captured only while the puzzle is the browser's local
calendar-day release. The score remains in its historical progress record at
midnight; late completion does not overwrite it. The rolling 14-day score,
history, and streaks are all derived from saved per-date progress.

Backword follows the same release-window eligibility for its all-time account
metrics: only a result completed on that Backword's own release date counts as
played, won, a streak entry, a win-rate result, or a guess-distribution entry.
Archive records remain synced so they can be resumed on another device, but are
shown as unplayed in the stats history: they never display guesses, a status,
or points and never alter those performance metrics.

### Browser Pro Weekly Crossword

`/weekly-crossword` is the browser counterpart to iOS's current 13×13 Pro
Crossword. It is available only to a signed-in account with a resolved active
Pro entitlement; guests and non-Pro players are directed to the web Pro page,
which then sends a trial purchaser through account sign-in. The released weekly
row is the latest `weekly_puzzles` entry on or before the browser's local
Sunday, and valid weekly payloads and account-scoped progress are cached in a
separate browser namespace.

Weekly progress syncs as `weekly_crossword` and preserves the native payload's
`isWeekly`, clue-count, hint, and release-score fields. Hints are unlimited
for Pro and deduct one point for every three used. Scores are captured only
while the completed puzzle belongs to the browser's current local Sunday
release window; the weekly stats surface mirrors iOS with two current-window
weeks and five prior games. Weekly archives and answer reveal remain iOS-only
on the web.

Quick and Pro Crossword expose the same info action and shared How to Play
sheet/modal on both platforms. Daily onboarding still opens it automatically
only for the daily game; the Pro Crossword presents it on demand.

The web Backword and Daily Crossword stats surfaces use the iOS semantic
palette: solid Accent score chips, Correct green for perfect scores, muted
secondary zero-score chips, solved gold, and the same rating-track tier
gradient. The web gradient is painted across the complete 70-point track and
then clipped (never scaled) to the current fill, so its gold tier appears only
near the end, just as it does in iOS. This keeps stat meaning visually
consistent across platforms. Stats sheets additionally show the iOS-style
animated white rating marker with Accent-blue ring and glow; the compact
in-game progress bars intentionally remain marker-free.

Total solved includes every successful crossword completion, including Archive
play. Current and best streaks, the Daily and Weekly Stats averages, and
per-row times use only successful completions made during that puzzle's own
release window and shown in the current 14-day history. An archive or previous
game completion must never extend a streak or inflate the release-window
average on either platform. When that window has no eligible solves, the UI
shows an en dash rather than falling back to an all-time average.

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

Players can choose a persistent Backword mode in How to Play or Settings. Easy is the default and restores the original minimum schedule: every wrong guess grows the revealed suffix by one letter, so the final two, three, four, and five letters are visible after the first through fourth wrong guesses. Normal uses the schedule above. In either mode, a longer correctly positioned suffix can reveal earlier.

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

### Mechanical giveaway certification

In addition to exact answer leakage, active crossword clues must not expose an
answer through a mechanically recognisable construction: a prefix or suffix,
contained constituent, inflection, derivational family, or ordinary spelling
shift within that family. For example, `AFIRE` cannot use `fire`, and
`CIRCULAR` cannot use `circle`; unrelated synonyms such as `burning` and
`round` remain valid.

`Backend/audit_answer_giveaways.py` is the canonical review-first workflow. It
uses a local high-recall scan, then exports only candidates for Terra review in
Codex; it never calls an OpenAI API. A second blind Terra decision confirms
flagged fields and separately verifies replacement clues. All review artifacts
are checksum-bound to the source bank, and only explicitly approved,
Terra-verified replacements can be applied.

Replacement authors mark a field `proposed`, export it through
`export-replacement-verification`, and record the blind decision before it can
be marked `approved`. The generated repair report shows only proposed
before/after pairs, making the human review surface compact without implying
that a pending field is safe.

Within one word-bank entry, `clues[]` are hint alternatives for `text`, and
`hard_text`/`hardText` is a hint alternative for the crossword clue fields.
New or repaired active clues therefore must not duplicate any sibling active
clue. The replacement exporter rejects an exact normalized collision before
blind Terra verification; authors also review the batch for non-identical
near-duplicates that would make a hint give away another clue.

`word_bank_answer_giveaway_certification.json` records every active
answer/clue-pair fingerprint under the current policy and scanner version.
Deterministically clean non-candidates are certified locally; ambiguous
spelling-family candidates require Terra provenance, while deterministic
giveaways cannot be certified. Daily and weekly generators validate that certification before
selecting any words and fail closed if a field changes, a review is unresolved,
or a dormant `hint` could become a fallback. `hint` itself is intentionally
outside the certificate while every entry retains non-empty `clues[]` and
`hard_text`/`hardText`.

After bank repairs are certified, use `Backend/audit_unreleased_puzzles.py` to
audit only future local artifacts and Supabase daily/weekly rows. Its update
packages preserve grids and answers, bind every replacement to the original
row and clues payload, and require explicit review plus `--yes` before a remote
write. Released and current puzzles are never changed by this workflow.

If an approved repair must also be propagated to released history, use the
script's separate `audit-history-remote` and `build-history-updates` commands.
They require both the pre-repair snapshot and the certified repaired bank, and
may change a historical clue only when its stored source field (or one unique
exact legacy value) is the precise old value from that repair. They never
rewrite a merely uncertified historical clue, grid, or answer; the current date
remains excluded.

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

## Word Bank Content Curation

The crossword word bank is family-friendly. Sexual, sexually suggestive, and
reproductive-health entries identified during content review are removed as
whole entries, including entries whose clue text alone introduced the concern.
`WordBankTests.testRemovedSensitiveEntriesAreAbsent` guards the reviewed
removal set against accidental reintroduction.

---

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
