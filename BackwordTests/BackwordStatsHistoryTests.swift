import Foundation
import Testing
@testable import Backword

@Suite("Backword Stats History Tests")
struct BackwordStatsHistoryTests {

    @Test("History shows every release in the last 14 days")
    func historyIncludesPlayedInProgressAndUnplayedDays() throws {
        let calendar = releaseCalendar()
        let now = try date("2026-07-28T12:00:00Z")

        var inProgress = BackwordProgress(date: "2026-07-28")
        inProgress.guesses = ["PLANET", "STREAM"]

        var solved = BackwordProgress(date: "2026-07-27")
        solved.guesses = ["PLANET", "CASTLE"]
        solved.wonFlag = true
        solved.completedAt = try date("2026-07-27T12:00:00Z")

        var failed = BackwordProgress(date: "2026-07-26")
        failed.guesses = ["PLANET", "STREAM", "CANDLE", "MARKET", "FLOWER"]
        failed.completedAt = try date("2026-07-26T12:00:00Z")

        let rating = OverallRating(dailyScores: [
            DailyScore(
                date: "2026-07-27",
                dailyCrossword: 0,
                weeklyCrossword: nil,
                backword: 4
            )
        ])

        let history = BackwordStatsHistory.make(
            rating: rating,
            progressRecords: [inProgress, solved, failed],
            releaseCalendar: ContentReleaseCalendar(now: now, calendar: calendar)
        )

        #expect(history.rows.count == 14)
        #expect(history.rows.first?.dateStr == "2026-07-28")
        #expect(history.rows.last?.dateStr == "2026-07-15")

        #expect(history.rows[0].isToday)
        #expect(history.rows[0].guessCount == 2)
        #expect(history.rows[0].outcome == .inProgress)
        #expect(history.rows[0].score == 0)

        #expect(history.rows[1].guessCount == 2)
        #expect(history.rows[1].outcome == .solved)
        #expect(history.rows[1].score == 4)

        #expect(history.rows[2].guessCount == 5)
        #expect(history.rows[2].outcome == .failed)
        #expect(history.rows[2].score == 0)

        #expect(history.rows[3].guessCount == nil)
        #expect(history.rows[3].outcome == .unplayed)
        #expect(history.rows[3].score == 0)
    }

    @Test("Completed progress supplies a score when rating history is missing")
    func completedProgressBackfillsDisplayedScore() throws {
        let calendar = releaseCalendar()
        let now = try date("2026-07-28T12:00:00Z")
        var solved = BackwordProgress(date: "2026-07-27")
        solved.guesses = ["PLANET", "STREAM", "CASTLE"]
        solved.wonFlag = true
        solved.completedAt = try date("2026-07-27T12:00:00Z")

        let history = BackwordStatsHistory.make(
            rating: OverallRating(),
            progressRecords: [solved],
            releaseCalendar: ContentReleaseCalendar(now: now, calendar: calendar)
        )

        #expect(history.rows[1].score == 3)
    }

    private func releaseCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ isoString: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        return try #require(formatter.date(from: isoString))
    }
}
