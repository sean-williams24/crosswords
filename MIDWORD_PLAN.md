# Midword implementation and content plan

Status: Midword is implemented in the working tree for review. The migration and scheduled publisher have not been deployed. Native visual verification remains for the developer in Xcode; the focused simulator test could not start because the configured simulator UUID is unavailable.

Release date: 2026-10-01. The publisher includes the current date on its first run.

## Confirmed rules

- Show two words and find a middle word that forms two compounds: BANK + NOTE = BANKNOTE; NOTE + BOOK = NOTEBOOK.
- Five accepted guesses. An on-time win scores 5, 4, 3, 2, or 1 points; failure scores 0.
- An incorrect guess receives whole-word feedback only. No letter-position feedback, coloured keyboard hints, or automatic letter reveals.
- Middle words contain 3–6 letters. Show the answer length through the number of cells. Recommend retaining three-letter answers and selecting difficulty by compound familiarity, not length alone.
- Two prompt words are vertically stacked with one active guess row between them. Previous guesses appear beneath the puzzle. Use the existing custom keyboard and a separate submit control, consistent with Backword.
- Use Backword cell interaction and completion animations with square corners and the supplied chartreuse #7A802F / charcoal #1F1F1F palette.

## Proposed defaults

- First release accepts closed compounds with unchanged spelling; spaces, hyphens, proper names, abbreviations, and arbitrary substring joins are excluded. Prompt words and the link must all be standalone words. Dictionary occurrence alone is not proof of a meaningful compound.
- Incomplete, duplicate, and unrecognised guesses do not consume attempts. Reuse the US/UK dictionary policy; approved puzzle answers always bypass system-dictionary rejection. A recognised but incorrect link consumes one attempt.
- Prefer a single familiar solution. Reject ambiguous candidates during curation; the payload may carry explicitly reviewed alternative answers of the same length so a legitimate known solution is never marked wrong.
- Free daily game, available from Home. Include the existing archive/progress/statistics patterns. No new monetisation rule is assumed.
- Scope is native iOS gameplay and its backend. Web sync/rating compatibility is required where shared data changes; a full web game is a separate scope decision.

## Repository findings

- Current app and test targets are Backword and BackwordTests. The Anagram files mentioned in the IDE context are absent from this checkout. Recheck the checkout before implementation if the user expects those components to be reused.
- Relevant references: Backword/Views/Backword/BackwordView.swift, BackwordLetterCell.swift, BackwordCompletionWordView.swift, BackwordStatsView.swift, and BackwordInstructionsContentView.swift; Backword/Views/Crosswords/CustomKeyboardView.swift.
- Reuse Home card issue-number/status patterns, AppFont, AppLayout, semantic asset colours, ContentReleaseCalendar, month-scoped archive caching, and spoiler-safe result sharing.
- Backword/Services/SupabaseClient.swift contains ProgressCloudSync. Both its records and Backend/supabase/schema.sql currently enumerate only Backword, daily crossword, and weekly crossword.
- OverallRating currently allows 140 free / 150 Pro points across 14 days. A third daily game eventually adds 70 points. Old Codable records must remain readable.
- Backend/generate_backword.py uses wordfreq, OpenAI review, and Supabase; .github/workflows/generate-backword.yml runs weekly, publishes ahead, and reports failures/low inventory.

## Implementation sequence

