import Foundation
import Testing
@testable import Backword

@Suite("Crossword Solve Time Summary Tests")
struct CrosswordSolveTimeSummaryTests {

    @Test("Daily average uses on-time progress solve times")
    func dailyAverageUsesOnTimeProgressSolveTimes() throws {
        let records = [
            dailyProgress(
                puzzleId: "daily-1",
                puzzleDate: "2026-07-14",
                startedAt: try date("2026-07-14T07:00:00Z"),
                completedAt: try date("2026-07-14T18:18:48Z")
            ),
            dailyProgress(
                puzzleId: "daily-2",
                puzzleDate: "2026-07-10",
                startedAt: try date("2026-07-10T11:00:00Z"),
                completedAt: try date("2026-07-10T11:46:32Z")
            ),
            dailyProgress(
                puzzleId: "daily-3",
                puzzleDate: "2026-07-09",
                startedAt: try date("2026-07-09T11:00:00Z"),
                completedAt: try date("2026-07-09T11:00:05Z")
            ),
            dailyProgress(
                puzzleId: "daily-4",
                puzzleDate: "2026-07-08",
                startedAt: try date("2026-07-08T08:00:00Z"),
                completedAt: try date("2026-07-08T17:11:26Z")
            ),
            dailyProgress(
                puzzleId: "daily-5",
                puzzleDate: "2026-07-07",
                startedAt: try date("2026-07-07T08:00:00Z"),
                completedAt: try date("2026-07-07T08:11:45Z")
            )
        ]

        #expect(CrosswordSolveTimeSummary.formattedAverageTime(from: records, isWeekly: false) == "4:17:43")
    }

    @Test("Average formats visible stats row solve times")
    func averageFormatsVisibleStatsRowSolveTimes() {
        let solveTimes = [
            11 * 60 * 60 + 18 * 60 + 48,
            46 * 60 + 32,
            5,
            9 * 60 * 60 + 11 * 60 + 26,
            11 * 60 + 45
        ]

        #expect(CrosswordSolveTimeSummary.formattedAverageTime(from: solveTimes) == "4:17:43")
    }

    @Test("Daily average ignores late and gave-up progress")
    func dailyAverageIgnoresLateAndGaveUpProgress() throws {
        var gaveUp = dailyProgress(
            puzzleId: "gave-up",
            puzzleDate: "2026-07-12",
            startedAt: try date("2026-07-12T10:00:00Z"),
            completedAt: try date("2026-07-12T11:00:00Z")
        )
        gaveUp.gaveUpAt = try date("2026-07-12T11:00:00Z")

        let records = [
            dailyProgress(
                puzzleId: "on-time",
                puzzleDate: "2026-07-13",
                startedAt: try date("2026-07-13T10:00:00Z"),
                completedAt: try date("2026-07-13T10:05:00Z")
            ),
            dailyProgress(
                puzzleId: "late",
                puzzleDate: "2026-07-11",
                startedAt: try date("2026-07-12T10:00:00Z"),
                completedAt: try date("2026-07-12T20:00:00Z")
            ),
            gaveUp
        ]

        #expect(CrosswordSolveTimeSummary.formattedAverageTime(from: records, isWeekly: false) == "5:00")
    }

    @Test("Weekly average ignores completions after the next weekly release")
    func weeklyAverageIgnoresCompletionsAfterNextWeeklyRelease() throws {
        let records = [
            weeklyProgress(
                puzzleId: "weekly-on-time",
                puzzleDate: "2026-07-05",
                startedAt: try date("2026-07-11T20:00:00Z"),
                completedAt: try date("2026-07-11T21:30:00Z")
            ),
            weeklyProgress(
                puzzleId: "weekly-late",
                puzzleDate: "2026-07-05",
                startedAt: try date("2026-07-12T00:00:00Z"),
                completedAt: try date("2026-07-12T01:30:00Z")
            )
        ]

        #expect(CrosswordSolveTimeSummary.formattedAverageTime(from: records, isWeekly: true) == "1:30:00")
    }

    private func dailyProgress(
        puzzleId: String,
        puzzleDate: String,
        startedAt: Date,
        completedAt: Date
    ) -> UserProgress {
        var progress = UserProgress(puzzleId: puzzleId, size: 9, puzzleDate: puzzleDate, totalClues: 5, isWeekly: false)
        progress.startedAt = startedAt
        progress.completedAt = completedAt
        return progress
    }

    private func weeklyProgress(
        puzzleId: String,
        puzzleDate: String,
        startedAt: Date,
        completedAt: Date
    ) -> UserProgress {
        var progress = UserProgress(puzzleId: puzzleId, size: 13, puzzleDate: puzzleDate, totalClues: 35, isWeekly: true)
        progress.startedAt = startedAt
        progress.completedAt = completedAt
        return progress
    }

    private func date(_ isoString: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        return try #require(formatter.date(from: isoString))
    }
}
