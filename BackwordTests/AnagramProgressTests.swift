import Foundation
import Testing
@testable import Backword

@Suite("Anagram progress")
struct AnagramProgressTests {
    private let puzzle = AnagramPuzzle(
        id: "00000000-0000-4000-8000-000000000001", date: "2026-10-01",
        puzzleNumber: 1, schemaVersion: 1, answer: "TRIANGLE",
        acceptedAnswers: ["INTEGRAL"], initialScramble: "RAGTLINE"
    )
    private let repeated = AnagramPuzzle(
        id: "00000000-0000-4000-8000-000000000002", date: "2026-10-02",
        puzzleNumber: 2, schemaVersion: 1, answer: "DESIGNER",
        acceptedAnswers: ["REDESIGN", "RESIGNED"], initialScramble: "EGDRSNEI"
    )

    @Test func homeCardStatusScoreAndStreakFollowReleaseDayResults() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.startOfDay(for: now)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        func record(daysAgo: Int, outcome: AnagramProgress.Outcome?, score: Int) -> AnagramProgress {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let datedPuzzle = AnagramPuzzle(
                id: "puzzle-\(daysAgo)", date: formatter.string(from: day),
                puzzleNumber: daysAgo + 1, schemaVersion: 1,
                answer: "TRIANGLE", acceptedAnswers: [], initialScramble: "RAGTLINE"
            )
            var progress = AnagramProgress(puzzle: datedPuzzle, now: day)
            progress.outcome = outcome
            progress.releaseDateScore = score
            if outcome != nil { progress.completedAt = day.addingTimeInterval(60) }
            return progress
        }

        let yesterday = record(daysAgo: 1, outcome: .solved, score: 4)
        let twoDaysAgo = record(daysAgo: 2, outcome: .solved, score: 2)
        let history = [twoDaysAgo, yesterday]
        let new = AnagramHomeCardSummary(progress: nil, history: history, now: now, calendar: calendar)
        #expect(new.status == .new)
        #expect(new.score == nil)
        #expect(new.streak == 2)

        let playing = record(daysAgo: 0, outcome: nil, score: 0)
        let inProgress = AnagramHomeCardSummary(progress: playing, history: history + [playing], now: now, calendar: calendar)
        #expect(inProgress.status == .inProgress)
        #expect(inProgress.streak == 2)

        let solved = record(daysAgo: 0, outcome: .solved, score: 5)
        let completed = AnagramHomeCardSummary(progress: solved, history: history + [solved], now: now, calendar: calendar)
        #expect(completed.status == .solved)
        #expect(completed.score == 5)
        #expect(completed.streak == 3)

        let gaveUp = record(daysAgo: 0, outcome: .gaveUp, score: 0)
        let failed = AnagramHomeCardSummary(progress: gaveUp, history: history + [gaveUp], now: now, calendar: calendar)
        #expect(failed.status == .gaveUp)
        #expect(failed.score == 0)
        #expect(failed.streak == 0)

        let lateSolve = record(daysAgo: 0, outcome: .solved, score: 0)
        let finished = AnagramHomeCardSummary(progress: lateSolve, history: history + [lateSolve], now: now, calendar: calendar)
        #expect(finished.status == .finished)
        #expect(finished.streak == 0)