1. Define pure MidwordPuzzle, MidwordProgress, and statistics/history models. Puzzle data includes immutable ID, date, issue number, first word, second word, answer, reviewed alternatives, both completed compounds, and schema version. Progress includes accepted guesses, completion outcome/time, updatedAt, and a durable release-date score. Validate payloads before use: A–Z words, 3–6-letter answers, equal-length alternatives, and exact compound concatenation.
2. Add an injected MidwordService plus @MainActor MidwordViewModel. The service handles fetching/caching and account-scoped persistence; the view model owns input, validation, submission, and transitions. Save locally first, then queue account-tagged cloud uploads. Prevent extra input and duplicate completion while an animation/submission is active. Resume incomplete games and preserve all guesses in terminal games.
3. Add isolated view files under Backword/Views/Midword/: game, board, guess history, home card, instructions, stats, and completion presentation. Extract a shared configurable letter-cell primitive from Backword rather than copying its animation implementation. Preserve Backword defaults; Midword supplies zero corner radius and its own semantic palette. Keep game rules outside the cell component.
4. Match the existing custom navigation bar: back, game title, stats, and info. Match sheet title style, dismissal controls, detents, padding, stats tiles, five-bar guess distribution, 14-day history, and release countdown. Completion shows the link plus both full compounds, using the existing staged reveal/bounce timing, appropriate outcome haptics, and Reduce Motion behaviour. Reopening a completed puzzle opens the completion sheet once per visit.
5. Integrate Home loading/error/retry states, issue number, saved progress, score/streak, local-midnight refresh, archive month loading, and app environment injection. Include loading and offline states; never silently substitute yesterday's game as today's. Keep an already-open puzzle tied to its original date across midnight, and score according to its release window.
6. Extend progress sync, guest migration, account isolation, conflict resolution, deletion/reset flows, rating breakdowns, history, and sharing. Reuse whole-record conflict rules; never merge individual guesses from different devices. Make new fields backward compatible and have web readers safely preserve or ignore unfamiliar records without deleting them.
7. Add the Midword rating category and its launch date. Count only eligible releases after launch in the 14-day denominator, reaching 210 free / 220 Pro points after 14 days. This avoids counting pre-launch days as missed games. Apply the same calculation to shared web rating surfaces. Preserve historical release-score snapshots so late play or later timezone changes cannot alter earned points.
8. Add database schema/migration, curated content tooling, scheduled publishing workflow, focused tests, source attribution, and the new game conventions. Update actual Xcode file membership without regenerating unrelated project settings.

## Layout and accessibility

- Suggested board: first word, centred square answer cells, second word; then attempt counter and previous guesses. The outer words remain visually distinct from editable cells. Completion explicitly demonstrates both combinations.
- Add game-specific semantic colour assets in AppTheme. Use exact chartreuse and charcoal for branding/background accents, with accessible semantic text and focus colours. Their measured mutual contrast is approximately 3.89:1, so they should not be the sole pairing for small body text. White on chartreuse is also below 4.5:1; use a darker on-accent text token.
- Reuse CustomKeyboardView with backward-compatible configuration if sizing or theming changes are needed. Its current fixed key height and fixed grid font need attention for this game's Dynamic Type requirement.
- Use scaled metrics and available-width layout for 3–6 cells. Keep cells square and the full answer in one row; allow the board to scroll horizontally at extreme text sizes rather than clipping letters or disabling Dynamic Type. Let secondary content and stats stack vertically when needed.
- Keep keyboard/submit reachable using safe-area layout, with a scrollable board; at accessibility sizes allow an alternative scroll layout if a pinned keyboard leaves insufficient board space. Do not fix sheet heights.
- VoiceOver labels announce prompt words, entered answer, remaining attempts, and whole-guess feedback. Provide non-colour failure/success indicators and respect Reduce Motion. Preview narrow phones, iPad layouts, long prompt words, largest accessibility sizes, and both appearances.

## Content sourcing and quality

The implemented candidate discovery uses the existing Backend/word_bank.json and the already-installed wordfreq library to rank familiarity. The checked-in, curated Midword inventory is the only source used by the scheduled publisher. A pinned WordNet dataset could add compound evidence in a future inventory-expansion pass; wordfreq is a frequency source, not a dictionary or compound validator.

A read-only feasibility check of this checkout's 22,299 word-bank records, requiring all parts and both joined words to be present and have Zipf frequency >= 3, found 3,611 mechanical triples. 3,418 prompt pairs had one answer within that limited bank: 1,521 three-letter, 1,667 four-letter, 213 five-letter, and 17 six-letter links. These are NOT approved puzzles: false splits such as FAT/HER/SELF occur. The counts demonstrate candidate supply only, not semantic validity or global uniqueness. Do not force equal answer-length quotas or loosen quality to fill a six-letter quota.

