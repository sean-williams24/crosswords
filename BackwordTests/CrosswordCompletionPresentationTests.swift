import Foundation
import Testing
@testable import Backword

@Suite("Crossword Completion Presentation Tests")
struct CrosswordCompletionPresentationTests {
    @Test("Grid reveal order is diagonal and ignores black cells")
    func gridRevealOrderIsDiagonalAndIgnoresBlackCells() {
        let letter = CellData(letter: "A", clueNumber: nil, acrossClueId: nil, downClueId: nil)
        let black = CellData(letter: nil, clueNumber: nil, acrossClueId: nil, downClueId: nil)
        let cells = [
            [letter, letter, black],
            [letter, black, letter],
            [letter, letter, letter]
        ]

        let positions = CrosswordCompletionAnimation.revealOrder(cells: cells)

        #expect(positions.count == 7)
        #expect(positions.first == CrosswordCompletionCellPosition(row: 0, column: 0))
        #expect(positions.map(\.revealStep) == positions.map(\.revealStep).sorted())
        #expect(positions.contains(CrosswordCompletionCellPosition(row: 0, column: 2)) == false)
        #expect(CrosswordCompletionAnimation.maximumRevealStep(cells: cells) == 5)
    }

    @Test("Daily and weekly grids cover their full diagonal")
    func dailyAndWeeklyGridsCoverTheirFullDiagonal() {
        let letter = CellData(letter: "A", clueNumber: nil, acrossClueId: nil, downClueId: nil)
        let daily = Array(repeating: Array(repeating: letter, count: 9), count: 9)
        let weekly = Array(repeating: Array(repeating: letter, count: 13), count: 13)

        #expect(CrosswordCompletionAnimation.maximumRevealStep(cells: daily) == 17)
        #expect(CrosswordCompletionAnimation.maximumRevealStep(cells: weekly) == 25)
    }

    @Test("Completion outcomes select tailored animation styles")
    func completionOutcomesSelectTailoredAnimationStyles() {
        let solved = CrosswordCompletionGridStyle(titleStyle: .solved)
        let finished = CrosswordCompletionGridStyle(titleStyle: .finished)
        let gaveUp = CrosswordCompletionGridStyle(titleStyle: .gaveUp)

        #expect(solved.performsBounce)
        #expect(solved.showsSparkles)
        #expect(finished.performsBounce)
        #expect(finished.showsSparkles == false)
        #expect(gaveUp.performsBounce == false)
        #expect(gaveUp.showsSparkles == false)
    }

    @Test("Daily countdown formats hours minutes and seconds")
    func dailyCountdownFormatting() {
        #expect(CrosswordCountdownText.value(secondsRemaining: 3_661, kind: .daily) == "01:01:01")
        #expect(CrosswordCountdownText.value(secondsRemaining: nil, kind: .daily) == "--:--:--")
        #expect(CrosswordReleaseKind.daily.label == "NEXT DAILY CROSSWORD IN")
    }

    @Test("Weekly countdown formats days hours minutes and seconds")
    func weeklyCountdownFormatting() {
        #expect(CrosswordCountdownText.value(secondsRemaining: 532_323, kind: .weekly) == "6d 03:52:03")
        #expect(CrosswordCountdownText.value(secondsRemaining: nil, kind: .weekly) == "--d --:--:--")
        #expect(CrosswordReleaseKind.weekly.label == "NEXT WEEKLY CROSSWORD IN")
    }

    @Test("Daily countdown follows the next local midnight across DST")
    func dailyCountdownFollowsLocalMidnightAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-03-28T23:30:00Z"))

        #expect(CrosswordCountdownText.value(at: now, kind: .daily, calendar: calendar) == "00:30:00")
    }

    @Test("Weekly countdown follows the next local Sunday")
    func weeklyCountdownFollowsNextLocalSunday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-05-08T16:00:00Z"))

        #expect(CrosswordCountdownText.value(at: now, kind: .weekly, calendar: calendar) == "1d 12:00:00")
    }

    @Test("Finished crossword score is zero")
    func finishedCrosswordScoreIsZero() {
        #expect(CrosswordCompletionMetrics.score(
            titleStyle: .finished,
            hasGivenUp: false,
            hintsUsed: 0,
            gaveUpScore: nil,
            savedReleaseDateScore: 5
        ) == 0)
        #expect(CrosswordCompletionMetrics.score(
            titleStyle: .solved,
            hasGivenUp: false,
            hintsUsed: 3,
            gaveUpScore: nil,
            savedReleaseDateScore: nil
        ) == 4)
    }

    @Test("Completion streak uses the matching crossword type")
    func completionStreakUsesMatchingCrosswordType() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!
        var stats = UserStats()
        stats.history = [
            PuzzleResult(puzzleId: "daily", date: today, timeSeconds: 60, hintsUsed: 0),
            PuzzleResult(puzzleId: "weekly-1", date: lastWeek, timeSeconds: 120, hintsUsed: 0, isWeekly: true),
            PuzzleResult(puzzleId: "weekly-2", date: today, timeSeconds: 120, hintsUsed: 0, isWeekly: true)
        ]

        #expect(CrosswordCompletionMetrics.streak(stats: stats, isWeekly: false) == 1)
        #expect(CrosswordCompletionMetrics.streak(stats: stats, isWeekly: true) == 2)
    }
}
