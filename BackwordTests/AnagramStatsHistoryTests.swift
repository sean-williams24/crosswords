import Foundation
import Testing
@testable import Backword

@Suite("Anagram stats history")
struct AnagramStatsHistoryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test("The 14-day history uses release-day results and excludes review and archive play")
    func releaseDayBreakdown() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-04T12:00:00Z"))
        let first = try progress(date: "2026-10-01", completed: "2026-10-01T12:00:45Z", outcome: .solved, score: 4, seconds: 45)
        let second = try progress(date: "2026-10-02", completed: "2026-10-02T12:01:10Z", outcome: .solved, score: 3, seconds: 70)
        let gaveUp = try progress(date: "2026-10-03", completed: "2026-10-03T12:00:30Z", outcome: .gaveUp, score: 0, seconds: 30)
        let playing = try progress(date: "2026-10-04")
        let archive = try progress(date: "2026-09-30", completed: "2026-10-04T12:00:50Z", outcome: .solved, score: 0, seconds: 50)
        let review = try progress(date: "review", completed: "2026-10-04T12:00:20Z", outcome: .solved, score: 5, seconds: 20)

        var rating = OverallRating()
        rating.upsertAnagram(score: 4, date: first.date)
        rating.upsertAnagram(score: 3, date: second.date)
        let history = AnagramStatsHistory.make(
            rating: rating,
            progressRecords: [first, second, gaveUp, playing, archive, review],
            releaseCalendar: ContentReleaseCalendar(now: now, calendar: calendar)
        )

        #expect(history.rows.count == 14)
        #expect(history.rows.first?.dateStr == "2026-10-04")
        #expect(history.rows.last?.dateStr == "2026-09-21")
        #expect(history.rows[0].outcome == .inProgress)
        #expect(history.rows[0].score == 0)
        #expect(history.rows[1].outcome == .gaveUp)
        #expect(history.rows[1].solveTime == nil)
        #expect(history.rows[2].outcome == .solved)
        #expect(history.rows[2].score == 3)
        #expect(history.rows[2].solveTime == 70)
        #expect(history.rows[3].score == 4)
        #expect(history.rows[4].outcome == .unplayed)
        #expect(history.rows[4].score == 0)
        #expect(history.totalSolved == 2)
        #expect(history.bestStreak == 2)
        #expect(history.currentStreak == 0)
        #expect(history.averageSolveTime == "0:57")
    }

    @Test("An unfinished today keeps yesterday's streak and missing scores use saved progress")
    func currentStreakAndSavedScore() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-04T12:00:00Z"))
        let yesterday = try progress(date: "2026-10-03", completed: "2026-10-03T12:00:25Z", outcome: .solved, score: 5, seconds: 25)
        let playing = try progress(date: "2026-10-04")
        let history = AnagramStatsHistory.make(
            rating: OverallRating(), progressRecords: [yesterday, playing],
            releaseCalendar: ContentReleaseCalendar(now: now, calendar: calendar)
        )

        #expect(history.currentStreak == 1)
        #expect(history.bestStreak == 1)
        #expect(history.rows[1].score == 5)
        #expect(history.averageSolveTime == "0:25")
    }

    private func progress(
        date: String, completed: String? = nil,
        outcome: AnagramProgress.Outcome? = nil,
        score: Int = 0, seconds: Int? = nil
    ) throws -> AnagramProgress {
        let startedAt = try #require(ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z"))
        let puzzle = AnagramPuzzle(
            id: "puzzle-\(date)", date: date, puzzleNumber: 1, schemaVersion: 1,
            answer: "TRIANGLE", acceptedAnswers: [], initialScramble: "RAGTLINE"
        )
        var progress = AnagramProgress(puzzle: puzzle, now: startedAt)
        progress.outcome = outcome
        progress.completedAt = completed.flatMap { ISO8601DateFormatter().date(from: $0) }
        progress.elapsedSecondsAtCompletion = seconds
        progress.releaseDateScore = score
        progress.updatedAt = progress.completedAt ?? startedAt
        return progress
    }
}
