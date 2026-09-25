# Anagram v1 contract

This contract is shared by the generator, iOS client, and later web client. The
first release date is configured in content, not inferred from installation
date. Before content is published, the iOS game uses a bundled review fixture.

## Content

`anagram_puzzles` has `id` (UUID), `date` (local release day, `YYYY-MM-DD`),
`puzzle_number` (immutable issue number), `schema_version` (`1`), and
`puzzle_data` with this shape:

```json
{
  "answer": "TRIANGLE",
  "acceptedAnswers": ["INTEGRAL"],
  "initialScramble": "RAGTLINE"
}
```

Production answers have 7–9 uppercase ASCII letters. `acceptedAnswers` omits
the primary answer. Every accepted answer has exactly the same letter multiset
as `answer`. `initialScramble` has that same multiset and is not an accepted
answer. The character at each zero-based index in `initialScramble` is a
distinct tile identity, even when characters repeat. Dates and issue numbers
are unique. A published row is immutable.

## Progress

`game_progress.game_type` is `anagram`; `content_key` is the puzzle date;
`schema_version` is `1`. Its JSON payload uses camelCase:

```json
{
  "schemaVersion": 1,
  "puzzleID": "00000000-0000-0000-0000-000000000000",
  "date": "2026-10-01",
  "startedAt": "2026-10-01T10:00:00Z",
  "trayOrder": [0, 1, 2, 3, 4, 5, 6, 7],
  "placedTileIDs": [null, null, null, null, null, null, null, null],
  "placementHistory": [],
  "hintUsed": false,
  "hintSource": null,
  "lockedCellIndex": null,
  "lockedTileID": null,
  "penaltySeconds": 0,
  "outcome": null,
  "completedAt": null,
  "elapsedSecondsAtCompletion": null,
  "releaseDateScore": 0,
  "updatedAt": "2026-10-01T10:00:00Z"
}
```

An absent progress record means Start has not been tapped. `startedAt` is
immutable after creation. `trayOrder` contains each tile ID once; shuffling
changes only the relative order of currently available IDs. `placedTileIDs`
has one entry per answer cell. A revealed, locked cell is represented by
`lockedCellIndex` and `lockedTileID` (both optional fields); its tile ID also
appears in `placedTileIDs`. `placementHistory` lists only player-placed tile
IDs, oldest first. Undo removes its last ID. Restart returns all history IDs
to the tray. A hint clears the history and player placements before locking
one correct tile. `hintSource` is `rewarded_ad` or `time_penalty`; a failed or
cancelled advert does not consume the hint. The penalty is 30 seconds for
`time_penalty` and zero for `rewarded_ad`.

`outcome` is `solved` or `gave_up`; terminal records cannot resume.
`elapsedSecondsAtCompletion` stores raw wall time from `startedAt` to
`completedAt`. The score uses that value plus `penaltySeconds`, while results
display both separately. Only a completion on the puzzle's local release date gets a
nonzero `releaseDateScore`; later completion must retain an earlier score.
Score thresholds use strict `< 30`, `< 60`, `< 120`, and `< 180` seconds.

The whole arrangement and matching Undo history form one conflict unit. Sync
must preserve the earliest `startedAt`, consumed hint and maximum penalty,
terminal outcome, and previously earned release score. Do not combine
two devices' cell arrays or Undo histories. Account and guest storage remain
separate, following the existing progress namespace and queued sync approach.
If only one branch has used a hint, its complete arrangement wins while both
branches remain in progress. If both have used a hint, select one complete
arrangement by the existing rank and update-time policy. A terminal branch
wins over an in-progress branch; two terminal branches retain the earliest
completion. Carry the earliest start and maximum penalty into the selected
record, so a stale device cannot restore a consumed hint or shorten the timer.
If an earlier start arrives after a terminal record, recalculate that record's
raw elapsed time and score from the earlier start and selected completion;
an unsynced later start cannot yield a faster score. A zero score from give up
or late completion remains zero.
