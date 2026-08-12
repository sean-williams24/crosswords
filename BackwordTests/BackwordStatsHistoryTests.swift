import Foundation
import Testing
@testable import Backword

@Suite("Backword Stats History Tests")
struct BackwordStatsHistoryTests {

    @Test("Account stats exclude archive results from all-time performance metrics")
    func accountStatsExcludeArchiveResults() throws {
        let calendar = releaseCalendar()
        var onTimeWin = BackwordProgress(date: "2026-08-02")
        onTimeWin.guesses = ["CASTLE"]
        onTimeWin.wonFlag = true
        onTimeWin.completedAt = try date("2026-08-02T12:00:00Z")

        var archiveWin = BackwordProgress(date: "2026-07-20")
        archiveWin.guesses = ["PLANET", "CASTLE"]
        archiveWin.wonFlag = true
        archiveWin.completedAt = try date("2026-08-03T12:00:00Z")

        var onTimeFailure = BackwordProgress(date: "2026-08-03")
        onTimeFailure.guesses = ["PLANET", "STREAM", "CANDLE", "MARKET", "FLOWER"]
        onTimeFailure.completedAt = try date("2026-08-03T12:00:00Z")

        let stats = BackwordStats.rebuiltForAccount(
            progressRecords: [onTimeWin, archiveWin, onTimeFailure],
            calendar: calendar
        )

        #expect(stats.gamesPlayed == 2)
        #expect(stats.gamesWon == 1)
        #expect(stats.winRate == 50)
        #expect(stats.count(forGuess: 1) == 1)
        #expect(stats.count(forGuess: 2) == 0)
        #expect(stats.longestStreak == 1)
    }

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
