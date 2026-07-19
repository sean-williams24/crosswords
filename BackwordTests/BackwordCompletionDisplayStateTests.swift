import Foundation
import Testing
@testable import Backword

@Suite("Backword Completion Display State Tests")
struct BackwordCompletionDisplayStateTests {

    @Test("Stats screen without completion shows stats and no title")
    func statsScreenWithoutCompletionShowsStatsAndNoTitle() {
        let state = BackwordCompletionDisplayState.make(
            progress: nil,
            isCompletion: false,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == nil)
        #expect(state.showsStats)
        #expect(state.message == nil)
    }

    @Test("Backword won on release date shows solved stats")
    func onTimeWinShowsSolvedStats() throws {
        let state = BackwordCompletionDisplayState.make(
            progress: progress(date: "2026-05-10", completedAt: try date("2026-05-10T10:00:00Z")),
            isCompletion: true,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == "Solved!")
        #expect(state.titleStyle == .solved)
        #expect(state.showsStats)
        #expect(state.message == nil)
    }

    @Test("Backword won after release date shows finished message and stats")
    func lateWinShowsFinishedMessageAndStats() throws {
        let state = BackwordCompletionDisplayState.make(
            progress: progress(date: "2026-05-10", completedAt: try date("2026-05-11T10:00:00Z")),
            isCompletion: true,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == "Finished")
        #expect(state.titleStyle == .finished)
        #expect(state.showsStats)
        #expect(state.message == "Complete Backword on its release date to earn points.")
    }

    @Test("Failed Backword shows failed stats")
    func failedBackwordShowsFailedStats() throws {
        var failedProgress = BackwordProgress(date: "2026-05-10")
        failedProgress.guesses = ["BRIDGX", "FXASXE", "MAXXXX", "PUZZLE", "CASTER"]
        failedProgress.completedAt = try date("2026-05-10T10:00:00Z")

        let state = BackwordCompletionDisplayState.make(
            progress: failedProgress,
            isCompletion: true,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == "Failed")
        #expect(state.titleStyle == .failed)
        #expect(state.showsStats)
        #expect(state.message == nil)
    }

    private func progress(date: String, completedAt: Date) -> BackwordProgress {
        var progress = BackwordProgress(date: date)
        progress.guesses = ["CASTLE"]
        progress.wonFlag = true
        progress.completedAt = completedAt
        return progress
    }

    private func calendar(for date: Date) -> ContentReleaseCalendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return ContentReleaseCalendar(now: date, calendar: calendar)
    }

    private func date(_ isoString: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        return try #require(formatter.date(from: isoString))
    }
}