Separate discovery/curation from daily publication:

1. Build and version a compound inventory with exact segmentation, definition/sense evidence, source attribution, and regional spelling metadata. Exclude misleading lexical coincidences such as FAT + HER = FATHER.
2. Join approved compounds around a shared 3–6-letter link. Check the full inventory for alternative links, prioritise familiar compounds on both sides, and exclude names, offensive material, obscure inflections, spelling changes, and previously rejected candidates.
3. Produce a review artifact showing both compounds, evidence, familiarity scores, possible alternatives, and rejection reasons. Start with a human-reviewed launch bank; aim for 60–90 approved daily puzzles before release, subject to actual quality yield.
4. Optionally reuse OPENAI_API_KEY for batched semantic review when expanding the bank. A model may propose/review candidates but must not invent the lexical evidence. Cache verdicts by content hash, source version, and prompt/model version. Limit batch size, retry count, output tokens, and total spend; malformed/missing verdicts reject the batch.
5. Publish only approved records. Routine scheduled selection then costs zero AI tokens; optional bank expansion is the only AI cost. Benchmark quality and cost per accepted puzzle before choosing a paid model or promising a monthly price. No paid dictionary API or new API key is required for the initial curated-bank approach.

Sources: https://github.com/rspeer/wordfreq ; https://wordnet.princeton.edu/ ; https://wordnet.princeton.edu/license-and-commercial-use . Preserve upstream attribution and licence notices. Princeton WordNet and wordfreq's frequency data are static resources, which is acceptable for common established compounds; assess gaps during curation.

## Backend and GitHub Actions

- Create midword_puzzles with unique date/issue number and validated puzzle data. Add midword to the game_progress constraint and supported sync types. Match existing RLS and account ownership rules; service-role credentials stay in workflow secrets.
- Add Backend/build_midword_bank.py (discovery/review artifacts) and Backend/generate_midword.py (approved-bank scheduling). Support date/range, count, deterministic seed, dry-run, and explicit publication. Dry-run must not require service-role access when supplied local history.
- Track puzzle signatures and answer reuse cooldowns. Check existing history with pagination. Never repeat the exact prompt pair, overwrite a released game, or renumber an existing issue on retries.
- Add .github/workflows/generate-midword.yml: weekly schedule plus workflow_dispatch, tests before publishing, existing SUPABASE_URL/SUPABASE_KEY secrets, concurrency protection, and a configurable future coverage target (initially 21 days).
- Find gaps from the release horizon forward and fill to the target date, rather than blindly adding another fixed batch after the maximum date. Account for the earliest local timezone when assessing coverage.
- Validate the entire selected batch before writing; publish atomically through a transaction/RPC. Retries are idempotent and incompatible existing rows cause failure. Never relax quality when inventory is exhausted.
- Upload a generation report and use the existing failure/low-inventory issue pattern. Scheduled publishing reads the approved bank and does not require OPENAI_API_KEY. Optional AI bank expansion is a separate, explicitly invoked job.

## Verification and handoff

- Focused Swift Testing coverage: all five win scores, fifth-guess failure, dictionary/duplicate rejection, approved alternatives, normalisation, input limits, completed-game immutability, save/resume, local-first persistence, account changes, sync conflicts, old payload decoding, midnight/DST behaviour, release snapshots, launch-aware rating maxima, stats history, and completion presentation/Reduce Motion state.
- Focused Python tests: exact compound joins, false-segmentation rejection, ambiguity, bounds, repeat exclusions, all-or-nothing validation, malformed optional reviewer replies, dry-run, gap filling, idempotent retries, and preserved issue numbers. Add schema constraint/RLS coverage using the existing backend test style.
- Run only affected unit tests. Do not run standalone builds, launch simulators, perform runtime verification, or retry simulator infrastructure failures without an explicit request. Provide an Xcode visual-check list for Dynamic Type and animations for the developer.
- Present changes for review and wait for explicit approval before committing, per AGENTS.md.
