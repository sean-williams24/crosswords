import Foundation
import Testing
@testable import Backword

#if DEBUG
@Suite("Midword debug reset", .serialized)
@MainActor
struct MidwordDebugResetTests {
    @Test("Reset clears today's saved game and preserves earlier progress",
          arguments: [false, true])
    func resetTodaysProgress(completed: Bool) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = try #require(calendar.date(from: DateComponents(
            year: 2098, month: 10, day: 16, hour: 12
        )))
        let releaseCalendar = ContentReleaseCalendar(now: now)
        let today = releaseCalendar.dailyDateString
        let yesterday = try #require(releaseCalendar.dailyDateString(offsetByDays: -1))
        let puzzle = MidwordPuzzle(
            id: "debug-reset", date: today, puzzleNumber: 1,
            firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: []
        )
        var current = MidwordProgress(date: today)
        current.submit(completed ? "NOTE" : "TEST", for: puzzle, at: now)
        let previous = MidwordProgress(date: yesterday)
        defer {
            MidwordProgress.delete(date: today)
            MidwordProgress.delete(date: yesterday)
        }
        current.save()
        previous.save()
        let savedPrevious = try #require(MidwordProgress.load(date: yesterday))
        #expect(MidwordProgress.load(date: today)?.guesses == current.guesses)
        let service = MidwordService()

        service.debugResetTodaysProgress(now: now)

        #expect(MidwordProgress.load(date: today) == nil)
        #expect(MidwordProgress.load(date: yesterday) == savedPrevious)

        // Repeating the reset leaves the game ready for a fresh start.
        service.debugResetTodaysProgress(now: now)
        #expect(MidwordProgress.load(date: today) == nil)
        #expect(MidwordProgress.load(date: yesterday) == savedPrevious)
    }
}
#endif
