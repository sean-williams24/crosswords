import Foundation
import Testing
@testable import Backword

@Suite("Weekly crossword history release scores")
struct WeeklyCrosswordStatsHistoryReleaseScoreTests {
    @Test("Previous games use their persisted release score after the rating window expires")
    func previousGameUsesPersistedReleaseScore() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let releaseCalendar = ContentReleaseCalendar(
            now: try date("2026-08-30T12:00:00Z"),
            calendar: calendar
        )
        var previousGame = UserProgress(
            puzzleId: "weekly-2026-08-16",
            size: 13,
            puzzleDate: "2026-08-16",
            totalClues: 40,
            isWeekly: true
        )
        previousGame.releaseDateScore = 3

        let history = WeeklyCrosswordStatsHistory.make(
            rating: OverallRating(),
            progressRecords: [previousGame],
            releaseCalendar: releaseCalendar
        )

        let row = try #require(history.previousGames.first { $0.dateStr == "2026-08-16" })
        #expect(row.score == 3)
    }

    private func date(_ isoString: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        return try #require(formatter.date(from: isoString))
    }
}