        let oldSolve = record(daysAgo: 4, outcome: .solved, score: 5)
        let interrupted = AnagramHomeCardSummary(progress: nil, history: [oldSolve], now: now, calendar: calendar)
        #expect(interrupted.streak == 0)
    }

    @Test func contentAndDistinctRepeatedTiles() {
        #expect(puzzle.isValid)
        #expect(repeated.isValid)
        var progress = AnagramProgress(puzzle: repeated)
        progress.place(0, in: repeated)
        progress.place(6, in: repeated)
        #expect(progress.placedTileIDs[0] == 0)
        #expect(progress.placedTileIDs[1] == 6)
        #expect(!progress.availableTileIDs.contains(0))
        #expect(!progress.availableTileIDs.contains(6))
        progress.undo()
        #expect(progress.availableTileIDs.contains(6))
        #expect(!progress.availableTileIDs.contains(0))
        progress.undo()
        #expect(progress.availableTileIDs.contains(0))
    }

    @Test func invalidRestoredTileIDsAreRejected() {
        var progress = AnagramProgress(puzzle: puzzle)
        progress.placedTileIDs[0] = 99
        #expect(!progress.isValid(for: puzzle))
        progress.placedTileIDs[0] = 0
        progress.placedTileIDs[1] = 0
        #expect(!progress.isValid(for: puzzle))
        progress.placedTileIDs[1] = nil
        progress.placementHistory = []
        #expect(!progress.isValid(for: puzzle))
        progress.placementHistory = [0, 0]
        #expect(!progress.isValid(for: puzzle))
        progress.placementHistory = [0]
        progress.penaltySeconds = 30
        #expect(!progress.isValid(for: puzzle))
        progress.penaltySeconds = 0
        progress.outcome = .gaveUp
        #expect(!progress.isValid(for: puzzle))
    }

    @Test func restoresUndoHistoryAndRestartKeepsClockAndHint() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var progress = AnagramProgress(puzzle: puzzle, now: start)
        progress.place(0, in: puzzle, now: start.addingTimeInterval(5))
        progress.place(1, in: puzzle, now: start.addingTimeInterval(7))
        let decoded = try JSONDecoder().decode(AnagramProgress.self, from: JSONEncoder().encode(progress))
        #expect(decoded.placementHistory == [0, 1])
        progress.revealHint(in: puzzle, source: .timePenalty, now: start.addingTimeInterval(10))
        #expect(progress.placementHistory.isEmpty)
        #expect(progress.lockedTileID != nil)
        #expect(progress.penaltySeconds == 30)
        progress.place(1, in: puzzle, now: start.addingTimeInterval(12))
        progress.restart(now: start.addingTimeInterval(20))
        #expect(progress.startedAt == start)
        #expect(progress.penaltySeconds == 30)
        #expect(progress.lockedTileID != nil)
        #expect(progress.placedTileIDs.compactMap { $0 } == [progress.lockedTileID!])
        #expect(progress.elapsedSeconds(at: start.addingTimeInterval(100)) == 100)
    }

    @Test func rewardedHintHasNoPenaltyAndCanOnlyBeUsedOnce() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var progress = AnagramProgress(puzzle: puzzle, now: start)
        progress.revealHint(in: puzzle, source: .rewardedAd, now: start.addingTimeInterval(10))
        let firstTile = progress.lockedTileID
        #expect(progress.hintUsed)
        #expect(progress.hintSource == .rewardedAd)
        #expect(progress.penaltySeconds == 0)
        progress.revealHint(in: puzzle, source: .timePenalty, now: start.addingTimeInterval(20))
        #expect(progress.lockedTileID == firstTile)
        #expect(progress.penaltySeconds == 0)
    }

    @Test func incorrectArrangementStaysEditableAndShufflePreservesPlacement() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var progress = AnagramProgress(puzzle: puzzle, now: start)
        for tile in [0, 1, 2, 3, 4, 5, 6, 7] {
            progress.place(tile, in: puzzle, now: start.addingTimeInterval(8))
        }
        #expect(progress.displayedAnswer(for: puzzle) == "RAGTLINE")
        #expect(progress.outcome == nil)
        #expect(progress.canUndo)
        progress.undo(now: start.addingTimeInterval(12))
        progress.undo(now: start.addingTimeInterval(12))
        let placement = progress.placedTileIDs
        let available = progress.availableTileIDs
        progress.shuffle(using: Array(available.reversed()), now: start.addingTimeInterval(15))
        #expect(progress.placedTileIDs == placement)
        #expect(progress.availableTileIDs == Array(available.reversed()))
        #expect(progress.startedAt == start)
        #expect(progress.penaltySeconds == 0)
        progress.giveUp(now: start.addingTimeInterval(20))
        #expect(progress.outcome == .gaveUp)
        #expect(progress.releaseDateScore == 0)
        #expect(!progress.canUndo)
        #expect(!progress.canRestart)
    }

    @Test func terminalGiveUpCannotInheritAnotherBranchPoints() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        let start = formatter.date(from: "2026-10-01 12:00:00")!
        var gaveUp = AnagramProgress(puzzle: puzzle, now: start)
        gaveUp.giveUp(now: start.addingTimeInterval(20))
        var laterSolve = AnagramProgress(puzzle: puzzle, now: start.addingTimeInterval(2))
        laterSolve.finish(.solved, now: start.addingTimeInterval(25))
        let merged = AnagramProgress.merged(gaveUp, laterSolve)
        #expect(merged.outcome == .gaveUp)
        #expect(merged.releaseDateScore == 0)
    }

    @Test func alternateAnswerAndScoreBoundaries() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        var progress = AnagramProgress(puzzle: puzzle, now: start)
        // RAGTLINE tile IDs for INTEGRAL.
        for tile in [5, 6, 3, 7, 2, 0, 1, 4] {
            progress.place(tile, in: puzzle, now: start.addingTimeInterval(30))
        }
        #expect(progress.outcome == .solved)
        #expect(progress.displayedAnswer(for: puzzle) == "INTEGRAL")
        #expect(progress.elapsedSecondsAtCompletion == 30)
        #expect(AnagramProgress.points(for: 29) == 5)
        #expect(AnagramProgress.points(for: 30) == 4)
        #expect(AnagramProgress.points(for: 59) == 4)
        #expect(AnagramProgress.points(for: 60) == 3)
        #expect(AnagramProgress.points(for: 119) == 3)
        #expect(AnagramProgress.points(for: 120) == 2)
        #expect(AnagramProgress.points(for: 179) == 2)
        #expect(AnagramProgress.points(for: 180) == 1)
    }

    @Test func elapsedTimeFormatsAcrossMinutesAndHours() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let progress = AnagramProgress(puzzle: puzzle, now: start)
        #expect(progress.elapsedSeconds(at: start.addingTimeInterval(5)).formattedTimeHHMMSS == "0:05")
        #expect(progress.elapsedSeconds(at: start.addingTimeInterval(65)).formattedTimeHHMMSS == "1:05")
        #expect(progress.elapsedSeconds(at: start.addingTimeInterval(12_573)).formattedTimeHHMMSS == "3:29:33")
    }

    @Test func mergePreservesOneArrangementAndEarnedScore() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var local = AnagramProgress(puzzle: puzzle, now: start)
        local.place(0, in: puzzle, now: start.addingTimeInterval(10))
        var remote = AnagramProgress(puzzle: puzzle, now: start.addingTimeInterval(3))
        remote.place(1, in: puzzle, now: start.addingTimeInterval(20))
        remote.place(2, in: puzzle, now: start.addingTimeInterval(21))
        let merged = AnagramProgress.merged(local, remote)
        #expect(merged.startedAt == start)
        #expect(merged.placedTileIDs == remote.placedTileIDs)
        #expect(merged.placementHistory == remote.placementHistory)
    }

    @Test func earlierStartCorrectsCrossDeviceTerminalScore() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        let start = formatter.date(from: "2026-10-01 12:00:00")!
        var earlier = AnagramProgress(puzzle: puzzle, now: start)
        earlier.place(0, in: puzzle, now: start.addingTimeInterval(2))
        var later = AnagramProgress(puzzle: puzzle, now: start.addingTimeInterval(40))
        later.finish(.solved, now: start.addingTimeInterval(50))
        #expect(later.releaseDateScore == 5)
        let merged = AnagramProgress.merged(earlier, later)
        #expect(merged.outcome == .solved)
        #expect(merged.startedAt == start)
        #expect(merged.elapsedSecondsAtCompletion == 50)
        #expect(merged.releaseDateScore == 4)
        #expect(merged.placedTileIDs == later.placedTileIDs)
        #expect(merged.placementHistory == later.placementHistory)
    }

    @Test func lateArchiveSolveCannotEarnReleasePoints() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        let start = formatter.date(from: "2026-10-02 12:00:00")!
        var progress = AnagramProgress(puzzle: puzzle, now: start)
        progress.finish(.solved, now: start.addingTimeInterval(12))
        #expect(progress.releaseDateScore == 0)
        #expect(progress.elapsedSecondsAtCompletion == 12)
        #expect(progress.outcome == .solved)
    }

    @Test func legacyRatingAndReleaseRamp() throws {
        let legacy = Data(#"{"date":"2026-10-01","dailyCrossword":4,"weeklyCrossword":null,"backword":3}"#.utf8)
        let decoded = try JSONDecoder().decode(DailyScore.self, from: legacy)
        #expect(decoded.anagram == 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = ISO8601DateFormatter()
        #expect(OverallRating.anagramPossiblePoints(now: formatter.date(from: "2026-10-01T12:00:00Z")!, calendar: calendar, firstRelease: "2026-10-01") == 5)
        #expect(OverallRating.anagramPossiblePoints(now: formatter.date(from: "2026-10-14T12:00:00Z")!, calendar: calendar, firstRelease: "2026-10-01") == 70)
        #expect(OverallRating.anagramPossiblePoints(now: formatter.date(from: "2026-09-30T12:00:00Z")!, calendar: calendar, firstRelease: "2026-10-01") == 0)
        let rating = OverallRating()
        let firstDay = formatter.date(from: "2026-10-01T12:00:00Z")!
        let established = formatter.date(from: "2026-10-14T12:00:00Z")!
        #expect(rating.maxPoints(isPro: false, now: firstDay, calendar: calendar, firstAnagramRelease: "2026-10-01") == 145)
        #expect(rating.maxPoints(isPro: true, now: firstDay, calendar: calendar, firstAnagramRelease: "2026-10-01") == 155)
        #expect(rating.maxPoints(isPro: false, now: established, calendar: calendar, firstAnagramRelease: "2026-10-01") == 210)
        #expect(rating.maxPoints(isPro: true, now: established, calendar: calendar, firstAnagramRelease: "2026-10-01") == 220)
    }
}
