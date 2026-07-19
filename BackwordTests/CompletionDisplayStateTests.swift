import Foundation
import Testing
@testable import Backword

@Suite("Completion Display State Tests")
struct CompletionDisplayStateTests {

    @Test("Daily crossword completed on release date shows solved stats")
    func dailyOnTimeCompletionShowsSolvedStats() throws {
        let completedAt = try date("2026-05-10T10:00:00Z")
        let progress = progress(completedAt: completedAt)

        let state = CompletionDisplayState.make(
            puzzle: puzzle(date: "2026-05-10", size: 9),
            progress: progress,
            hasGivenUp: false,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == "Solved!")
        #expect(state.titleStyle == .solved)
        #expect(state.showsStats)
        #expect(state.message == nil)
    }

    @Test("Daily archive crossword completed after release date shows finished message and stats")
    func dailyLateCompletionShowsFinishedMessageAndStats() throws {
        let completedAt = try date("2026-05-11T10:00:00Z")
        let progress = progress(completedAt: completedAt)

        let state = CompletionDisplayState.make(
            puzzle: puzzle(date: "2026-05-10", size: 9),
            progress: progress,
            hasGivenUp: false,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == "Finished")
        #expect(state.titleStyle == .finished)
        #expect(state.showsStats)
        #expect(state.message == "Complete the puzzle on its release date to earn maximum points.")
    }

    @Test("Weekly crossword completed in release week shows solved stats")
    func weeklyOnTimeCompletionShowsSolvedStats() throws {
        let completedAt = try date("2026-05-13T10:00:00Z")
        let progress = progress(completedAt: completedAt)

        let state = CompletionDisplayState.make(
            puzzle: puzzle(date: "2026-05-10", size: 13),
            progress: progress,
            hasGivenUp: false,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == "Solved!")
        #expect(state.showsStats)
    }

    @Test("Weekly archive crossword completed after release week shows finished message and stats")
    func weeklyLateCompletionShowsFinishedMessageAndStats() throws {
        let completedAt = try date("2026-05-17T10:00:00Z")
        let progress = progress(completedAt: completedAt)

        let state = CompletionDisplayState.make(
            puzzle: puzzle(date: "2026-05-10", size: 13),
            progress: progress,
            hasGivenUp: false,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == "Finished")
        #expect(state.showsStats)
        #expect(state.message == "Complete the puzzle during its release week to earn maximum points.")
    }

    @Test("Gave up completion keeps gave up stats")
    func gaveUpCompletionKeepsGaveUpStats() throws {
        let completedAt = try date("2026-05-11T10:00:00Z")
        let progress = progress(completedAt: completedAt)

        let state = CompletionDisplayState.make(
            puzzle: puzzle(date: "2026-05-10", size: 9),
            progress: progress,
            hasGivenUp: true,
            calendar: { calendar(for: $0) }
        )

        #expect(state.title == "Gave up")
        #expect(state.titleStyle == .gaveUp)
        #expect(state.showsStats)
        #expect(state.message == nil)
    }

    private func calendar(for date: Date) -> ContentReleaseCalendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return ContentReleaseCalendar(now: date, calendar: calendar)
    }

    private func progress(completedAt: Date) -> UserProgress {
        var progress = UserProgress(puzzleId: "completion-display-test", size: 9)
        progress.startedAt = completedAt.addingTimeInterval(-120)
        progress.completedAt = completedAt
        return progress
    }

    private func puzzle(date: String, size: Int) -> Puzzle {
        Puzzle(
            id: "completion-display-puzzle-\(date)-\(size)",
            puzzleNumber: 1,
            date: date,
            size: size,
            cells: [],
            clues: []
        )
    }

    private func date(_ isoString: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        return try #require(formatter.date(from: isoString))
    }
}
