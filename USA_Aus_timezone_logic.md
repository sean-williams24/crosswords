# USA / Aus Timezone Logic

## USA (behind UTC)

New content drops **in the evening of the previous local day**:

| Timezone | UTC midnight arrives at | Effect |
|---|---|---|
| EDT (UTC-4) | 8:00 PM local, May 9 | May 10's puzzle available the night before |
| CDT (UTC-5) | 7:00 PM local, May 9 | Same — evening before |
| MDT (UTC-6) | 6:00 PM local, May 9 | Same — evening before |
| PDT (UTC-7) | 5:00 PM local, May 9 | Same — afternoon before |

**UX impact:** US users get "tomorrow's" puzzle in the evening. This mirrors the NYT crossword convention (next-day puzzle drops at 10 PM ET), so it's actually familiar. The "TODAY" label (which uses local time) will correctly show "TODAY" once local midnight passes, aligning the label with the user's expectation.

The midnight refresh `Task` fires at UTC midnight (e.g. 8 PM EDT) — the user may still be active, so they'll see new content appear in-session.

## Australia (ahead of UTC)

New content doesn't arrive until **mid-morning** of the local day:

| Timezone | UTC midnight arrives at | Effect |
|---|---|---|
| AWST (UTC+8) | 8:00 AM local, May 10 | Puzzle unavailable until 8 AM |
| ACST (UTC+9:30) | 9:30 AM local, May 10 | Puzzle unavailable until 9:30 AM |
| AEST (UTC+10) | 10:00 AM local, May 10 | Puzzle unavailable until 10 AM |
| AEDT (UTC+11) | 11:00 AM local, May 10 | Puzzle unavailable until 11 AM |

**UX impact:** Australian users wake up and "today's" puzzle isn't available yet. From midnight to ~10 AM AEST, local-today is ahead of UTC-today. During this window:
- The `RatingDetailSheet` "TODAY" label won't appear (local date ≠ UTC date)
- The "Until X:XX AM" hint kicks in — showing e.g. "Until 10:00 AM" for AEST users
- The midnight refresh fires at 10 AM local, which is when the app updates

**This is the weakest scenario** — Australian morning users (a prime puzzle-solving time) must wait hours into their day for fresh content.

---

## Key question

Would you like to explore changes to address the Australian experience? Options include:
1. **Do nothing** — accept the tradeoff (simplest, current state)
2. **Shift the release time earlier** (e.g. publish puzzles at 14:00 UTC the day before → available at midnight AEST, but then US users get it even earlier at ~10 AM ET)
3. **Per-region release windows** — more complex, requires multiple scheduled dates or timezone-aware queries

---
