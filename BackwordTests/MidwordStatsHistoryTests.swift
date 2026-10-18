import Foundation
import Testing
@testable import Backword

@Suite("Midword stats history")
struct MidwordStatsHistoryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test("History includes release-day results and builds streak and guess totals")
    func releaseDayBreakdown() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z"))
        let first = try progress(date: "2026-10-01", completed: "2026-10-01T12:00:00Z", won: true, score: 4, guesses: 2)
        let second = try progress(date: "2026-10-02", completed: "2026-10-02T12:00:00Z", won: true, score: 3, guesses: 3)
        let failed = try progress(date: "2026-10-03", completed: "2026-10-03T12:00:00Z", won: false, guesses: 5)
        let yesterday = try progress(date: "2026-10-04", completed: "2026-10-04T12:00:00Z", won: true, score: 5, guesses: 1)
        let playing = try progress(date: "2026-10-05", guesses: 1)
        let archive = try progress(date: "2026-09-30", completed: "2026-10-05T12:00:00Z", won: true, guesses: 1)

        var rating = OverallRating()
        rating.upsertMidword(score: 4, date: first.date)
        let history = MidwordStatsHistory.make(
            rating: rating,
            progressRecords: [first, second, failed, yesterday, playing, archive],
            releaseCalendar: ContentReleaseCalendar(now: now, calendar: calendar)
        )

        #expect(history.rows.count == 5)
        #expect(history.rows[0].outcome == .inProgress)
        #expect(history.rows[1].outcome == .solved)
        #expect(history.rows[1].guessCount == 1)
        #expect(history.rows[2].outcome == .failed)
        #expect(history.rows[3].score == 3)
        #expect(history.rows[4].score == 4)
        #expect(history.totalSolved == 3)
        #expect(history.currentStreak == 1)
        #expect(history.bestStreak == 2)
        #expect(history.guessDistribution == [1: 1, 2: 1, 3: 1])
    }

    @Test("A failure today resets the current streak")
    func failedTodayResetsStreak() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z"))
        let yesterday = try progress(date: "2026-10-04", completed: "2026-10-04T12:00:00Z", won: true, score: 5, guesses: 1)
        let today = try progress(date: "2026-10-05", completed: "2026-10-05T12:00:00Z", won: false, guesses: 5)
        let history = MidwordStatsHistory.make(
            rating: OverallRating(),
            progressRecords: [yesterday, today],
            releaseCalendar: ContentReleaseCalendar(now: now, calendar: calendar)
        )

        #expect(history.currentStreak == 0)
    }

    @Test("Countdown uses clock formatting and rounds partial seconds up")
    func countdownFormatting() {
        #expect(MidwordCountdownText.value(secondsRemaining: 7_545.2) == "02:05:46")
        #expect(MidwordCountdownText.value(secondsRemaining: nil) == "--:--:--")
    }

    private func progress(
        date: String,
        completed: String? = nil,
        won: Bool = false,
        score: Int = 0,
        guesses: Int = 0
    ) throws -> MidwordProgress {
        var progress = MidwordProgress(date: date)
        progress.guesses = Array(repeating: "WORD", count: guesses)
        progress.completedAt = completed.flatMap { ISO8601DateFormatter().date(from: $0) }
        progress.won = won
        progress.releaseDateScore = score
        progress.updatedAt = progress.completedAt ?? Date(timeIntervalSince1970: 0)
        return progress
    }
}
